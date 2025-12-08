---@diagnostic disable: undefined-field, undefined-global
---@diagnostic disable: undefined-global, lowercase-global
-- WWII Pilot Intuition System using Moose Framework
--
-- Description:
-- This script simulates a WWII-era pilot intuition system for DCS World missions. It enhances immersion by providing realistic reconnaissance capabilities,
-- alerting pilots to nearby air and ground threats through voice-like messages and optional markers, mimicking how pilots spotted targets in WWII without modern aids.
--
-- Purpose:
-- To bridge the gap between modern DCS gameplay and historical WWII aviation, where situational awareness relied on visual scanning, formation flying, and intuition.
-- It helps players maintain awareness of their surroundings in dense or chaotic environments, promoting better tactics and immersion.
--
-- Use Case:
-- Ideal for WWII-themed missions, dogfights, or ground attack scenarios. Players can fly without relying on radar or labels, using the system to spot bandits,
-- ground units, and receive formation feedback. It's particularly useful in multiplayer servers for coordinated flights or solo play for enhanced challenge.

-- Features:
-- - Dynamic detection ranges based on formation flying and environmental conditions (night, weather).
-- - Realistic messaging simulating pilot radio calls for spotting bandits and ground threats.
-- - Formation integrity monitoring with alerts for wingmen presence.
-- - Dogfight assistance with alerts for merging bandits, tail warnings, head-on threats, and more.
-- - Optional visual markers (smoke, flares) for spotted targets.
-- - Configurable settings via F10 menu for players to customize their experience.

