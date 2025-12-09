---@diagnostic disable: undefined-field
-- Moose_CTLD_FAC.lua
--[[
Full-featured FAC/RECCE module (FAC2 parity) for pure-MOOSE CTLD, without MIST
==========================================================================
Dependencies: MOOSE (Moose.lua) and DCS core. No MIST required.

Capabilities
- AFAC/RECCE auto-detect (by group name or unit type) on Birth; per-group F10 menu
- Auto-lase (laser + IR) using DCS Spot API; configurable marker type/color; per-FAC laser code
- Manual target workflow: scan nearby, list top 10 (prioritize AA/SAM), select one, multi-strike helper
- RECCE sweeps: LoS-based scan; adds map marks with DMS/MGRS/alt/heading/speed; stores target list
- Fires & strikes: Artillery, Naval guns, Bombers/Fighters; HE/illum/mortar, guided multi-task combos
- Carpet/TALD: via menu or map marks (CBRQT/TDRQT/AttackAz <heading>)
- Event handling: Map marks (tasking), Shots (re-task), periodic schedulers (menus, status, AI spotter)

Quick start
1) Load order: Moose.lua -> Moose_CTLD.lua -> Moose_CTLD_FAC.lua
2) In mission init: local fac = _MOOSE_CTLD_FAC:New(ctld, { CoalitionSide = coalition.side.BLUE })
3) Put players in groups named with AFAC/RECON/RECCE (or use configured aircraft types)
4) Use F10 FAC/RECCE: Auto Laze ON, Scan, Select Target, Artillery, etc.

Design notes
- This module aims to match FAC2 behaviors using DCS+MOOSE equivalents; some heuristics (e.g., naval ranges)
  are conservative approximations to avoid silent failures.
]]

---@diagnostic disable: undefined-global, lowercase-global
-- MOOSE framework globals are defined at runtime by DCS World

if not _G.BASE then
  env.info('[Moose_CTLD_FAC] Moose (BASE) not detected. Ensure Moose.lua is loaded before this script.')
end

local FAC = {}
FAC.__index = FAC
FAC.Version = '1.0.1'

local LOG_NONE = 0
local LOG_ERROR = 1
local LOG_INFO = 2
local LOG_VERBOSE = 3
local LOG_DEBUG = 4

local _logLevelLabels = {
  [LOG_ERROR] = 'ERROR',
  [LOG_INFO] = 'INFO',
  [LOG_VERBOSE] = 'VERBOSE',
  [LOG_DEBUG] = 'DEBUG',
}

-- Safe deep copy: prefer MOOSE UTILS.DeepCopy when available; fallback to Lua implementation
local function _deepcopy_fallback(obj, seen)
  if type(obj) ~= 'table' then return obj end
  seen = seen or {}
  if seen[obj] then return seen[obj] end
  local res = {}
  seen[obj] = res
  for k, v in pairs(obj) do
    res[_deepcopy_fallback(k, seen)] = _deepcopy_fallback(v, seen)
  end
  local mt = getmetatable(obj)
  if mt then setmetatable(res, mt) end
  return res
end

local function DeepCopy(obj)
  if _G.UTILS and type(UTILS.DeepCopy) == 'function' then
    return UTILS.DeepCopy(obj)
  end
  return _deepcopy_fallback(obj)
end

-- Deep-merge src into dst (recursively). Arrays/lists in src replace dst.
local function DeepMerge(dst, src)
  if type(dst) ~= 'table' or type(src) ~= 'table' then return src end
  for k, v in pairs(src) do
    if type(v) == 'table' then
      local isArray = (rawget(v, 1) ~= nil)
      if isArray then
        dst[k] = DeepCopy(v)
      else
        dst[k] = DeepMerge(dst[k] or {}, v)
      end
    else
      dst[k] = v
    end
  end
  return dst
end

-- #region Config
-- Configuration for FAC behavior and UI. Adjust defaults here or pass overrides to :New().
FAC.Config = {
  CoalitionSide = coalition.side.BLUE,
  UseGroupMenus = true,
  CreateMenuAtMissionStart = false,      -- if true with UseGroupMenus=true, creates empty root menu at mission start to reserve F10 position
  RootMenuName = 'FAC/RECCE',            -- Name for the root F10 menu. Note: Menu ordering depends on script load order in mission editor.
  MenuAnnounceCooldown = 45,             -- seconds to wait before repeating the "menu ready" message for the same group
  MenuInactiveGrace = 30,                -- seconds to keep menus alive after the last player disappears (prevents thrash during slot swaps)
  LogLevel = nil,                        -- nil inherits CTLD.LogLevel; falls back to INFO when standalone

  -- Visuals / marking
  FAC_maxDistance = 18520,        -- FAC LoS search distance (m)
  FAC_smokeOn_RED = true,
  FAC_smokeOn_BLUE = true,
  FAC_smokeColour_RED = trigger.smokeColor.Blue,
  FAC_smokeColour_BLUE = trigger.smokeColor.Red,
  MarkerDefault = 'FLARES',       -- 'FLARES' | 'SMOKE'

  FAC_location = true,            -- include coords in messages
  FAC_lock = 'all',               -- 'vehicle' | 'troop' | 'all'
  FAC_laser_codes = { '1688','1677','1666','1113','1115','1111' },

  fireMissionRounds = 24,         -- default shells per call
  illumHeight = 500,              -- illumination height
  facOffsetDist = 5000,           -- offset aimpoint for mortars

  -- Platform type hints (names or types)
  facACTypes = { 'SA342L','UH-1H','Mi-8MTV2','SA342M','SA342Minigun', 'UH-60L', 'CH-47F' },
  artyDirectorTypes = { 'Soldier M249','Paratrooper AKS-74','Soldier M4' },

  -- RECCE scan
  RecceScanRadius = 40000,
  MinReportSeparation = 400,

  -- Arty tasking
  Arty = {
    Enabled = true,
  },
}
-- #endregion Config

-- #region State
-- Internal state tracking for FACs, targets, menus, and tasking
FAC._ctld = nil
FAC._menus = {}           -- [groupName] = { root = MENU_GROUP, ... }
FAC._menuAnnouncements = {} -- [groupName] = last announcement timestamp (seconds)
FAC._menuLastSeen = {}    -- [groupName] = last time the group was confirmed active
FAC._facUnits = {}        -- [unitName] = { name, side }
FAC._facOnStation = {}    -- [unitName] = true|nil
FAC._laserCodes = {}      -- [unitName] = '1688'
FAC._markerType = {}      -- [unitName] = 'FLARES'|'SMOKE'
FAC._markerColor = {}     -- [unitName] = smokeColor (0..4)
FAC._currentTargets = {}  -- [unitName] = { name, unitType, unitId }
FAC._laserSpots = {}      -- [unitName] = { ir=Spot, laser=Spot }
FAC._smokeMarks = {}      -- [targetName] = nextTime
FAC._manualLists = {}     -- [unitName] = { Unit[] }

FAC._facPilotNames = {}   -- dynamic add on Birth if name contains AFAC/RECON/RECCE or type in facACTypes
FAC._reccePilotNames = {}
FAC._artDirectNames = {}

-- Laser code reservation per coalition side: [side] = { [code] = unitName }
FAC._reservedCodes = {}

-- Coalition-level admin/help menu handle per side
FAC._coalitionMenus = {}

FAC._ArtyTasked = {}      -- [groupName] = { tasked=int, timeTasked=time, tgt=Unit|nil, requestor=string|nil }
FAC._RECCETasked = {}     -- [unitName] = 1 when busy

-- Map mark debouncing
FAC._lastMarks = {}       -- [zoneName] = { x,z }
-- #endregion State

-- #region Utilities (no MIST)
-- Helpers for logging, vectors, coordinate formatting, headings, classification, etc.
local function _currentLogLevel(self)
  if not self then return LOG_INFO end
  local lvl = self.Config and self.Config.LogLevel
  if lvl == nil and self._ctld and self._ctld.Config then
    lvl = self._ctld.Config.LogLevel
  end
  return lvl or LOG_INFO
end

local function _log(self, level, msg)
  if level <= LOG_NONE then return end
  if level > _currentLogLevel(self) then return end
  local label = _logLevelLabels[level] or tostring(level)
  env.info(string.format('[FAC][%s] %s', label, tostring(msg)))
end

local function _dbg(self, msg)
  _log(self, LOG_DEBUG, msg)
end

local function _logInfo(self, msg)
  _log(self, LOG_INFO, msg)
end

local function _in(list, value)
  if not list then return false end
  for _,v in ipairs(list) do if v == value then return true end end
  return false
end

local function _removeKey(tbl, key)
  if tbl then tbl[key] = nil end
end

local function _vec3(p)
  return { x = p.x, y = p.y or land.getHeight({ x = p.x, y = p.z or p.y or 0 }), z = p.z or p.y }
end