--
-- Setup Instructions:
-- 1. Ensure the Moose framework is installed and loaded in your DCS mission (download from https://flightcontrol-master.github.io/MOOSE_DOCS/).
-- 2. Add this script to your mission via the DCS Mission Editor: Go to Triggers > Mission Start > Do Script File, and select this Lua file.
-- 3. Optionally, customize the PILOT_INTUITION_CONFIG table below to adjust ranges, multipliers, and behaviors to fit your mission.
-- 4. The system initializes automatically on mission start. Players will see a welcome message and can access settings via the F10 menu.
-- 5. For best results, test in a mission with active AI units or other players to verify detection ranges and messaging.

-- Global configuration table for settings
PILOT_INTUITION_CONFIG = {
    airDetectionRange = 5000,  -- Meters (base range for air targets) (can be modified by formation and environment)
    groundDetectionRange = 3000,  -- Meters (base range for ground targets) (can be modified by formation and environment)
    messageCooldown = 10,  -- Seconds between messages
    markerType = "smoke",  -- Options: "smoke", "flare", "none"
    markerDuration = 300,  -- Seconds for marker visibility (dcs default can't be changed, so this is just for reference)
    threatHotRange = 1000,  -- Meters for "hot" threat
    threatColdRange = 5000,  -- Meters for "cold" threat
    scanInterval = 5,  -- Seconds between scans
    mergeRange = 500,  -- Meters for merge detection
    tailWarningRange = 1000,  -- Meters for tail warnings
    headOnRange = 1000,  -- Meters for head-on detection
    beamRange = 1500,  -- Meters for beam aspect detection
    multipleBanditsRange = 2000,  -- Meters for multiple bandits detection
    formationRange = 1000,  -- Meters for considering players in formation
    minFormationWingmen = 1,  -- Minimum wingmen for formation integrity warnings
    nightDetectionMultiplier = 0.5,  -- Detection range multiplier at night
    badWeatherMultiplier = 0.7,  -- Detection range multiplier in bad weather
    dogfightAssistEnabled = true,  -- Enable dogfight assistance by default
    dogfightMessageCooldown = 3,  -- Seconds between dogfight assist messages
    criticalSpeedThreshold = 150,  -- Knots - warn if speed drops below this in dogfight
    altitudeDeltaThreshold = 300,  -- Meters - significant altitude difference for callouts
    highClosureRate = 100,  -- M/s - warn if closure rate exceeds this
    positionChangeThreshold = 45,  -- Degrees - trigger update if bandit moves this much
    maxMultiplier = 6,  -- Max detection multiplier to prevent excessive ranges
    summaryInterval = 120,  -- Seconds between scheduled summaries (0 to disable)
    summaryCooldown = 30,  -- Minimum seconds between on-demand summaries
    activeMessaging = true,  -- Enable live alerts; false for on-demand only
    showGlobalMenu = true,  -- Enable global settings menu for players
    showWelcomeMessage = true,  -- Show welcome message to new players
    enableCloseFlyingCompliments = true,  -- Enable compliments for close flying
    complimentRange = 75,  -- Meters for close flying compliment
    headOnWarningRange = 150,  -- Meters for head-on warning
    closeFlyingMessageCooldown = 10,  -- Seconds between close flying messages
}

-- Message table with variations for different types
PILOT_INTUITION_MESSAGES = {
    welcome = {
        "Welcome to WWII Pilot Intuition! This system simulates pilot reconnaissance for spotting air and ground targets. Use F10 menu for settings.",
        "Greetings, pilot! WWII Pilot Intuition is active. It helps you spot bandits and ground threats. Check F10 for options.",
        "Pilot Intuition engaged! Simulate WWII-era reconnaissance. F10 menu for controls.",
    },
    formationJoin = {
        "You've joined flight with %s - air detection increased to %dm, ground to %dm.",
        "%s is now flying off your wing - detection ranges boosted to %dm air, %dm ground.",
        "Welcome aboard, %s! Formation tightens detection to %dm for air, %dm for ground.",
        "%s joins the formation - eyes sharper now, %dm air, %dm ground range.",
    },
    formationLeave = {
        "%s left formation - air detection reduced to %dm, ground to %dm.",
        "%s is outa here - detection drops to %dm air, %dm ground.",
        "Formation broken by %s - ranges now %dm air, %dm ground.",
        "%s has peeled off - back to solo detection: %dm air, %dm ground.",
    },
    formationIntegrityLow = {
        "Formation integrity low! Tighten up.",
        "Form up, pilots! We're spread too thin.",
        "Close ranks! Formation integrity compromised.",
        "Get back in formation, lads! We're vulnerable.",
    },
    airTargetDetected = {
        "Bandit %s at %.0f degrees, %.1f km, angels %.0f (%s)!",
        "Enemy aircraft %s: %.0f degrees, %.1f km, altitude %.0f (%s).",
        "Bogey %s at %.0f o'clock, %.1f km out, angels %.0f (%s).",
        "Hostile contact %s: %.0f degrees, %.1f km, %.0f angels (%s).",
        "Bandit inbound %s: %.0f degrees, %.1f km, angels %.0f (%s).",
    },
    groundTargetDetected = {
        "%s contact: %s %s at %.0f degrees, %.1f km.",
        "Ground threat: %s %s spotted at %.0f degrees, %.1f km.",
        "%s units detected: %s %s, %.0f degrees, %.1f km.",
        "Enemy ground: %s %s at bearing %.0f, %.1f km away.",
    },
    dogfightEngaged = {
        "Engaged!",
        "Tally ho! Dogfight started.",
        "Bandit engaged! Fight's on.",
        "Dogfight! Guns hot.",
    },
    dogfightConcluded = {
        "Dogfight concluded.",
        "Fight's over. Clear.",
        "Dogfight ended. Stand down.",
        "Engagement terminated.",
    },
    underFire = {
        "Under fire! Break %s!%s",
        "Taking hits! Evade %s!%s",
        "Shots fired! Turn %s now!%s",
        "Incoming! Break %s!%s",
    },
    closeFlyingCompliment = {
        "Nice flying! Tip-to-tip formation.",
        "Hey, nice! That's some close flying.",
        "Great job! That's close!",
        "Easy does it there tiger, I don't know you that well!",
        "Impressive! Wingtip to wingtip.",
        "Smooth moves! Close quarters flying.",
        "Damn, that's tight! Good flying.",
        "Holy shit, that's close! Nice one.",
    },
    headOnWarning = {
        "Whew! That was close!",
        "Whoa! Nearly a head-on!",
        "Close call! Watch that pass.",
        "Damn, that was tight! Be careful.",
        "Holy crap, almost collided!",
    },
    markerSet = {
        "Marker set to %s.",
        "Markers now %s.",
        "Marker type changed to %s.",
    },
    dogfightAssistToggle = {
        "Dogfight assist %s.",
        "Dogfight assistance %s.",
    },
    activeMessagingToggle = {
        "Active messaging %s.",
        "Live alerts %s.",
    },
    summaryCooldown = {
        "Summary on cooldown.",
        "Wait a bit for another summary.",
    },
    noThreats = {
        "No active threats.",
        "All clear.",
        "Situation normal.",
    },
}

-- Pilot Intuition Class
PilotIntuition = {
    ClassName = "PilotIntuition",
    players = {},  -- Table to track per-player data
    trackedGroundTargets = {},  -- Global table to track ground targets
    lastMessageTime = 0,
    menu = nil,
    enabled = true,
    summaryScheduler = nil,
}

function PilotIntuition:GetRandomMessage(messageType, params)
    local messages = PILOT_INTUITION_MESSAGES[messageType]
    if not messages or #messages == 0 then
        env.info("PilotIntuition: No messages for type " .. tostring(messageType))
        return "Message type not found: " .. tostring(messageType)
    end
    local msg = messages[math.random(#messages)]
    env.info("PilotIntuition: Selected message: " .. msg)
    if params then
        msg = string.format(msg, unpack(params))
        env.info("PilotIntuition: Formatted message: " .. msg)
    end
    return msg
end

function PilotIntuition:New()
    env.info("PilotIntuition: New called")
    local self = BASE:Inherit(self, BASE:New())
    self.players = {}
    self.trackedGroundTargets = {}
    self.lastMessageTime = timer.getTime()
    self:SetupMenu()
    self:StartScheduler()
    return self
end

function PilotIntuition:ScanTargets()
    env.info("PilotIntuition: ScanTargets called")
    if not self.enabled then
        return
    end
    local clients = SET_CLIENT:New():FilterActive():FilterOnce()
    local activeClients = {}
    local activePlayerNames = {}
    -- Build active client list and map for fast lookup
    clients:ForEachClient(function(client)
        if client and type(client.GetUnit) == "function" then
            local unit = client:GetUnit()
            if unit and unit:IsAlive() then
                local playerName = unit:GetPlayerName() or unit:GetName()
                local pos = unit:GetCoordinate()
                activeClients[#activeClients + 1] = { client = client, unit = unit, name = playerName, pos = pos, coalition = unit:GetCoalition() }
                activePlayerNames[playerName] = true
                if not self.players[playerName] then
                    self.players[playerName] = {
                        trackedAirTargets = {},
                        lastMessageTime = timer.getTime(),
                        wingmenList = {},
                        formationWarned = false,
                        lastFormationChangeTime = 0,
                        lastConclusionTime = 0,
                        trackedGroundTargets = {},
                        dogfightAssist = PILOT_INTUITION_CONFIG.dogfightAssistEnabled,
                        lastDogfightAssistTime = 0,
                        markerType = PILOT_INTUITION_CONFIG.markerType,
                        lastSpeed = 0,
                        primaryTarget = nil,
                        lastPrimaryTargetBearing = nil,
                        lastSummaryTime = 0,
                        hasBeenWelcomed = false,
                        lastComplimentTime = 0,
                        lastHeadOnWarningTime = 0,
                    }
                end
            end
        end
    end)

    -- Send welcome message to new players
    for _, info in ipairs(activeClients) do
        local playerName = info.name
        if self.players[playerName] and not self.players[playerName].hasBeenWelcomed and PILOT_INTUITION_CONFIG.showWelcomeMessage then
            MESSAGE:New(self:GetRandomMessage("welcome"), 10):ToClient(info.client)
            self.players[playerName].hasBeenWelcomed = true
        end
    end

    -- Clean up stale player data
    for playerName, _ in pairs(self.players) do
        if not activePlayerNames[playerName] then
            self.players[playerName] = nil
        end
    end

    -- Build enemy unit lists once per coalition for the scan
    local enemyAirByCoalition = {}
    enemyAirByCoalition[coalition.side.BLUE] = {}
    enemyAirByCoalition[coalition.side.RED] = {}
    local allEnemyUnits = SET_UNIT:New():FilterActive():FilterCategories("plane")
    allEnemyUnits:ForEachUnit(function(u)
        local c = u:GetCoalition()
        if c == coalition.side.BLUE or c == coalition.side.RED then
            enemyAirByCoalition[c][#enemyAirByCoalition[c] + 1] = u
        end
    end)

    local enemyGroundByCoalition = {}
    enemyGroundByCoalition[coalition.side.BLUE] = {}
    enemyGroundByCoalition[coalition.side.RED] = {}
    local allEnemyGroups = SET_GROUP:New():FilterActive():FilterCategories("ground")
    allEnemyGroups:ForEachGroup(function(g)
        local c = g:GetCoalition()
        if c == coalition.side.BLUE or c == coalition.side.RED then
            enemyGroundByCoalition[c][#enemyGroundByCoalition[c] + 1] = g
        end
    end)

    -- Now scan per active client
    for _, info in ipairs(activeClients) do
        local client = info.client
        local unit = info.unit
        local playerName = info.name
        local playerData = self.players[playerName]
        if playerData and unit and unit:IsAlive() then
            -- Determine enemy lists for this player
            local playerCoal = unit:GetCoalition()
            local enemyCoal = (playerCoal == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
            self:ScanAirTargetsForPlayer(unit, playerData, client, activeClients, enemyAirByCoalition[enemyCoal])
            self:ScanGroundTargetsForPlayer(unit, client, activeClients, enemyGroundByCoalition[enemyCoal])
            self:CheckCloseFlyingForPlayer(unit, playerData, client, activeClients)
        end
    end

    -- Prune dead ground targets globally
    for id, data in pairs(self.trackedGroundTargets) do
        if not data.group:IsAlive() then
            self.trackedGroundTargets[id] = nil
        end
    end
end

-- Setup the mission and per-player menus for pilot intuition toggles
function PilotIntuition:SetupMenu()
    -- Guard: Ensure MENU_MISSION exists
    if not MENU_MISSION then
        env.info("PilotIntuition: MENU_MISSION not found, skipping SetupMenu")
        return
    end

    -- Create a top-level mission menu for toggles
    local rootMenu = MENU_MISSION:New("WWII Pilot Intuition")
    self.menu = rootMenu

    -- Marker type choices
    MENU_MISSION_COMMAND:New("Marker Smoke", rootMenu, self.MenuSetMarkerType, self, "smoke")
    MENU_MISSION_COMMAND:New("Marker Flare", rootMenu, self.MenuSetMarkerType, self, "flare")
    MENU_MISSION_COMMAND:New("Marker None", rootMenu, self.MenuSetMarkerType, self, "none")

    -- Active messaging toggle
    MENU_MISSION_COMMAND:New("Active Messaging On", rootMenu, self.MenuSetActiveMessaging, self, true)
    MENU_MISSION_COMMAND:New("Active Messaging Off", rootMenu, self.MenuSetActiveMessaging, self, false)

    -- Per-player menu group: create a settings node for each active player
    self:SetupPlayerMenus()

    -- schedule periodic update for player menus to catch new players
    SCHEDULER:New(nil, self.SetupPlayerMenus, {self}, 1, 10)
end
function PilotIntuition:SetupPlayerMenus()
    local clients = SET_CLIENT:New():FilterActive():FilterOnce()
    clients:ForEachClient(function(client)
        if client and type(client.GetUnit) == "function" then
            local unit = client:GetUnit()
            if unit and unit:IsAlive() then
                local playerGroup = unit:GetGroup()
                local playerName = unit:GetPlayerName() or unit:GetName()
                local playerMenu = MENU_GROUP:New(playerGroup, 'Pilot Intuition')
                -- create a short, non-spamming set of toggles for player
                MENU_GROUP_COMMAND:New(playerGroup, "Dogfight Assist On", playerMenu, self.MenuSetPlayerDogfightAssist, self, unit, true)
                MENU_GROUP_COMMAND:New(playerGroup, "Dogfight Assist Off", playerMenu, self.MenuSetPlayerDogfightAssist, self, unit, false)
                -- also allow player to toggle markers themselves
                MENU_GROUP_COMMAND:New(playerGroup, "Marker: Smoke", playerMenu, self.MenuSetPlayerMarker, self, unit, "smoke")
                MENU_GROUP_COMMAND:New(playerGroup, "Marker: Flare", playerMenu, self.MenuSetPlayerMarker, self, unit, "flare")
                MENU_GROUP_COMMAND:New(playerGroup, "Marker: None", playerMenu, self.MenuSetPlayerMarker, self, unit, "none")
                -- Summary commands
                MENU_GROUP_COMMAND:New(playerGroup, "Summary: Brief", playerMenu, self.MenuSendPlayerSummary, self, unit, "brief")
                MENU_GROUP_COMMAND:New(playerGroup, "Summary: Detailed", playerMenu, self.MenuSendPlayerSummary, self, unit, "detailed")
            end
        end
    end)
end

function PilotIntuition:MenuSetPlayerMarker(playerUnit, markerType)
    env.info("PilotIntuition: MenuSetPlayerMarker called for " .. tostring(playerUnit and playerUnit:GetName()) .. " with " .. tostring(markerType))
    if not playerUnit then return end
    local playerName = playerUnit:GetPlayerName() or playerUnit:GetName()
    -- store as player pref only - not global config
    if self.players[playerName] then
        self.players[playerName].markerType = markerType
        local client = playerUnit:GetClient()
        if client then
            MESSAGE:New(self:GetRandomMessage("markerSet", {markerType}), 10):ToClient(client)
        end
    end
end
function PilotIntuition:MenuSetMarkerType(type)
    env.info("PilotIntuition: MenuSetMarkerType called with " .. tostring(type))
    PILOT_INTUITION_CONFIG.markerType = type
    local msg = self:GetRandomMessage("markerSet", {tostring(type)})
    env.info("PilotIntuition: Marker message: " .. msg)
    self:BroadcastMessageToAll(msg)
end

function PilotIntuition:MenuSetPlayerDogfightAssist(playerUnit, onoff)
    env.info("PilotIntuition: MenuSetPlayerDogfightAssist called for " .. tostring(playerUnit and playerUnit:GetName()) .. " with " .. tostring(onoff))
    if not playerUnit then return end
    local playerName = playerUnit:GetPlayerName() or playerUnit:GetName()
    if self.players[playerName] then
        self.players[playerName].dogfightAssist = onoff
        local status = onoff and "enabled" or "disabled"
        local client = playerUnit:GetClient()
        if client then
            MESSAGE:New(self:GetRandomMessage("dogfightAssistToggle", {status}), 10):ToClient(client)
        end
    end
end

function PilotIntuition:MenuSetActiveMessaging(onoff)
    env.info("PilotIntuition: MenuSetActiveMessaging called with " .. tostring(onoff))
    PILOT_INTUITION_CONFIG.activeMessaging = onoff
    if onoff then
        local msg = self:GetRandomMessage("activeMessagingToggle", {"enabled"})
        env.info("PilotIntuition: Active messaging message: " .. msg)
        self:BroadcastMessageToAll(msg)
        if self.summaryScheduler then
            self.summaryScheduler:Stop()
            self.summaryScheduler = nil
        end
    else
        local msg = self:GetRandomMessage("activeMessagingToggle", {"disabled. Use summaries for updates."})
        env.info("PilotIntuition: Active messaging message: " .. msg)
        self:BroadcastMessageToAll(msg)
        if PILOT_INTUITION_CONFIG.summaryInterval > 0 then
            self.summaryScheduler = SCHEDULER:New(nil, self.SendScheduledSummaries, {self}, 1, PILOT_INTUITION_CONFIG.summaryInterval)
        end
    end
end

function PilotIntuition:MenuSendPlayerSummary(playerUnit, detailLevel)
    self:SendPlayerSummary(playerUnit, detailLevel)
end

function PilotIntuition:BroadcastMessageToAll(text)
    env.info("PilotIntuition: Broadcasting message: " .. tostring(text))
    MESSAGE:New(text, 10):ToAll()  -- Added duration 10 seconds
    env.info("PilotIntuition: Broadcasted to all with duration 10")
end

function PilotIntuition:GetPlayerSummary(playerName, detailLevel)
    local data = self.players[playerName]
    if not data then return nil end
    local summaryParts = {}
    -- Count bandits
    local banditCount = 0
    local closestDist = math.huge
    local closestDesc = nil
    for id, t in pairs(data.trackedAirTargets or {}) do
        if t.unit and t.unit:IsAlive() then
            banditCount = banditCount + 1
            local d = t.lastRange or 0
            if d < closestDist then
                closestDist = d
                closestDesc = t.unit:GetTypeName() or id
            end
        end
    end
    if banditCount > 0 then
        table.insert(summaryParts, string.format("Bandits: %d", banditCount))
        if closestDesc and detailLevel == "detailed" then
            table.insert(summaryParts, string.format("Closest: %s (%.0fm)", closestDesc, closestDist))
        end
    end
    -- Ground targets
    local gcount = 0
    for id, _ in pairs(data.trackedGroundTargets or {}) do gcount = gcount + 1 end
    if gcount > 0 then
        table.insert(summaryParts, string.format("Ground: %d groups", gcount))
    end
    -- Dogfight & formation status
    if data.dogfightAssist then table.insert(summaryParts, "DF assist: ON") else table.insert(summaryParts, "DF assist: OFF") end
    if #data.wingmenList > 0 then table.insert(summaryParts, "Wingmen: " .. #data.wingmenList) end
    -- Settings
    if detailLevel == "detailed" then
        table.insert(summaryParts, string.format("Marker: %s", data.markerType or "none"))
    end
    return table.concat(summaryParts, " | ")
end

function PilotIntuition:SendPlayerSummary(playerUnit, detailLevel)
    if not playerUnit then return end
    local playerName = playerUnit:GetPlayerName() or playerUnit:GetName()
    local client = playerUnit:GetClient()
    if not self.players[playerName] or not client then return end
    local now = timer.getTime()
    local data = self.players[playerName]
    if data.lastSummaryTime and (now - data.lastSummaryTime) < (PILOT_INTUITION_CONFIG.summaryCooldown or 30) then
        MESSAGE:New(self:GetRandomMessage("summaryCooldown"), 10):ToClient(client)
        return
    end
    local summary = self:GetPlayerSummary(playerName, detailLevel)
    if summary and summary ~= "" then
        MESSAGE:New(summary, 10):ToClient(client)
        data.lastSummaryTime = now
    else
        MESSAGE:New(self:GetRandomMessage("noThreats"), 10):ToClient(client)
    end
end

function PilotIntuition:SendScheduledSummaries()
    if not PILOT_INTUITION_CONFIG.activeMessaging then
        local clients = SET_CLIENT:New():FilterActive():FilterOnce()
        clients:ForEachClient(function(client)
            if client and type(client.GetUnit) == "function" then
                local unit = client:GetUnit()
                if unit and unit:IsAlive() then
                    self:SendPlayerSummary(unit, "brief")
                end
            end
        end)
    end
end

function PilotIntuition:StartScheduler()
    -- Schedule periodic scans
    SCHEDULER:New(nil, self.ScanTargets, {self}, 1, PILOT_INTUITION_CONFIG.scanInterval)
end

-- (old ScanTargets removed; using the optimized ScanTargets above)

function PilotIntuition:ScanAirTargetsForPlayer(playerUnit, playerData, client, activeClients, enemyAirUnits)
    local playerPos = playerUnit:GetCoordinate()
    local playerCoalition = playerUnit:GetCoalition()
    local enemyCoalition = (playerCoalition == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
    -- enemyAirUnits is provided by ScanTargets; it's an array of units

    -- Calculate wingmen count (players in formation)
    -- Calculate wingmen count using precomputed activeClients
    local currentWingmen = {}
    for _, info in ipairs(activeClients) do
        local u = info.unit
        if u and u:IsAlive() and u:GetCoalition() == playerUnit:GetCoalition() and u:GetName() ~= playerUnit:GetName() then
            local dist = playerPos:Get2DDistance(u:GetCoordinate())
            if dist <= PILOT_INTUITION_CONFIG.formationRange then
                table.insert(currentWingmen, u:GetName())
            end
        end
    end
        -- enemyAirUnits passed in as array
    local wingmen = #currentWingmen
    local multiplier = (wingmen > 0) and (2 * wingmen) or 1
    -- Clamp multiplier to configured maximum
    if multiplier > PILOT_INTUITION_CONFIG.maxMultiplier then
        multiplier = PILOT_INTUITION_CONFIG.maxMultiplier
    end
    local envMult = self:GetDetectionMultiplier()
    local detectionRange = PILOT_INTUITION_CONFIG.airDetectionRange * multiplier * envMult

    -- Notify formation changes
    local previousWingmen = playerData.wingmenList or {}
    local function contains(list, item)
        for _, v in ipairs(list) do
            if v == item then return true end
        end
        return false
    end
    local now = timer.getTime()
    if (now - playerData.lastFormationChangeTime) >= PILOT_INTUITION_CONFIG.messageCooldown then
        local newWingmen = #currentWingmen
        local newMultiplier = (newWingmen > 0) and (2 * newWingmen) or 1
        local newAirRange = math.floor(PILOT_INTUITION_CONFIG.airDetectionRange * newMultiplier * envMult)
        local newGroundRange = math.floor(PILOT_INTUITION_CONFIG.groundDetectionRange * newMultiplier * envMult)
        
        for _, name in ipairs(currentWingmen) do
            if not contains(previousWingmen, name) then
                if PILOT_INTUITION_CONFIG.activeMessaging then
                    MESSAGE:New(self:GetRandomMessage("formationJoin", {name, newAirRange, newGroundRange}), 10):ToClient(client)
                end
                playerData.lastFormationChangeTime = now
                break
            end
        end
        for _, name in ipairs(previousWingmen) do
            if not contains(currentWingmen, name) then
                if PILOT_INTUITION_CONFIG.activeMessaging then
                    MESSAGE:New(self:GetRandomMessage("formationLeave", {name, newAirRange, newGroundRange}), 10):ToClient(client)
                end
                playerData.lastFormationChangeTime = now
                break
            end
        end
    end
    playerData.wingmenList = currentWingmen

    -- Formation integrity warning (only if previously had wingmen)
    if #previousWingmen >= PILOT_INTUITION_CONFIG.minFormationWingmen and wingmen < PILOT_INTUITION_CONFIG.minFormationWingmen then
        if not playerData.formationWarned and (now - playerData.lastFormationChangeTime) >= PILOT_INTUITION_CONFIG.messageCooldown then
            if PILOT_INTUITION_CONFIG.activeMessaging then
                MESSAGE:New(self:GetRandomMessage("formationIntegrityLow"), 10):ToClient(client)
            end
            playerData.formationWarned = true
            playerData.lastFormationChangeTime = now
        end
    elseif wingmen >= PILOT_INTUITION_CONFIG.minFormationWingmen then
        playerData.formationWarned = false
    end

    -- Prune dead or out-of-range air targets
    for id, data in pairs(playerData.trackedAirTargets) do
        if not data.unit:IsAlive() or playerPos:Get2DDistance(data.unit:GetCoordinate()) > detectionRange then
            playerData.trackedAirTargets[id] = nil
        end
    end

    local banditCount = 0
    local closestUnit = nil
    local minDistance = math.huge
    for _, unit in ipairs(enemyAirUnits or {}) do
        local distance = playerPos:Get2DDistance(unit:GetCoordinate())
        if distance <= detectionRange then
            banditCount = banditCount + 1
            if distance < minDistance then
                minDistance = distance
                closestUnit = unit
            end
            local targetID = unit:GetName()
            local now = timer.getTime()
            local bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(unit:GetCoordinate()))
            local playerHeading = math.deg(playerUnit:GetHeading())
            local relativeBearing = bearing - playerHeading
            relativeBearing = (relativeBearing % 360 + 360) % 360  -- Normalize to 0-360

            if not playerData.trackedAirTargets[targetID] then
                playerData.trackedAirTargets[targetID] = { unit = unit, engaged = false, lastRange = distance, lastTime = now, wasHot = false, lastRelativeBearing = relativeBearing, lastEngagedTime = 0 }
            else
                playerData.trackedAirTargets[targetID].lastRange = playerData.trackedAirTargets[targetID].lastRange or distance
                playerData.trackedAirTargets[targetID].lastTime = playerData.trackedAirTargets[targetID].lastTime or now
                playerData.trackedAirTargets[targetID].lastRelativeBearing = playerData.trackedAirTargets[targetID].lastRelativeBearing or relativeBearing
            end
            local data = playerData.trackedAirTargets[targetID]
            local closing = distance < data.lastRange
            local wasHot = data.wasHot
            if distance <= PILOT_INTUITION_CONFIG.threatHotRange then
                data.wasHot = true
            end
            data.lastRange = distance
            data.lastTime = now
            local lastRelativeBearing = data.lastRelativeBearing
            data.lastRelativeBearing = relativeBearing

            -- Reset engaged status after 2 minutes of no engagement or if bandit is out of range
            if data.engaged and ((now - data.lastEngagedTime) > 120 or distance > PILOT_INTUITION_CONFIG.airDetectionRange) then
                data.engaged = false
                if (now - playerData.lastConclusionTime) >= PILOT_INTUITION_CONFIG.messageCooldown then
                    if PILOT_INTUITION_CONFIG.activeMessaging then
                        MESSAGE:New(self:GetRandomMessage("dogfightConcluded"), 10):ToClient(client)
                    end
                    playerData.lastConclusionTime = now
                end
            end

            if not data.engaged then
                -- Check for dogfight situations (for all, but report only for closest)
                local onTail = relativeBearing > 150 and relativeBearing < 210
                local headOn = relativeBearing < 30 or relativeBearing > 330
                local beam = (relativeBearing > 60 and relativeBearing < 120) or (relativeBearing > 240 and relativeBearing < 300)
                local overshoot = lastRelativeBearing < 90 and relativeBearing > 270

                if distance < PILOT_INTUITION_CONFIG.mergeRange and closing then
                    self:ReportDogfight(unit, playerPos, playerData, client, "Merging bandit!")
                elseif onTail and distance < PILOT_INTUITION_CONFIG.tailWarningRange then
                    self:ReportDogfight(unit, playerPos, playerData, client, "Tail warning!")
                elseif headOn and distance < PILOT_INTUITION_CONFIG.headOnRange then
                    self:ReportDogfight(unit, playerPos, playerData, client, "Head-on bandit!")
                elseif beam and distance < PILOT_INTUITION_CONFIG.beamRange then
                    self:ReportDogfight(unit, playerPos, playerData, client, "Beam bandit!")
                elseif wasHot and distance > PILOT_INTUITION_CONFIG.threatHotRange and not closing then
                    self:ReportDogfight(unit, playerPos, playerData, client, "Bandit breaking off!")
                elseif overshoot then
                    self:ReportDogfight(unit, playerPos, playerData, client, "Bandit overshot!")
                end
            end
            
            -- Dogfight assist features (if enabled)
            if playerData.dogfightAssist and data.engaged then
                self:ProvideDogfightAssist(playerUnit, unit, distance, relativeBearing, lastRelativeBearing, playerData, client, closing)
            end
        end
    end

    -- Report the closest unengaged bandit
    if closestUnit then
        local data = playerData.trackedAirTargets[closestUnit:GetName()]
        if data and not data.engaged then
            self:ReportAirTarget(closestUnit, playerPos, playerData, client)
        end
    end

    -- Check for multiple bandits
    if banditCount > 1 then
        self:ReportDogfight(nil, playerPos, playerData, client, "Multiple bandits in vicinity!")
    end
end

function PilotIntuition:ReportAirTarget(unit, playerPos, playerData, client)
    local now = timer.getTime()
    if now - playerData.lastMessageTime < PILOT_INTUITION_CONFIG.messageCooldown then return end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end

    local bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(unit:GetCoordinate()))
    local range = playerPos:Get2DDistance(unit:GetCoordinate()) / 1000  -- In km
    local alt = unit:GetAltitude() / 1000  -- In km
    local threat = "cold"
    if range * 1000 <= PILOT_INTUITION_CONFIG.threatHotRange then
        threat = "hot"
    end
    local groupSize = #unit:GetGroup():GetUnits()
    local sizeDesc = groupSize == 1 and "single" or (groupSize == 2 and "pair" or "flight of " .. groupSize)

    MESSAGE:New(self:GetRandomMessage("airTargetDetected", {threat, bearing, range, alt, sizeDesc}), 10):ToClient(client)
    playerData.lastMessageTime = now
end

function PilotIntuition:ReportDogfight(unit, playerPos, playerData, client, message)
    local now = timer.getTime()
    if now - playerData.lastMessageTime < PILOT_INTUITION_CONFIG.messageCooldown then return end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end

    MESSAGE:New(message, 10):ToClient(client)
    playerData.lastMessageTime = now
end

function PilotIntuition:ScanGroundTargetsForPlayer(playerUnit, client, activeClients, enemyGroundGroups)
    local playerPos = playerUnit:GetCoordinate()
    local playerCoalition = playerUnit:GetCoalition()
    local enemyCoalition = (playerCoalition == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
    local unitName = playerUnit:GetName()
    local playerData = self.players[unitName]
    if not playerData then return end

    -- Calculate wingmen count using precomputed activeClients
    local wingmen = 0
    for _, info in ipairs(activeClients) do
        local u = info.unit
        if u and u:IsAlive() and u:GetCoalition() == playerUnit:GetCoalition() and u:GetName() ~= playerUnit:GetName() then
            local dist = playerPos:Get2DDistance(u:GetCoordinate())
            if dist <= PILOT_INTUITION_CONFIG.formationRange then
                wingmen = wingmen + 1
            end
        end
    end
    local multiplier = (wingmen > 0) and (2 * wingmen) or 1
    if multiplier > PILOT_INTUITION_CONFIG.maxMultiplier then
        multiplier = PILOT_INTUITION_CONFIG.maxMultiplier
    end
    local envMult = self:GetDetectionMultiplier()
    local detectionRange = PILOT_INTUITION_CONFIG.groundDetectionRange * multiplier * envMult

    -- Prune out-of-range ground targets for this player
    for id, _ in pairs(playerData.trackedGroundTargets) do
        local group = self.trackedGroundTargets[id]
        if not group or not group.group:IsAlive() or playerPos:Get2DDistance(group.group:GetCoordinate()) > detectionRange then
            playerData.trackedGroundTargets[id] = nil
        end
    end

    -- Collect candidates within range
    local candidates = {}
    for _, group in ipairs(enemyGroundGroups or {}) do
        local distance = playerPos:Get2DDistance(group:GetCoordinate())
        if distance <= detectionRange then
            table.insert(candidates, {group = group, distance = distance})
        end
    end

    -- Sort by distance
    table.sort(candidates, function(a, b) return a.distance < b.distance end)

    -- Mark the closest unmarked target for this player
    for _, cand in ipairs(candidates) do
        local targetID = cand.group:GetName()
        if not self.trackedGroundTargets[targetID] then
            self.trackedGroundTargets[targetID] = { group = cand.group, marked = false }
        end
            if not playerData.trackedGroundTargets[targetID] then
            self:ReportGroundTarget(cand.group, playerUnit, client)
            self.trackedGroundTargets[targetID].marked = true
            playerData.trackedGroundTargets[targetID] = true
            break  -- Only mark one per player per scan
        end
    end
end

function PilotIntuition:CheckCloseFlyingForPlayer(playerUnit, playerData, client, activeClients)
    if not PILOT_INTUITION_CONFIG.enableCloseFlyingCompliments then return end
    local playerPos = playerUnit:GetCoordinate()
    local playerCoalition = playerUnit:GetCoalition()
    local now = timer.getTime()
    local playerHeading = math.deg(playerUnit:GetHeading())

    for _, info in ipairs(activeClients) do
        local otherUnit = info.unit
        if otherUnit and otherUnit:IsAlive() and otherUnit:GetCoalition() == playerCoalition and otherUnit:GetName() ~= playerUnit:GetName() then
            local distance = playerPos:Get2DDistance(otherUnit:GetCoordinate())
            if distance <= PILOT_INTUITION_CONFIG.complimentRange then
                -- Calculate relative bearing
                local bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(otherUnit:GetCoordinate()))
                local relativeBearing = bearing - playerHeading
                relativeBearing = (relativeBearing % 360 + 360) % 360  -- Normalize to 0-360

                -- Check if head-on (within 30 degrees of front or back, but for pass, focus on front)
                local isHeadOn = relativeBearing < 30 or relativeBearing > 330

                if isHeadOn and distance <= PILOT_INTUITION_CONFIG.headOnWarningRange then
                    if now - playerData.lastHeadOnWarningTime >= PILOT_INTUITION_CONFIG.closeFlyingMessageCooldown then
                        MESSAGE:New(self:GetRandomMessage("headOnWarning"), 10):ToClient(client)
                        playerData.lastHeadOnWarningTime = now
                    end
                elseif not isHeadOn then
                    if now - playerData.lastComplimentTime >= PILOT_INTUITION_CONFIG.closeFlyingMessageCooldown then
                        MESSAGE:New(self:GetRandomMessage("closeFlyingCompliment"), 10):ToClient(client)
                        playerData.lastComplimentTime = now
                    end
                end
            end
        end
    end
end

function PilotIntuition:ReportGroundTarget(group, playerUnit, client)
    local now = timer.getTime()
    if now - self.lastMessageTime < PILOT_INTUITION_CONFIG.messageCooldown then return end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end
    local playerPos = playerUnit:GetCoordinate()
    local bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(group:GetCoordinate()))
    local distance = playerPos:Get2DDistance(group:GetCoordinate()) / 1000  -- In km
    local unitType = group:GetUnits()[1]:GetTypeName()
    local category = self:ClassifyGroundUnit(unitType)
    local groupSize = #group:GetUnits()
    local sizeDesc = groupSize == 1 and "single" or (groupSize <= 4 and "group" or "platoon")

    MESSAGE:New(self:GetRandomMessage("groundTargetDetected", {category, sizeDesc, unitType, bearing, distance}), 10):ToClient(client)
    self.lastMessageTime = now

    -- Place marker
    -- Determine marker type: prefer player preference if set, otherwise global config
    local markerType = PILOT_INTUITION_CONFIG.markerType
    local playerName = playerUnit:GetPlayerName() or playerUnit:GetName()
    if self.players[playerName] and self.players[playerName].markerType then
        markerType = self.players[playerName].markerType
    end
    if markerType ~= "none" then
        local coord = group:GetCoordinate()
        if markerType == "smoke" then
            coord:SmokeRed()
        elseif markerType == "flare" then
            coord:FlareRed()
        end
        -- Note: Markers are temporary; Moose doesn't have built-in timed markers, so this is basic
    end
end

function PilotIntuition:GetDetectionMultiplier()
    -- Basic night detection: reduce range at night (22:00 to 06:00)
    local time = timer.getAbsTime() % 86400
    local hour = math.floor(time / 3600)
    local isNight = hour >= 22 or hour < 6
    local mult = 1
    if isNight then
        mult = mult * PILOT_INTUITION_CONFIG.nightDetectionMultiplier
    end
    -- TODO: Add weather check if available
    return mult
end

function PilotIntuition:ClassifyGroundUnit(unitType)
    unitType = string.lower(unitType)
    if string.find(unitType, "tank") or string.find(unitType, "armor") or string.find(unitType, "panzer") then
        return "Armor"
    elseif string.find(unitType, "infantry") or string.find(unitType, "soldier") then
        return "Infantry"
    elseif string.find(unitType, "aaa") or string.find(unitType, "flak") or string.find(unitType, "aa") then
        return "Anti-Air"
    elseif string.find(unitType, "truck") or string.find(unitType, "vehicle") or string.find(unitType, "transport") then
        return "Logistics"
    else
        return "Ground"
    end
end

function PilotIntuition:ProvideDogfightAssist(playerUnit, banditUnit, distance, relativeBearing, lastRelativeBearing, playerData, client, closing)
    local now = timer.getTime()
    if (now - playerData.lastDogfightAssistTime) < PILOT_INTUITION_CONFIG.dogfightMessageCooldown then
        return
    end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end
    
    local playerPos = playerUnit:GetCoordinate()
    local banditPos = banditUnit:GetCoordinate()
    local playerAlt = playerUnit:GetAltitude()
    local banditAlt = banditUnit:GetAltitude()
    local altDelta = banditAlt - playerAlt
    
    -- Check for speed warning
    local velocity = playerUnit:GetVelocityKMH()
    local speedKnots = velocity * 0.539957
    if speedKnots < PILOT_INTUITION_CONFIG.criticalSpeedThreshold then
        MESSAGE:New("Speed critical! Extend!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Target loss detection (front to rear hemisphere)
    if lastRelativeBearing and lastRelativeBearing < 90 and relativeBearing > 270 then
        MESSAGE:New("Lost visual! Bandit reversing on you!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Check for bandit moving behind (now behind, wasn't before)
    if relativeBearing > 150 and relativeBearing < 210 and distance < PILOT_INTUITION_CONFIG.tailWarningRange then
        local direction = relativeBearing < 180 and "left" or "right"
        MESSAGE:New("Bandit at 6 o'clock! Break " .. direction .. "!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Altitude advantage/disadvantage
    if math.abs(altDelta) > PILOT_INTUITION_CONFIG.altitudeDeltaThreshold then
        if altDelta > 0 then
            MESSAGE:New("Bandit above by " .. math.floor(altDelta) .. "m!", 10):ToClient(client)
        else
            MESSAGE:New("You have altitude advantage!", 10):ToClient(client)
        end
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Closure rate warning
    if closing and distance < PILOT_INTUITION_CONFIG.threatHotRange then
        MESSAGE:New("Bandit closing fast! Prepare to engage!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Significant position change
    if playerData.lastPrimaryTargetBearing then
        local bearingChange = math.abs(relativeBearing - playerData.lastPrimaryTargetBearing)
        if bearingChange > PILOT_INTUITION_CONFIG.positionChangeThreshold and bearingChange < (360 - PILOT_INTUITION_CONFIG.positionChangeThreshold) then
            local clockPos = math.floor(relativeBearing / 30) + 1
            if clockPos > 12 then clockPos = clockPos - 12 end
            MESSAGE:New("Bandit moving to " .. clockPos .. " o'clock!", 10):ToClient(client)
            playerData.lastDogfightAssistTime = now
        end
    end
    playerData.lastPrimaryTargetBearing = relativeBearing
end

-- Handle engagement (simplified: if player shoots, assume engagement for nearest target)
function PilotIntuition:OnPlayerShot(EventData)
    if not self.enabled then return end
    local playerUnit = EventData.IniUnit
    local client = playerUnit:GetClient()
    if client then
        local unitName = playerUnit:GetName()
        if self.players[unitName] then
            local playerData = self.players[unitName]
            -- Calculate wingmen for extended range
            local clients = SET_CLIENT:New():FilterActive():FilterOnce()
            local wingmen = 0
            clients:ForEachClient(function(c)
                if c and type(c.GetUnit) == "function" then
                    local u = c:GetUnit()
                    if u and u:IsAlive() and u:GetCoalition() == playerUnit:GetCoalition() and u:GetName() ~= playerUnit:GetName() then
                    local dist = playerUnit:GetCoordinate():Get2DDistance(u:GetCoordinate())
                    if dist <= PILOT_INTUITION_CONFIG.formationRange then
                        wingmen = wingmen + 1
                    end
                    end
                end
            end)
            local multiplier = (wingmen > 0) and (2 * wingmen) or 1
            if multiplier > PILOT_INTUITION_CONFIG.maxMultiplier then
                multiplier = PILOT_INTUITION_CONFIG.maxMultiplier
            end
            local detectionRange = PILOT_INTUITION_CONFIG.airDetectionRange * multiplier
            -- Find nearest air target and mark as engaged
            local minDist = math.huge
            local nearestID = nil
            for id, data in pairs(playerData.trackedAirTargets) do
                if not data.engaged then
                    local distance = playerUnit:GetCoordinate():Get2DDistance(data.unit:GetCoordinate())
                    if distance < minDist then
                        minDist = distance
                        nearestID = id
                    end
                end
            end
            if nearestID and minDist <= detectionRange then
                playerData.trackedAirTargets[nearestID].engaged = true
                playerData.trackedAirTargets[nearestID].lastEngagedTime = timer.getTime()
                if PILOT_INTUITION_CONFIG.activeMessaging then
                    MESSAGE:New(self:GetRandomMessage("dogfightEngaged"), 10):ToClient(client)
                end
            end
        end
    end
end

-- Handle being shot at
function PilotIntuition:OnShotFired(EventData)
    if not self.enabled then return end
    local shooter = EventData.IniUnit
    if not shooter then return end
    
    -- Check if any player is the target
    local clients = SET_CLIENT:New():FilterActive():FilterOnce()
    clients:ForEachClient(function(client)
        if client and type(client.GetUnit) == "function" then
            local playerUnit = client:GetUnit()
        if playerUnit and playerUnit:IsAlive() and playerUnit:GetCoalition() ~= shooter:GetCoalition() then
            local playerName = playerUnit:GetPlayerName() or playerUnit:GetName()
            if self.players[playerName] and self.players[playerName].dogfightAssist then
                local playerData = self.players[playerName]
                local now = timer.getTime()
                if not PILOT_INTUITION_CONFIG.activeMessaging then return end
                
                -- Check if shot is directed at player (within range and aspect)
                local distance = playerUnit:GetCoordinate():Get2DDistance(shooter:GetCoordinate())
                if distance < 1500 and (now - playerData.lastDogfightAssistTime) >= PILOT_INTUITION_CONFIG.dogfightMessageCooldown then
                    local playerPos = playerUnit:GetCoordinate()
                    local shooterPos = shooter:GetCoordinate()
                    local bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(shooterPos))
                    local playerHeading = math.deg(playerUnit:GetHeading())
                    local relativeBearing = (bearing - playerHeading + 360) % 360
                    
                    -- Determine evasion direction
                    local direction = "left"
                    if relativeBearing > 180 then
                        direction = "right"
                    end
                    
                    -- Check if above or below
                    local altDelta = shooter:GetAltitude() - playerUnit:GetAltitude()
                    local vertical = ""
                    if altDelta > 100 then
                        vertical = " Push!"
                    elseif altDelta < -100 then
                        vertical = " Pull!"
                    end
                    
                    MESSAGE:New(self:GetRandomMessage("underFire", {direction, vertical})):ToClient(client)
                    playerData.lastDogfightAssistTime = now
                end
            end
        end
        end
    end)
end

-- Initialize the Pilot Intuition system
local pilotIntuitionSystem = PilotIntuition:New()

-- Event handler for shots
EVENT:New():HandleEvent(EVENTS.Shot, function(EventData) 
    pilotIntuitionSystem:OnPlayerShot(EventData)
    pilotIntuitionSystem:OnShotFired(EventData)
end)