local function _llToDMS(lat, lon)
  -- Convert lat/lon in degrees to DMS string (e.g., 33°30'12.34"N 036°12'34.56"E)
  local function dms(v, isLat)
    local hemi = isLat and (v >= 0 and 'N' or 'S') or (v >= 0 and 'E' or 'W')
    v = math.abs(v)
    local d = math.floor(v)
    local mFloat = (v - d) * 60
    local m = math.floor(mFloat)
    local s = (mFloat - m) * 60
    return string.format('%d°%02d\'%05.2f"%s', d, m, s, hemi)
  end
  return dms(lat, true)..' '..dms(lon, false)
end

local function _mgrsToString(m)
  -- Format DCS coord.LLtoMGRS table to "XXYY 00000 00000"; fallback to key=value if shape differs
  if not m then return '' end
  -- DCS coord.LLtoMGRS returns table like: { UTMZone=XX, MGRSDigraph=YY, Easting=nnnnn, Northing=nnnnnn }
  if m.UTMZone and m.MGRSDigraph and m.Easting and m.Northing then
    return string.format('%s%s %05d %05d', tostring(m.UTMZone), tostring(m.MGRSDigraph), math.floor(m.Easting+0.5), math.floor(m.Northing+0.5))
  end
  -- fallback stringify
  local t = {}
  for k,v in pairs(m) do table.insert(t, tostring(k)..'='..tostring(v)) end
  return table.concat(t, ',')
end

local function _bearingDeg(from, to)
  local dx = (to.x - from.x)
  local dz = (to.z - from.z)
  local ang = math.deg(math.atan(dx, dz))
  if ang < 0 then ang = ang + 360 end
  return math.floor(ang + 0.5)
end

local function _distance(a, b)
  local dx = a.x - b.x
  local dz = a.z - b.z
  return math.sqrt(dx*dx + dz*dz)
end

local function _getHeading(unit)
  -- Approximate true heading using unit orientation + true north correction
  local pos = unit:getPosition()
  if pos then
    ---@diagnostic disable-next-line: deprecated
    local heading = math.atan(pos.x.z, pos.x.x)
    -- add true-north correction
    local p = pos.p
    local lat, lon = coord.LOtoLL(p)
    local northPos = coord.LLtoLO(lat + 1, lon)
    heading = heading + math.atan(northPos.z - p.z, northPos.x - p.x)
    if heading < 0 then heading = heading + 2*math.pi end
    return heading
  end
  return 0
end

local function _formatUnitGeo(u)
  -- Extracts geo/status for a unit: DMS/MGRS, altitude (m/ft), heading (deg), speed (mph)
  local p = u:getPosition().p
  local lat, lon = coord.LOtoLL(p)
  local dms = _llToDMS(lat, lon)
  local mgrs = _mgrsToString(coord.LLtoMGRS(lat, lon))
  local altM = math.floor(p.y)
  local altF = math.floor(p.y * 3.28084)
  local vel = u:getVelocity() or {x=0,y=0,z=0}
  local spd = math.sqrt((vel.x or 0)^2 + (vel.z or 0)^2)
  local mph = math.floor(spd * 2) -- approx
  local hdg = math.floor(_getHeading(u) * 180/math.pi)
  return dms, mgrs, altM, altF, hdg, mph
end

local function _isInfantry(u)
  -- Heuristic: treat named manpads/mortars as infantry
  local tn = string.lower(u:getTypeName() or '')
  return tn:find('infantry') or tn:find('paratrooper') or tn:find('stinger') or tn:find('manpad') or tn:find('mortar')
end

local function _isVehicle(u)
  return not _isInfantry(u)
end

local function _isArtilleryUnit(u)
  -- Detect tube/MLRS artillery; include mortar/howitzer/SPG by type name to cover units lacking attributes
  if u:hasAttribute('Artillery') or u:hasAttribute('MLRS') then return true end
  local tn = string.lower(u:getTypeName() or '')
  if tn:find('mortar') or tn:find('2b11') or tn:find('m252') then return true end
  if tn:find('howitzer') or tn:find('m109') or tn:find('paladin') or tn:find('2s19') or tn:find('msta') or tn:find('2s3') or tn:find('akatsiya') then return true end
  if tn:find('mlrs') or tn:find('m270') or tn:find('bm%-21') or tn:find('grad') then return true end
  return false
end

local function _isNavalUnit(u)
  -- Use DCS attributes to detect surface ships with guns capability
  return u:hasAttribute('Naval') or u:hasAttribute('Cruisers') or u:hasAttribute('Frigates') or u:hasAttribute('Corvettes') or u:hasAttribute('Landing Ships')
end

local function _isBomberOrFighter(u)
  -- Detect fixed-wing strike-capable aircraft (for carpet/guided tasks)
  return u:hasAttribute('Strategic bombers') or u:hasAttribute('Bombers') or u:hasAttribute('Multirole fighters')
end

local function _artyMaxRangeForUnit(u)
  -- Heuristic max range (meters) by unit type name; conservative to avoid "never fires" when out of range
  local tn = string.lower(u:getTypeName() or '')
  if tn:find('mortar') or tn:find('2b11') or tn:find('m252') then return 6000 end
  if tn:find('mlrs') or tn:find('m270') or tn:find('bm%-21') or tn:find('grad') then return 30000 end
  if tn:find('howitzer') or tn:find('m109') or tn:find('paladin') or tn:find('2s19') or tn:find('msta') or tn:find('2s3') or tn:find('akatsiya') then return 20000 end
  -- generic tube artillery fallback
  return 12000
end

local function _coalitionOpposite(side)
  return (side == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
end
-- #endregion Utilities (no MIST)

-- #region Construction
-- Create a new FAC module instance. Optionally pass your CTLD instance and a config override table.
function FAC:New(ctld, cfg)
  local o = setmetatable({}, self)
  o._ctld = ctld
  o.Config = DeepCopy(FAC.Config)
  if cfg then o.Config = DeepMerge(o.Config, cfg) end
  o.Side = o.Config.CoalitionSide
  o._zones = {}

  o:_wireBirth()
  o:_wireMarks()
  o:_wireShots()

  -- Schedulers for menus/status/lase loop/AI spotters
  local gcCounter = 0
  o._schedMenus = SCHEDULER:New(nil, function() o:_ensureMenus() end, {}, 5, 10)
  o._schedStatus = SCHEDULER:New(nil, function() 
    o:_checkFacStatus()
    -- Incremental GC every 60 iterations (60 seconds at 1s interval)
    gcCounter = gcCounter + 1
    if gcCounter >= 60 then
      collectgarbage('step', 100)
      gcCounter = 0
    end
  end, {}, 5, 1.0)
  o._schedAI = SCHEDULER:New(nil, function() o:_artyAICall() end, {}, 10, 30)

  -- Create placeholder menu at mission start to reserve F10 position if requested
  if o.Config.UseGroupMenus and o.Config.CreateMenuAtMissionStart then
    o.PlaceholderMenu = MENU_COALITION:New(o.Side, o.Config.RootMenuName or 'FAC/RECCE')
    MENU_COALITION_COMMAND:New(o.Side, 'Spawn in a FAC/RECCE aircraft to see options', o.PlaceholderMenu, function()
      MESSAGE:New('FAC/RECCE menus will appear when you spawn in an appropriate aircraft.', 10):ToCoalition(o.Side)
    end)
  end

  -- Only create coalition-level Admin/Help when not using per-group menus
  if not o.Config.UseGroupMenus then
    o:_ensureCoalitionMenu()
  end

  return o
end
-- #endregion Construction

-- #region Event wiring
-- Wire Birth (to detect AFAC/RECCE/Artillery Director), Map Mark handlers (tasking), and Shot events (re-tasking)
function FAC:_wireBirth()
  local h = EVENTHANDLER:New()
  h:HandleEvent(EVENTS.Birth)
  h:HandleEvent(EVENTS.Dead)
  h:HandleEvent(EVENTS.Crash)
  h:HandleEvent(EVENTS.PlayerLeaveUnit)
  local selfref = self
  function h:OnEventBirth(e)
    local unit = e.IniUnit
    if not unit or not unit:IsAlive() then return end
    if unit:GetCoalition() ~= selfref.Side then return end
    
    -- Skip if this is a static object or doesn't have GetGroup method
    if not unit.GetGroup then return end
    
    -- classify as AFAC / RECCE / Arty Director
    local name = unit:GetName()
    local tname = unit:GetTypeName()
    local g = unit:GetGroup()
    if not g then return end
    local gname = g:GetName() or name

  local isAFAC = (gname:find('AFAC') or gname:find('RECON')) or _in(selfref.Config.facACTypes, tname)
  local isRECCE = (gname:find('RECCE') or gname:find('RECON')) or _in(selfref.Config.facACTypes, tname)
  local isAD = _in(selfref.Config.artyDirectorTypes, tname)

    if isAFAC then selfref._facPilotNames[name] = true end
    if isRECCE then selfref._reccePilotNames[name] = true end
    if isAD then selfref._artDirectNames[name] = true end
  end

  local function handleDeparture(eventData)
    if not eventData then return end
    local unit = eventData.IniUnit or eventData.IniDCSUnit
    local name = eventData.IniUnitName or eventData.IniDCSUnitName
    if unit then
      selfref:_handleUnitDeparture(unit)
    elseif name then
      selfref:_handleUnitDeparture(name)
    end
  end

  function h:OnEventDead(e)
    handleDeparture(e)
  end

  function h:OnEventCrash(e)
    handleDeparture(e)
  end

  function h:OnEventPlayerLeaveUnit(e)
    handleDeparture(e)
  end
  self._hBirth = h
end

function FAC:_wireMarks()
  -- Map mark handlers for Carpet Bomb/TALD and RECCE area tasks
  local selfref = self
  self._markEH = {}
  function self._markEH:onEvent(e)
    if not e or not e.id then return end
    if e.id == world.event.S_EVENT_MARK_ADDED then
      if type(e.text) == 'string' then
        if e.text:find('CBRQT') or e.text:find('TDRQT') or e.text:find('AttackAz') then
          local az = tonumber((e.text or ''):match('(%d+)%s*$'))
          local mode = e.text:find('TDRQT') and 'TALD' or 'CARPET'
          selfref:_executeCarpetOrTALD(e.pos, e.coalition, mode, az)
          trigger.action.removeMark(e.idx)
        elseif e.text:find('RECCE') then
          selfref:_executeRecceMark(e.pos, e.coalition)
          trigger.action.removeMark(e.idx)
        end
      end
    end
  end
  world.addEventHandler(self._markEH)
end

function FAC:_wireShots()
  local selfref = self
  self._shotEH = {}
  function self._shotEH:onEvent(e)
    if e.id == world.event.S_EVENT_SHOT and e.initiator then
      local g = Unit.getGroup(e.initiator)
      if not g then return end
      local gname = g:getName()
      local T = selfref._ArtyTasked[gname]
      if T then
        T.tasked = math.max(0, (T.tasked or 0) - 1)
        if T.tasked == 0 then
          local d = g:getUnit(1):getDesc()
          trigger.action.outTextForCoalition(g:getCoalition(), (d and d.displayName or gname)..' Task Group available for re-tasking', 10)
          selfref._ArtyTasked[gname] = nil
        end
      end
    end
  end
  world.addEventHandler(self._shotEH)
end
-- #endregion Event wiring

-- #region Housekeeping
function FAC:_safeRemoveMenu(menu, reason)
  if not menu or type(menu) ~= 'table' then return end

  local shouldRemove = true
  if MENU_INDEX and menu.Group and menu.MenuText then
    local okPath, path = pcall(function()
      return MENU_INDEX:ParentPath(menu.ParentMenu, menu.MenuText)
    end)
    if okPath and path then
      local okHas, registered = pcall(function()
        return MENU_INDEX:HasGroupMenu(menu.Group, path)
      end)
      if not okHas or registered ~= menu then
        shouldRemove = false
      end
    else
      shouldRemove = false
    end
  end

  if shouldRemove and menu.Remove then
    local ok, err = pcall(function() menu:Remove() end)
    if not ok and err then
      _log(self, LOG_VERBOSE, string.format('Failed removing menu (%s): %s', tostring(reason or menu.MenuText or 'unknown'), tostring(err)))
    end
  elseif not shouldRemove then
    _log(self, LOG_DEBUG, string.format('Skip stale menu removal (%s)', tostring(reason or menu.MenuText or 'unknown')))
  end

  if menu.Destroy then pcall(function() menu:Destroy() end) end
  if menu.Delete then pcall(function() menu:Delete() end) end
end

function FAC:_cleanupMenuForGroup(gname)
  local menuSet = self._menus[gname]
  if not menuSet then return end
  for _,menu in pairs(menuSet) do
    self:_safeRemoveMenu(menu, gname)
  end
  self._menus[gname] = nil
  self._menuLastSeen[gname] = nil
end

function FAC:_pruneMenus(active)
  local now = (timer and timer.getTime and timer.getTime()) or 0
  local grace = self.Config.MenuInactiveGrace or 0
  for gname,_ in pairs(self._menus) do
    if active[gname] then
      if now > 0 then
        self._menuLastSeen[gname] = now
      end
    else
      if now > 0 then
        local last = self._menuLastSeen[gname]
        local shouldRemove = true
        if type(last) == 'number' then
          shouldRemove = (grace <= 0) or ((now - last) >= grace)
        elseif last ~= nil then
          -- Non-number sentinel: treat as recently seen.
          shouldRemove = false
        end
        if shouldRemove then
          self:_cleanupMenuForGroup(gname)
        end
      end
    end
  end
end

function FAC:_pruneManualLists()
  for uname,list in pairs(self._manualLists) do
    local alive = {}
    for _,unit in ipairs(list) do
      if unit and unit.isExist and unit:isExist() and unit:getLife() > 0 then
        alive[#alive+1] = unit
      end
    end
    self._manualLists[uname] = (#alive > 0) and alive or nil
  end
end

function FAC:_pruneSmokeMarks()
  for targetName,_ in pairs(self._smokeMarks) do
    local target = Unit.getByName(targetName)
    if not target or not target:isActive() or target:getLife() <= 1 then
      self._smokeMarks[targetName] = nil
    end
  end
end

function FAC:_pruneArtyTasked()
  local now = timer.getTime()
  for gname,info in pairs(self._ArtyTasked) do
    local g = Group.getByName(gname)
    local staleTime = info and info.timeTasked and (now - info.timeTasked > 900)
    local noTasks = not info or (info.tasked or 0) <= 0
    if not g or not g:isExist() or staleTime or noTasks then
      self._ArtyTasked[gname] = nil
    end
  end
end

function FAC:_unregisterPilotName(uname)
  _removeKey(self._facPilotNames, uname)
  _removeKey(self._reccePilotNames, uname)
  _removeKey(self._artDirectNames, uname)
end

function FAC:_handleUnitDeparture(unitOrName)
  local uname
  if type(unitOrName) == 'string' then
    uname = unitOrName
  elseif unitOrName then
    if unitOrName.GetName then
      uname = unitOrName:GetName()
    elseif unitOrName.getName then
      uname = unitOrName:getName()
    end
  end
  if not uname then return end
  self:_cleanupFac(uname)
end
-- #endregion Housekeeping

-- #region Zone-based RECCE (optional)
-- Add a named or coordinate-based zone for periodic DETECTION_AREAS scans
function FAC:AddRecceZone(def)
  local z
  if def.name then z = ZONE:FindByName(def.name) end
  if not z and def.coord then
    local r = def.radius or 5000
    local v2 = (VECTOR2 and VECTOR2.New) and VECTOR2:New(def.coord.x, def.coord.z) or { x = def.coord.x, y = def.coord.z }
    z = ZONE_RADIUS:New(def.name or ('FAC_ZONE_'..math.random(10000,99999)), v2, r)
  end
  if not z then return nil end
  local enemySide = _coalitionOpposite(self.Side)
  local setEnemies = SET_GROUP:New():FilterCoalitions(enemySide):FilterCategoryGround():FilterStart()
  local det = DETECTION_AREAS:New(setEnemies, z:GetRadius())
  det:BoundZone(z)
  local Z = { Zone = z, Name = z:GetName(), Detector = det, LastScan = 0 }
  table.insert(self._zones, Z)
  return Z
end

function FAC:RunZones(interval)
  -- Start/Restart periodic scans of configured recce zones
  if self._zoneSched then self._zoneSched:Stop() end
  self._zoneSched = SCHEDULER:New(nil, function()
    for _,Z in ipairs(self._zones) do self:_scanZone(Z) end
  end, {}, 5, interval or 20)
end

-- Backwards-compatible Run() entry point used by init scripts
function FAC:Run()
  -- Schedulers for menus/status are started in New(); here we can kick off zone scans if any zones exist.
  if #self._zones > 0 then self:RunZones() end
  return self
end

function FAC:_scanZone(Z)
  -- Perform one detection update and mark contacts, with spatial de-duplication
  Z.Detector:DetectionUpdate()
  local reps = Z.Detector:GetDetectedItems() or {}
  for _,rep in ipairs(reps) do
    local pos2 = rep.point
    if pos2 then
      local point = { x = pos2.x, z = pos2.y }
      local last = self._lastMarks[Z.Name]
      if not last or _distance(point, last) >= (self.Config.MinReportSeparation or 400) then
        self._lastMarks[Z.Name] = { x = point.x, z = point.z }
        self:_markPoint(nil, point, rep.type or 'Contact')
      end
    end
  end
end
-- #endregion Zone-based RECCE (optional)

-- #region Menus
-- Ensure per-group menus exist for active coalition player groups
function FAC:_unitEligibleForFac(unit)
  if not unit then return false end
  local uname = (unit.GetName and unit:GetName()) or (unit.getName and unit:getName())
  if uname then
    if self._facPilotNames[uname] or self._reccePilotNames[uname] or self._artDirectNames[uname] then
      return true
    end
  end

  local tname = (unit.GetTypeName and unit:GetTypeName()) or (unit.getTypeName and unit:getTypeName())
  if tname then
    if _in(self.Config.facACTypes, tname) or _in(self.Config.artyDirectorTypes, tname) then
      return true
    end
  end

  local grp = (unit.GetGroup and unit:GetGroup()) or (unit.getGroup and unit:getGroup())
  local gname = grp and ((grp.GetName and grp:GetName()) or (grp.getName and grp:getName())) or nil
  if type(gname) == 'string' then
    if gname:find('AFAC') or gname:find('RECCE') or gname:find('RECON') then
      return true
    end
  end

  return false
end

function FAC:_groupEligibleForFacMenus(group)
  if not group or not group:IsAlive() then return false end
  local units = group:GetUnits()
  if type(units) ~= 'table' then
    local single = group:GetUnit(1)
    if single then
      return self:_unitEligibleForFac(single)
    end
    return false
  end
  for _,u in ipairs(units) do
    if self:_unitEligibleForFac(u) then
      return true
    end
  end
  return false
end

function FAC:_ensureMenus()
  if not self.Config.UseGroupMenus then return end
  local players = coalition.getPlayers(self.Side) or {}
  local active = {}
  local now = (timer and timer.getTime and timer.getTime()) or 0
  for _,u in ipairs(players) do
    local dg = u:getGroup()
    if dg then
      local gname = dg:getName()
      local mg = GROUP:FindByName(gname)
      if mg then
        local eligible = self:_groupEligibleForFacMenus(mg)
        active[gname] = true
        if now > 0 then
          self._menuLastSeen[gname] = now
        else
          self._menuLastSeen[gname] = self._menuLastSeen[gname] or 0
        end
        local existing = self._menus[gname]
        local needsRefresh = not existing or (existing.role == 'fac' and not eligible) or (existing.role == 'observer' and eligible)
        if needsRefresh then
          if existing then
            self:_cleanupMenuForGroup(gname)
          end
          local menuSet
          if eligible then
            menuSet = self:_buildGroupMenus(mg)
            if menuSet then menuSet.role = 'fac' end
          else
            menuSet = self:_buildObserverMenu(mg)
            if menuSet then menuSet.role = 'observer' end
          end
          if menuSet then
            self._menus[gname] = menuSet
            self:_announceMenuReady(mg)
          else
            _log(self, LOG_ERROR, string.format('FAC menu creation returned nil for group %s', tostring(gname)))
          end
        end
      end
    end
  end
  self:_pruneMenus(active)
end

function FAC:_ensureCoalitionMenu()
  if self.Config.UseGroupMenus then return end
  -- Create a coalition-level Admin/Help menu, nested under a FAC parent (not at F10 root)
  if self._coalitionMenus[self.Side] then return end
  self._coalitionRoot = self._coalitionRoot or {}
  -- Create or reuse the coalition-level parent menu for FAC
  self._coalitionRoot[self.Side] = self._coalitionRoot[self.Side] or MENU_COALITION:New(self.Side, 'FAC/RECCE Admin')
  local parent = self._coalitionRoot[self.Side]
  local root = MENU_COALITION:New(self.Side, 'Admin/Help', parent)
  MENU_COALITION_COMMAND:New(self.Side, 'Show FAC Codes In Use', root, function()
    self:_showCodesCoalition()
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Set FAC Log Level: DEBUG', root, function()
    self.Config.LogLevel = LOG_DEBUG
    _logInfo(self, string.format('Log level set to DEBUG via coalition admin menu (%s)', tostring(self.Side)))
    trigger.action.outTextForCoalition(self.Side, 'FAC log level set to DEBUG', 8)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Set FAC Log Level: INFO', root, function()
    self.Config.LogLevel = LOG_INFO
    _logInfo(self, string.format('Log level set to INFO via coalition admin menu (%s)', tostring(self.Side)))
    trigger.action.outTextForCoalition(self.Side, 'FAC log level set to INFO', 8)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Inherit CTLD Log Level', root, function()
    self.Config.LogLevel = nil
    _logInfo(self, string.format('Log level inheritance restored via coalition admin menu (%s)', tostring(self.Side)))
    trigger.action.outTextForCoalition(self.Side, 'FAC log level now inherits CTLD setting', 8)
  end)
  self._coalitionMenus[self.Side] = root
end

function FAC:_announceMenuReady(group)
  if not group or not group.GetName then return end
  local gname = group:GetName()
  if not gname or gname == '' then return end

  self._menuAnnouncements = self._menuAnnouncements or {}
  local now = (timer and timer.getTime and timer.getTime()) or 0
  local last = self._menuAnnouncements[gname]
  local cooldown = self.Config.MenuAnnounceCooldown or 45

  local shouldAnnounce = false

  if not last then
    shouldAnnounce = true
  elseif type(last) == 'number' and now > 0 then
    shouldAnnounce = (now - last) >= cooldown
  elseif type(last) ~= 'number' then
    shouldAnnounce = true
  end

  if shouldAnnounce then
    MESSAGE:New('FAC/RECCE menu ready (F10)', 10):ToGroup(group)
    if now > 0 then
      self._menuAnnouncements[gname] = now
    else
      self._menuAnnouncements[gname] = true
    end
  elseif (not last or type(last) ~= 'number') and now > 0 then
    -- Backfill numeric timestamp once timer API becomes available
    self._menuAnnouncements[gname] = now
  end
end

function FAC:_buildGroupMenus(group)
  -- Build the entire FAC/RECCE menu tree for a MOOSE GROUP
  if not group or not group:IsAlive() then return nil end
  local gname = group:GetName()
  local root = MENU_GROUP:New(group, self.Config.RootMenuName or 'FAC/RECCE')
  if not root then
    _log(self, LOG_ERROR, string.format('Failed to create FAC menu for group %s (MENU_GROUP:New returned nil)', tostring(gname)))
    return nil
  end
  _log(self, LOG_INFO, string.format('FAC menu built for group %s', tostring(gname)))
  -- Safe menu command helper: wraps callbacks to avoid silent errors and report to group
  local function CMD(title, parent, cb)
    return MENU_GROUP_COMMAND:New(group, title, parent, function()
      local ok, err = pcall(cb)
      if not ok then
        env.info('[FAC] Menu error: '..tostring(err))
        MESSAGE:New('FAC menu error: '..tostring(err), 8):ToGroup(group)
      end
    end)
  end

  -- Status & On-Station
  CMD('FAC: Status', root, function() self:_showFacStatus(group) end)

  local tgtRoot = MENU_GROUP:New(group, 'Targeting Mode', root)
  CMD('Auto Laze ON', tgtRoot, function() self:_setOnStation(group, true) end)
  CMD('Auto Laze OFF', tgtRoot, function() self:_setOnStation(group, nil) end)
  CMD('Scan for Close Targets', tgtRoot, function() self:_scanManualList(group) end)
  local selRoot = MENU_GROUP:New(group, 'Select Found Target', tgtRoot)
  for i=1,10 do
  CMD('Target '..i, selRoot, function() self:_setManualTarget(group, i) end)
  end
  CMD('Call arty on all manual targets', tgtRoot, function() self:_multiStrike(group) end)

  -- Laser codes
  local lzr = MENU_GROUP:New(group, 'Laser Code', root)
  for _,code in ipairs(self.Config.FAC_laser_codes) do
    CMD(code, lzr, function() self:_setLaserCode(group, code) end)
  end
  local cust = MENU_GROUP:New(group, 'Custom Code', lzr)
  local function addDigitMenu(d, max)
    local m = MENU_GROUP:New(group, 'Digit '..d, cust)
    for n=1,max do
      CMD(tostring(n), m, function() self:_setLaserDigit(group, d, n) end)
    end
  end
  addDigitMenu(1,1); addDigitMenu(2,6); addDigitMenu(3,8); addDigitMenu(4,8)

  -- Marker
  local mk = MENU_GROUP:New(group, 'Marker', root)
  local sm = MENU_GROUP:New(group, 'Smoke', mk)
  local fl = MENU_GROUP:New(group, 'Flares', mk)
  local function setM(typeName, color)
    return function() self:_setMarker(group, typeName, color) end
  end
  CMD('GREEN', sm, setM('SMOKE', trigger.smokeColor.Green))
  CMD('RED', sm, setM('SMOKE', trigger.smokeColor.Red))
  CMD('WHITE', sm, setM('SMOKE', trigger.smokeColor.White))
  CMD('ORANGE', sm, setM('SMOKE', trigger.smokeColor.Orange))
  CMD('BLUE', sm, setM('SMOKE', trigger.smokeColor.Blue))
  CMD('GREEN', fl, setM('FLARES', trigger.smokeColor.Green))
  CMD('WHITE', fl, setM('FLARES', trigger.smokeColor.White))
  CMD('ORANGE', fl, setM('FLARES', trigger.smokeColor.Orange))
  CMD('Map Marker current target', mk, function() self:_setMapMarker(group) end)

  -- Artillery
  local arty = MENU_GROUP:New(group, 'Artillery', root)
  CMD('Check available arty', arty, function() self:_checkArty(group) end)
  CMD('Call Fire Mission (HE)', arty, function() self:_callFireMission(group, self.Config.fireMissionRounds, 0) end)
  CMD('Call Illumination', arty, function() self:_callFireMission(group, self.Config.fireMissionRounds, 1) end)
  CMD('Call Mortar Only (anti-infantry)', arty, function() self:_callFireMission(group, self.Config.fireMissionRounds, 2) end)
  CMD('Call Heavy Only (no smart)', arty, function() self:_callFireMission(group, 10, 3) end)

  local air = MENU_GROUP:New(group, 'Air/Naval', arty)
  CMD('Single Target (GPS/Guided)', air, function() self:_callFireMission(group, 1, 4) end)
  CMD('Multi Target (Guided only)', air, function() self:_callFireMissionMulti(group, 1, 4) end)
  CMD('Carpet Bomb (attack heading = aircraft heading)', air, function() self:_callCarpetOnCurrent(group) end)

  -- RECCE
  CMD('RECCE: Sweep & Mark', root, function() self:_recceDetect(group) end)

  -- Admin/Help (nested inside FAC/RECCE group menu when using group menus)
  local admin = MENU_GROUP:New(group, 'Admin/Help', root)
  CMD('Show FAC Codes In Use', admin, function() self:_showCodesCoalition() end)
  CMD('Set FAC Log Level: DEBUG', admin, function()
    self.Config.LogLevel = LOG_DEBUG
    _logInfo(self, string.format('Log level set to DEBUG via group admin menu (%s)', group:GetName()))
    MESSAGE:New('FAC log level set to DEBUG', 8):ToGroup(group)
  end)
  CMD('Set FAC Log Level: INFO', admin, function()
    self.Config.LogLevel = LOG_INFO
    _logInfo(self, string.format('Log level set to INFO via group admin menu (%s)', group:GetName()))
    MESSAGE:New('FAC log level set to INFO', 8):ToGroup(group)
  end)
  CMD('Inherit CTLD Log Level', admin, function()
    self.Config.LogLevel = nil
    _logInfo(self, string.format('Log level inheritance restored via group admin menu (%s)', group:GetName()))
    MESSAGE:New('FAC log level now inherits CTLD setting', 8):ToGroup(group)
  end)

  -- Log-level controls (mission-maker convenience; per-instance toggle)
  local dbg = MENU_GROUP:New(group, 'Log Level', root)
  CMD('Set Log Level: DEBUG', dbg, function()
    self.Config.LogLevel = LOG_DEBUG
    local u = group:GetUnit(1); local who = (u and u:GetName()) or 'Unknown'
    _logInfo(self, string.format('Log level set to DEBUG by %s', who))
    MESSAGE:New('FAC log level set to DEBUG', 8):ToGroup(group)
  end)
  CMD('Set Log Level: INFO', dbg, function()
    self.Config.LogLevel = LOG_INFO
    local u = group:GetUnit(1); local who = (u and u:GetName()) or 'Unknown'
    _logInfo(self, string.format('Log level set to INFO by %s', who))
    MESSAGE:New('FAC log level set to INFO', 8):ToGroup(group)
  end)
  CMD('Inherit from CTLD', dbg, function()
    self.Config.LogLevel = nil
    local u = group:GetUnit(1); local who = (u and u:GetName()) or 'Unknown'
    _logInfo(self, string.format('Log level inheritance restored by %s', who))
    MESSAGE:New('FAC log level now inherits CTLD setting', 8):ToGroup(group)
  end)
  return { root = root }
end

function FAC:_buildObserverMenu(group)
  if not group or not group:IsAlive() then return nil end
  local gname = group:GetName()
  local root = MENU_GROUP:New(group, self.Config.RootMenuName or 'FAC/RECCE')
  if not root then
    _log(self, LOG_ERROR, string.format('Failed to create observer FAC menu for group %s', tostring(gname)))
    return nil
  end

  local function CMD(title, cb)
    return MENU_GROUP_COMMAND:New(group, title, root, function()
      local ok, err = pcall(cb)
      if not ok then
        env.info('[FAC] Observer menu error: '..tostring(err))
        MESSAGE:New('FAC observer menu error: '..tostring(err), 8):ToGroup(group)
      end
    end)
  end

  CMD('Show Active FAC/RECCE Controllers', function() self:_showFacStatus(group) end)
  CMD('Show FAC Codes In Use', function() self:_showCodesCoalition() end)
  CMD('FAC/RECCE Help', function()
    local types = self.Config.facACTypes or {}
    local typeList = (#types > 0) and table.concat(types, ', ') or 'see mission briefing'

    local laserCodes = self.Config.FAC_laser_codes or {'1688'}
    local defaultCode = laserCodes[1] or '1688'
    local allCodes = table.concat(laserCodes, ', ')

    local maxDist = tostring(self.Config.FAC_maxDistance or 18520)
    local rootName = self.Config.RootMenuName or 'FAC/RECCE'
    local markerDefault = self.Config.MarkerDefault or 'FLARES'

    local msg = table.concat({
      'FAC/RECCE Overview:',
      '',
      '- This module lets certain aircraft act as an airborne JTAC / artillery spotter.',
      '- To get the FAC menu, you must be in a group named with AFAC/RECCE/RECON,',
      '  or flying one of the approved FAC aircraft types (' .. typeList .. ').',
      '',
      'Basic Usage:',
      '- Open the F10 radio menu and look for "' .. rootName .. '".',
      '- Use "Auto Laze ON" to have the module automatically search for and lase nearby enemy targets.',
      '- Use "Scan for Close Targets" then "Select Found Target" to manually pick a target from a list.',
      '- Use "RECCE: Sweep & Mark" to scan a larger area and drop map markers on detected contacts.',
      '',
      'Laser Codes:',
      '- Default FAC laser code: ' .. defaultCode .. '.',
      '- Allowed codes: ' .. allCodes .. '.',
      '- Use the "Laser Code" submenu to change your code if another FAC is already using it.',
      '- The module will try to avoid code conflicts and will notify you if a different code is assigned.',
      '',
      'Markers & Smoke:',
      '- Default marker type: ' .. markerDefault .. '.',
      '- FAC can mark the current target with smoke or flares in different colors.',
      '- Use the "Marker" submenu to choose SMOKE or FLARES and a color for your marks.',
      '',
      'Range & Line of Sight:',
      '- FAC search range is about ' .. maxDist .. ' meters (~10 NM).',
      '- Targets must be within line-of-sight; hills and terrain can block detection and lasing.',
      '',
      'Artillery & Air Support:',
      '- The "Artillery" and "Air/Naval" menus look for AI units on your side that can fire on the target.',
      '- If no suitable unit is in range or has ammo, the module will tell you.',
      '- Guided/air/naval options require appropriate AI aircraft or ships placed by the mission designer.',
      '',
      'If you do not see FAC menus:',
      '- Check that your group name contains AFAC/RECCE/RECON, or you are flying a supported FAC aircraft type.',
      '- Make sure Moose.lua, Moose_CTLD.lua, and Moose_CTLD_FAC.lua are all loaded in the mission (in that order).',
    }, '\n')

    MESSAGE:New(msg, 30):ToGroup(group)
  end)

  return { root = root }
end
-- #endregion Menus

-- #region Status & On-station
function FAC:_facName(unitName)
  local u = Unit.getByName(unitName)
  if u and u:getPlayerName() then return u:getPlayerName() end
  return unitName
end

function FAC:_showFacStatus(group)
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  local side = unit:GetCoalition()
  local colorToStr = { [trigger.smokeColor.Green]='GREEN',[trigger.smokeColor.Red]='RED',[trigger.smokeColor.White]='WHITE',[trigger.smokeColor.Orange]='ORANGE',[trigger.smokeColor.Blue]='BLUE' }
  local msg = 'FAC STATUS:\n\n'
  for uname,_ in pairs(self._facUnits) do
    local u = Unit.getByName(uname)
    if u and u:getLife()>0 and u:isActive() and u:getCoalition()==side and self._facOnStation[uname] then
      local tgt = self._currentTargets[uname]
      local lcd = self._laserCodes[uname] or 'UNKNOWN'
      local marker = self._markerType[uname] or self.Config.MarkerDefault
      local mcol = self._markerColor[uname]
      local mcolStr = mcol and (colorToStr[mcol] or tostring(mcol)) or 'WHITE'
      if tgt then
        local eu = Unit.getByName(tgt.name)
        if eu and eu:isActive() and eu:getLife()>0 then
          msg = msg .. string.format('%s targeting %s CODE %s %s\nMarked %s %s\n', self:_facName(uname), eu:getTypeName(), lcd, self:_posString(eu), mcolStr, marker)
        else
          msg = msg .. string.format('%s on-station CODE %s\n', self:_facName(uname), lcd)
        end
      else
        msg = msg .. string.format('%s on-station CODE %s\n', self:_facName(uname), lcd)
      end
    end
  end
  if msg == 'FAC STATUS:\n\n' then
    msg = 'No Active FACs. Join AFAC/RECON to play as flying JTAC and Artillery Spotter.'
  end
  trigger.action.outTextForCoalition(side, msg, 20)
end

function FAC:_posString(u)
  -- Render a compact position string for messages
  if not self.Config.FAC_location then return '' end
  local p = u:getPosition().p
  local lat, lon = coord.LOtoLL(p)
  local dms = _llToDMS(lat, lon)
  local mgrs = _mgrsToString(coord.LLtoMGRS(lat, lon))
  local altM = math.floor(p.y)
  local altF = math.floor(p.y*3.28084)
  return string.format('@ DMS %s MGRS %s Alt %dm/%dft', dms, mgrs, altM, altF)
end

function FAC:_setOnStation(group, on)
  local u = group:GetUnit(1)
  if not u or not u:IsAlive() then return end
  if not self:_unitEligibleForFac(u) then
    MESSAGE:New('FAC controls unavailable for this aircraft type.', 10):ToGroup(group)
    return
  end
  local uname = u:GetName()
  _dbg(self, string.format('Action:SetOnStation unit=%s on=%s', uname, tostring(on and true or false)))
  -- init defaults
  if not self._laserCodes[uname] then
    -- Assign a free code on first-time activation
    local code = self:_assignFreeCode(u:GetCoalition(), uname)
    self._laserCodes[uname] = code or (self.Config.FAC_laser_codes and self.Config.FAC_laser_codes[1]) or '1688'
  end
  if not self._markerType[uname] then self._markerType[uname] = self.Config.MarkerDefault end
  if not self._facUnits[uname] then self._facUnits[uname] = { name = uname, side = u:GetCoalition() } end

  if not self._facOnStation[uname] and on then
    trigger.action.outTextForCoalition(u:GetCoalition(), string.format('[FAC "%s" on-station using CODE %s]', self:_facName(uname), self._laserCodes[uname]), 10)
  elseif self._facOnStation[uname] and not on then
    trigger.action.outTextForCoalition(u:GetCoalition(), string.format('[FAC "%s" off-station]', self:_facName(uname)), 10)
    self:_cleanupFac(uname, true)
  end
  if on then
    self._facOnStation[uname] = true
    -- start autolase one-shot; the status scheduler keeps it alive every 1s
    self:_autolase(uname)
  else
    self._facOnStation[uname] = nil
  end
end

function FAC:_setLaserCode(group, code)
  -- Set the laser code for this FAC; updates status if on-station
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  _dbg(self, string.format('Action:SetLaserCode unit=%s code=%s', uname, tostring(code)))
  -- Enforce simple reservation: reassign if taken
  local assigned = self:_reserveCode(u:GetCoalition(), uname, tostring(code))
  self._laserCodes[uname] = assigned
  if self._facOnStation[uname] then
    trigger.action.outTextForCoalition(u:GetCoalition(), string.format('[FAC "%s" on-station using CODE %s]', self:_facName(uname), self._laserCodes[uname]), 10)
  end
end

function FAC:_setLaserDigit(group, digit, val)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  _dbg(self, string.format('Action:SetLaserDigit unit=%s digit=%d val=%s', uname, digit, tostring(val)))
  local cur = self._laserCodes[uname] or '1688'
  local s = tostring(cur)
  if #s ~= 4 then s = '1688' end
  local pre = s:sub(1, digit-1)
  local post = s:sub(digit+1)
  s = pre .. tostring(val) .. post
  self:_setLaserCode(group, s)
end

function FAC:_setMarker(group, typ, color)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  _dbg(self, string.format('Action:SetMarker unit=%s type=%s color=%s', uname, tostring(typ), tostring(color)))
  self._markerType[uname] = typ
  self._markerColor[uname] = color
  local colorStr = ({[trigger.smokeColor.Green]='GREEN',[trigger.smokeColor.Red]='RED',[trigger.smokeColor.White]='WHITE',[trigger.smokeColor.Orange]='ORANGE',[trigger.smokeColor.Blue]='BLUE'})[color] or 'WHITE'
  if self._facOnStation[uname] then
    trigger.action.outTextForCoalition(u:GetCoalition(), string.format('[FAC "%s" on-station marking with %s %s]', self:_facName(uname), colorStr, typ), 10)
  else
    MESSAGE:New('Marker set to '..colorStr..' '..typ, 10):ToGroup(group)
  end
end

function FAC:_setMapMarker(group)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  local tgt = self._currentTargets[uname]
  if not tgt then MESSAGE:New('No Target to Mark', 10):ToGroup(group); return end
  local t = Unit.getByName(tgt.name)
  if not t or not t:isActive() then return end
  _dbg(self, string.format('Action:MapMarker unit=%s target=%s', uname, tgt.name))
  local dms, mgrs, altM, altF, hdg, mph = _formatUnitGeo(t)
  local text = string.format('%s - DMS %s Alt %dm/%dft\nHeading %d Speed %d MPH\nSpotted by %s', t:getTypeName(), dms, altM, altF, hdg, mph, self:_facName(uname))
  local id = math.floor(timer.getTime()*1000 + 0.5)
  trigger.action.markToCoalition(id, text, t:getPoint(), u:GetCoalition(), false)
  timer.scheduleFunction(function(idp) trigger.action.removeMark(idp) end, id, timer.getTime() + 300)
end
-- #endregion Status & On-station

-- #region Auto-lase loop & target selection
function FAC:_checkFacStatus()
  self:_pruneManualLists()
  self:_pruneSmokeMarks()
  self:_pruneArtyTasked()
  -- Autostart for AI FACs and run autolase cadence
  for uname,_ in pairs(self._facPilotNames) do
    local u = Unit.getByName(uname)
    if u and u:isActive() and u:getLife()>0 then
      if not self._facUnits[uname] and (u:getPlayerName() == nil) then
        self._facOnStation[uname] = true
      end
      if (not self._facUnits[uname]) and self._facOnStation[uname] then
        self:_autolase(uname)
      end
    end
  end
end

function FAC:_autolase(uname)
  local u = Unit.getByName(uname)
  if not u then
    if self._facUnits[uname] then
      trigger.action.outTextForCoalition(self._facUnits[uname].side, string.format('[FAC "%s" MIA]', self:_facName(uname)), 10)
    end
    self:_cleanupFac(uname)
    return
  end
  if not self._facOnStation[uname] then self:_cancelLase(uname); self._currentTargets[uname]=nil; return end
  if not self._laserCodes[uname] then self._laserCodes[uname] = self.Config.FAC_laser_codes[1] end
  if not self._facUnits[uname] then self._facUnits[uname] = { name = u:getName(), side = u:getCoalition() } end
  if not self._markerType[uname] then self._markerType[uname] = self.Config.MarkerDefault end

  if not u:isActive() then
    timer.scheduleFunction(function(args) self:_autolase(args[1]) end, {uname}, timer.getTime()+30)
    return
  end

  local enemy = self:_currentOrFindEnemy(u, uname)
  if enemy then
    _dbg(self, string.format('AutoLase: unit=%s target=%s type=%s', uname, enemy:getName(), enemy:getTypeName()))
    self:_laseUnit(enemy, u, uname, self._laserCodes[uname])
    -- variable next tick based on target speed
    local v = enemy:getVelocity() or {x=0,z=0}
    local spd = math.sqrt((v.x or 0)^2 + (v.z or 0)^2)
    local next = (spd < 1) and 1 or 1/spd
    timer.scheduleFunction(function(args) self:_autolase(args[1]) end, {uname}, timer.getTime()+next)
    -- markers recurring
    local nm = self._smokeMarks[enemy:getName()]
    if not nm or nm < timer.getTime() then self:_createMarker(enemy, uname) end
  else
    _dbg(self, string.format('AutoLase: unit=%s no-visible-target -> cancel', uname))
    self:_cancelLase(uname)
    timer.scheduleFunction(function(args) self:_autolase(args[1]) end, {uname}, timer.getTime()+5)
  end
end

function FAC:_currentOrFindEnemy(facUnit, uname)
  local cur = self._currentTargets[uname]
  if cur then
    local eu = Unit.getByName(cur.name)
    if eu and eu:isActive() and eu:getLife()>0 then
      local d = _distance(eu:getPoint(), facUnit:getPoint())
      if d < (self.Config.FAC_maxDistance or 18520) then
        local epos = eu:getPoint()
        if land.isVisible({x=epos.x,y=epos.y+2,z=epos.z}, {x=facUnit:getPoint().x,y=facUnit:getPoint().y+2,z=facUnit:getPoint().z}) then
          return eu
        end
      end
    end
  end
  -- find nearest visible
  _dbg(self, string.format('FindNearest: unit=%s mode=%s', uname, tostring(self.Config.FAC_lock)))
  return self:_findNearestEnemy(facUnit, self.Config.FAC_lock)
end

function FAC:_findNearestEnemy(facUnit, targetType)
  local facSide = facUnit:getCoalition()
  local enemySide = _coalitionOpposite(facSide)
  local nearest, best = nil, self.Config.FAC_maxDistance or 18520
  local origin = facUnit:getPoint()
  _dbg(self, string.format('Search: origin=(%.0f,%.0f) radius=%d targetType=%s', origin.x, origin.z, self.Config.FAC_maxDistance or 18520, tostring(targetType)))

  local volume = { id = world.VolumeType.SPHERE, params = { point = origin, radius = self.Config.FAC_maxDistance or 18520 } }
  local function search(u)
    if u:getLife() <= 1 or u:inAir() then return end
    if u:getCoalition() ~= enemySide then return end
    local up = u:getPoint()
    local d = _distance(up, origin)
    if d >= best then return end
    local allowed = true
    if targetType == 'vehicle' then
      allowed = _isVehicle(u) and true or false
    elseif targetType == 'troop' then
      allowed = _isInfantry(u) and true or false
    end
    if not allowed then return end
    if land.isVisible({x=up.x,y=up.y+2,z=up.z}, {x=origin.x,y=origin.y+2,z=origin.z}) and u:isActive() then
      best = d; nearest = u
    end
  end
  world.searchObjects(Object.Category.UNIT, volume, search)
  if nearest then
    local uname = facUnit:getName()
    self._currentTargets[uname] = { name = nearest:getName(), unitType = nearest:getTypeName(), unitId = nearest:getID() }
    self:_announceNewTarget(facUnit, nearest, uname)
    self:_createMarker(nearest, uname)
    _dbg(self, string.format('Search: selected target=%s type=%s dist=%.0f', nearest:getName(), nearest:getTypeName(), best))
  end
  return nearest
end

function FAC:_announceNewTarget(facUnit, enemy, uname)
  local col = self._markerColor[uname]
  local colorStr = ({[trigger.smokeColor.Green]='GREEN',[trigger.smokeColor.Red]='RED',[trigger.smokeColor.White]='WHITE',[trigger.smokeColor.Orange]='ORANGE',[trigger.smokeColor.Blue]='BLUE'})[col or trigger.smokeColor.White] or 'WHITE'
  local dms, mgrs, altM, altF, hdg, mph = _formatUnitGeo(enemy)
  _dbg(self, string.format('AnnounceTarget: fac=%s target=%s code=%s mark=%s %s', self:_facName(uname), enemy:getName(), self._laserCodes[uname] or '1688', colorStr, self._markerType[uname] or 'FLARES'))
  local msg = string.format('[%s lasing new target %s. CODE %s @ DMS %s MGRS %s Alt %dm/%dft\nMarked %s %s]',
    self:_facName(uname), enemy:getTypeName(), self._laserCodes[uname] or '1688', dms, mgrs, altM, altF, colorStr, self._markerType[uname] or 'FLARES')
  trigger.action.outTextForCoalition(facUnit:getCoalition(), msg, 10)
end

function FAC:_createMarker(enemy, uname)
  local typ = self._markerType[uname] or self.Config.MarkerDefault
  local col = self._markerColor[uname]
  local when = (typ == 'SMOKE') and 300 or 5
  self._smokeMarks[enemy:getName()] = timer.getTime() + when
  local p = enemy:getPoint()
  _dbg(self, string.format('CreateMarker: target=%s type=%s color=%s ttl=%.0fs', enemy:getName(), typ, tostring(col or trigger.smokeColor.White), when))
  if typ == 'SMOKE' then
    trigger.action.smoke({x=p.x, y=p.y+2, z=p.z}, col or trigger.smokeColor.White)
  else
    trigger.action.signalFlare({x=p.x, y=p.y+2, z=p.z}, col or trigger.smokeColor.White, 0)
  end
end

function FAC:_cancelLase(uname)
  local S = self._laserSpots[uname]
  if S then
    if S.ir then Spot.destroy(S.ir) end
    if S.laser then Spot.destroy(S.laser) end
    self._laserSpots[uname] = nil
  end
end

function FAC:_laseUnit(enemy, facUnit, uname, code)
  local p = enemy:getPoint()
  local tgt = { x=p.x, y=p.y+2, z=p.z }
  local spots = self._laserSpots[uname]
  if not spots then
    spots = {}
    local ok, res = pcall(function()
      spots.ir = Spot.createInfraRed(facUnit, {x=0,y=2,z=0}, tgt)
      spots.laser = Spot.createLaser(facUnit, {x=0,y=2,z=0}, tgt, tonumber(code) or 1688)
      return spots
    end)
    if ok then
      self._laserSpots[uname] = spots
    else
      env.error('[FAC] Spot creation failed: '..tostring(res))
    end
  else
    if spots.ir then spots.ir:setPoint(tgt) end
    if spots.laser then spots.laser:setPoint(tgt) end
  end
end

function FAC:_cleanupFac(uname, preserveRole)
  if not uname then return end
  local current = self._currentTargets[uname]
  if current and current.name then
    self._smokeMarks[current.name] = nil
  end
  self:_cancelLase(uname)
  self._laserCodes[uname] = nil
  self._markerType[uname] = nil
  self._markerColor[uname] = nil
  self._manualLists[uname] = nil
  self._laserSpots[uname] = nil
  self._currentTargets[uname] = nil
  if not preserveRole then
    self:_unregisterPilotName(uname)
  end
  -- release reserved code if any
  local side = (self._facUnits[uname] and self._facUnits[uname].side) or self.Side
  if side then self:_releaseCode(side, uname) end
  self._facUnits[uname] = nil
  self._facOnStation[uname] = nil
end

-- #endregion Auto-lase loop & target selection

-- #region Manual Scan/Select
-- Manual Scan/Select
function FAC:_scanManualList(group)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  -- Use DCS Unit position for robust coords
  local du = Unit.getByName(uname)
  if not du or not du:getPoint() then return end
  local origin = du:getPoint()
  _dbg(self, string.format('Action:ScanManual unit=%s origin=(%.0f,%.0f) radius=%d', uname, origin.x, origin.z, self.Config.FAC_maxDistance))
  local enemySide = _coalitionOpposite(u:GetCoalition())
  local foundAA, foundOther = {}, {}
  local function ins(tbl, item) table.insert(tbl, item) end
  local function cb(item)
    if item:getCoalition() ~= enemySide then return end
    if item:inAir() or not item:isActive() or item:getLife() <= 1 then return end
    local p = item:getPoint()
    if land.isVisible({x=p.x,y=p.y+2,z=p.z}, {x=origin.x,y=origin.y+2,z=origin.z}) then
      if item:hasAttribute('SAM TR') or item:hasAttribute('IR Guided SAM') or item:hasAttribute('AA_flak') then
        ins(foundAA, item)
      else
        ins(foundOther, item)
      end
    end
  end
  world.searchObjects(Object.Category.UNIT, { id=world.VolumeType.SPHERE, params={ point = origin, radius = self.Config.FAC_maxDistance } }, cb)
  local list = {}
  for i=1,10 do list[i] = foundAA[i] or foundOther[i] end
  self._manualLists[uname] = list
  _dbg(self, string.format('Action:ScanManual unit=%s results=%d', uname, #list))
  -- print bearings/ranges
  local gid = group:GetDCSObject() and group:GetDCSObject():getID() or nil
  for i,v in ipairs(list) do
    if v then
      local p = v:getPoint()
      local d = _distance(p, origin)
      local dy, dx = p.z - origin.z, p.x - origin.x
      local hdg = math.deg(math.atan(dx, dy))
      if hdg < 0 then hdg = hdg + 360 end
      if gid then
        trigger.action.outTextForGroup(gid, string.format('Target %d: %s Bearing %d Range %dm/%dft', i, v:getTypeName(), math.floor(hdg+0.5), math.floor(d), math.floor(d*3.28084)), 30)
        local id = math.floor(timer.getTime()*1000 + i)
        trigger.action.markToGroup(id, 'Target '..i..':'..v:getTypeName(), v:getPoint(), gid, false)
        timer.scheduleFunction(function(mid) trigger.action.removeMark(mid) end, id, timer.getTime()+60)
      end
    end
  end
end

function FAC:_setManualTarget(group, idx)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  _dbg(self, string.format('Action:SetManualTarget unit=%s index=%d', uname, idx))
  local list = self._manualLists[uname]
  if not list or not list[idx] then
    MESSAGE:New('Invalid Target', 10):ToGroup(group)
    return
  end
  local enemy = list[idx]
  if enemy and enemy:getLife()>0 then
    self._currentTargets[uname] = { name = enemy:getName(), unitType = enemy:getTypeName(), unitId = enemy:getID() }
    self:_setOnStation(group, true)
    self:_createMarker(enemy, uname)
    MESSAGE:New(string.format('Designating Target %d: %s', idx, enemy:getTypeName()), 10):ToGroup(group)
    _dbg(self, string.format('Action:SetManualTarget unit=%s target=%s type=%s', uname, enemy:getName(), enemy:getTypeName()))
  else
    MESSAGE:New(string.format('Target %d already dead', idx), 10):ToGroup(group)
    _dbg(self, string.format('Action:SetManualTarget unit=%s index=%d dead', uname, idx))
  end
end

function FAC:_multiStrike(group)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  local list = self._manualLists[uname] or {}
  _dbg(self, string.format('Action:MultiStrike unit=%s targets=%d', uname, #list))
  for _,t in ipairs(list) do if t and t:isExist() then self:_callFireMission(group, 10, 0, t) end end
end
-- #endregion Manual Scan/Select

-- #region RECCE sweep (aircraft-based)
function FAC:_recceDetect(group)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  local side = u:GetCoalition()
  -- Use DCS Unit API for coordinates to avoid relying on MOOSE point methods
  local du = Unit.getByName(uname)
  if not du or not du:getPoint() then return end
  local pos = du:getPoint()
  _dbg(self, string.format('Action:RecceSweep unit=%s center=(%.0f,%.0f) radius=%d', uname, pos.x, pos.z, self.Config.RecceScanRadius))
  local enemySide = _coalitionOpposite(side)
  local temp = {}
  local count = 0
  local function cb(item)
    if item:getCoalition() ~= enemySide then return end
    if item:getLife() < 1 then return end
    local p = item:getPoint()
    if land.isVisible({x=p.x,y=p.y+2,z=p.z}, {x=pos.x,y=pos.y+2,z=pos.z}) and (item:isActive() or item:getCategory()==Object.Category.STATIC) then
      count = count + 1
      local dms, mgrs, altM, altF, hdg, mph = _formatUnitGeo(item)
      local id = math.floor(timer.getTime()*1000 + count)
      local text = string.format('%s - DMS %s Alt %dm/%dft\nHeading %d Speed %d MPH\nSpotted by %s', item:getTypeName(), dms, altM, altF, hdg, mph, self:_facName(uname))
      trigger.action.markToCoalition(id, text, item:getPoint(), side, false)
      timer.scheduleFunction(function(mid) trigger.action.removeMark(mid) end, id, timer.getTime()+300)
      table.insert(temp, item)
    end
  end
  world.searchObjects(Object.Category.UNIT, { id=world.VolumeType.SPHERE, params={ point = pos, radius = self.Config.RecceScanRadius } }, cb)
  world.searchObjects(Object.Category.STATIC, { id=world.VolumeType.SPHERE, params={ point = pos, radius = self.Config.RecceScanRadius } }, cb)
  self._manualLists[uname] = temp
  _dbg(self, string.format('Action:RecceSweep unit=%s results=%d', uname, #temp))
  if #temp > 0 then
    MESSAGE:New(string.format('RECCE: %d contact(s) marked on map for 5 minutes. Open F10 Map to view.', #temp), 10):ToGroup(group)
    -- Coalition heads-up so other players know to check the map
    local lat, lon = coord.LOtoLL(pos)
    local mgrs = _mgrsToString(coord.LLtoMGRS(lat, lon))
    local loc = (mgrs and mgrs ~= '') and ('MGRS '..mgrs) or 'FAC position'
    trigger.action.outTextForCoalition(side, string.format('RECCE: %d contact(s) marked near %s. Check F10 map.', #temp, loc), 10)
  else
    MESSAGE:New('RECCE: No visible enemy contacts found.', 8):ToGroup(group)
  end
end

function FAC:_executeRecceMark(pos, coal)
  -- Find nearest AI recce unit of coalition not busy, task to fly over and run recceDetect via script action
  -- For simplicity we just run a coalition-wide recce flood at mark point using nearby AI if available; else no-op.
  trigger.action.outTextForCoalition(coal, 'RECCE task requested at map mark', 10)
end
-- #endregion RECCE sweep (aircraft-based)

-- #region Artillery/Naval/Air tasking
function FAC:_artyAmmo(units)
  local total = 0
  for i=1,#units do
    local ammo = units[i]:getAmmo()
    if ammo then
      if ammo[1] then total = total + (ammo[1].count or 0) end
    end
  end
  return total
end

function FAC:_guidedAmmo(units)
  local total = 0
  for i=1,#units do
    local ammo = units[i]:getAmmo()
    if ammo then
      for k=1,#ammo do
        local d = ammo[k].desc
        if d and d.guidance == 1 then total = total + (ammo[k].count or 0) end
      end
    end
  end
  return total
end

function FAC:_navalGunStats(units)
  local total, maxRange = 0, 0
  for i=1,#units do
    local ammo = units[i]:getAmmo()
    if ammo then
      for k=1,#ammo do
        local d = ammo[k].desc
        if d and d.category == 0 and d.warhead and d.warhead.caliber and d.warhead.caliber >= 75 then
          total = total + (ammo[k].count or 0)
          local r = (d.warhead.caliber >= 120) and 22222 or 18000
          if r > maxRange then maxRange = r end
        end
      end
    end
  end
  return total, maxRange
end

function FAC:_getArtyFor(point, facUnit, mode)
  -- mode: 0 HE, 1 illum, 2 mortar only, 3 heavy only (no smart), 4 guided/naval/air, -1 any except bombers
  -- Accept either a MOOSE Unit (GetCoalition) or a DCS Unit (getCoalition)
  local side
  if facUnit then
    if facUnit.GetCoalition then
      side = facUnit:GetCoalition()
    elseif facUnit.getCoalition then
      side = facUnit:getCoalition()
    end
  end
  side = side or self.Side
  local bestName
  local candidates = {}
  local function consider(found)
    if found:getCoalition() ~= side or not found:isActive() or found:getPlayerName() then return end
    local u = found
    local g = u:getGroup()
    if not g then return end
    local gname = g:getName()
    if candidates[gname] then return end
    if not self._ArtyTasked[gname] then self._ArtyTasked[gname] = { name=gname, tasked=0, timeTasked=nil, tgt=nil, requestor=nil } end
    if self._ArtyTasked[gname].tasked ~= 0 and (mode ~= -1 or self._ArtyTasked[gname].requestor ~= 'AI Spotter') then return end
    table.insert(candidates, gname)
  end
  world.searchObjects(Object.Category.UNIT, { id=world.VolumeType.SPHERE, params={ point = point, radius = 4600000 } }, consider)

  local filtered = {}
  for _,gname in ipairs(candidates) do
    local g = Group.getByName(gname)
    if g and g:isExist() then
      local u1 = g:getUnit(1)
      local pos = u1:getPoint()
      local d = _distance(pos, point)
      if mode == 4 then
        if _isBomberOrFighter(u1) or _isNavalUnit(u1) then
          if _isNavalUnit(u1) then
            local tot, rng = self:_navalGunStats(g:getUnits())
            _dbg(self, string.format('ArtySelect: %s (naval) dist=%.0f max=%.0f ammo=%d %s', gname, d, rng, tot or 0, (tot>0 and rng>=d) and 'OK' or 'SKIP'))
            if tot>0 and rng >= d then table.insert(filtered, gname) end
          else
            local guided = self:_guidedAmmo(g:getUnits())
            _dbg(self, string.format('ArtySelect: %s (air) dist=%.0f guided=%d %s', gname, d, guided or 0, (guided>0) and 'OK' or 'SKIP'))
            if guided > 0 then table.insert(filtered, gname) end
          end
        end
      else
        if _isNavalUnit(u1) then
          local tot, rng = self:_navalGunStats(g:getUnits())
          _dbg(self, string.format('ArtySelect: %s (naval) dist=%.0f max=%.0f ammo=%d %s', gname, d, rng, tot or 0, (tot>0 and rng>=d) and 'OK' or 'SKIP'))
          if tot>0 and rng >= d then table.insert(filtered, gname) end
        elseif _isArtilleryUnit(u1) then
          local r = _artyMaxRangeForUnit(u1)
          _dbg(self, string.format('ArtySelect: %s (artillery %s) dist=%.0f max=%.0f %s', gname, u1:getTypeName() or '?', d, r, (d<=r) and 'OK' or 'SKIP'))
          if d <= r then table.insert(filtered, gname) end
        end
      end
    end
  end
  local best, bestAmmo
  for _,gname in ipairs(filtered) do
    local g = Group.getByName(gname)
    local ammo = self:_artyAmmo(g:getUnits())
    if (not bestAmmo) or ammo > bestAmmo then bestAmmo = ammo; best = gname end
  end
  if best then return Group.getByName(best) end
  return nil
end

function FAC:_checkArty(group)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  -- Resolve using DCS Unit position
  local du = Unit.getByName(u:GetName())
  if not du or not du:getPoint() then return end
  local pos = du:getPoint()
  _dbg(self, string.format('Action:CheckArty unit=%s at=(%.0f,%.0f)', u:GetName(), pos.x, pos.z))
  local g = self:_getArtyFor(pos, du, 0)
  if g then
    _dbg(self, string.format('Action:CheckArty unit=%s found=%s', u:GetName(), g:getName()))
    MESSAGE:New('Arty available: '..g:getName(), 10):ToGroup(group)
  else
    _dbg(self, string.format('Action:CheckArty unit=%s none-found', u:GetName()))
    MESSAGE:New('No untasked arty/bomber/naval in range', 10):ToGroup(group)
  end
end

function FAC:_callFireMission(group, rounds, mode, specificTarget)
  -- Resolve a suitable asset (arty/naval/air) and push a task at the current target or a forward offset
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  local enemy = specificTarget or (self._currentTargets[uname] and Unit.getByName(self._currentTargets[uname].name))
  local attackPoint
  if enemy and enemy:isActive() then attackPoint = enemy:getPoint() else
    -- offset forward of FAC as fallback
    local du = Unit.getByName(uname)
    if not du or not du:getPoint() then return end
    local hdg = _getHeading(du)
    local up = du:getPoint()
    attackPoint = { x = up.x + math.cos(hdg)*self.Config.facOffsetDist, y = up.y, z = up.z + math.sin(hdg)*self.Config.facOffsetDist }
  end
  _dbg(self, string.format('Action:CallFireMission unit=%s rounds=%s mode=%s target=%s', uname, tostring(rounds), tostring(mode), enemy and enemy:getName() or 'offset'))
  local arty = self:_getArtyFor(attackPoint, Unit.getByName(uname), mode)
  if not arty then
    _dbg(self, string.format('Action:CallFireMission unit=%s no-asset-in-range', uname))
    MESSAGE:New('Unable to process fire mission: no asset in range', 10):ToGroup(group)
    return
  end
  local firepoint = { x = attackPoint.x, y = attackPoint.z, altitude = arty:getUnit(1):getPoint().y, altitudeEnabled = true, attackQty = 1, expend = 'One', weaponType = 268402702 }
  local task
  if _isNavalUnit(arty:getUnit(1)) then
    -- FireAtPoint expects a 2D vec2 where y=z; do not pass altitude here
    task = { id='FireAtPoint', params = { point = { x = attackPoint.x, y = attackPoint.z }, expendQty = 1, radius = 50, weaponType = 0 } }
  elseif _isBomberOrFighter(arty:getUnit(1)) then
    task = { id='Bombing', params = { y = attackPoint.z, x = attackPoint.x, altitude = firepoint.altitude, altitudeEnabled = true, attackQty = 1, groupAttack = true, weaponType = 2147485694 } }
  else
    -- Ground artillery
    task = { id='FireAtPoint', params = { point = { x = attackPoint.x, y = attackPoint.z }, expendQty = rounds or 1, radius = 50, weaponType = 0 } }
  end
  local ctrl = arty:getController()
  ctrl:pushTask(task)
  -- Avoid forcing unknown option ids; rely on group's ROE/AlarmState from mission editor
  local ammo = self:_artyAmmo(arty:getUnits())
  self._ArtyTasked[arty:getName()] = { name = arty:getName(), tasked = rounds or 1, timeTasked = timer.getTime(), tgt = enemy, requestor = self:_facName(uname) }
  trigger.action.outTextForCoalition(u:GetCoalition(), string.format('Fire mission sent: %s firing %d rounds. Requestor: %s', arty:getUnit(1):getTypeName(), rounds or 1, self:_facName(uname)), 10)
  _dbg(self, string.format('Action:CallFireMission unit=%s asset=%s rounds=%s point=(%.0f,%.0f)', uname, arty:getName(), tostring(rounds), attackPoint.x, attackPoint.z))
end

function FAC:_callFireMissionMulti(group, rounds, mode)
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  local list = self._manualLists[uname]
  if not list or #list == 0 then MESSAGE:New('No manual targets. Scan first.', 10):ToGroup(group) return end
  local first = list[1]
  local arty = self:_getArtyFor(first:getPoint(), u, 4)
  if not arty then MESSAGE:New('No guided asset available', 10):ToGroup(group) return end
  _dbg(self, string.format('Action:CallFireMissionMulti unit=%s targets=%d asset=%s', uname, #list, arty:getName()))
  local tasks = {}
  local guided = self:_guidedAmmo(arty:getUnits())
  for i,t in ipairs(list) do
    if i > guided then break end
    local p = t:getPoint()
    tasks[#tasks+1] = { number = i, id='Bombing', enabled=true, auto=false, params={ y=p.z, x=p.x, altitude=arty:getUnit(1):getPoint().y, altitudeEnabled=true, attackQty=1, groupAttack=false, weaponType=8589934592 } }
  end
  local combo = { id='ComboTask', params = { tasks = tasks } }
  local ctrl = arty:getController()
  ctrl:setOption(1,1)
  ctrl:pushTask(combo)
  ctrl:setOption(10,3221225470)
  self._ArtyTasked[arty:getName()] = { name=arty:getName(), tasked = #tasks, timeTasked=timer.getTime(), tgt=nil, requestor=self:_facName(uname) }
  trigger.action.outTextForCoalition(u:GetCoalition(), string.format('Guided strike queued on %d targets', #tasks), 10)
  _dbg(self, string.format('Action:CallFireMissionMulti unit=%s queuedTasks=%d', uname, #tasks))
end

function FAC:_callCarpetOnCurrent(group)
  -- Carpet bomb the current target using attack heading of the aircraft
  local u = group:GetUnit(1); if not u or not u:IsAlive() then return end
  local uname = u:GetName()
  local tgt = self._currentTargets[uname]
  if not tgt then MESSAGE:New('No current target', 10):ToGroup(group) return end
  local enemy = Unit.getByName(tgt.name)
  if not enemy or not enemy:isActive() then MESSAGE:New('Target invalid', 10):ToGroup(group) return end
  local du = Unit.getByName(uname)
  local attackHdgDeg = du and math.floor(_getHeading(du)*180/math.pi) or 0
  _dbg(self, string.format('Action:Carpet unit=%s target=%s hdg=%d', uname, enemy:getName(), attackHdgDeg))
  self:_executeCarpetOrTALD(enemy:getPoint(), u:GetCoalition(), 'CARPET', attackHdgDeg)
end

function FAC:_executeCarpetOrTALD(point, coal, mode, attackHeadingDeg)
  local side = coal or self.Side
  local arty = self:_getArtyFor(point, nil, (mode=='TALD') and 4 or 5)
  if not arty then
    trigger.action.outTextForCoalition(side, 'No bomber/naval asset available for '..(mode or 'CARPET'), 10)
    return
  end
  local u1 = arty:getUnit(1)
  local pos = u1:getPoint()
  local hdg = attackHeadingDeg and math.rad(attackHeadingDeg) or 0
  local weaponType = (mode=='TALD') and 8589934592 or 2147485694
  local altitude = (mode=='TALD') and 10000 or pos.y
  _dbg(self, string.format('Action:%s asset=%s heading=%d', tostring(mode or 'CARPET'), u1:getName(), attackHeadingDeg or -1))
  local task = { id='Bombing', params={ x=point.x, y=point.z, altitude=altitude, altitudeEnabled=true, attackQty=1, groupAttack=true, weaponType=weaponType, direction=hdg, directionEnabled=true } }
  local ctrl = arty:getController()
  ctrl:setOption(1,1)
  ctrl:setTask(task)
  ctrl:setOption(10,3221225470)
  trigger.action.outTextForCoalition(side, string.format('%s ordered to attack map mark (hdg %d)', u1:getTypeName(), attackHeadingDeg or 0), 10)
end
-- Provide a stub for periodic AI spotter loop (safe to extend as needed)
function FAC:_artyAICall()
  return
end

-- #endregion Artillery/Naval/Air tasking

-- #region Mark helpers
function FAC:_markPoint(group, point, label)
  local p3 = { x=point.x, y=land.getHeight({x=point.x,y=point.z}), z=point.z }
  trigger.action.smoke(p3, self.Config.FAC_smokeColour_BLUE)
  local id = math.floor(timer.getTime()*1000 + 0.5)
  local lat, lon = coord.LOtoLL(p3)
  local txt = string.format('FAC: %s at %s', label or 'Contact', _llToDMS(lat,lon))
  trigger.action.markToCoalition(id, txt, p3, self.Side, true)
end

-- #region Code reservation helpers
function FAC:_reserveCode(side, uname, code)
  self._reservedCodes[side] = self._reservedCodes[side] or {}
  local pool = self._reservedCodes[side]
  code = tostring(code)
  if pool[code] and pool[code] ~= uname then
    -- Find a free alternative from configured list
    local fallback = self:_assignFreeCode(side, uname)
    if fallback then
      -- Inform coalition about reassignment
      trigger.action.outTextForCoalition(side, string.format('FAC %s requested code %s but it is in use by %s. Assigned %s instead.', self:_facName(uname), code, self:_facName(pool[code]), fallback), 10)
      return fallback
    end
    -- No free code, keep requested (collision allowed with notice)
    trigger.action.outTextForCoalition(side, string.format('FAC %s is sharing code %s with %s (no free codes).', self:_facName(uname), code, self:_facName(pool[code])), 10)
  end
  pool[code] = uname
  return code
end

function FAC:_assignFreeCode(side, uname)
  self._reservedCodes[side] = self._reservedCodes[side] or {}
  local pool = self._reservedCodes[side]
  for _,c in ipairs(self.Config.FAC_laser_codes or {'1688'}) do
    local key = tostring(c)
    if not pool[key] or pool[key] == uname then
      pool[key] = uname
      return key
    end
  end
  return nil
end

function FAC:_releaseCode(side, uname)
  local pool = self._reservedCodes[side]
  if not pool then return end
  for code,owner in pairs(pool) do
    if owner == uname then pool[code] = nil end
  end
end

function FAC:_showCodesCoalition()
  local side = self.Side
  local pool = self._reservedCodes[side] or {}
  local lines = {'FAC Codes In Use:\n'}
  local any = false
  for _,c in ipairs(self.Config.FAC_laser_codes or {'1688'}) do
    local owner = pool[tostring(c)]
    if owner then any = true; table.insert(lines, string.format('  %s -> %s', tostring(c), self:_facName(owner))) end
  end
  if not any then table.insert(lines, '  (none)') end
  trigger.action.outTextForCoalition(side, table.concat(lines, '\n'), 15)
end
-- #endregion Code reservation helpers
-- #endregion Mark helpers

-- #region Export
_MOOSE_CTLD_FAC = FAC
return FAC
-- #endregion Export
