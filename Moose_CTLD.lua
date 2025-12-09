---@diagnostic disable: undefined-field, deprecated
-- Pure-MOOSE, template-free CTLD-style logistics & troop transport
-- Drop-in script: no MIST, no mission editor templates required
-- Dependencies: Moose.lua must be loaded before this script
-- Author: Copilot (generated)
--
-- LOGGING SYSTEM:
-- LogLevel configuration controls verbosity: 0=NONE, 1=ERROR, 2=INFO (default), 3=VERBOSE, 4=DEBUG
-- Set LogLevel in config to reduce log spam on production servers. See LOGGING_GUIDE.md for details.

-- Contract
-- Inputs: Config table or defaults. No ME templates needed. Zones may be named ME trigger zones or provided via coordinates in config.
-- Outputs: F10 menus for helo/transport groups; crate spawning/building; troop load/unload; optional JTAC hookup (via FAC module);
-- Error modes: missing Moose -> abort; unknown crate key -> message; spawn blocked in enemy airbase; zone missing -> message.
-- 
-- Orignal Author of CTLD: Ciribob
-- Moose adaptation: Lathe, Copilot, F99th-TracerFacer

---@diagnostic disable: undefined-global, lowercase-global
-- MOOSE framework globals are defined at runtime by DCS World

--#region Config
_DEBUG = false
local CTLD = {}
CTLD.Version = '1.0.2'
CTLD.__index = CTLD
CTLD._lastSalvageInterval = CTLD._lastSalvageInterval or 0
CTLD._playerUnitPrefs = CTLD._playerUnitPrefs or {}

local _msgGroup, _msgCoalition
local _log, _logError, _logInfo, _logVerbose, _logDebug, _logImmediate

-- General CTLD event messages (non-hover). Tweak freely.
CTLD.Messages = {
  -- Crates
  crate_spawn_requested = "Request received—spawning {type} crate at {zone}.",
  pickup_zone_required = "Move within {zone_dist} {zone_dist_u} of a Supply Zone to request crates. Bearing {zone_brg}° to nearest zone.",
  no_pickup_zones = "No Pickup Zones are configured for this coalition. Ask the mission maker to add supply zones or disable the pickup zone requirement.",
  crate_re_marked = "Re-marking crate {id} with {mark}.",
  crate_expired = "Crate {id} expired and was removed.",
  crate_max_capacity = "Max load reached ({total}). Drop or build before picking up more.",
  crate_aircraft_capacity = "Aircraft capacity reached ({current}/{max} crates). Your {aircraft} can only carry {max} crates.",
  troop_aircraft_capacity = "Aircraft capacity reached. Your {aircraft} can only carry {max} troops (you need {count}).",
  crate_spawned = "Crate’s live! {type} [{id}]. Bearing {brg}° range {rng} {rng_u}.\nCall for vectors if you need a hand.\n\nTo load: HOVER within 25m at 5-20m AGL, or LAND within 35m and hold for 25s.",

  -- Drops
  drop_initiated = "Dropping {count} crate(s) here…",
  dropped_crates = "Dropped {count} crate(s) at your location.",
  no_loaded_crates = "No loaded crates to drop.",

  -- Build
  build_insufficient_crates = "Insufficient crates to build {build}.",
  build_requires_ground = "You have {total} crate(s) onboard—drop them first to build here.",
  build_started = "Building {build} at your position…",
  build_success = "{build} deployed to the field!",
  build_success_coalition = "{player} deployed {build} to the field!",
  build_failed = "Build failed: {reason}.",
  fob_restricted = "FOB building is restricted to designated FOB zones.",
  auto_fob_built = "FOB auto-built at {zone}.",

  -- Troops
  troops_loaded = "Loaded {count} troops—ready to deploy.",
  troops_unloaded = "Deployed {count} troops.",
  troops_unloaded_coalition = "{player} deployed {count} troops.",
  troops_fast_roped = "Fast-roped {count} troops into the field!",
  troops_fast_roped_coalition = "{player} fast-roped {count} troops from {aircraft}!",
  no_troops = "No troops onboard.",
  troops_deploy_failed = "Deploy failed: {reason}.",
  troop_pickup_zone_required = "Move inside a Supply Zone to load troops. Nearest zone is {zone_dist}, {zone_dist_u} away bearing {zone_brg}°.",
  troop_load_must_land = "Must be on the ground to load troops. Land and reduce speed to < {max_speed} {speed_u}.",
  troop_load_too_fast = "Ground speed too high for loading. Reduce to < {max_speed} {speed_u} (current: {current_speed} {speed_u}).",
  troop_unload_altitude_too_high = "Too high for fast-rope deployment. Maximum: {max_agl} m AGL (current: {current_agl} m). Land or descend.",
  troop_unload_altitude_too_low = "Too low for safe fast-rope. Minimum: {min_agl} m AGL (current: {current_agl} m). Climb or land.",

  -- Ground auto-load
  ground_load_started = "{ground_line}\nHold position for {seconds}s to load {count} crate(s)...",
  ground_load_progress = "{ground_line}\n{remaining}s remaining. Hold position.",
  ground_load_complete = "{ground_line}\nLoaded {count} crate(s).",
  ground_load_aborted = "Ground load aborted: aircraft moved or lifted off.",
  ground_load_no_zone = "Ground auto-load requires being inside a Pickup Zone. Nearest zone: {zone_dist} {zone_dist_u} at {zone_brg}°.",
  ground_load_no_crates = "No crates within {radius}m to load.",

  -- Coach & nav
  vectors_to_crate = "Nearest crate {id}: bearing {brg}°, range {rng} {rng_u}.",
  vectors_to_pickup_zone = "Nearest supply zone {zone}: bearing {brg}°, range {rng} {rng_u}.",
  coach_enabled = "Hover Coach enabled.",
  coach_disabled = "Hover Coach disabled.",

  -- Hover Coach guidance
  coach_arrival = "You’re close—nice and easy. Hover at 5–20 meters.",
  coach_close = "Reduce speed below 15 km/h and set 5–20 m AGL.",
  coach_hint = "{hints} GS {gs} {gs_u}.",
  coach_too_fast = "Too fast for pickup: GS {gs} {gs_u}. Reduce below 8 km/h.",
  coach_too_high = "Too high: AGL {agl} {agl_u}. Target 5–20 m.",
  coach_too_low = "Too low: AGL {agl} {agl_u}. Maintain at least 5 m.",
  coach_drift = "Outside pickup window. Re-center within 25 m.",
  coach_hold = "Oooh, right there! HOLD POSITION…",
  coach_loaded = "Crate is hooked! Nice flying!",
  coach_hover_lost = "Movement detected—recover hover to load.",
  coach_abort = "Hover lost. Reacquire within 25 m, GS < 8 km/h, AGL 5–20 m.",

  -- Zone state changes
  zone_activated = "{kind} Zone {zone} is now ACTIVE.",
  zone_deactivated = "{kind} Zone {zone} is now INACTIVE.",
  
  -- Attack/Defend announcements
  attack_enemy_announce = "{unit_name} deployed by {player} has spotted an enemy {enemy_type} at {brg}°, {rng} {rng_u}. Moving to engage!",
  attack_base_announce = "{unit_name} deployed by {player} is moving to capture {base_name} at {brg}°, {rng} {rng_u}.",
  attack_no_targets = "{unit_name} deployed by {player} found no targets within {rng} {rng_u}. Holding position.",

  jtac_onstation = "JTAC {jtac} on station. CODE {code}.",
  jtac_new_target = "JTAC {jtac} lasing {target}. CODE {code}. POS {grid}.",
  jtac_target_lost = "JTAC {jtac} lost target. Reacquiring.",
  jtac_target_destroyed = "JTAC {jtac} reports target destroyed.",
  jtac_idle = "JTAC {jtac} scanning for targets.",

  -- Zone restrictions
  drop_forbidden_in_pickup = "Cannot drop crates inside a Supply Zone. Move outside the zone boundary.",
  troop_deploy_forbidden_in_pickup = "Cannot deploy troops inside a Supply Zone. Move outside the zone boundary.",
  drop_zone_too_close_to_pickup = "Drop Zone creation blocked: too close to Supply Zone {zone} (need at least {need} {need_u}; current {dist} {dist_u}). Fly further away and try again.",
  
  -- MEDEVAC messages
  medevac_crew_spawned = "MEDEVAC REQUEST: {vehicle} crew at {grid}. {crew_size} personnel awaiting rescue. Salvage value: {salvage}.",
  medevac_crew_loaded = "Rescued {vehicle} crew ({crew_size} personnel). {vehicle} will respawn shortly.",
  medevac_vehicle_respawned = "{vehicle} repaired and returned to the field at original location!",
  medevac_crew_delivered_mash = "{player} delivered {vehicle} crew to MASH. Earned {salvage} salvage points! Coalition total: {total}.",
  medevac_crew_timeout = "MEDEVAC FAILED: {vehicle} crew at {grid} KIA - no rescue attempted. Vehicle lost.",
  medevac_crew_killed = "MEDEVAC FAILED: {vehicle} crew killed in action. Vehicle lost.",
  medevac_crew_killed_lines = {
    "Stranded Crew ({vehicle} @ {grid}): We're taking heavy fire—where's that bird— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Ahh— we're under fire— we can't h— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): They're right on top of us— we won't ho— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Rounds incoming— this is it boys— *explosion*",
    "Stranded Crew ({vehicle} @ {grid}): If you hear this, we didn't make— *static*",
    "Stranded Crew ({vehicle} @ {grid}): No more cover! We can't hold— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): This is it— tell them we tried— *static*",
    "Stranded Crew ({vehicle} @ {grid}): They're all around us— oh God— *explosion*",
    "Stranded Crew ({vehicle} @ {grid}): Taking direct hits— we're not walking out of— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Where's that ride— we're pinned— we can't— *boom*",
    -- New Mo-blame lines
    "Stranded Crew ({vehicle} @ {grid}): Mo said this LZ was 'low threat'—remind him how that turned out— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Copy, still no bird—did Mo forget to file the MEDEVAC again?— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): We only took this route because Mo said it was 'shortcut friendly'— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Tell Mo his ‘won’t be hot for long’ brief was a lie— *explosion*",
    "Stranded Crew ({vehicle} @ {grid}): Command, if Mo planned this exfil, we’d like a refund— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Mo promised we’d be home for chow—guess we’re staying for artillery instead— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): We’re still at {grid}—unless Mo ‘optimized’ the coordinates again— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Whoever let Mo pick this landing zone owes us new helmets— *explosion*",
    "Stranded Crew ({vehicle} @ {grid}): Be advised, Mo’s ‘safe corridor’ is mostly explosions right now— *static*",
    "Stranded Crew ({vehicle} @ {grid}): If the bird’s lost, check if Mo touched the map— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): This is what we get for trusting Mo’s weather call— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Mo swore enemy armor ‘never comes this far’—they’re waving at us— *explosion*",
    "Stranded Crew ({vehicle} @ {grid}): We’re painted from every angle—next time, maybe don’t let Mo do the route card— *static*",
    "Stranded Crew ({vehicle} @ {grid}): If Mo filed our grid as a coffee break, we’re gonna haunt him— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): Radio check—anyone but Mo on comms? We’d like a real pickup— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Mo said ‘in and out, easy day’—we’re on hour one of ‘not easy’— *explosion*",
    "Stranded Crew ({vehicle} @ {grid}): Still no rotors—ask Mo if he scheduled this MEDEVAC for tomorrow— *static*",
    "Stranded Crew ({vehicle} @ {grid}): If Mo’s running the flight schedule, tell him we’re fresh out of patience— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): Mo briefed ‘minimal contact’—we’re currently meeting the entire enemy battalion— *static*",
    "Stranded Crew ({vehicle} @ {grid}): Rescue bird, if you’re circling, that’s Mo’s navigation, not ours— *explosion*",
    "Stranded Crew ({vehicle} @ {grid}): We popped smoke twice—maybe Mo told them to ignore it— *static*",
    "Stranded Crew ({vehicle} @ {grid}): If they ask how we got stuck here, just say ‘Mo’—they’ll understand— *boom*",
    "Stranded Crew ({vehicle} @ {grid}): Mo said ‘what’s the worst that could happen’—tell him he’s about to find out— *static*",
  },
  medevac_no_requests = "No active MEDEVAC requests.",
  medevac_vectors = "MEDEVAC: {vehicle} crew bearing {brg}°, range {rng} {rng_u}. Time remaining: {time_remain} mins.",
  medevac_salvage_status = "Coalition Salvage Points: {points}. Use salvage to build out-of-stock items.",
  medevac_salvage_used = "Built {item} using {salvage} salvage points. Remaining: {remaining}.",
  medevac_salvage_insufficient = "Out of stock. Requires {need} salvage points (need {deficit} more). Earn salvage by delivering MEDEVAC crews to MASH or sling-loading enemy wreckage.",
  medevac_crew_warn_15min = "WARNING: {vehicle} crew at {grid} - rescue window expires in 15 minutes!",
  medevac_crew_warn_5min = "URGENT: {vehicle} crew at {grid} - rescue window expires in 5 minutes!",
  medevac_unload_hold = "MEDEVAC: Stay grounded in the MASH zone for {seconds} seconds to offload casualties.",
  
  -- Sling-Load Salvage messages
  slingload_salvage_spawned = "SALVAGE OPPORTUNITY: Enemy wreckage at {grid}. Weight: {weight}kg, Est. Value: {reward}pts. {time_remain} remaining to collect!",
  slingload_salvage_delivered = "{player} delivered {weight}kg salvage for {reward} points ({condition})! Coalition total: {total}",
  slingload_salvage_expired = "SALVAGE LOST: Crate {id} at {grid} deteriorated.",
  slingload_salvage_damaged = "CAUTION: Salvage crate damaged in transit. Value reduced to {reward}pts.",
  slingload_salvage_vectors = "Nearest salvage crate {id}: bearing {brg}°, range {rng} {rng_u}. Weight: {weight}kg, Value: {reward}pts.",
  slingload_salvage_no_crates = "No active salvage crates available.",
  slingload_salvage_zone_created = "Salvage Collection Zone '{zone}' created at your position (radius: {radius}m).",
  slingload_salvage_zone_activated = "Salvage Collection Zone '{zone}' is now ACTIVE.",
  slingload_salvage_zone_deactivated = "Salvage Collection Zone '{zone}' is now INACTIVE.",
  slingload_salvage_warn_30min = "SALVAGE REMINDER: Crate {id} at {grid} expires in 30 minutes. Weight: {weight}kg.",
  slingload_manual_crates_registered = "Registered {count} pre-placed salvage crate(s) from mission editor.",
  
  -- FARP System messages
  farp_upgrade_started = "Upgrading FOB to FARP Stage {stage}... Building in progress.",
  farp_upgrade_complete = "{player} upgraded FOB to FARP Stage {stage}!\nFOB still active for logistics and troop operations.",
  farp_upgrade_complete_stage3 = "{player} upgraded FOB to FARP Stage 3!\nFunctional FARP operational! Use F8 Ground Crew for refuel/rearm services.\nFOB still active for logistics and troop operations.",
  farp_upgrade_insufficient_salvage = "Insufficient salvage to upgrade to FARP Stage {stage}. Need {need} points (have {current}). Deliver crews to MASH or sling-load salvage!",
  farp_status = "FOB + FARP Status: Stage {stage}/{max_stage}\nInfrastructure only - upgrade to Stage 3 for services\nFOB logistics: ACTIVE\nNext upgrade: {next_cost} salvage (Stage {next_stage})",
  farp_status_stage3 = "FOB + FARP Status: Stage 3/3\nFunctional FARP operational - use F8 Ground Crew menu\nFOB logistics: ACTIVE\nNext upgrade: {next_cost} salvage (Stage {next_stage})",
  farp_status_maxed = "FOB + FARP Status: Stage 3/3 (FULLY UPGRADED)\nFunctional FARP operational - use F8 Ground Crew menu\nFOB logistics: ACTIVE",
  farp_not_at_fob = "You must be near a FOB Pickup Zone to upgrade it to a FARP.",
  farp_already_maxed = "This FOB is already at maximum FARP stage (Stage 3).",
  slingload_salvage_warn_5min = "SALVAGE URGENT: Crate {id} at {grid} expires in 5 minutes!",
  slingload_salvage_hooked_in_zone = "Salvage crate {id} is inside {zone}. Release the sling to complete delivery.",
  slingload_salvage_wrong_zone = "Salvage crate {id} is sitting in {zone_type} zone {zone}. Take it to an active Salvage zone for credit.",
  slingload_salvage_received_quips = {
    "{player}: Leroy just whispered that's the smoothest receiving job he's seen since Jenkins tried the backwards hover.",
    "Jenkins radios {player}, 'Keep receiving cargo like that and Mo might finally stop polishing his hook.'",
    "Mo mutters, 'I thought we were receiving ammo, not a love letter, {player}.'",
    "Leroy is yelling 'RECEIVE IT' like we're back at basic—nice work, {player}.",
    "Jenkins keeps a scoreboard titled 'Most dramatic receiving'. Congrats, {player}, you're on top.",
    "Mo claims he can hear the crate blush when {player} talks about receiving it.",
    "Leroy swears the secret to receiving cargo is wink twice and yell 'Jenkins!'—apparently {player} nailed it.",
    "Jenkins asked if {player} offers receiving lessons; I told him to practice on Mo's toolbox first.",
    "Mo's diary entry tonight: '{player} received cargo and my rotor wash feelings.'",
    "Leroy just gave {player} a 'World's Best Receiver' sticker; don't ask where he kept it.",
    "Jenkins would like to know how {player} made receiving cargo look like interpretive dance.",
    "Mo says the crate purred when {player} set it down. I blame Leroy's commentary.",
    "Leroy keeps chanting 'receiver of the year' while pointing at {player}. Jenkins is jealous.",
    "Jenkins tried to high five {player} mid-receive; Mo tackled him for safety reasons (probably).",
    "Mo claims {player}'s receiving form violates at least three flirtation regulations.",
    "Leroy just filed paperwork changing {player}'s callsign to 'Receiver Prime'.",
    "Jenkins bet Mo twenty bucks {player} would blush while receiving. Pay up, Mo.",
    "Mo suggests engraving {player}'s name on the salvage zone after that receive.",
    "Leroy is teaching a receiving clinic now, curriculum: 'Be {player}'.",
    "Jenkins whispered, 'Was it good for you, cargo?' right after {player} touched down.",
    "Mo's clipboard has doodles of {player} receiving crates with heroic sparkles.",
    "Leroy just threw fake rose petals over the zone as {player} finished receiving.",
    "Jenkins swears he heard a saxophone during that receive. You owe the band, {player}.",
    "Mo radioed, 'Easy on the receiving, {player}. Jenkins can't handle that much elegance.'",
    "Leroy said {player}'s receiving style is 'spicy yet responsible'. I'm both impressed and confused.",
    "Jenkins taped a 'Certified Receiver' badge on {player}'s dash. It's glittery. You're stuck with it.",
    "Mo reckons {player} could receive a crate blindfolded; Leroy begged to test that theory.",
    "Leroy keeps shouting 'stick the landing' but {player} already did—twice.",
    "Jenkins requested that {player} narrate the next receiving so he can take notes.",
    "Mo says if {player} receives one more crate like that, he'll start writing poetry.",
    "Leroy just named this salvage drop 'Operation Receive and Believe' in {player}'s honor.",
    "Jenkins said '{player} receives cargo like it's a surprise party and everyone's invited.'",
    "Mo's new checklist: 1) Fuel 2) Ammo 3) Compliment {player}'s receiving technique.",
    "Leroy tried to slow clap mid-receive; Jenkins confiscated his gloves.",
    "Jenkins asked if {player} rehearsed that receive with mirrors. Mo said 'jealous much?'.",
    "Mo beams, 'If receiving had judges, {player} just earned a 10 from Leroy and a dramatic sigh from Jenkins.'",
    "Leroy told {player} to teach Jenkins how to receive without dropping his dignity.",
    "Jenkins insists {player}'s receiving aura smells like jet fuel and confidence.",
    "Mo logged today's weather as 'partly cloudy with a 100% chance of {player} receiving nicely.'",
    "Leroy carved '{player} receives like a legend' into the ready room table. Again.",
    "Jenkins wrote a haiku about that receiving: 'Crate softly descends / {player} grins / Mo steals the pen.'",
    "Mo radioed 'next crate volunteers to be received by {player} only'. That's a policy now.",
    "Leroy just asked supply for a 'Receiver of Renown' patch for {player}.",
    "Jenkins claims he can feel the cargo sigh happily whenever {player} receives it.",
    "Mo's schedule: 0900 watch {player} receive cargo, 0915 tease Jenkins about it.",
    "Leroy calls {player}'s receiving style 'buttery smooth'. Jenkins now refuses to eat butter.",
    "Jenkins left a sticky note on the crate: 'Thanks for receiving me gently, {player}.'",
    "Mo wants to rename the salvage zone 'The {player} Receiving Lounge'.",
    "Leroy drew hearts on the map where {player} usually receives cargo. Tactical? Maybe.",
    "Jenkins petitioned command to play theme music every time {player} receives.",
    "Mo refuses to stop chuckling about the way {player} said 'receiving' over comms.",
    "Leroy says {player}'s receiving vibe is 'half heroics, half mischief'. Jenkins says 'all jealous'.",
    "Jenkins asked if {player} could autograph the crate before sending it to depots.",
    "Mo declared 'receiving is believing' after watching {player} today.",
    "Leroy reenacting {player}'s receiving on the ramp is the finest comedy we've had all week.",
    "Jenkins keeps practicing saying 'receiving' with the same swagger {player} has.",
    "Mo whispers, 'Every time {player} receives cargo, a wrench somewhere falls in love.'",
    "Leroy filed a noise complaint: 'Jenkins screaming while {player} receives is distracting.'",
    "Jenkins now greets crates with 'prepare to be received by {player}—lucky you.'",
    "Mo replaced the zone sign with 'Please announce yourself before {player} receives you.'",
    "Leroy says the salvage crate winked at {player}. Jenkins is skeptical but also jealous.",
    "Jenkins claims {player}'s receiving technique could calm a startled MANPAD crew.",
    "Mo has a coffee mug that reads 'I watched {player} receive cargo and all I got was this latte.'",
    "Leroy tried to choreograph a receiving dance for {player}; Jenkins tripped at step two.",
    "Jenkins keeps bragging he called dibs on being {player}'s receiving hype man.",
    "Mo scribbled 'receiving champion' under {player}'s name on the roster.",
    "Leroy says {player}'s receiving voice has more bass than the AWACS channel.",
    "Jenkins asked supply for velvet ropes to keep crowds away while {player} receives.",
    "Mo's new ringtone is {player} saying 'receiving'. Leroy set it as his alarm too.",
    "Leroy's advice to rookies: 'Just copy whatever {player} does when receiving.'",
    "Jenkins says he needs sunglasses to watch {player} receive because it's that dazzling.",
    "Mo keeps muttering 'receiving goals' every time {player} touches down in the zone.",
    "Leroy left chalk arrows around the FARP labeled 'This way to watch {player} receive.'",
    "Jenkins insists the crate asked for {player}'s comm frequency after that receive.",
    "Mo bet the maintenance crew that {player} could receive cargo upside down. Please don't try it.",
    "Leroy's latest call sign suggestion for {player}: 'Receiver Supreme'.",
    "Jenkins laminated a card that says 'Ask me about {player}'s receiving technique.'",
    "Mo says the wind socks lean toward {player} out of respect whenever receiving begins.",
    "Leroy drew a cartoon of {player} receiving cargo while Jenkins fans them with a checklist.",
    "Jenkins keeps replaying the cockpit tape of {player} saying 'receiving' on loop.",
    "Mo told supply to send extra polish for the pad because {player} only receives on shiny decks.",
    "Leroy swears he heard the crate whisper 'thanks, {player}' as it touched down.",
    "Jenkins offers motivational speeches to crates before {player} arrives, just to set the mood.",
    "Mo added 'compliment {player}'s receiving tone' to the preflight checklist.",
    "Leroy refuses to call it unloading anymore; it's 'the {player} receiving ritual'.",
    "Jenkins keeps practicing finger guns for when {player} calls 'receiving'.",
    "Mo doodled {player} surfing on a crate labeled 'Receiving Champion'.",
    "Leroy renamed the F10 menu option to 'Let {player} receive it'. QA is furious.",
    "Jenkins says whenever {player} receives cargo, somewhere a sim pilot sheds a proud tear.",
    "Mo now greets every crate with 'Ready to be received {player}-style?'.",
    "Leroy told the intel guys to log {player}'s receiving pattern as a morale asset.",
    "Jenkins claims {player}'s receiving aura smells like hydraulic fluid and heroics.",
    "Mo keeps a chalkboard tally titled '{player}'s Receives vs Jenkins' Complaints'. Receives win.",
    "Leroy is convinced {player}'s receiving callouts add five knots to every rotorcraft nearby.",
    "Jenkins practices saying 'nice receiving' in the mirror so he doesn't squeak on comms.",
    "Mo decorated the salvage zone with disco lights for the next time {player} receives.",
    "Leroy asked PAO for a documentary called 'Receiving with {player}'.",
    "Jenkins swears {player}'s receiving cadence syncs perfectly with the base siren. Spooky.",
    "Mo now ends every debrief with 'and that's how {player} receives cargo, folks.'",
    "Leroy wrote a limerick about {player} receiving; Jenkins begged him not to recite it.",
    "Jenkins told the new guy 'if {player} says receiving, salute the crate.'",
    "Mo keeps drawing diagrams titled 'Ideal Receiving Cones' with {player} stick figures.",
    "Leroy asked meteorology for a forecast of '{player} receiving with 100% sass'.",
    "Jenkins says hearing {player} say 'receiving' cured his fear of autorotations.",
    "Mo replaced the salvage beacon tone with {player} humming the receiving tune.",
    "Leroy told Jenkins, 'If you can't receive like {player}, at least clap rhythmically.'",
    "Jenkins is workshopping a catchphrase: '{player} receives, Mo believes, Leroy deceives.'",
    "Mo says the only thing smoother than {player}'s receiving is Leroy's questionable pickup lines.",
    "Leroy wants to build a statue of {player} holding a crate; Jenkins suggested maybe start with a sticker.",
    "Jenkins insists {player}'s receiving voice lowers enemy morale by 10%. Science-ish.",
    "Mo has a bingo card of {player}'s receiving compliments; he's already got blackout.",
    "Leroy now ends every briefing with 'remember, let {player} receive first'.",
    "Jenkins swears his headset auto-tunes whenever {player} says 'receiving'.",
    "Mo just said, 'If receiving had medals, {player} would need a bigger flight suit.'",
    "Leroy warns crates, 'If {player} receives you, expect fireworks and Jenkins squealing.'",
    "Jenkins' new mantra: 'Breathe in rotor wash, breathe out {player}'s receiving tips.'",
    "Mo says {player}'s receiving swagger should be issued with the flight manual.",
    "Leroy doodled {player} riding a crate labeled 'Receiving Express'—Mo framed it.",
    "Jenkins told logistics, 'Mark that crate FRAGILE, {player} receives with feelings.'",
    "Mo now pronounces 'receiving' with extra syllables whenever {player} is on station.",
    "Leroy thinks {player}'s receiving just added three morale points to the whole AO.",
    "Jenkins said he'd write a sonnet about {player}'s receiving if he knew what a sonnet was.",
    "Mo just asked if we could get {player} to receive the mail too, because wow.",
    "Leroy polished the landing zone so {player}'s next receiving feels fancy.",
    "Jenkins is holding up scorecards every time {player} says 'receiving'. The numbers keep climbing.",
    "Mo claims {player}'s receiving is now a controlled substance in three states.",
    "Leroy told everyone to clear the pad—'{player} needs room to receive with flair!'.",
    "Jenkins thinks {player}'s receiving tone should replace the standard 'cargo secure' call.",
    "Mo concluded today's briefing with 'Step 1: Let {player} receive. Step 2: Profit.'",
    "Leroy keeps whispering 'look how {player} receives' like it's a wildlife documentary.",
    "Jenkins renamed his playlist 'Songs to Receive Cargo Like {player}'.",
    "Mo's checklist scribble says 'Remember to compliment {player} after receiving'.",
    "Leroy just added 'receiving swagger' to the SOP because of {player}.",
    "Jenkins insists {player}'s receiving posture cured his back pain. Untested claim.",
    "Mo now uses '{player}-level receiving' as a unit of measurement for excellence.",
    "Leroy stuck a note on the crate: 'You were received by {player}. You're welcome.'",
    "Jenkins laughed so hard at {player}'s receiving banter that he nearly dropped his clipboard.",
    "Mo just declared {player} the patron saint of receiving, halo made of tie-down straps.",
    "Leroy vows to shout 'RECEIVE IT' every time {player} descends, purely for morale.",
    "Jenkins says {player}'s receiving swagger should be bottled and issued to recruits.",
  },
  medevac_unload_aborted = "MEDEVAC: Unload aborted - {reason}. Land and hold for {seconds} seconds.",
  
  -- Mobile MASH messages
  medevac_mash_deployed = "Mobile MASH {mash_id} deployed at {grid}. Beacon: {freq}. Delivering MEDEVAC crews here earns salvage points.",
  medevac_mash_announcement = "Mobile MASH {mash_id} available at {grid}. Beacon: {freq}.",
  medevac_mash_destroyed = "Mobile MASH {mash_id} destroyed! No longer accepting deliveries.",
  mash_announcement = "MASH {name} operational at {grid}. Accepting MEDEVAC deliveries for salvage credit. Monitoring {freq} AM.",
  mash_vectors = "Nearest MASH: {name} at bearing {brg}°, range {rng} {rng_u}.",
  mash_no_zones = "No MASH zones available.",
}

--#endregion Messaging

CTLD.Config = {
  -- === Instance & Access ===
  CoalitionSide = coalition.side.BLUE,   -- default coalition this instance serves (menus created for this side)
  CountryId = nil,                       -- optional explicit country id for spawned groups; falls back per coalition
  AllowedAircraft = {                    -- transport-capable unit type names (case-sensitive as in DCS DB)
    'UH-1H','Mi-8MTV2','Mi-24P','SA342M','SA342L','SA342Minigun','Ka-50','Ka-50_3','AH-64D_BLK_II','UH-60L','CH-47Fbl1','CH-47F','Mi-17','GazelleAI'
  },
  -- === Runtime & Messaging ===
  -- Logging control: set the desired level of detail for env.info logging to DCS.log
  -- 0 = NONE      - No logging at all (production servers)
  -- 1 = ERROR     - Only critical errors and warnings
  -- 2 = INFO      - Important state changes, initialization, cleanup (default for production)
  -- 3 = VERBOSE   - Detailed operational info (zone validation, menus, builds, MEDEVAC events)
  -- 4 = DEBUG     - Everything including hover checks, crate pickups, detailed troop spawns
  LogLevel = 1,  -- lowered from DEBUG (4) to INFO (2) for production performance
  MessageDuration = 15,                  -- seconds for on-screen messages

  -- Debug toggles for detailed crate proximity logging (useful when tuning hover coach / ground autoload)
  DebugHoverCrates = false,
  DebugHoverCratesInterval = 1.0,      -- seconds between hover debug log bursts (per aircraft)
  DebugHoverCratesStep = 25,           -- log again when nearest crate distance changes by this many meters
  DebugGroundCrates = false,
  DebugGroundCratesInterval = 2.0,     -- seconds between ground debug log bursts (per aircraft)
  DebugGroundCratesStep = 10,          -- log again when nearest crate distance changes by this many meters

  -- === Menu & Catalog ===
  UseGroupMenus = true,                  -- if true, F10 menus per player group; otherwise coalition-wide (leave this alone)
  CreateMenuAtMissionStart = false,      -- creates empty root menu at mission start to reserve F10 position (populated on player spawn)
  RootMenuName = 'CTLD',                 -- name for the root F10 menu; menu ordering depends on script load order in mission editor
  UseCategorySubmenus = true,            -- if true, organize crate requests by category submenu (menuCategory)
  UseBuiltinCatalog = false,             -- start with the shipped catalog (true) or expect mission to load its own (false)

  -- === Transport Capacity ===
  -- Default capacities for aircraft not listed in AircraftCapacities table
  -- Used as fallback for any transport aircraft without specific limits defined
  DefaultCapacity = {
    maxCrates = 4,      -- reasonable middle ground
    maxTroops = 12,     -- moderate squad size
    maxWeightKg = 2000, -- default weight capacity in kg (omit to disable weight modeling)
  },

  -- Per-aircraft capacity limits (realistic cargo/troop capacities)
  -- Set maxCrates = 0 and maxTroops = 0 for attack helicopters with no cargo capability
  -- If an aircraft type is not listed here, it will use DefaultCapacity values
  -- maxWeightKg: optional weight capacity in kilograms (if omitted, only count limits apply)
  -- requireGround: optional override for ground requirement (true = must land, false = can load in hover/flight)
  -- maxGroundSpeed: optional override for max ground speed during loading (m/s)
  AircraftCapacities = {
    -- Small/Light Helicopters (very limited capacity)
    ['SA342M']        = { maxCrates = 1,  maxTroops = 3,  maxWeightKg = 400 },   -- Gazelle - tiny observation/scout helo
    ['SA342L']        = { maxCrates = 1,  maxTroops = 3,  maxWeightKg = 400 },
    ['SA342Minigun']  = { maxCrates = 1,  maxTroops = 3,  maxWeightKg = 400 },
    ['GazelleAI']     = { maxCrates = 1,  maxTroops = 3,  maxWeightKg = 400 },

    -- Attack Helicopters (no cargo capacity - combat only)
    ['Ka-50']         = { maxCrates = 0,  maxTroops = 0,  maxWeightKg = 0 },     -- Black Shark - single seat attack
    ['Ka-50_3']       = { maxCrates = 0,  maxTroops = 0,  maxWeightKg = 0 },     -- Black Shark 3
    ['AH-64D_BLK_II'] = { maxCrates = 0,  maxTroops = 0,  maxWeightKg = 0 },     -- Apache - attack/recon only
    ['Mi-24P']        = { maxCrates = 2,  maxTroops = 8,  maxWeightKg = 1000 },  -- Hind - attack helo but has small troop bay

    -- Light Utility Helicopters (moderate capacity)
    ['UH-1H']         = { maxCrates = 3,  maxTroops = 11, maxWeightKg = 1800 },  -- Huey - classic light transport

    -- Medium Transport Helicopters (good capacity)
    ['Mi-8MTV2']      = { maxCrates = 5,  maxTroops = 24, maxWeightKg = 4000 },  -- Hip - Russian medium transport
    ['Mi-17']         = { maxCrates = 5,  maxTroops = 24, maxWeightKg = 4000 },  -- Hip variant
    ['UH-60L']        = { maxCrates = 4,  maxTroops = 11, maxWeightKg = 4000 },  -- Black Hawk - medium utility

    -- Heavy Lift Helicopters (maximum capacity)
    ['CH-47Fbl1']     = { maxCrates = 10, maxTroops = 33, maxWeightKg = 12000 }, -- Chinook - heavy lift beast
    ['CH-47F']        = { maxCrates = 10, maxTroops = 33, maxWeightKg = 12000 }, -- Chinook variant

    -- Fixed Wing Transport (limited capacity)
    -- NOTE: C-130 has requireGround configurable - set to false if you want to allow in-flight loading (unrealistic but flexible)
    ['C-130']         = { maxCrates = 20, maxTroops = 92, maxWeightKg = 20000, requireGround = true, maxGroundSpeed = 1.0 }, -- C-130 Hercules - tactical airlifter (must be fully stopped)
    ['C-17A']         = { maxCrates = 30, maxTroops = 150, maxWeightKg = 77500, requireGround = true, maxGroundSpeed = 1.0 }, -- C-17 Globemaster III - strategic airlifter
  },

  -- === Loading & Deployment Rules ===
  RequireGroundForTroopLoad = true,      -- must be landed to load troops (prevents loading while hovering)
  RequireGroundForVehicleLoad = true,    -- must be landed to load vehicles (C-130/large transports)
  MaxGroundSpeedForLoading = 2.0,        -- meters/second limit while loading (roughly 4 knots)

  -- Fast-rope deployment (allows troop unload while hovering at safe altitude)
  EnableFastRope = true,                 -- if true, troops can fast-rope from hovering helicopters
  FastRopeMaxHeight = 20,                -- meters AGL: maximum altitude for fast-rope deployment
  FastRopeMinHeight = 5,                 -- meters AGL: minimum altitude for fast-rope deployment (too low = collision risk)

  -- Safety offsets to avoid spawning units too close to player aircraft
  BuildSpawnOffset = 40,                 -- meters: shift build point forward from the aircraft (0 = spawn centered on aircraft)
  TroopSpawnOffset = 25,                 -- meters: shift troop unload point forward from the aircraft
  DropCrateForwardOffset = 35,           -- meters: drop loaded crates this far in front of the aircraft

  -- === Build & Crate Handling ===
  BuildRequiresGroundCrates = true,      -- required crates must be on the ground (not still carried)
  BuildRadius = 100,                     -- meters around build point to collect crates
  BuildDispersionRadius = 30,            -- meters: randomize spawn positions within this radius (Build All mode only; 0 = disable)
  RestrictFOBToZones = false,            -- only allow FOB recipes inside configured FOBZones
  AutoBuildFOBInZones = false,           -- auto-build FOB recipes when required crates are inside a FOB zone
  CrateLifetime = 3600,                  -- seconds before crates auto-clean up; 0 = disable

  -- Build safety
  BuildConfirmEnabled = false,           -- require a second confirmation within a short window before building
  BuildConfirmWindowSeconds = 30,        -- seconds allowed between first and second "Build Here" press
  BuildCooldownEnabled = true,           -- impose a cooldown before allowing another build by the same group
  BuildCooldownSeconds = 0,             -- seconds of cooldown after a successful build per group

  -- === Pickup & Drop Zone Rules ===
  RequirePickupZoneForCrateRequest = true, -- enforce that crate requests must be near a Supply (Pickup) Zone
  RequirePickupZoneForTroopLoad = true,   -- troops can only be loaded while inside a Supply (Pickup) Zone
  PickupZoneMaxDistance = 10000,          -- meters; nearest pickup zone must be within this distance to allow a request
  ForbidDropsInsidePickupZones = true,    -- block crate drops while inside a Pickup Zone
  ForbidTroopDeployInsidePickupZones = true, -- block troop deploy while inside a Pickup Zone
  ForbidChecksActivePickupOnly = true,    -- when true, restriction applies only to ACTIVE pickup zones; false blocks all configured pickup zones

  -- Dynamic Drop Zone settings
  DropZoneRadius = 500,                  -- meters: radius used when creating a Drop Zone via the admin menu at player position
  MinDropZoneDistanceFromPickup = 2000,  -- meters: minimum distance from nearest Pickup Zone required to create a dynamic Drop Zone (0 to disable)
  MinDropDistanceActivePickupOnly = true, -- when true, only ACTIVE pickup zones are considered for the minimum distance check

  -- === Pickup Zone Spawn Placement ===
  PickupZoneSpawnRandomize = true,       -- spawn crates at a random point within the pickup zone (avoids stacking)
  PickupZoneSpawnEdgeBuffer = 20,        -- meters: keep spawns at least this far inside the zone edge
  PickupZoneSpawnMinOffset = 75,        -- meters: keep spawns at least this far from the exact center
  CrateSpawnMinSeparation = 7,           -- meters: try not to place a new crate closer than this to an existing one
  CrateSpawnSeparationTries = 6,         -- attempts to find a non-overlapping position before accepting best effort
  CrateClusterSpacing = 8,               -- meters: spacing used when clustering crates within a bundle
  PickupZoneSmokeColor = trigger.smokeColor.Green, -- default smoke color when spawning crates at pickup zones

  -- Crate Smoke Settings
  -- NOTE: Individual smoke effects last ~5 minutes (DCS hardcoded, cannot be changed)
  -- These settings control whether/how often NEW smoke is spawned, not how long each smoke lasts
  CrateSmoke = {
    Enabled = true,                      -- spawn smoke when crates are created; if false, no smoke at all
    AutoRefresh = false,                 -- automatically spawn new smoke every RefreshInterval seconds
    RefreshInterval = 240,               -- seconds: how often to spawn new smoke (only used if AutoRefresh = true)
    MaxRefreshDuration = 600,            -- seconds: stop auto-refresh after this long (safety limit)
    OffsetMeters = 0,                    -- meters: horizontal offset from crate so helicopters don't hover in smoke
    OffsetRandom = true,                 -- if true, randomize horizontal offset direction; if false, always offset north
    OffsetVertical = 20,                 -- meters: vertical offset above ground level (helps smoke be more visible)
  },

  -- === Autonomous Assets ===
  -- Air-spawn settings for CTLD-built drones (AIRPLANE catalog entries like MQ-9 / WingLoong)
  DroneAirSpawn = {
    Enabled = true,                      -- when true, AIRPLANE catalog items that opt-in can spawn in the air at a set altitude
    AltitudeMeters = 5000,               -- default spawn altitude ASL (meters)
    SpeedMps = 120                       -- default initial speed in m/s
  },

  JTAC = {
    Enabled = true,
    Verbose = false,                -- when true, emit detailed JTAC registration & target scan logs
    AutoLase = {
      Enabled = true,
      SearchRadius = 8000,          -- meters to scan for enemy targets
      RefreshSeconds = 15,          -- seconds between active target updates
      IdleRescanSeconds = 30,       -- seconds between scans when no target locked
      LostRetrySeconds = 10,        -- wait before trying to reacquire after transport/line-of-sight loss
      TransportHoldSeconds = 10,    -- defer lase loop while JTAC is in transport (group empty)
    },
    Smoke = {
      Enabled = true,
      ColorBlue = trigger.smokeColor.Orange,
      ColorRed = trigger.smokeColor.Green,
      RefreshSeconds = 300,         -- seconds between smoke refreshes on active targets
      OffsetMeters = 5,             -- random offset radius for smoke placement
    },
    LaserCodes = { '1688','1677','1666','1113','1115','1111' },
    LockType = 'all',               -- 'all' | 'vehicle' | 'troop'
    Announcements = {
      Enabled = true,
      Duration = 15,
    },
    
  },

  -- === Combat Automation ===
  AttackAI = {
    Enabled = true,                 -- master switch for attack behavior
    TroopSearchRadius = 6000,       -- meters: when deploying troops with Attack, search radius for targets/bases
    VehicleSearchRadius = 12000,     -- meters: when building vehicles with Attack, search radius
    PrioritizeEnemyBases = true,    -- if true, prefer enemy-held bases over ground units when both are in range
    -- Smart omniscient targeting: when true, LOS / DCS detection quirks are ignored for target *selection*.
    -- The script will always pick the nearest valid enemy/base within the configured radius and order a move
    -- toward it. DCS AI LOS still governs when units can actually fire once they get there.
    SmartTargeting = true,
    TroopAdvanceSpeedKmh = 20,      -- movement speed for troops when ordered to attack
    VehicleAdvanceSpeedKmh = 35,    -- movement speed for vehicles when ordered to attack
  },

  -- === Visual Aids ===
  -- Optional: draw zones on the F10 map using trigger.action.* markup (ME Draw-like)
  MapDraw = {
    Enabled = true,              -- master switch for any map drawings created by this script
    DrawPickupZones = true,      -- draw Pickup/Supply zones as shaded circles with labels
    DrawDropZones = true,        -- optionally draw Drop zones
    DrawFOBZones = true,         -- optionally draw FOB zones
    DrawMASHZones = true,        -- optionally draw MASH (medical) zones
    DrawSalvageZones = true,     -- optionally draw Salvage Collection zones
    FontSize = 18,               -- label text size
    ReadOnly = true,             -- prevent clients from removing the shapes
    ForAll = false,              -- if true, draw shapes to all (-1) instead of coalition only (useful for testing/briefing)
    OutlineColor = {1, 1, 0, 0.85},  -- RGBA 0..1 for outlines (bright yellow)
    -- Optional per-kind fill overrides
    FillColors = {
      Pickup = {0, 1, 0, 0.15},   -- light green fill for Pickup zones
      Drop   = {0, 0, 0, 0.25},   -- black fill for Drop zones
      FOB    = {1, 1, 0, 0.15},   -- yellow fill for FOB zones
      MASH   = {1, 0.75, 0.8, 0.25}, -- pink fill for MASH zones
      SalvageDrop = {1, 0, 1, 0.15}, -- magenta fill for Salvage zones
    },
    LineType = 1,                -- default line type if per-kind is not set (0 None, 1 Solid, 2 Dashed, 3 Dotted, 4 DotDash, 5 LongDash, 6 TwoDash)
    LineTypes = {                -- override border style per zone kind
      Pickup = 3,                -- dotted
      Drop   = 2,                -- dashed
      FOB    = 4,                -- dot-dash
      MASH   = 1,                -- solid
      SalvageDrop = 2,           -- dashed
    },
    -- Label placement tuning (simple):
    -- Effective extra offset from the circle edge = r * LabelOffsetRatio + LabelOffsetFromEdge
    LabelOffsetFromEdge = -50,    -- meters beyond the zone radius to place the label (12 o'clock)
    LabelOffsetRatio = 0.5,       -- fraction of the radius to add to the offset (e.g., 0.1 => +10% of r)
    LabelOffsetX = 200,           -- meters: horizontal nudge; adjust if text appears left-anchored in your DCS build
    -- Per-kind label prefixes
    LabelPrefixes = {
      Pickup = 'Supply',
      Drop   = 'Drop',
      FOB    = 'FOB',
      MASH   = 'MASH',
      SalvageDrop = 'Salvage',
    }
  },

  -- === Inventory & Troops ===
  -- Inventory system (per pickup zone and FOBs)
  Inventory = {
    Enabled = true,              -- master switch for per-location stock control
    FOBStockFactor = 0.50,       -- starting stock at newly built FOBs relative to pickup-zone initialStock
    ShowStockInMenu = true,      -- append simple stock hints to menu labels (per current nearest zone)
    HideZeroStockMenu = false,   -- removed: previously created an "In Stock Here" submenu; now disabled by default
  },

  -- Troop type presets (menu-driven loadable teams)
  Troops = {
    DefaultType = 'AS',          -- default troop type to use when no specific type is chosen
    -- Team definitions: loaded from catalog via _CTLD_TROOP_TYPES global
    -- If no catalog is loaded, empty table is used (and fallback logic applies)
    TroopTypes = {},
  },

  -- === Zone Tables ===
  -- Mission makers should populate these arrays with zone definitions
  -- Each zone entry can be: { name = 'ZoneName' } or { name = 'ZoneName', flag = 9001, activeWhen = 0, smoke = color, radius = meters }
  Zones = {
    PickupZones = {},  -- Supply zones where crates/troops can be requested
    DropZones   = {},  -- Optional Drop/AO zones
    FOBZones    = {},  -- FOB zones (restrict FOB building to these if RestrictFOBToZones = true)
    MASHZones   = {},  -- Medical zones for MEDEVAC crew delivery (MASH = Mobile Army Surgical Hospital)
    SalvageDropZones = {}, -- Salvage collection zones for sling-load salvage delivery
  },

  -- === Sling-Load Salvage System ===
  -- Spawn salvageable crates when enemy units are destroyed; deliver to collection zones for rewards
  SlingLoadSalvage = {
    Enabled = true,
    
    -- Manual salvage crates (pre-placed in mission editor)
    EnableManualCrates = true,      -- Scan for and register pre-placed cargo statics as salvage
    ManualCratePrefix = 'SALVAGE-', -- Only cargo statics starting with this prefix are registered
    
    -- Spawn probability when enemy ground units die
    SpawnChance = {
      [coalition.side.BLUE] = 0.10, -- 20% chance when BLUE unit dies (RED can collect the salvage)
      [coalition.side.RED] = 0.10,  -- 20% chance when RED unit dies (BLUE can collect the salvage)
    },
    
    -- Weight classes with spawn probabilities and reward rates
    WeightClasses = {
      { name = 'Light', min = 500, max = 1000, probability = 0.50, rewardPer500kg = 0.5 },    -- 1-2 pts (reduced from 2)
      { name = 'Medium', min = 2501, max = 5000, probability = 0.30, rewardPer500kg = 1 },   -- 5-10 pts (reduced from 3)
      { name = 'Heavy', min = 5001, max = 8000, probability = 0.15, rewardPer500kg = 1.5 },  -- 15-24 pts (reduced from 5)
      { name = 'SuperHeavy', min = 8001, max = 12000, probability = 0.05, rewardPer500kg = 2 }, -- 32-48 pts (reduced from 8)
    },
    
    -- Condition-based reward multipliers (based on crate health when delivered)
    ConditionMultipliers = {
      Undamaged = 1.5,     -- >= 90% health
      Damaged = 1.0,       -- 50-89% health
      HeavyDamage = 0.5,   -- < 50% health
    },
    
  CrateLifetime = 3600,   -- 1 hour (seconds)
    WarningTimes = { 1800, 300 }, -- Warn at 30min and 5min remaining
    
    -- Visual indicators
    SpawnSmoke = false,
    SmokeDuration = 120, -- 2 minutes
    SmokeColor = trigger.smokeColor.Orange,
    MaxActiveCrates = 40,    -- hard cap on simultaneously spawned salvage crates per coalition
    AdaptiveIntervals = { idle = 10, low = 20, medium = 25, high = 30 },
    
    -- Spawn restrictions
    MinSpawnDistance = 25,        -- meters from death location
    MaxSpawnDistance = 45,        -- meters from death location
    NoSpawnNearPickupZones = true,
    NoSpawnNearPickupZoneDistance = 1000, -- meters
    NoSpawnNearAirbasesKm = 1,
    
    DetectionInterval = 5, -- seconds between salvage zone checks
    
    -- Cargo static types (DCS sling-loadable cargo)
    CargoTypes = {
      'container_cargo',
      'ammo_cargo',
      'fueltank_cargo',
      'barrels_cargo',
      'uh1h_cargo',
      'pipes_small_cargo',
      'pipes_big_cargo',
      'tetrapod_cargo',
      'trunks_small_cargo',
      'trunks_long_cargo',
      'oiltank_cargo',
      'f_bar_cargo',
      'm117_cargo',
    },
    
    -- Salvage Collection Zone defaults
    DefaultZoneRadius = 300,
    DynamicZoneLifetime = 5400, -- seconds a player-created zone stays active (0 disables auto-expiry)
    MaxDynamicZones = 6,        -- cap player-created zones per coalition instance (oldest retire first)
    ZoneColors = {
      border = {1, 0.5, 0, 0.85},   -- orange border
      fill = {1, 0.5, 0, 0.15},      -- light orange fill
    },
  },
}
--#endregion Config

-- =========================
-- FARP System Configuration
-- =========================
-- Progressive FOB->FARP upgrade system with static object layouts
CTLD.FARPConfig = {
  Enabled = true,
  
  -- Salvage costs for each stage upgrade
  StageCosts = {
    [1] = 10,   -- FOB -> Stage 1 FARP (basic pad)
    [2] = 20,   -- Stage 1 -> Stage 2 (operational fuel)
    [3] = 40,   -- Stage 2 -> Stage 3 (full forward airbase)
  },
  
  -- FARP static object provides services via DCS F8 Ground Crew menu
  -- These radius values are for visual reference only
  ServiceRadius = {
    [1] = 50,   -- Stage 1: basic pad only
    [2] = 65,   -- Stage 2: fuel depot added
    [3] = 80,   -- Stage 3: full FARP with ammo
  },
  
  -- Static object layouts for each FARP stage
  -- Format: { type = "DCS_Static_Name", x = offset_x, z = offset_z, heading = degrees, height = 0 }
  -- Positions are relative to FOB center point
  -- Layout: Square perimeter expanding outward
  -- NOTE: Functional FARP at Stage 3 is ~270m edge-to-edge, so Stages 1-2 must be outside that
  StageLayouts = {
    -- Stage 1: Inner Square Perimeter (3 salvage) - 150m from center (outside FARP footprint)
    [1] = {
      -- North side
      { type = "FARP Tent", x = 0, z = 150, heading = 180 },
      { type = "Windsock", x = 40, z = 150, heading = 0 },
      { type = "container_20ft", x = -40, z = 150, heading = 180 },
      
      -- South side
      { type = "FARP Tent", x = 0, z = -150, heading = 0 },
      { type = "GeneratorF", x = 40, z = -150, heading = 0 },
      { type = "container_20ft", x = -40, z = -150, heading = 0 },
      
      -- East side
      { type = "FARP Tent", x = 150, z = 0, heading = 270 },
      { type = "container_20ft", x = 150, z = 35, heading = 270 },
      
      -- West side
      { type = "FARP Tent", x = -150, z = 0, heading = 90 },
      { type = "container_20ft", x = -150, z = -35, heading = 90 },
    },
    
    -- Stage 2: Outer Square Perimeter (5 salvage) - 200m from center, logistics/support
    [2] = {
      -- North side
      { type = "FARP Fuel Depot", x = -50, z = 200, heading = 180 },
      { type = "FARP Fuel Depot", x = 50, z = 200, heading = 180 },
      { type = "FARP Tent", x = 0, z = 200, heading = 180 },
      { type = "FARP CP Blindage", x = 100, z = 200, heading = 180 },
      
      -- South side  
      { type = "FARP Ammo Dump Coating", x = -50, z = -200, heading = 0 },
      { type = "FARP Ammo Dump Coating", x = 50, z = -200, heading = 0 },
      { type = "container_40ft", x = 0, z = -200, heading = 0 },
      { type = "Shelter", x = -100, z = -200, heading = 0 },
      
      -- East side
      { type = "FARP Tent", x = 200, z = 50, heading = 270 },
      { type = "FARP Tent", x = 200, z = -50, heading = 270 },
      { type = "GeneratorF", x = 200, z = 0, heading = 270 },
      
      -- West side
      { type = "FARP Tent", x = -200, z = 50, heading = 90 },
      { type = "FARP Tent", x = -200, z = -50, heading = 90 },
      { type = "Electric power box", x = -200, z = 0, heading = 90 },
      
      -- Corner markers
      { type = "container_20ft", x = 180, z = 180, heading = 225 },
      { type = "container_20ft", x = -180, z = 180, heading = 135 },
      { type = "container_20ft", x = 180, z = -180, heading = 315 },
      { type = "container_20ft", x = -180, z = -180, heading = 45 },
    },
    
    -- Stage 3: Uses functional FARP - no static layout needed, decorations added separately
    [3] = {},
  },
}

-- Immersive Hover Coach configuration (messages, thresholds, throttling)
-- All user-facing text lives here; logic only fills placeholders.
CTLD.HoverCoachConfig = {
  enabled = true,             -- master switch for hover coaching feature
  coachOnByDefault = true,    -- per-player default; players can toggle via F10 > Navigation > Hover Coach
  
  -- Pickup parameters
  maxCratesPerLoad = 6,       -- maximum crates the aircraft can carry simultaneously
  autoPickupDistance = 25,    -- meters max search distance for candidate crates

  thresholds = {
    arrivalDist = 1000,       -- m: start guidance "You're close…"
    closeDist = 100,          -- m: reduce speed / set AGL guidance
    precisionDist = 8,       -- m: start precision hints
    captureHoriz = 15,         -- m: horizontal sweet spot radius
    captureVert = 15,          -- m: vertical sweet spot tolerance around AGL window
    aglMin = 5,               -- m: hover window min AGL
    aglMax = 20,              -- m: hover window max AGL
    maxGS = 8/3.6,            -- m/s: 8 km/h for precision, used for errors
    captureGS = 4/3.6,        -- m/s: 4 km/h capture requirement
    maxVS = 2.0,              -- m/s: absolute vertical speed during capture
    driftResetDist = 13,      -- m: if beyond, reset precision phase
    stabilityHold = 2.0       -- s: hold steady before loading
  },

  throttle = {
    coachUpdate = 3.0,         -- s between hint updates in precision
    generic = 3.0,            -- s between non-coach messages
    repeatSame = 6.0          -- s before repeating same message key
  },
}

-- =========================
-- Ground Auto-Load Configuration
-- =========================
-- Automatic crate loading while landed (for pilots who prefer not to hover)
CTLD.GroundAutoLoadConfig = {
  Enabled = true,               -- master switch for ground auto-load feature
  LoadDelay = 25,               -- seconds to hold position on ground before auto-loading
  GroundContactAGL = 3.5,       -- meters AGL considered "on the ground" (matches MEDEVAC)
  MaxGroundSpeed = 2.0,         -- m/s maximum ground speed during loading (~4 knots)
  SearchRadius = 35,            -- meters to search for nearby crates
  AbortGrace = 2,               -- seconds of movement/liftoff tolerated before aborting
  RequirePickupZone = true,     -- MUST be inside a pickup zone to auto-load (prevents drop/re-pickup loops)
  AllowInFOBZones = true,       -- also allow auto-load in FOB zones (once built)
}

CTLD.GroundLoadComms = {
  ProgressInterval = 5,
  Start = {
    "Loadmaster: Copy {count} crate(s). Give us {seconds}s to round up the rollers.",
    "Ramp boss says {seconds}s and L. Jenkins will have those {count} crate(s) chained down.",
    "Crew chief: {count} crate(s) inbound—stay planted for {seconds}s.",
    "Forklift mafia deputized Leroy to kidnap {count} crate(s) in {seconds}s.",
    "Ground crew brewing a plan: {count} crate(s) in {seconds}s.",
    "Cargo gnomes awake—{seconds}s to wrangle {count} crate(s).",
    "Engineers counting {count} crate(s); set a timer for {seconds}s.",
    "Deck boss: {seconds}s of zen before {count} crate(s) clack aboard.",
    "Log cell crunches numbers: {count} crate(s) move in {seconds}s.",
    "Supply sergeant wants {seconds}s to line up {count} crate(s).",
    "Palettes staged—{count} crate(s) climbing aboard after {seconds}s.",
    "Ramp trolls wave: {seconds}s pause, {count} crate(s) prize.",
    "Hook teams prepping—{count} crate(s) latched in {seconds}s.",
    "Handler: keep rotors calm for {seconds}s; {count} crate(s) en route.",
    "Deck boss hums while Jenkins L salts {count} crate(s) in {seconds}s.",
    "Logistics whisperer: {seconds}s to sweet-talk {count} crate(s).",
    "Crate wrangler: {count} boxen saddled after {seconds}s.",
    "Crew phones mom: {count} crate(s) adopt you in {seconds}s.",
    "Load team stretching—{seconds}s till {count} crate(s) leap aboard.",
    "Forklift rave: {count} crate(s) crowd-surfing in {seconds}s.",
    "Ammo guys promise {seconds}s to leash {count} crate(s).",
    "Supply goblins: {count} crate(s) conjured after {seconds}s.",
    "Winch crew rolling cables—{seconds}s countdown for {count} crate(s).",
    "Deck judge bangs gavel: {count} crate(s) filed in {seconds}s.",
    "Ramp DJ cues track—{seconds}s jam for {count} crate(s).",
    "Hangar rats: {count} crate(s) tango aboard in {seconds}s.",
    "Pit crew swapped tires; {seconds}s to fuel {count} crate(s).",
    "Clipboard ninja checking boxes—{count} crate(s) ready in {seconds}s.",
    "Dock boss sharpening pencils: {count} crate(s) manifest in {seconds}s.",
    "Groundlings choreograph {count} crate(s) ballet—{seconds}s rehearsal.",
    "Supply monks meditate {seconds}s to summon {count} crate(s).",
    "Winch whisperer: {count} crate(s) ascend in {seconds}s.",
    "Ramp champion bets {seconds}s for {count} crate(s).",
    "Crew lounge evacuated; {count} crate(s) arriving in {seconds}s.",
    "Load shack scoreboard: {seconds}s to snag {count} crate(s).",
    "Logi wizard scribbles runes—{count} crate(s) appear after {seconds}s.",
    "Deck sergeant orders {seconds}s freeze; {count} crate(s) inbound.",
    "Cargo penguins waddling—{seconds}s to herd {count} crate(s).",
    "Hangar bard plays; {count} crate(s) drop beat in {seconds}s.",
    "Ramp dragon yawns: {seconds}s before {count} crate(s) charred.",
    "Supply pirates shout—{count} crate(s) plundered in {seconds}s.",
    "Ground crew printing receipts—{seconds}s to notarize {count} crate(s).",
    "Forklift derby lights up; {count} crate(s) cross line in {seconds}s.",
    "Load ninja breathes—{seconds}s later {count} crate(s) vanish aboard.",
    "Deck boss bribes gravity; {count} crate(s) float up in {seconds}s.",
    "Ammo elves: {seconds}s swirl to gift-wrap {count} crate(s).",
    "Ramp philosopher ponders {count} crate(s) for {seconds}s.",
    "Crew chef prepping snacks; {count} crate(s) served in {seconds}s.",
    "Crate wrangler ties boots—{seconds}s to rope {count} crate(s).",
    "Paladin of pallets: {count} crate(s) blessed in {seconds}s.",
    "Load doc scribbles—{seconds}s to sign {count} crate(s).",
    "Ground squirrels stash {count} crate(s) after {seconds}s.",
    "Deck poet recites; {count} crate(s) respond in {seconds}s.",
    "Winch gremlin oils gears—{seconds}s for {count} crate(s).",
    "Ramp hype crew chants {seconds}s mantra for {count} crate(s).",
    "Supply DJ scratching—{count} crate(s) drop bass in {seconds}s.",
    "Cargo therapist assures {count} crate(s) in {seconds}s.",
    "Crew zookeeper wrangles {count} crate(s) herd—{seconds}s.",
    "Deck botanist grows {count} crate(s) vines in {seconds}s.",
    "Load astronomer charts {count} crate(s) orbit—{seconds}s.",
    "Ramp comedian promises laughs for {seconds}s then {count} crate(s).",
    "Hangar historian says {count} crate(s) arrive in {seconds}s per tradition.",
    "Supply drummer counts in {seconds}s for {count} crate(s).",
    "Deck meteorologist predicts {count} crate(s) storm in {seconds}s.",
    "Cargo architect sketches {count} crate(s) stacking plan—{seconds}s.",
    "Ramp coder debugs manifest; {count} crate(s) compile in {seconds}s.",
    "Load barista pulls espresso—{count} crate(s) perk up in {seconds}s.",
    "Ground bard writes sea shanty; {count} crate(s) join in {seconds}s.",
    "Supply prankster hides {count} crate(s); reveal in {seconds}s.",
    "Ramp alchemist mixes fuel—{count} crate(s) transmute after {seconds}s.",
    "Crate whisperer says hold {seconds}s for {count} crate(s).",
    "Deck detective tracks {count} crate(s) trail—{seconds}s ETA.",
    "Load beekeeper herds {count} crate(s) swarm—{seconds}s.",
    "Ground tailor stitches nets; {count} crate(s) fitted in {seconds}s.",
    "Supply DJ rewinds—{seconds}s then {count} crate(s) drop.",
    "Ramp cloud-gazer sees {count} crate(s) in {seconds}s forecast.",
    "Load punster drafts {count} crate(s) jokes—{seconds}s needed.",
    "Deck volcanologist warns {count} crate(s) eruption in {seconds}s.",
    "Cargo puppeteer choreographs {count} crate(s); show in {seconds}s.",
    "Ground cartographer maps {count} crate(s) journey—{seconds}s.",
    "Ramp mathematician solves {count} crate(s) problem—{seconds}s.",
    "Load meteor chaser counts {seconds}s till {count} crate(s) strike.",
    "Supply astronomer spots {count} crate(s) constellation—{seconds}s.",
    "Deck lifeguard whistles; {count} crate(s) swim aboard in {seconds}s.",
    "Cargo sommelier decants {count} crate(s)—need {seconds}s to breathe.",
    "Ramp locksmith picks {count} crate(s) locks—{seconds}s.",
    "Load carpenter measures twice; {count} crate(s) cut loose in {seconds}s.",
    "Ground geologist drills plan—{count} crate(s) surface in {seconds}s.",
    "Supply fireman slides pole; {count} crate(s) rescued in {seconds}s.",
    "Ramp hacker breaches {count} crate(s) firewall—{seconds}s.",
    "Load illusionist shuffles {count} crate(s)—{seconds}s reveal.",
    "Deck astronomer winks: {count} crate(s) align in {seconds}s.",
    "Cargo mixologist shakes {count} crate(s); {seconds}s pour time.",
    "Ramp weatherman says {count} crate(s) drizzle in {seconds}s.",
    "Load surveyor levels deck—{count} crate(s) land in {seconds}s.",
    "Ground sculptor chisels path; {count} crate(s) glide in {seconds}s.",
    "Supply DJ double-drops; {count} crate(s) drop after {seconds}s.",
    "Deck clockmaker rewinds {seconds}s, {count} crate(s) tick in.",
    "Cargo cart racer drifts up with {count} crate(s) in {seconds}s.",
    "Ramp ringmaster cues circus; {count} crate(s) center ring in {seconds}s.",
  },
  Progress = {
    "Crew chief: {remaining}s on the clock—don't wiggle.",
    "Ramp boss tapping boot while Jenkins L calls {remaining}s remaining.",
    "Leroy J. humming; {remaining}s until hooks click.",
    "Forklift tires chirp—{remaining}s before stack settles.",
    "Cargo chains rattling, {remaining}s left.",
    "Handler flashes thumbs-up once Leroy yells go in {remaining}s.",
    "Deck boss juggling paperwork—{remaining}s.",
    "Ground crew sipping caf, {remaining}s reminder.",
    "Winch motors whining: {remaining}s.",
    "Clipboard ninja says {remaining}s until signatures.",
    "Ramp trolls mid chant—{remaining}s.",
    "Load doc verifying straps—{remaining}s.",
    "Forklift derby lap {remaining}s.",
    "Ammo goblins grumble {remaining}s.",
    "Supply bard hits chorus in {remaining}s.",
    "Deck meteorologist reads {remaining}s forecast.",
    "Cargo AI recalculating—{remaining}s.",
    "Ground gremlin twisting wrenches for {remaining}s.",
    "Ramp conductor waves baton—{remaining}s of tempo.",
    "Load punster drafting joke; {remaining}s left.",
    "Deck alchemist stirring {remaining}s.",
    "Crate wrangler double-knots—{remaining}s.",
    "Forklift jazz solo ends in {remaining}s.",
    "Supply DJ building drop—{remaining}s.",
    "Ramp philosopher meditates {remaining}s.",
    "Load botanist waters nets—{remaining}s.",
    "Deck coder compiling manifest—{remaining}s.",
    "Ground astronomer counts {remaining}s shooting stars.",
    "Cargo weathervane spins {remaining}s.",
    "Loader handshake pending {remaining}s.",
    "Ramp poet editing stanza—{remaining}s.",
    "Load bartender shakes drink—{remaining}s of chill.",
    "Deck zookeeper calms crates—{remaining}s.",
    "Ground sculptor chisels wedge—{remaining}s.",
    "Supply tailor hemming slings—{remaining}s.",
    "Ramp locksmith turning tumblers—{remaining}s.",
    "Load whisperer soothing pallets for {remaining}s.",
    "Deck drummer counting down {remaining}s.",
    "Cargo painter adds racing stripes—{remaining}s.",
    "Ground beekeeper herding boxes—{remaining}s.",
    "Ramp ninja mid flip—{remaining}s.",
    "Load DJ scratching vinyl for {remaining}s.",
    "Deck geologist sampling dust—{remaining}s.",
    "Cargo puppeteer angles strings—{remaining}s.",
    "Ground interpreter translating crate beeps—{remaining}s.",
    "Ramp comedian holding punchline {remaining}s.",
    "Load surfer riding forklift forks—{remaining}s.",
    "Deck data nerd buffering {remaining}s.",
    "Cargo snowplow clearing pebbles—{remaining}s.",
    "Ground pyrotechnician keeps sparks at bay {remaining}s.",
    "Ramp snorkeler holding breath {remaining}s.",
    "Load astronomer calibrates scope—{remaining}s.",
    "Deck spelunker exploring skid row—{remaining}s.",
    "Cargo beekeeper suits up—{remaining}s.",
    "Ground carpenter setting chalk lines—{remaining}s.",
    "Ramp wizard muttering {remaining}s spell.",
    "Load falconer whistles—{remaining}s before talons release.",
    "Deck tuba blares sustain for {remaining}s.",
    "Cargo juggler keeps crates aloft {remaining}s.",
    "Ground chemist titrates patience—{remaining}s.",
    "Ramp puppeteer cues strings—{remaining}s.",
    "Load archaeologist brushes dust—{remaining}s.",
    "Deck racer redlines stopwatch {remaining}s.",
    "Cargo coder spams F5 for {remaining}s.",
    "Ground gardener trims net corners—{remaining}s.",
    "Ramp DJ layering loops—{remaining}s.",
    "Load glaciologist monitors ice melt—{remaining}s.",
    "Deck prankster hides cones for {remaining}s.",
    "Cargo scribe inks manifest—{remaining}s.",
    "Ground wanderer paces {remaining}s.",
    "Ramp baker timing souffle—{remaining}s.",
    "Load therapist tells crates to breathe {remaining}s.",
    "Deck hype squad chanting {remaining}s.",
    "Cargo spelunker checks tie-down caverns—{remaining}s.",
    "Ground sherpa hauls straps—{remaining}s.",
    "Ramp rebel flicks toothpick {remaining}s.",
    "Load fortune teller sees {remaining}s in cards.",
    "Deck quatermaster double-counts {remaining}s.",
    "Cargo dinosaur roaring softly {remaining}s.",
    "Ground mech tunes hydraulics—{remaining}s.",
    "Ramp botanist sniffs fuel—{remaining}s.",
    "Load journalist scribbles {remaining}s update.",
    "Deck gamer farming XP for {remaining}s.",
    "Cargo archivist files forms—{remaining}s.",
    "Ground referee watches chalk line—{remaining}s.",
    "Ramp kite flyer reels string—{remaining}s.",
    "Load detective dusts prints—{remaining}s.",
    "Deck prank caller rings tower for {remaining}s.",
    "Cargo shoemaker taps soles—{remaining}s.",
    "Ground chandler pours wax—{remaining}s.",
    "Ramp falcon loops {remaining}s.",
    "Load diver equalizes ears {remaining}s.",
    "Deck astronomer rechecks alignment—{remaining}s.",
    "Cargo DJ rewinds sample {remaining}s.",
    "Ground quartermaster ties ledger—{remaining}s.",
    "Ramp magpie collecting shiny bolts—{remaining}s.",
    "Load muralist adds stencil—{remaining}s.",
    "Deck tech updates firmware—{remaining}s.",
    "Cargo babysitter hushes pallets {remaining}s.",
    "Ground marshal gives steady-hand signal for {remaining}s.",
    "Hey! Watch what you're doing with those crates! {remaining}s left.",
    "Hey! You can't put that there! Over there instead! {remaining}s left.",
    "Hey! Is your name Leroy! Because you better be getting those crates loaded! {remaining}s left.",
    "Jenkins!!! Get those crates loaded! {remaining}s left.",
    "Leroy!!! Stop daydreaming and get those crates loaded! {remaining}s left.",
    "Come on Leroy, those crates won't load themselves! {remaining}s left.",
    "Hurry up Jenkins, we got a bird waiting! {remaining}s left.",
    "Get a move on Leroy, those crates ain't gonna load themselves! {remaining}s left.",
    "You call that loading Jenkins? {remaining}s left.",
    "Pick up the pace Leroy! {remaining}s left.",
    "Faster Jenkins! {remaining}s left.",
    "Let's hustle Leroy! {remaining}s left.",
    "Time's a-tickin' Jenkins! {remaining}s left.",
    "Chop-chop Leroy! {remaining}s left.",
    "Jenkins! Stop playing with the cargo! Those dildo's belong to Mo! {remaining}s left.",
    "Leroy here sir! We got that cargo right where you wanted it! {remaining}s left.",
    "Jenkins! Get back to work! Mo's complaining! {remaining}s left.",
  },
  Complete = {
    "Crew chief: {count} crate(s) strapped and smiling—clear to lift.",
    "Ramp boss reports {count} crate(s) locked tight by Jenkins L.",
    "Loadmaster: {count} crate(s) tucked in like kittens.",
    "Forklift mafia salutes—{count} crate(s) delivered.",
    "Deck boss stamped {count} crate(s) good to go.",
    "Cargo goblins vanished—Leroy swears he secured {count} crate(s).",
    "Winch team claims victory—{count} crate(s) aboard.",
    "Clipboard ninja checked {count} boxes.",
    "Ramp trolls cheer: {count} crate(s) riding shotgun.",
    "Handler: {count} crate(s) bolted; throttle up.",
    "Deck poet pens ode to {count} crate(s) now yours.",
    "Supply gnomes wave bye to {count} crate(s).",
    "Ground crew says {count} crate(s) ready for adventure.",
    "Ramp DJ drops beat—{count} crate(s) locked in rhythm.",
    "Load doc signs release: {count} crate(s).",
    "Deck alchemist transmuted paperwork—{count} crate(s).",
    "Cargo therapist declares {count} crate(s) emotionally stable.",
    "Forklift derby trophy goes to {count} crate(s) now aboard.",
    "Ramp philosopher satisfied—{count} crate(s) exist on deck.",
    "Load botanist pruned nets—{count} crate(s) bloom there.",
    "Deck coder returned true: {count} crate(s).",
    "Ground bard ends tune with {count} crate(s) crescendo.",
    "Ramp prankster can't hide {count} crate(s)—they're on board.",
    "Cargo beekeeper counts {count} crate(s) in hive.",
    "Deck meteorologist confirms {count} crate(s) high pressure.",
    "Load painter signs mural of {count} crate(s) strapped.",
    "Ground tailor hemmed slings—{count} crate(s) fitted.",
    "Ramp locksmith snapped padlocks on {count} crate(s).",
    "Cargo DJ fades track—{count} crate(s) secure.",
    "Deck archaeologist labels {count} crate(s) artifact.",
    "Load comedian retires bit; {count} crate(s) landing.",
    "Ground sculptor polishes {count} crate(s) corners.",
    "Ramp astronomer charts {count} crate(s) orbit now stable.",
    "Cargo puppeteer bows—{count} crate(s) performance done.",
    "Deck detective solved case of {count} crate(s).",
    "Load shark fins down: {count} crate(s) fed to cargo bay.",
    "Ground sherpa drops pack—{count} crate(s) summit achieved.",
    "Ramp hacker logs off—{count} crate(s) uploaded.",
    "Cargo barista served {count} crate(s) double-shot of tie downs.",
    "Deck referee whistles end—{count} crate(s) win.",
    "Load fencer sheathes sword—{count} crate(s) defended.",
    "Ground medic clears {count} crate(s) to travel.",
    "Ramp monk bows: {count} crate(s) enlightened.",
    "Cargo kite now tethered—{count} crate(s).",
    "Deck astronomer applauds {count} crate(s) alignment.",
    "Load geologist marks {count} crate(s) strata complete.",
    "Ground gardener plants {count} crate(s) firmly.",
    "Ramp puppet master cuts strings—{count} crate(s) stay.",
    "Cargo DJ signs off—{count} crate(s) final mix.",
    "Deck beekeeper seals hive with {count} crate(s).",
    "Load mathematician tallies {count} crate(s) exact.",
    "Ground fireworks canceled—{count} crate(s) safe.",
    "Ramp storm chaser says {count} crate(s) in the eye.",
    "Cargo sculptor chisels notch—{count} crate(s) nested.",
    "Deck tailor stitches last knot on {count} crate(s).",
    "Load wizard snaps fingers—{count} crate(s) appear strapped.",
    "Ground referee raises flag: {count} crate(s) legal.",
    "Ramp brewer clinks mugs—{count} crate(s) on tap.",
    "Cargo philosopher logs {count} crate(s) as truth.",
    "Deck DJ loops outro—{count} crate(s) seated.",
    "Load detective closes file—{count} crate(s) accounted.",
    "Ground lifeguard thumbs up—{count} crate(s) afloat.",
    "Ramp spelunker resurfaces with {count} crate(s).",
    "Cargo dancer nails finale—{count} crate(s).",
    "Deck poet rhymes {count} crate(s) with fate.",
    "Load dragon goes back to sleep—{count} crate(s) fed.",
    "Ground chemist labels vials—{count} crate(s) stable.",
    "Ramp tailor satisfied stitchwork on {count} crate(s).",
    "Cargo quarterback yells touchdown—{count} crate(s).",
    "Deck glaciologist notes {count} crate(s) frozen in place.",
    "Load eagle roosts—{count} crate(s) in nest.",
    "Ground DJ cues victory sting—{count} crate(s) done.",
    "Ramp botanist logs {count} crate(s) in flora guide.",
    "Cargo surfer throws shaka—{count} crate(s) ride smooth.",
    "Deck juggler bows—{count} crate(s) landed.",
    "Load translator confirms {count} crate(s) say thanks.",
    "Ground weatherman clears skies—{count} crate(s) shining.",
    "Ramp trickster hides clipboard: {count} crate(s) can't hide.",
    "Cargo archivist files {count} crate(s) under awesome.",
    "Deck beekeeper high-fives {count} crate(s) bees.",
    "Load marathoner crosses finish with {count} crate(s).",
    "Ground astronomer stamps {count} crate(s) star chart.",
    "Ramp baker presents {count} crate(s) pie fresh.",
    "Cargo diver surfaces cheering {count} crate(s).",
    "Deck data nerd graphs {count} crate(s) success.",
    "Load hypnotist snaps fingers—{count} crate(s) obey.",
    "Ground marshal rolls wand—{count} crate(s) staged.",
    "Ramp timekeeper stops watch at {count} crate(s).",
    "Cargo composer final chord—{count} crate(s).",
    "Deck quartermaster locks ledger: {count} crate(s).",
    "Load astronaut gives thumbs up from cargo bay—{count} crate(s).",
    "Ground ninja vanishes leaving {count} crate(s).",
    "Ramp botanist labels {count} crate(s) species secure.",
    "Cargo conductor yells all aboard—{count} crate(s).",
    "Deck muralist signs name under {count} crate(s).",
    "Load shepherd counts {count} crate(s) asleep.",
    "Ground pirate buries hatchet—{count} crate(s) share plunder.",
    "Ramp gamer hits save—{count} crate(s) progress locked.",
    "Cargo weaver ties final knot on {count} crate(s).",
    "Deck captain stamps log—{count} crate(s) embarked.",
  }
}

-- =========================
-- MEDEVAC Configuration
-- =========================
--#region MEDEVAC Config
CTLD.MEDEVAC = {
  Enabled = true,
  
  -- Crew spawning
  -- Per-coalition spawn probabilities for asymmetric scenarios
  CrewSurvivalChance = {
    [coalition.side.BLUE] = .50,  -- probability (0.0-1.0) that BLUE crew survives to spawn MEDEVAC request. 1.0 = 100% (testing), 0.02 = 2% (production)
    [coalition.side.RED] = .50,   -- probability (0.0-1.0) that RED crew survives to spawn MEDEVAC request
  },
  ManPadSpawnChance = {
    [coalition.side.BLUE] = 0.1,  -- probability (0.0-1.0) that BLUE crew spawns with a MANPADS soldier. 1.0 = 100% (testing), 0.1 = 10% (production)
    [coalition.side.RED] = 0.1,   -- probability (0.0-1.0) that RED crew spawns with a MANPADS soldier
  },
  CrewSpawnDelay = 300,           -- seconds after death before crew spawns (gives battle time to clear). 300 = 5 minutes
  CrewAnnouncementDelay = 60,     -- seconds after spawn before announcing mission to players (verify crew survival). 60 = 1 minute
  CrewTimeout = 3600,             -- 1 hour max wait before crew is KIA (after spawning)
  CrewSpawnOffset = 25,           -- meters from death location (toward nearest enemy)
  CrewDefaultSize = 2,            -- default crew size if not specified in catalog
  CrewDefendSelf = true,          -- crews will return fire if engaged
  
  -- Crew protection during announcement delay
  CrewImmortalDuringDelay = true, -- make crew immortal (invulnerable) during announcement delay to prevent early death
  CrewInvisibleDuringDelay = true, -- make crew invisible to AI during announcement delay (won't be targeted by enemy)
  CrewImmortalAfterAnnounce = false, -- if true, crew stays immortal even after announcing mission (easier gameplay)
  KeepCrewInvisibleForLifetime = true, -- if true, keep crew invisible to AI for entire mission lifetime
  
  -- Smoke signals
  PopSmokeOnSpawn = true,         -- crew pops smoke when they first spawn
  PopSmokeOnApproach = true,      -- crew pops smoke when rescue helo approaches
  PopSmokeOnApproachDistance = 8000, -- meters - distance at which crew detects approaching helo
  SmokeCooldown = 900,            -- seconds between smoke pops (default 900 = 15 minutes) - prevents spam when helo circles
  SmokeColor = {                  -- smoke colors per coalition
    [coalition.side.BLUE] = trigger.smokeColor.Blue,
    [coalition.side.RED] = trigger.smokeColor.Red,
  },
  SmokeOffsetMeters = 0,          -- horizontal offset from crew position (meters) so helicopters don't hover in smoke
  SmokeOffsetRandom = true,       -- randomize horizontal offset direction (true) or always offset north (false)
  SmokeOffsetVertical = 20,        -- vertical offset above ground level (meters) for better visibility
  
  -- Greeting messages when crew detects rescue helo
  GreetingMessages = {
    "Stranded Crew: We see you, boy that thing is loud! Follow the smoke!",
    "Stranded Crew: We hear you coming.. yep, we see you.. bring it on down to the smoke!",
    "Stranded Crew: Whew! We sure are glad you're here! Over here by the smoke!",
    "Stranded Crew: About damn time! We're over here at the smoke!",
    "Stranded Crew: Thank God! We thought you forgot about us! Follow the smoke!",
    "Stranded Crew: Hey! We're the good looking ones by the smoke!",
    "Stranded Crew: Copy that, we have visual! Popping smoke now!",
    "Stranded Crew: Roger, we hear your rotors! Follow the smoke and come get us!",
    "Stranded Crew: Finally! My feet are killing me out here! We're at the smoke!",
    "Stranded Crew: That's the prettiest sound we've heard all day! Head for the smoke!",
    "Stranded Crew: Is that you or are the enemy reinforcements? Just kidding, get down here at the smoke!",
    "Stranded Crew: We've been working on our tans, come check it out! Smoke's popped!",
    "Stranded Crew: Hope you brought snacks, we're starving! Follow the smoke in!",
    "Stranded Crew: Your Uber has arrived? No, YOU'RE our Uber! We're at the smoke!",
    "Stranded Crew: Could you be any louder? The whole country knows we're here now! At least follow the smoke!",
    "Stranded Crew: Next time, could you not take so long? My coffee got cold! Smoke's up!",
    "Stranded Crew: We see you! Don't worry, we only look this bad! Head for the smoke!",
    "Stranded Crew: Inbound helo spotted! Someone owes me 20 bucks! Smoke is marking our position!",
    "Stranded Crew: Hey taxi! We're at the corner of Blown Up Avenue and Oh Crap Street! Follow the smoke!",
    "Stranded Crew: You're a sight for sore eyes! Literally, there's so much dust out here! Smoke's popped!",
    "Stranded Crew: Visual contact confirmed! Get your ass down here to the smoke!",
    "Stranded Crew: Oh thank hell, a bird! We're ready to get the fuck outta here! Smoke's marking us!",
    "Stranded Crew: We hear you! Follow the smoke and the smell of desperation!",
    "Stranded Crew: Rotors confirmed! Popping smoke now! Don't leave us hanging!",
    "Stranded Crew: That you up there? About time! We've been freezing out here! Look for the smoke!",
    "Stranded Crew: Helo inbound! We've got the salvage and the trauma, come get both! Smoke's up!",
    "Stranded Crew: Eyes on rescue bird! Someone tell me this isn't a mirage! Follow the smoke!",
    "Stranded Crew: We hear those beautiful rotors! Land this thing before we cry! Smoke marks the spot!",
    "Stranded Crew: Confirmed visual! If you leave without us, we're keeping the salvage! Smoke's popped!",
    "Stranded Crew: Choppers overhead! Finally! We were about to start walking! Head for the smoke!",
    "Stranded Crew: That's our ride! Everyone look alive and try not to smell too bad! We're at the smoke!",
    "Stranded Crew: Helo spotted! Quick, somebody look professional! Smoke's marking our position!",
    "Stranded Crew: You're here! We'd hug you but we're covered in dirt and shame! Follow the smoke!",
    "Stranded Crew: Bird inbound! Popping smoke! Someone owes us overtime for this shit!",
    "Stranded Crew: Visual on rescue! Get down here before the enemy spots you too! Smoke's up!",
    "Stranded Crew: We see you! Follow the smoke and broken dreams!",
    "Stranded Crew: Incoming helo! Thank fuck! We're ready to leave this lovely hellscape! Smoke marks us!",
    "Stranded Crew: Eyes on bird! We've got salvage, stories, and a desperate need for AC! Look for the smoke!",
    "Stranded Crew: That you? Get down here! We've been standing here like idiots for hours! Smoke's popped!",
    "Stranded Crew: Helo visual! Popping smoke! Anyone got room for some very tired, very angry crew?",
    "Stranded Crew: We see you up there! Don't you dare fly past us! Follow the smoke!",
    "Stranded Crew: Rescue inbound! Finally! We were starting to plan a walk home! Smoke's marking us!",
    "Stranded Crew: Contact! We have eyes on you! Come get us before we change our minds about this whole military thing! Smoke's up!",
    "Stranded Crew: Helo confirmed! Smoke's up! Let's get this reunion started!",
    "Stranded Crew: You beautiful bastard! We see you! Get down here to the smoke!",
    "Stranded Crew: Visual on rescue! We're ready! Let's get out before our luck runs out! Follow the smoke!",
    "Stranded Crew: Bird spotted! Smoke deployed! Hurry before we attract more attention!",
    "Stranded Crew: There you are! What took so long? Never mind, just land at the smoke!",
    "Stranded Crew: We see you! Follow the smoke and the sound of relieved cursing!",
    "Stranded Crew: Helo inbound! Everyone grab your shit! We're leaving this place! Smoke marks the LZ!",
    "Stranded Crew: Is that our ride or just someone sightseeing? Either way, smoke's up!",
    "Stranded Crew: We've got eyes on you! Come to the smoke before we lose our minds!",
    "Stranded Crew: Tally ho! That's military speak for 'follow the damn smoke'!",
    "Stranded Crew: You're late! But we'll forgive you if you land at the smoke!",
    "Stranded Crew: Helo overhead! Popping smoke! This better not be a drill!",
    "Stranded Crew: Contact confirmed! Smoke's marking us! Don't make us wait!",
    "Stranded Crew: We hear rotors! Please be friendly! Smoke's up either way!",
    "Stranded Crew: Bird inbound! Smoke deployed! Let's make this quick!",
    "Stranded Crew: Visual on helo! Follow the smoke to the worst day of our lives!",
    "Stranded Crew: You found us! Smoke's marking the spot! Gold star for you!",
    "Stranded Crew: Rescue bird spotted! Smoke's up! We're the desperate ones!",
    "Stranded Crew: We see you! Land at the smoke before we start charging rent!",
    "Stranded Crew: Helo visual! Smoke deployed! This isn't a vacation spot!",
    "Stranded Crew: That's you! Finally! Follow the smoke to glory!",
    "Stranded Crew: Eyes on rescue! Smoke marks our misery! Come fix it!",
    "Stranded Crew: We hear you! Smoke's popped! Let's end this nightmare!",
    "Stranded Crew: Contact! Visual! Smoke! All the good stuff! Get down here!",
    "Stranded Crew: Rescue inbound! Smoke's up! We've rehearsed this moment!",
    "Stranded Crew: You're here! Smoke's marking us! Don't screw this up!",
    "Stranded Crew: Helo confirmed! Follow the smoke to the saddest party ever!",
    "Stranded Crew: We see you! Smoke's deployed! Land before we cry!",
    "Stranded Crew: Bird spotted! Smoke marks us! We're the ones waving frantically!",
    "Stranded Crew: Visual contact! Smoke's up! This is not a joke!",
    "Stranded Crew: You made it! Follow the smoke! We've got beer money! (Lies, but follow the smoke anyway!)",
    "Stranded Crew: Helo inbound! Smoke deployed! Pick us up before our wives find out!",
    "Stranded Crew: We hear you! Smoke's marking our stupidity! Come save us from ourselves!",
    "Stranded Crew: Contact! Smoke's up! We promise we're worth the fuel!",
    "Stranded Crew: Rescue bird! Smoke marks the spot! This is awkward for everyone!",
    "Stranded Crew: You're here! Smoke deployed! We'll explain everything later!",
    "Stranded Crew: Visual on helo! Follow the smoke to disappointment and gratitude!",
    "Stranded Crew: We see you! Smoke's up! Let's never speak of this again!",
    "Stranded Crew: Helo spotted! Smoke marks us! We're the embarrassed ones!",
    "Stranded Crew: Contact confirmed! Smoke deployed! This wasn't in the manual!",
    "Stranded Crew: You found us! Smoke's up! Someone's getting a promotion!",
    "Stranded Crew: Bird inbound! Follow the smoke to heroes and idiots!",
    "Stranded Crew: We hear you! Smoke's marking us! Please don't tell command!",
    "Stranded Crew: Visual! Smoke deployed! We'll buy you drinks forever!",
    "Stranded Crew: Helo confirmed! Smoke's up! Best day of our lives right here!",
    "Stranded Crew: You're here! Follow the smoke! We're never leaving base again!",
    "Stranded Crew: Contact! Smoke marks us! This is our rock bottom!",
    "Stranded Crew: Rescue inbound! Smoke deployed! We're upgrading your Yelp review!",
    "Stranded Crew: We see you! Smoke's up! Land before the enemy does!",
    "Stranded Crew: Bird spotted! Follow the smoke! We've learned our lesson!",
    "Stranded Crew: Visual on helo! Smoke's marking us! This is so embarrassing!",
    "Stranded Crew: You made it! Smoke deployed! We owe you everything!",
    "Stranded Crew: Helo inbound! Smoke marks the spot! Let's go home!",
    "Stranded Crew: We hear you! Follow the smoke! We're the lucky ones!",
    "Stranded Crew: Contact confirmed! Smoke's up! Thank you, thank you, thank you!",
    "Stranded Crew: Rescue bird! Smoke deployed! You're our favorite person ever!",
  },
  
  -- Request airlift messages (initial mission announcement)
  RequestAirLiftMessages = {
    "Stranded Crew: This is {vehicle} crew at {grid}. Need pickup ASAP! We have {salvage} salvage to collect.",
    "Stranded Crew: Yo, this is {vehicle} survivors at {grid}. Come get us before the bad guys do! {salvage} salvage available.",
    "Stranded Crew: {vehicle} crew reporting from {grid}. We're alive but our ride isn't. {salvage} salvage ready for extraction.",
    "Stranded Crew: Mayday! {vehicle} crew at {grid}. Send taxi, will pay in salvage! ({salvage} units available)",
    "Stranded Crew: This is what's left of {vehicle} crew at {grid}. Pick us up and grab the {salvage} salvage while you're at it!",
    "Stranded Crew: {vehicle} survivors here at {grid}. We've got {salvage} salvage and a bad attitude. Come get us!",
    "Stranded Crew: Former {vehicle} operators at {grid}. Vehicle's toast but we salvaged {salvage} units. Need immediate evac!",
    "Stranded Crew: {vehicle} crew broadcasting from {grid}. Situation: homeless. Salvage: {salvage} units. Mood: not great.",
    "Stranded Crew: This is {vehicle} at {grid}. Well, WAS {vehicle}. Now it's scrap. Got {salvage} salvage though!",
    "Stranded Crew: Hey! {vehicle} crew at {grid}! Our insurance definitely doesn't cover this. {salvage} salvage available.",
    "Stranded Crew: {vehicle} survivors reporting. Grid {grid}. Status: walking. Salvage: {salvage}. Pride: wounded.",
    "Stranded Crew: To whom it may concern: {vehicle} crew at {grid} requests immediate pickup. {salvage} salvage awaiting recovery.",
    "Stranded Crew: {vehicle} down at {grid}. Crew status: annoyed but alive. Salvage count: {salvage}. Hurry up!",
    "Stranded Crew: This is a priority call from {vehicle} crew at {grid}. We got {salvage} salvage and zero patience left!",
    "Stranded Crew: {vehicle} operators at {grid}. The vehicle gave up, we didn't. {salvage} salvage ready to go!",
    "Stranded Crew: Urgent! {vehicle} crew stranded at {grid}. Got {salvage} salvage and a serious need for extraction!",
    "Stranded Crew: {vehicle} here, well, parts of it anyway. Crew at {grid}. Salvage: {salvage}. Morale: questionable.",
    "Stranded Crew: {vehicle} down at {grid}. We're fine, vehicle's dead. {salvage} salvage secured. Come get us before we walk home!",
    "Stranded Crew: Calling all angels! {vehicle} crew at {grid} needs a lift. Bringing {salvage} salvage as payment!",
    "Stranded Crew: {vehicle} crew broadcasting from scenic {grid}. Collected {salvage} salvage. Would not recommend this location!",
    "Stranded Crew: This is {vehicle} at {grid}. Vehicle status: spectacular fireball (was). Crew status: could use a ride. Salvage: {salvage}.",
    "Stranded Crew: {vehicle} survivors at {grid}. We've got {salvage} salvage and stories you won't believe. Extract us!",
    "Stranded Crew: Former {vehicle} crew at {grid}. Current occupants of a smoking crater. {salvage} salvage available!",
    "Stranded Crew: {vehicle} operators requesting immediate evac from {grid}. Salvage secured: {salvage} units. Bring beer.",
    "Stranded Crew: This is {vehicle} crew. Location: {grid}. Situation: not ideal. Salvage: {salvage}. Need: helicopter. NOW.",
    "Stranded Crew: {grid}, party of {crew_size} from {vehicle}. Got {salvage} salvage and nowhere to go. Send help!",
    "Stranded Crew: {vehicle} down at {grid}. Crew bailed, grabbed {salvage} salvage, now standing here like idiots. Pick us up!",
    "Stranded Crew: Emergency broadcast from {vehicle} crew at {grid}. {salvage} salvage ready. Our ride? Not so much.",
    "Stranded Crew: {vehicle} at {grid}. Status report: vehicle's a loss, crew's intact, {salvage} salvage secured. Send taxi!",
    "Stranded Crew: Hey command! {vehicle} crew at {grid}. We saved {salvage} salvage but couldn't save the vehicle. Priorities!",
    "Stranded Crew: This is {vehicle} broadcasting from {grid}. Crew's good, vehicle's bad, {salvage} salvage available. Get us outta here!",
    "Stranded Crew: {vehicle} survivors at {grid} with {salvage} salvage. We're sunburned, pissed off, and ready for extraction!",
    "Stranded Crew: Attention: {vehicle} crew at {grid} requires pickup. {salvage} salvage recovered. Hurry before we become salvage too!",
    "Stranded Crew: {vehicle} here at {grid}. The good news: {salvage} salvage. The bad news: everything else. Send help!",
    "Stranded Crew: From the smoking remains of {vehicle} at {grid}, we bring you {salvage} salvage and a request for immediate evac!",
    "Stranded Crew: {vehicle} crew calling from {grid}. Vehicle's done, crew's done waiting. {salvage} salvage ready. Move it!",
    "Stranded Crew: This is {vehicle} at {grid}. Collected {salvage} salvage while our ride went up in flames. Worth it?",
    "Stranded Crew: {vehicle} operators at {grid}. Got {salvage} salvage and a newfound appreciation for walking. Please send helo!",
    "Stranded Crew: {grid} here. {vehicle} crew reporting. Salvage count: {salvage}. Ride count: zero. Help count: needed!",
    "Stranded Crew: {vehicle} down at {grid}! Crew up and ready with {salvage} salvage! Someone come get us already!",
    "Stranded Crew: This is {vehicle} broadcasting on guard. Position {grid}. {salvage} salvage secured. Crew status: tired of your shit, send pickup!",
    "Stranded Crew: {vehicle} crew at {grid} here. We've got {salvage} salvage, bad sunburns, and a dying radio battery. Hurry!",
    "Stranded Crew: Emergency call from {grid}! {vehicle} crew alive with {salvage} salvage. Vehicle? Not so lucky. Extract ASAP!",
    "Stranded Crew: {vehicle} at {grid}. Mission status: FUBAR. Crew status: alive. Salvage status: {salvage} units ready. Send bird!",
    "Stranded Crew: This is {vehicle} crew. We're at {grid} with {salvage} salvage and zero transportation. Someone fix that!",
    "Stranded Crew: {vehicle} survivors broadcasting from {grid}. Got the salvage ({salvage} units), lost the vehicle. Fair trade?",
    "Stranded Crew: Urgent from {grid}! {vehicle} crew here with {salvage} salvage and rapidly depleting patience. Pick us up!",
    "Stranded Crew: {vehicle} down at {grid}. Crew condition: grumpy but mobile. Salvage available: {salvage}. Ride home: none.",
    "Stranded Crew: This is {vehicle} calling from {grid}. We're standing in the middle of nowhere with {salvage} salvage. Sound fun?",
    "Stranded Crew: {vehicle} crew at {grid}. Salvage recovered: {salvage}. Pride recovered: maybe later. Need pickup now!",
    "Stranded Crew: SOS from {grid}! {vehicle} crew requesting airlift! {salvage} salvage secured! This is not a drill!",
    "Stranded Crew: {vehicle} survivors at {grid}. Vehicle kaput. Crew intact. {salvage} salvage ready. Send chopper!",
    "Stranded Crew: This is {vehicle} crew at {grid}. We walked away from the wreck with {salvage} salvage. Now what?",
    "Stranded Crew: Priority message! {vehicle} down at {grid}! Crew needs evac! {salvage} salvage available!",
    "Stranded Crew: {vehicle} at {grid}. The vehicle didn't make it but we did. {salvage} salvage waiting. Send help!",
    "Stranded Crew: Distress call from {grid}! {vehicle} crew needs immediate pickup! {salvage} salvage on site!",
    "Stranded Crew: {vehicle} operators broadcasting from {grid}. Status: stranded. Payload: {salvage} salvage. Request: extraction!",
    "Stranded Crew: This is {vehicle} crew. Grid: {grid}. Vehicle: destroyed. Salvage: {salvage}. Spirit: broken. Send pickup!",
    "Stranded Crew: {vehicle} down at {grid}. We've got {salvage} salvage and a story that'll make you cringe. Extract us!",
    "Stranded Crew: Emergency! {vehicle} crew at {grid}! Vehicle lost! {salvage} salvage recovered! Need airlift stat!",
    "Stranded Crew: {vehicle} survivors reporting from {grid}. {salvage} salvage secured. Vehicle unsalvageable. We're not!",
    "Stranded Crew: This is {vehicle} at {grid}. Crew escaped with {salvage} salvage. Need immediate extraction before enemy finds us!",
    "Stranded Crew: {vehicle} crew broadcasting from {grid}. Got {salvage} salvage. Lost everything else. Please respond!",
    "Stranded Crew: Mayday from {grid}! {vehicle} crew needs rescue! {salvage} salvage available! Don't leave us here!",
    "Stranded Crew: {vehicle} operators at {grid}. Salvage count: {salvage}. Morale count: negative. Pickup count: zero so far!",
    "Stranded Crew: This is {vehicle} crew at {grid}. We managed to save {salvage} salvage. Can you save us?",
    "Stranded Crew: {vehicle} down at {grid}! Crew on foot with {salvage} salvage! Send taxi before we start hitchhiking!",
    "Stranded Crew: Emergency call! {vehicle} crew at {grid}! {salvage} salvage ready! Vehicle not! We need help!",
    "Stranded Crew: {vehicle} survivors broadcasting from {grid}. We're alive, vehicle's not, {salvage} salvage secured. What now?",
    "Stranded Crew: This is {vehicle} at {grid}. Crew status: homeless. Salvage status: {salvage} units. Transportation status: needed!",
    "Stranded Crew: {vehicle} crew calling from {grid}. We've got {salvage} salvage and no way home. Fix that!",
    "Stranded Crew: Priority rescue needed! {vehicle} at {grid}! {salvage} salvage secured! Crew waiting!",
    "Stranded Crew: {vehicle} operators from {grid}. Vehicle destroyed. Salvage recovered: {salvage}. Us recovered: not yet!",
    "Stranded Crew: This is {vehicle} crew. Location: {grid}. Salvage: {salvage}. Transportation: missing. Patience: running out!",
    "Stranded Crew: {vehicle} down at {grid}! We escaped with {salvage} salvage! Send extraction before our luck runs out!",
    "Stranded Crew: Emergency broadcast from {grid}! {vehicle} crew needs airlift! {salvage} salvage ready for recovery!",
    "Stranded Crew: {vehicle} survivors at {grid}. Got {salvage} salvage. Need helicopter. Preferably soon. Please?",
    "Stranded Crew: This is {vehicle} at {grid}. Vehicle: totaled. Crew: intact. Salvage: {salvage}. Ride: requested!",
    "Stranded Crew: {vehicle} crew broadcasting from {grid}. We saved {salvage} salvage from the wreck. Now save us!",
    "Stranded Crew: Urgent! {vehicle} at {grid}! Crew needs extraction! {salvage} salvage available! Respond ASAP!",
    "Stranded Crew: {vehicle} operators from {grid}. Salvage secured: {salvage}. Everything else: lost. Help requested!",
    "Stranded Crew: This is {vehicle} crew at {grid}. {salvage} salvage recovered. Now we need to be recovered!",
    "Stranded Crew: {vehicle} down at {grid}! Crew survived with {salvage} salvage! Vehicle didn't! Send pickup!",
    "Stranded Crew: Emergency call from {grid}! {vehicle} crew requesting immediate evac! {salvage} salvage on hand!",
    "Stranded Crew: {vehicle} survivors broadcasting from {grid}. Status: stranded. Cargo: {salvage} salvage. Mood: desperate!",
    "Stranded Crew: This is {vehicle} at {grid}. We walked away from disaster with {salvage} salvage. Don't make us walk home!",
    "Stranded Crew: {vehicle} crew calling from {grid}. Vehicle: gone. Salvage: {salvage}. Hope: fading. Send help!",
    "Stranded Crew: Priority message! {vehicle} at {grid}! Crew needs pickup! {salvage} salvage ready! Time is critical!",
    "Stranded Crew: {vehicle} operators from {grid}. We've got {salvage} salvage and no vehicle. Math doesn't work. Send helo!",
    "Stranded Crew: This is {vehicle} crew at {grid}. Salvage recovered: {salvage}. Pride recovered: TBD. Pickup needed: definitely!",
    "Stranded Crew: {vehicle} down at {grid}! Crew intact with {salvage} salvage! Vehicle scattered across 50 meters! Extract us!",
    "Stranded Crew: Emergency from {grid}! {vehicle} crew needs airlift! {salvage} salvage secured! Don't forget about us!",
    "Stranded Crew: {vehicle} survivors at {grid}. We managed to grab {salvage} salvage. Can you manage to grab us?",
    "Stranded Crew: This is {vehicle} broadcasting from {grid}. Crew safe. Vehicle unsafe. {salvage} salvage ready. Pickup overdue!",
    "Stranded Crew: {vehicle} crew at {grid}. We've got {salvage} salvage and regrets. Send extraction before we have more regrets!",
    "Stranded Crew: Urgent call from {grid}! {vehicle} crew stranded! {salvage} salvage on site! Need immediate pickup!",
    "Stranded Crew: {vehicle} operators from {grid}. Salvage count: {salvage}. Vehicle count: zero. Help count: requested!",
  },
  
  -- Load messages (shown when crew boards helicopter - initial contact)
  LoadMessages = {
    "Crew: Alright, we're in! Get us the hell out of here!",
    "Crew: Loaded up! Thank God you showed up!",
    "Crew: We're aboard! Let's not hang around!",
    "Crew: All accounted for! Move it, move it!",
    "Crew: Everyone's in! Punch it!",
    "Crew: Secure! Get airborne before they spot us!",
    "Crew: We're good! Nice flying, now let's go!",
    "Crew: Loaded! You're our hero, let's bounce!",
    "Crew: In the bird! Hit the gas!",
    "Crew: Everyone's aboard! Go go go!",
    "Crew: Mounted up! Don't wait for an invitation!",
    "Crew: We're in! Holy shit, that was close!",
    "Crew: All souls aboard! Time to leave!",
    "Crew: Secure! Best thing I've seen all day!",
    "Crew: Loaded! You magnificent bastard!",
    "Crew: We're good to go! Pedal to the metal!",
    "Crew: All in! Get us home, please!",
    "Crew: Aboard! This is not a drill, GO!",
    "Crew: Everyone's in! You're a lifesaver!",
    "Crew: Locked and loaded! Wait, wrong phrase... just go!",
    "Crew: All personnel aboard! Outstanding work!",
    "Crew: We're in! Never been happier to see a helicopter!",
    "Crew: Boarding complete! Let's get the fuck out of here!",
    "Crew: Secure! You deserve a medal for this!",
    "Crew: Everyone's aboard! Enemy's probably watching!",
    "Crew: All in! Don't let us keep you!",
    "Crew: Mounted! Nice flying, seriously!",
    "Crew: Loaded up! First round's on us!",
    "Crew: We're in! Best Uber rating ever!",
    "Crew: All aboard! You're a goddamn angel!",
    "Crew: Secure! Nicest thing anyone's done for us!",
    "Crew: Everyone's in! Time's wasting!",
    "Crew: Boarding complete! You rock!",
    "Crew: All souls accounted for! Let's roll!",
    "Crew: We're good! Get altitude, fast!",
    "Crew: Loaded! I could kiss you!",
    "Crew: Everyone's aboard! Don't wait around!",
    "Crew: All in! Unbelievable timing!",
    "Crew: Secure! You're the best!",
    "Crew: Mounted up! We owe you big time!",
    "Crew: All aboard! Rotors up, let's go!",
    "Crew: We're in! Perfect execution!",
    "Crew: Loaded! Smoothest pickup ever!",
    "Crew: Everyone's good! Haul ass!",
    "Crew: All accounted for! Spectacular flying!",
    "Crew: Secure! Get us out of this hellhole!",
    "Crew: We're aboard! Don't stick around!",
    "Crew: All in! You're incredible!",
    "Crew: Loaded up! Time to jet!",
    "Crew: Everyone's secure! Outstanding!",
    "Crew: All aboard! Best day ever!",
    "Crew: We're good! Thank fucking God!",
    "Crew: Loaded! You beautiful human being!",
    "Crew: All personnel in! Fly fly fly!",
    "Crew: Secure! Can't thank you enough!",
    "Crew: Everyone's aboard! Green light!",
    "Crew: All in! You're a legend!",
    "Crew: Loaded! Sweet baby Jesus, let's go!",
    "Crew: We're aboard! Best rescue ever!",
    "Crew: All accounted for! Move out!",
    "Crew: Secure! You saved our asses!",
    "Crew: Everyone's in! Don't wait!",
    "Crew: All aboard! Brilliant work!",
    "Crew: Loaded up! We're getting married!",
    "Crew: We're good! Absolutely perfect!",
    "Crew: All in! Hit the throttle!",
    "Crew: Secure! You're amazing!",
    "Crew: Everyone's aboard! Let's leave!",
    "Crew: All accounted for! Superb!",
    "Crew: Loaded! Get us home safe!",
    "Crew: We're in! Textbook pickup!",
    "Crew: All aboard! Go go go!",
    "Crew: Secure! We love you!",
    "Crew: Everyone's good! Don't linger!",
    "Crew: All in! Professional as hell!",
    "Crew: Loaded up! Time to skedaddle!",
    "Crew: We're aboard! You're the GOAT!",
    "Crew: All souls in! Get moving!",
    "Crew: Secure! We're naming our kids after you!",
    "Crew: Everyone's aboard! Clear to leave!",
    "Crew: All in! Never doubt yourself!",
    "Crew: Loaded! You're a fucking hero!",
    "Crew: We're good! Exceptional timing!",
    "Crew: All accounted for! Hats off!",
    "Crew: Secure! Best pilot ever!",
    "Crew: Everyone's in! Throttle up!",
    "Crew: All aboard! You're the man!",
    "Crew: Loaded up! Pure excellence!",
    "Crew: We're aboard! Flawless!",
    "Crew: All in! Get us airborne!",
    "Crew: Secure! Impressive stuff!",
    "Crew: Everyone's good! Don't delay!",
    "Crew: All accounted for! Top notch!",
    "Crew: Loaded! Words can't express our thanks!",
    "Crew: We're in! You're certified awesome!",
    "Crew: All aboard! Time to split!",
    "Crew: Secure! We're forever grateful!",
    "Crew: Everyone's aboard! Wheels up!",
    "Crew: All in! Couldn't be better!",
    "Crew: Loaded up! You're the best pilot we know!",
    "Crew: We're good! Clear skies ahead!",
    "Crew: All souls aboard! Let's book it!",
    "Crew: Secure! You're our guardian angel!",
  },
  
  -- Loading messages (shown periodically during boarding process)
  LoadingMessages = {
    "Crew: Hold still, we're getting in...",
    "Crew: Watch your head! Coming through!",
    "Crew: Almost there, keep it steady...",
    "Crew: Just a sec, getting situated...",
    "Crew: Loading up, hang tight...",
    "Crew: Careful with Jenkins, he's bleeding pretty bad...",
    "Crew: Someone grab the salvage!",
    "Crew: Easy does it, wounded coming aboard...",
    "Crew: Keep it level, we're climbing in...",
    "Crew: Steady now, injured personnel...",
    "Crew: Oh God, there's so much blood...",
    "Crew: Medic! Where's the first aid kit?",
    "Crew: Hold position, almost loaded...",
    "Crew: Watch the rotor wash!",
    "Crew: Someone's unconscious, careful!",
    "Crew: Getting the wounded in first...",
    "Crew: Steady as she goes...",
    "Crew: Holy hell, Mike's leg is fucked up...",
    "Crew: Hurry, he's losing blood fast!",
    "Crew: Nice and easy, don't rush...",
    "Crew: Everyone watch your step...",
    "Crew: Loading wounded, give us a second...",
    "Crew: Jesus, that's a lot of shrapnel...",
    "Crew: Keep those rotors spinning!",
    "Crew: Almost done, standby...",
    "Crew: Careful, compound fracture here!",
    "Crew: Someone's in shock, move it!",
    "Crew: Loading gear, then we're good...",
    "Crew: Stay put, we're working...",
    "Crew: Damn, this guy's a mess...",
    "Crew: Getting everyone situated...",
    "Crew: Nice flying, keep it steady...",
    "Crew: Hold still while we board...",
    "Crew: Watch that head wound!",
    "Crew: Everyone stay calm...",
    "Crew: Getting the critical cases first...",
    "Crew: Standby, loading continues...",
    "Crew: Someone's got a sucking chest wound!",
    "Crew: Keep that bird steady, sir!",
    "Crew: Almost there, patience...",
    "Crew: Wounded first, then equipment...",
    "Crew: Oh fuck, internal bleeding...",
    "Crew: Stay with us, buddy!",
    "Crew: Loading process underway...",
    "Crew: Keep those engines running!",
    "Crew: Careful with his arm, it's shattered!",
    "Crew: Getting everyone secured...",
    "Crew: Hold your position, pilot!",
    "Crew: Someone's not breathing right...",
    "Crew: Almost done loading...",
    "Crew: Watch your footing!",
    "Crew: Traumatic amputation, careful!",
    "Crew: Everyone grab something!",
    "Crew: Standby, still boarding...",
    "Crew: Nice hover, keep it up...",
    "Crew: Getting the gear stowed...",
    "Crew: Oh man, burns everywhere...",
    "Crew: Stay conscious, stay with me!",
    "Crew: Loading in progress...",
    "Crew: Excellent flying, seriously...",
    "Crew: Watch out for that wound!",
    "Crew: Everyone move carefully...",
    "Crew: He's going into shock!",
    "Crew: Almost finished boarding...",
    "Crew: Keep it stable, we're working...",
    "Crew: Jesus, look at his face...",
    "Crew: Getting everyone in...",
    "Crew: Hold that position!",
    "Crew: Someone's barely conscious...",
    "Crew: Loading continues, standby...",
    "Crew: Perfect hover, captain!",
    "Crew: Careful, severe trauma here...",
    "Crew: Everyone's moving slow...",
    "Crew: Hold on, still loading...",
    "Crew: Damn good flying, pilot!",
    "Crew: Watch the blood slick!",
    "Crew: Getting situated here...",
    "Crew: He needs a hospital NOW...",
    "Crew: Almost done, keep steady...",
    "Crew: Loading wounded personnel...",
    "Crew: Stay with us, soldier!",
    "Crew: Keep those rotors turning...",
    "Crew: Careful, major injuries...",
    "Crew: Everyone board carefully...",
    "Crew: Hold position, nearly done...",
    "Crew: Oh God, the smell...",
    "Crew: Loading critical cases...",
    "Crew: Steady now, pilot...",
    "Crew: Someone's in bad shape...",
    "Crew: Almost loaded up...",
    "Crew: Nice hover, excellent control...",
    "Crew: Watch the shrapnel wounds!",
    "Crew: Everyone move slowly...",
    "Crew: He's bleeding out!",
    "Crew: Getting everyone aboard...",
    "Crew: Hold that hover!",
    "Crew: Severe burns, careful!",
    "Crew: Loading in progress, standby...",
    "Crew: Perfect positioning, sir...",
    "Crew: Watch those injuries!",
    "Crew: Everyone take it easy...",
    "Crew: Almost finished here...",
  },
  
  -- Unloading messages (shown when delivering crew to MASH)
  UnloadingMessages = {
  "Crew: Hold steady, do not lift - stretchers are rolling out!",
    "Crew: Stay put, we're getting the wounded offloaded!",
    "Crew: Keep us grounded, medics are still working inside!",
    "Crew: We're at MASH! Thank you so much!",
    "Crew: Finally! Get these guys to the docs!",
    "Crew: Medical team, we need help here!",
    "Crew: We made it! Get the wounded inside!",
    "Crew: MASH arrival! These guys need immediate attention!",
    "Crew: Unloading! Someone call the surgeons!",
    "Crew: We're here! Priority casualties!",
    "Crew: Made it alive! You're incredible!",
    "Crew: MASH delivery! Critical patients!",
    "Crew: Get the medics! We got wounded!",
    "Crew: Arrived! These guys are in bad shape!",
    "Crew: We're down! Medical emergency!",
    "Crew: At MASH! Someone help these men!",
    "Crew: Delivered! Thank God for you!",
    "Crew: We made it! Get stretchers!",
    "Crew: Arrival confirmed! Wounded aboard!",
    "Crew: Finally here! Need doctors NOW!",
    "Crew: MASH drop-off! Several critical!",
    "Crew: We're safe! Get the medical team!",
    "Crew: Landed! These boys need surgery!",
    "Crew: Delivery complete! You saved lives today!",
    "Crew: At medical! Urgent care needed!",
    "Crew: We're here! Someone's coding!",
    "Crew: MASH arrival! Serious trauma cases!",
    "Crew: Made it! Outstanding flying!",
    "Crew: Delivered safely! Medical assist required!",
    "Crew: We're down! Get the surgical team!",
    "Crew: At MASH! Multiple wounded!",
    "Crew: Arrived! These guys won't last long!",
    "Crew: Delivery! We owe you everything!",
    "Crew: MASH landing! Emergency cases!",
    "Crew: We made it! Immediate medical attention!",
    "Crew: Here safe! Call the surgeons!",
    "Crew: Delivered! Some really bad injuries!",
    "Crew: At medical! They need help fast!",
    "Crew: We're here! You're a hero!",
    "Crew: MASH drop! Priority patients!",
    "Crew: Arrived alive! Medical emergency!",
    "Crew: Delivery complete! Get them inside!",
    "Crew: We made it! Someone's critical!",
    "Crew: At MASH! Severe casualties!",
    "Crew: Landed safely! Thank you!",
    "Crew: Delivered! Medical team needed!",
    "Crew: We're here! These guys are fucked up!",
    "Crew: MASH arrival! Get the doctors!",
    "Crew: Made it! They're losing blood!",
    "Crew: Arrived! Urgent surgical cases!",
    "Crew: We're down! Multiple trauma!",
    "Crew: At medical! You saved our asses!",
    "Crew: Delivery! Several critical injuries!",
    "Crew: MASH landing! They need OR stat!",
    "Crew: We made it! Heavy casualties!",
    "Crew: Here safely! Medical response!",
    "Crew: Delivered! Some won't make it without surgery!",
    "Crew: At MASH! Emergency personnel needed!",
    "Crew: Arrived! These boys need immediate care!",
    "Crew: We're here! Call triage!",
    "Crew: MASH drop-off! Serious wounds!",
    "Crew: Made it alive! Outstanding work!",
    "Crew: Delivered safely! Get the medics!",
    "Crew: We're down! They're in rough shape!",
    "Crew: At medical! Priority one casualties!",
    "Crew: Arrived! You're a lifesaver!",
    "Crew: Delivery complete! Medical emergency!",
    "Crew: MASH landing! Critical patients!",
    "Crew: We made it! Someone's not breathing well!",
    "Crew: Here! Get them to surgery!",
    "Crew: Delivered! Severe trauma aboard!",
    "Crew: At MASH! They need doctors now!",
    "Crew: Arrived safely! You're amazing!",
    "Crew: We're here! Multiple serious injuries!",
    "Crew: MASH drop! Get the surgical team!",
    "Crew: Made it! Thank fucking God!",
    "Crew: Delivered! Several need immediate surgery!",
    "Crew: We're down! Medical assist!",
    "Crew: At medical! These guys are critical!",
    "Crew: Arrived! You deserve a medal!",
    "Crew: Delivery! Heavy casualties!",
    "Crew: MASH landing! Emergency patients!",
    "Crew: We made it! Get help quick!",
    "Crew: Here safely! Brilliant flying!",
    "Crew: Delivered! Someone's in bad shape!",
    "Crew: At MASH! Urgent care!",
    "Crew: Arrived alive! Medical emergency!",
    "Crew: We're here! They need triage!",
    "Crew: MASH drop-off! You saved lives!",
    "Crew: Made it! These boys need help!",
    "Crew: Delivered safely! Call the doctors!",
    "Crew: We're down! Priority casualties!",
    "Crew: At medical! You're our hero!",
    "Crew: Arrived! Severe wounds here!",
    "Crew: Delivery complete! Get medical personnel!",
    "Crew: MASH landing! Critical condition!",
    "Crew: We made it! They're barely hanging on!",
    "Crew: Here! Immediate medical attention!",
    "Crew: Delivered! Someone's dying!",
    "Crew: At MASH! Get the OR ready!",
    "Crew: Arrived safely! We can't thank you enough!",
    "Crew: We're here! Emergency surgery needed!",
    "Crew: MASH drop! Multiple trauma!",
    "Crew: Made it alive! Exceptional flying!",
    "Crew: Delivered! They need help now!",
    "Crew: We're down! Medical response required!",
  },

  -- Unload completion messages (shown when offload finishes)
  UnloadCompleteMessages = {
    "MASH: Offload complete! Medical teams have the wounded!",
    "MASH: Patients transferred! You're cleared to lift!",
    "MASH: All casualties delivered! Incredible flying!",
    "MASH: They're inside! Mission accomplished!",
    "MASH: Every patient is in triage! Thank you!",
    "MASH: Transfer complete! Head back when ready!",
    "MASH: Doctors have them! Outstanding job!",
    "MASH: Wounded are inside! You saved them!",
    "MASH: Hand-off confirmed! You're good to go!",
    "MASH: Casualties secure! Medical team standing by!",
    "MASH: Delivery confirmed! Take a breather, pilot!",
    "MASH: All stretchers filled! We are done here!",
    "MASH: Hospital staff has the patients! Great work!",
    "MASH: Unload complete! You nailed that landing!",
    "MASH: MASH has control! You're clear, thank you!",
    "MASH: Every survivor is inside! Hell yes!",
    "MASH: Docs have them! Back to the fight when ready!",
    "MASH: Handoff complete! You earned the praise!",
    "MASH: Medical team secured the wounded! Legend!",
    "MASH: Transfer complete! Outstanding steady hover!",
    "MASH: They're in the OR! You rock, pilot!",
    "MASH: Casualties delivered! Spin it back up when ready!",
    "MASH: MASH confirms receipt! You're a lifesaver!",
    "MASH: Every patient is safe! Mission complete!",
  },

  -- Enroute messages (periodic chatter with bearing/distance to MASH)
  EnrouteToMashMessages = {
    "Crew: Steady hands—{mash} sits at bearing {brg}°, {rng} {rng_u} ahead; patients are trying to nap.",
    "Crew: Nav board says {mash} is {brg}° for {rng} {rng_u}; keep it gentle so the IVs stay put.",
    "Crew: If you hold {brg}° for {rng} {rng_u}, {mash} will have hot coffee waiting—no promises on taste.",
    "Crew: Confirmed, {mash} straight off the nose at {brg}°, {rng} {rng_u}; wounded are counting on you.",
    "Crew: Stay on {brg}° for {rng} {rng_u} and we’ll roll into {mash} like heroes instead of hooligans.",
    "Crew: Tilt a hair left—{mash} lies {brg}° at {rng} {rng_u}; let’s not overshoot the hospital.",
    "Crew: Keep the climb smooth; {mash} is {brg}° at {rng} {rng_u} and the patients already look green.",
    "Crew: Plot shows {mash} bearing {brg}°, range {rng} {rng_u}; mother hen wants her chicks delivered.",
    "Crew: Hold that heading {brg}° and we’ll be on final to {mash} in {rng} {rng_u}; medics are on standby.",
    "Crew: Reminder—{mash} is {brg}° at {rng} {rng_u}; try not to buzz the command tent this run.",
    "Crew: Flight doc says keep turbulence down; {mash} sits {brg}° out at {rng} {rng_u}.",
    "Crew: Stay focused—{mash} ahead {brg}°, {rng} {rng_u}; every bump costs us more paperwork.",
    "Crew: We owe those medics a beer; {mash} is {brg}° for {rng} {rng_u}, so let’s get there in one piece.",
    "Crew: Update from ops: {mash} remains {brg}° at {rng} {rng_u}; throttle down before the pad sneaks up.",
    "Crew: Patients are asking if this thing comes with a smoother ride—{mash} {brg}°, {rng} {rng_u} to go.",
    "Crew: Keep your cool—{mash} is {brg}° at {rng} {rng_u}; med bay is laying out stretchers now.",
    "Crew: Good news, {mash} has fresh morphine; bad news, it’s {brg}° and {rng} {rng_u} away—step on it.",
    "Crew: Command wants ETA—tell them {mash} is {brg}° for {rng} {rng_u} and we’re hauling wounded and sass.",
    "Crew: That squeak you hear is the stretcher—stay on {brg}° for {rng} {rng_u} to {mash}.",
    "Crew: Don’t mind the swearing; we’re {rng} {rng_u} from {mash} on bearing {brg}° and the pain meds wore off.",
    "Crew: Eyes outside—{mash} sits {brg}° at {rng} {rng_u}; flak gunners better keep their heads down.",
    "Crew: Weather’s clear—{mash} is {brg}° out {rng} {rng_u}; let’s not invent new IFR procedures.",
    "Crew: Remember your autorotation drills? Neither do we. Fly {brg}° for {rng} {rng_u} to {mash} and keep her humming.",
    "Crew: The guy on stretcher two wants to know if {mash} is really {brg}° at {rng} {rng_u}; I told him yes, please prove me right.",
    "Crew: Rotor check good; {mash} bearing {brg}°, distance {rng} {rng_u}. Try to act like professionals.",
    "Crew: Stay low and fast—{mash} {brg}° {rng} {rng_u}; enemy radios are whining already.",
    "Crew: You’re doing great—just keep {brg}° for {rng} {rng_u} and {mash} will take the baton.",
    "Crew: Map scribble says {mash} is {brg}° and {rng} {rng_u}; let’s prove cartography still works.",
    "Crew: Pilot, the patients voted: less banking, more {mash}. Bearing {brg}°, {rng} {rng_u}.",
    "Crew: We cross the line into {mash} territory in {rng} {rng_u} at {brg}°; keep the blades happy.",
    "Crew: Hot tip—{mash} chefs saved us soup if we make {brg}° in {rng} {rng_u}; pretty sure it’s edible.",
    "Crew: Another bump like that and I’m filing a complaint; {mash} is {brg}° at {rng} {rng_u}, so aim true.",
    "Crew: The wounded in back just made side bets on landing—bearing {brg}°, range {rng} {rng_u} to {mash}.",
    "Crew: Stay on that compass—{mash} sits {brg}° at {rng} {rng_u}; medics already prepped the triage tent.",
    "Crew: Copy tower—{mash} runway metaphorically lies {brg}° and {rng} {rng_u} ahead; no victory rolls.",
    "Crew: Someone alert the chaplain—we’re {rng} {rng_u} out from {mash} on {brg}° and our patients could use jokes.",
    "Crew: Keep chatter clear—{mash} is {brg}° away at {rng} {rng_u}; let’s land before the morphine fades.",
    "Crew: They promised me coffee at {mash} if we stick {brg}° for {rng} {rng_u}; don’t ruin this.",
    "Crew: Plotting intercept—{mash} coordinates show {brg}°/{rng} {rng_u}; maintain this track.",
    "Crew: I know the gauges say fine but the guys in back disagree; {mash} {brg}°, {rng} {rng_u}.",
    "Crew: Remember, no barrel rolls; {mash} lies {brg}° at {rng} {rng_u}, and the surgeon will kill us if we’re late.",
    "Crew: Keep the skids level; {mash} is {brg}° and {rng} {rng_u} away begging for customers.",
    "Crew: We’re on schedule—{mash} sits {brg}° at {rng} {rng_u}; try not to invent new delays.",
    "Crew: Latest wind check says {mash} {brg}°, {rng} {rng_u}; adjust trim before the patients revolt.",
    "Crew: The medic in back just promised cookies if we hit {brg}° for {rng} {rng_u} to {mash}.",
    "Crew: Hold blades steady—{mash} is {brg}° at {rng} {rng_u}; stretcher straps can only do so much.",
    "Crew: Copy you’re bored, but {mash} is {brg}° for {rng} {rng_u}; no scenic detours today.",
    "Crew: If you overshoot {mash} by {rng} {rng_u} I’m telling command it was deliberate; target bearing {brg}°.",
    "Crew: Serious faces—we’re {rng} {rng_u} out from {mash} on {brg}° and these folks hurt like hell.",
    "Crew: Hey pilot, the guy with the busted leg says thanks—just keep {brg}° for {rng} {rng_u} to {mash}.",
    "Crew: That was a nice thermal—maybe avoid the next one; {mash} sits {brg}° at {rng} {rng_u}.",
    "Crew: Keep those eyes up; {mash} is {brg}° away {rng} {rng_u}; CAS flights are buzzing around.",
    "Crew: Reminder: {mash} won’t accept deliveries dumped on the lawn; {brg}° and {rng} {rng_u} to touchdown.",
    "Crew: Ops pinged again; told them we’re {rng} {rng_u} from {mash} on heading {brg}° and flying like pros.",
    "Crew: We promised the patients a soft landing; {mash} bearing {brg}°, distance {rng} {rng_u}.",
    "Crew: Keep the profile low—{mash} is {brg}° at {rng} {rng_u}; AAA spots are grumpy today.",
    "Crew: Message from tower: {mash} pad is clear; track {brg}° for {rng} {rng_u} and watch the dust.",
    "Crew: Someone in back just yanked an IV—slow the hell down; {mash} {brg}°, {rng} {rng_u}.",
    "Crew: We’re so close I can smell antiseptic—{mash} is {brg}° and {rng} {rng_u} from here.",
    "Crew: If we shave more time the medics might actually smile; {mash} lies {brg}° at {rng} {rng_u}.",
    "Crew: Friendly reminder—{mash} is {brg}° at {rng} {rng_u}; try not to park on their tent again.",
    "Crew: The patients voted you best pilot if we hit {mash} at {brg}° in {rng} {rng_u}; don’t blow the election.",
    "Crew: I’ve got morphine bets riding on you; {mash} sits {brg}° for {rng} {rng_u}.",
    "Crew: Keep your head in the game—{mash} {brg}°, {rng} {rng_u}; enemy gunners love tall rotor masts.",
    "Crew: That rattle is the litter, not the engine; {mash} is {brg}° and {rng} {rng_u} out.",
    "Crew: Flight lead wants a status—reported {mash} bearing {brg}°, {rng} {rng_u}; keep us honest.",
    "Crew: Patient three says thanks for not crashing—yet; {mash} {brg}°, {rng} {rng_u}.",
    "Crew: If you see the chaplain waving, you missed—{mash} sits {brg}° at {rng} {rng_u}.",
    "Crew: Med bay just radioed; they’re warming blankets. That’s {mash} {brg}° at {rng} {rng_u}.",
    "Crew: Stay locked on {brg}° for {rng} {rng_u}; {mash} already cleared a pad.",
    "Crew: Little turbulence ahead; {mash} bearing {brg}°, {rng} {rng_u}; grip it and grin.",
    "Crew: The guy on the stretcher wants to know if we’re lost—tell him {mash} {brg}°, {rng} {rng_u}.",
    "Crew: Hold altitude; {mash} is {brg}° away {rng} {rng_u} and the medics hate surprise autorotations.",
    "Crew: Confirming nav—{mash} at {brg}°, {rng} {rng_u}; you keep flying, we’ll keep them calm.",
    "Crew: If anyone asks, yes we’re inbound; {mash} sits {brg}° {rng} {rng_u} out.",
    "Crew: Think happy thoughts—{mash} is {brg}° at {rng} {rng_u}; patients can smell fear.",
    "Crew: Quit sightseeing—{mash} lies {brg}° and {rng} {rng_u}; let’s deliver the meat wagon.",
    "Crew: Keep that nose pointed {brg}°; {mash} is only {rng} {rng_u} away and my nerves are shot.",
    "Crew: We promised a fast ride; {mash} sits {brg}° at {rng} {rng_u}. No pressure.",
    "Crew: You’re lined up perfect—{mash} {brg}°, {rng} {rng_u}; now just keep it that way.",
    "Crew: The surgeon texted—he wants his patients now. {mash} bearing {brg}°, {rng} {rng_u}.",
    "Crew: The wounded are timing us; {mash} is {brg}° at {rng} {rng_u} so don’t dilly-dally.",
    "Crew: Another five minutes and {mash} will start nagging—hold {brg}° for {rng} {rng_u}.",
    "Crew: Keep the blade slap mellow; {mash} sits {brg}° at {rng} {rng_u}.",
    "Crew: Airspeed’s good; {mash} is {brg}° for {rng} {rng_u}; cue inspirational soundtrack.",
    "Crew: Patient four says if we keep {brg}° for {rng} {rng_u}, drinks are on him at {mash}.",
    "Crew: Don’t ask why the stretcher smells like smoke; just fly {brg}° {rng} {rng_u} to {mash}.",
    "Crew: Tower says we’re clear direct {mash}; bearing {brg}°, {rng} {rng_u}.",
    "Crew: If the engine coughs again we’re walking—{mash} sits {brg}° at {rng} {rng_u}; keep the RPM up.",
    "Crew: Calm voices only—{mash} sits {brg}° {rng} {rng_u}; the patients listen to tone more than words.",
    "Crew: Promise the guys in back we’ll hit {brg}° for {rng} {rng_u} and land like silk at {mash}.",
    "Crew: There’s a small bet you’ll flare too high; prove them wrong—{mash} {brg}°, {rng} {rng_u}.",
    "Crew: The medic wants you to skip the cowboy routine; {mash} lies {brg}° at {rng} {rng_u}.",
    "Crew: That vibration is fine; what’s not fine is missing {mash} at {brg}° in {rng} {rng_u}.",
    "Crew: Keep the collective steady—{mash} {brg}°, {rng} {rng_u}; we’re hauling precious cargo.",
    "Crew: Someone promised me a hot meal at {mash}; stay on {brg}° for {rng} {rng_u} and make it happen.",
    "Crew: The patients say if you wobble again they’re walking; {mash} {brg}°, {rng} {rng_u}.",
    "Crew: Hold that horizon—{mash} is {brg}° for {rng} {rng_u}; the doc already scrubbed in.",
    "Crew: Eyes on the prize—{mash} {brg}°, {rng} {rng_u}; don’t let the wind push us off.",
    "Crew: Finish strong; {mash} sits {brg}° {rng} {rng_u}. Wheels down and we’re heroes again.",
  },
  
  -- Crew unit types per coalition (fallback if not specified in catalog)
  CrewUnitTypes = {
    [coalition.side.BLUE] = 'Soldier M4',
    [coalition.side.RED] = 'Paratrooper RPG-16',  -- Try Russian paratrooper instead
  },
  
  -- MANPADS unit types per coalition (one random crew member gets this weapon)
  ManPadUnitTypes = {
    [coalition.side.BLUE] = 'Soldier stinger',
    [coalition.side.RED] = 'SA-18 Igla manpad',
  },
  
  -- Respawn settings
  RespawnOnPickup = true,         -- if true, vehicle respawns when crew loaded into helo
  RespawnOffset = 15,             -- meters from original death position
  RespawnSameHeading = true,      -- preserve original heading
  
  -- Automatic pickup/unload settings
  AutoPickup = {
    Enabled = true,               -- if true, crews will be picked up automatically when helicopter lands nearby
    MaxDistance = 30,             -- meters - max distance for automatic crew pickup
    CheckInterval = 3,            -- seconds between checks for landed helicopters
    RequireGroundContact = true,  -- when true, helicopter must be firmly on the ground before crews move
    GroundContactAGL = 4,         -- meters AGL threshold treated as “landed” for ground contact purposes
    MaxLandingSpeed = 2,          -- m/s ground speed limit while parked; prevents chasing sliding helicopters
    LoadDelay = 15,               -- seconds crews need to board after reaching helicopter (must stay landed)
    SettledAGL = 6.0,             -- maximum AGL considered safely settled during boarding hold
    AirAbortGrace = 2,            -- seconds of hover tolerated during boarding before aborting
  },
  
  AutoUnload = {
    Enabled = true,               -- if true, crews automatically unload when landed in MASH zone
    UnloadDelay = 15,              -- seconds after landing before auto-unload triggers
    GroundContactAGL = 3.5,        -- meters AGL treated as “on the ground” for auto-unload (taller skids/mod helos)
    SettledAGL = 6.0,              -- maximum AGL considered safely settled for the unload hold to run (relative to terrain)
    MaxLandingSpeed = 2.0,         -- m/s ground speed limit while holding to unload
    AirAbortGrace = 2,             -- seconds of hover wiggle tolerated before aborting the unload hold
  },

  EnrouteMessages = {
    Enabled = true,
    Interval = 123,               -- seconds between in-flight status quips while MEDEVAC patients onboard
  },
  
  -- Salvage system
  Salvage = {
    Enabled = true,
    PoolType = 'global',          -- 'global' = coalition-wide pool
    DefaultValue = 1,             -- default salvageValue if not in catalog
    ShowInStatus = true,          -- show salvage points in F10 status menu
    AutoApply = true,             -- auto-use salvage when out of stock (no manual confirmation)
    AllowAnyItem = true,          -- can build items that never had inventory using salvage
  },
  
  -- Map markers for downed crews
  MapMarkers = {
    Enabled = true,
    IconText = '🔴 MEDEVAC',      -- prefix for marker text
    ShowGrid = true,              -- include grid coordinates in marker
    ShowTimeRemaining = true,     -- show expiration time in marker
    ShowSalvageValue = true,      -- show salvage value in marker
  },
  
  -- Warning messages before crew timeout
  Warnings = {
    { time = 900, message = 'MEDEVAC: {crew} at {grid} has 15 minutes remaining!' },
    { time = 300, message = 'URGENT MEDEVAC: {crew} at {grid} will be KIA in 5 minutes!' },
  },
  
  MASHZoneRadius = 500,           -- default radius for MASH zones
  MASHZoneColors = {
    border = {1, 1, 0, 0.85},     -- yellow border
    fill = {1, 0.75, 0.8, 0.25},  -- pink fill
  },
  
  -- Mobile MASH (player-deployable via crates)
  MobileMASH = {
    Enabled = true,
    ZoneRadius = 500,                     -- radius of Mobile MASH zone in meters
    CrateRecipeKey = 'MOBILE_MASH',       -- catalog key for building mobile MASH
    AnnouncementInterval = 1800,          -- 30 mins between announcements
    BeaconFrequency = '30.0 FM',          -- radio frequency for announcements
    Destructible = true,
    VehicleTypes = {
      [coalition.side.BLUE] = 'M-113',    -- Medical variant for BLUE
      [coalition.side.RED] = 'BTR_D',     -- Medical/transport variant for RED
    },
    AutoIncrementName = true,             -- "Mobile MASH 1", "Mobile MASH 2"...
  },
  
  -- Statistics tracking
  Statistics = {
    Enabled = true,
    TrackByPlayer = false,            -- if true, track per-player stats (not yet implemented)
  },
}

-- =========================
-- Sling-Load Salvage Configuration (MOVED)
-- =========================
--#region SlingLoadSalvage Config
-- NOTE: SlingLoadSalvage configuration has been MOVED into CTLD.Config.SlingLoadSalvage
-- so that it properly gets copied to each CTLD instance via DeepCopy/DeepMerge.
-- The old CTLD.SlingLoadSalvage global definition here is removed to avoid confusion.
-- See CTLD.Config.SlingLoadSalvage above for the actual configuration.
--#endregion SlingLoadSalvage Config
--===================================================================================================================================================
--#endregion MEDEVAC Config

  --#region State
  -- Internal state tables
CTLD._instances = CTLD._instances or {}
CTLD._crates = {}          -- [crateName] = { key, zone, side, spawnTime, point }
CTLD._troopsLoaded = {}    -- [groupName] = { count, typeKey, weightKg }
CTLD._loadedCrates = {}    -- [groupName] = { total=n, totalWeightKg=w, byKey = { key -> count } }
CTLD._loadedTroopTypes = {} -- [groupName] = { total=n, byType = { typeKey -> count }, labels = { typeKey -> label } }
CTLD._deployedTroops = {}  -- [groupName] = { typeKey, count, side, spawnTime, point, weightKg }
CTLD._hoverState = {}       -- [unitName] = { targetCrate=name, startTime=t }
CTLD._unitLast = {}         -- [unitName] = { x, z, t }
CTLD._coachState = {}       -- [unitName] = { lastKeyTimes = {key->time}, lastHint = "", phase = "", lastPhaseMsg = 0, target = crateName, holdStart = nil }
CTLD._msgState = { }        -- messaging throttle state: [scopeKey] = { lastKeyTimes = { key -> time } }
CTLD._buildConfirm = {}     -- [groupName] = time of first build request (awaiting confirmation)
CTLD._buildCooldown = {}    -- [groupName] = time of last successful build
CTLD._NextMarkupId = 10000  -- global-ish id generator shared by instances for map drawings
-- Spatial indexing for hover pickup performance
CTLD._spatialGrid = CTLD._spatialGrid or {}  -- [gridKey] = { crates = {name->meta}, troops = {name->meta} }
CTLD._spatialGridSize = 500  -- meters per grid cell (tunable based on hover pickup distance)
-- Inventory state
CTLD._stockByZone = CTLD._stockByZone or {}   -- [zoneName] = { [crateKey] = count }
CTLD._inStockMenus = CTLD._inStockMenus or {} -- per-group filtered menu handles
CTLD._jtacReservedCodes = CTLD._jtacReservedCodes or {
  [coalition.side.BLUE] = {},
  [coalition.side.RED] = {},
  [coalition.side.NEUTRAL] = {},
}
-- MEDEVAC state
CTLD._medevacCrews = CTLD._medevacCrews or {}     -- [crewGroupName] = { vehicleType, side, spawnTime, position, salvageValue, markerID, originalHeading, requestTime, warningsSent }
CTLD._salvagePoints = CTLD._salvagePoints or {}   -- [coalition.side] = points (global pool)
CTLD._mashZones = CTLD._mashZones or {}           -- [zoneName] = { zone, side, isMobile, unitName (if mobile) }
CTLD._mobileMASHCounter = CTLD._mobileMASHCounter or { [coalition.side.BLUE] = 0, [coalition.side.RED] = 0 }
CTLD._medevacStats = CTLD._medevacStats or {      -- [coalition.side] = { spawned, rescued, delivered, timedOut, killed, salvageEarned, vehiclesRespawned }
  [coalition.side.BLUE] = { spawned = 0, rescued = 0, delivered = 0, timedOut = 0, killed = 0, salvageEarned = 0, vehiclesRespawned = 0, salvageUsed = 0 },
  [coalition.side.RED] = { spawned = 0, rescued = 0, delivered = 0, timedOut = 0, killed = 0, salvageEarned = 0, vehiclesRespawned = 0, salvageUsed = 0 },
}
CTLD._medevacUnloadStates = CTLD._medevacUnloadStates or {} -- [groupName] = { startTime, delay, holdAnnounced, nextReminder }
CTLD._medevacLoadStates = CTLD._medevacLoadStates or {} -- [groupName] = { startTime, delay, crewGroupName, crewData, holdAnnounced, nextReminder }
CTLD._medevacEnrouteStates = CTLD._medevacEnrouteStates or {} -- [groupName] = { nextSend, lastIndex }

-- Sling-Load Salvage state
CTLD._salvageCrates = CTLD._salvageCrates or {}   -- [crateName] = { side, weight, spawnTime, position, initialHealth, rewardValue, warningsSent, staticObject, crateClass }
CTLD._salvageDropZones = CTLD._salvageDropZones or {} -- [zoneName] = { zone, side, active }
CTLD._salvageStats = CTLD._salvageStats or {      -- [coalition.side] = { spawned, delivered, expired, totalWeight, totalReward }
  [coalition.side.BLUE] = { spawned = 0, delivered = 0, expired = 0, totalWeight = 0, totalReward = 0 },
  [coalition.side.RED]  = { spawned = 0, delivered = 0, expired = 0, totalWeight = 0, totalReward = 0 },
}
-- One-shot timer tracking for cleanup
CTLD._pendingTimers = CTLD._pendingTimers or {}  -- [timerId] = true

-- FARP System state
CTLD._farpData = CTLD._farpData or {}  -- [fobZoneName] = { stage = 1/2/3, statics = {name1, name2...}, coalition = side }

local function _distanceXZ(a, b)
  if not a or not b then return math.huge end
  local dx = (a.x or 0) - (b.x or 0)
  local dz = (a.z or 0) - (b.z or 0)
  return math.sqrt(dx * dx + dz * dz)
end

local function _buildSphereVolume(point, radius)
  local px = (point and point.x) or 0
  local pz = (point and point.z) or 0
  local py = (point and (point.y or point.alt))
  if py == nil and land and land.getHeight then
    local ok, h = pcall(land.getHeight, { x = px, y = pz })
    if ok and type(h) == 'number' then py = h end
  end
  py = py or 0
  local volId = (world and world.VolumeType and world.VolumeType.SPHERE) or 0
  return {
    id = volId,
    params = {
      point = { x = px, y = py, z = pz },
      radius = radius or 0,
    }
  }
end

-- Check if a crate is being sling-loaded by scanning for nearby helicopters
-- Static objects don't have inAir() method, so we check if any unit is carrying it
local function _isCrateHooked(crateObj)
  if not crateObj then return false end
  
  -- For dynamic objects (vehicles), inAir() works
  if crateObj.inAir then
    local ok, result = pcall(function() return crateObj:inAir() end)
    if ok and result then return true end
  end
  
  -- For static objects: check if the crate itself is elevated above ground
  -- This indicates it's actually being carried, not just near a helicopter
  local cratePos = crateObj:getPoint()
  if not cratePos then return false end
  
  -- Get ground height at crate position
  local landHeight = land.getHeight({x = cratePos.x, y = cratePos.z})
  if not landHeight then landHeight = 0 end
  
  -- If crate is more than 2 meters above ground, it's being carried
  -- (accounts for terrain variations and crate size)
  local heightAboveGround = cratePos.y - landHeight
  if heightAboveGround > 2 then
    return true
  end
  
  return false
end

local function _fmtTemplate(tpl, data)
  if not tpl or tpl == '' then return '' end
  -- Support placeholder keys with underscores (e.g., {zone_dist_u})
  return (tpl:gsub('{([%w_]+)}', function(k)
    local v = data and data[k]
    -- If value is missing, leave placeholder intact to aid debugging
    if v == nil then return '{'..k..'}' end
    return tostring(v)
  end))
end

function CTLD:_FindNearestFriendlyTransport(position, side, radius)
  if not position or not side then return nil end
  radius = radius or 600
  local bestGroupName
  local bestDist = math.huge
  local sphere = _buildSphereVolume(position, radius)
  world.searchObjects(Object.Category.UNIT, sphere, function(obj)
    if not obj or (not obj.isExist or not obj:isExist()) then return true end
    if not obj.getCoalition or obj:getCoalition() ~= side then return true end
    local grp = obj.getGroup and obj:getGroup()
    if not grp then return true end
    local grpName = grp.getName and grp:getName()
    if not grpName then return true end
    local objPos = obj.getPoint and obj:getPoint()
    local dist = _distanceXZ(position, objPos)
    if dist < bestDist then
      bestDist = dist
      bestGroupName = grpName
    end
    return true
  end)
  if not bestGroupName then return nil end
  local mooseGrp = GROUP:FindByName(bestGroupName)
  return mooseGrp
end

function CTLD:_SendSalvageHint(meta, messageKey, data, position, cooldown)
  if not meta or not messageKey then return end
  cooldown = cooldown or 10
  meta.hintCooldowns = meta.hintCooldowns or {}
  local hintKey = messageKey
  if data and data.zone then hintKey = hintKey .. ':' .. data.zone end
  local now = timer.getTime()
  local last = meta.hintCooldowns[hintKey] or 0
  if (now - last) < cooldown then return end
  meta.hintCooldowns[hintKey] = now

  local template = self.Messages and self.Messages[messageKey]
  if not template then return end
  local text = _fmtTemplate(template, data or {})
  if not text or text == '' then return end

  local recipient = self:_FindNearestFriendlyTransport(position, meta.side, 700)
  local recipientLabel
  if recipient then
    _msgGroup(recipient, text)
    recipientLabel = recipient.GetName and recipient:GetName() or 'nearest transport'
  else
    _msgCoalition(meta.side, text)
    recipientLabel = string.format('coalition-%s', meta.side == coalition.side.BLUE and 'BLUE' or 'RED')
  end

  local zoneLabel = (data and data.zone) and (' zone '..tostring(data.zone)) or ''
  _logInfo(string.format('[SlingLoadSalvage] Hint %s -> %s for crate %s%s',
    messageKey,
    recipientLabel or 'unknown recipient',
    data and data.id or 'unknown',
    zoneLabel))
end

function CTLD:_CheckCrateZoneHints(crateName, meta, cratePos)
  if not meta or not cratePos then return end
  local zoneSets = {
    { list = self.PickupZones, active = self._ZoneActive and self._ZoneActive.Pickup, label = 'Pickup' },
    { list = self.FOBZones, active = self._ZoneActive and self._ZoneActive.FOB, label = 'FOB' },
    { list = self.DropZones, active = self._ZoneActive and self._ZoneActive.Drop, label = 'Drop' },
  }

  for _, entry in ipairs(zoneSets) do
    local zones = entry.list or {}
    if #zones > 0 then
      for _, zone in ipairs(zones) do
        local zoneName = zone:GetName()
        local isActive = true
        if entry.active and zoneName then
          isActive = (entry.active[zoneName] ~= false)
        end
        if isActive and zone:IsVec3InZone(cratePos) then
          self:_SendSalvageHint(meta, 'slingload_salvage_wrong_zone', {
            id = crateName,
            zone = zoneName,
            zone_type = entry.label,
          }, cratePos, 15)
          return
        end
      end
    end
  end
end

  --#endregion State

-- =========================
-- Utilities
-- =========================
  --#region Utilities

-- Select a random crate spawn point inside the zone while respecting separation rules.
function CTLD:_computeCrateSpawnPoint(zone, opts)
  opts = opts or {}
  if not zone or not zone.GetPointVec3 then return nil end

  local centerVec = zone:GetPointVec3()
  if not centerVec then return nil end
  local center = { x = centerVec.x, z = centerVec.z }
  local rZone = self:_getZoneRadius(zone)

  local edgeBuf = math.max(0, opts.edgeBuffer or self.Config.PickupZoneSpawnEdgeBuffer or 10)
  local minOff = math.max(0, opts.minOffset or self.Config.PickupZoneSpawnMinOffset or 5)
  local extraPad = math.max(0, opts.additionalEdgeBuffer or 0)
  local rMax = math.max(0, (rZone or 150) - edgeBuf - extraPad)
  if rMax < 0 then rMax = 0 end

  local tries = math.max(1, opts.tries or self.Config.CrateSpawnSeparationTries or 6)
  local minSep = opts.minSeparation
  if minSep == nil then
    minSep = math.max(0, self.Config.CrateSpawnMinSeparation or 7)
  end

  local skipSeparation = opts.skipSeparationCheck == true
  local ignoreCrates = {}
  if opts.ignoreCrates then
    for name,_ in pairs(opts.ignoreCrates) do
      ignoreCrates[name] = true
    end
  end

  local preferred = opts.preferredPoint
  local usePreferred = (preferred ~= nil)

  local function candidate()
    if usePreferred then
      usePreferred = false
      return { x = preferred.x, z = preferred.z }
    end
    if (self.Config.PickupZoneSpawnRandomize == false) or rMax <= 0 then
      return { x = center.x, z = center.z }
    end
    local rr
    if rMax > minOff then
      rr = minOff + math.sqrt(math.random()) * (rMax - minOff)
    else
      rr = rMax
    end
    local th = math.random() * 2 * math.pi
    return { x = center.x + rr * math.cos(th), z = center.z + rr * math.sin(th) }
  end

  local function isClear(pt)
    if skipSeparation or minSep <= 0 then return true end
    for name, meta in pairs(CTLD._crates) do
      if not ignoreCrates[name] and meta and meta.side == self.Side and meta.point then
        local dx = (meta.point.x - pt.x)
        local dz = (meta.point.z - pt.z)
        if (dx*dx + dz*dz) < (minSep*minSep) then
          return false
        end
      end
    end
    return true
  end

  local chosen = candidate()
  if not chosen then return nil end
  if not isClear(chosen) then
    for _ = 1, tries - 1 do
      local c = candidate()
      if c and isClear(c) then
        chosen = c
        break
      end
    end
  end
  return chosen
end

-- Build a centered grid of offsets for cluster placement, keeping index 1 at the origin.
function CTLD:_buildClusterOffsets(count, spacing)
  local offsets = {}
  if count <= 0 then return offsets, 0, 0 end

  offsets[1] = { x = 0, z = 0 }
  if count == 1 then return offsets, 1, 1 end

  local perRow = math.ceil(math.sqrt(count))
  local rows = math.ceil(count / perRow)
  local positions = {}

  for r = 1, rows do
    for c = 1, perRow do
      local ox = (c - ((perRow + 1) / 2)) * spacing
      local oz = (r - ((rows + 1) / 2)) * spacing
      if math.abs(ox) > 0.01 or math.abs(oz) > 0.01 then
        positions[#positions + 1] = { x = ox, z = oz }
      end
    end
  end

  table.sort(positions, function(a, b)
    local da = a.x * a.x + a.z * a.z
    local db = b.x * b.x + b.z * b.z
    if da == db then
      if a.x == b.x then return a.z < b.z end
      return a.x < b.x
    end
    return da < db
  end)

  local idx = 2
  for _,pos in ipairs(positions) do
    if idx > count then break end
    offsets[idx] = pos
    idx = idx + 1
  end

  return offsets, perRow, rows
end

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

local function _trim(value)
  if type(value) ~= 'string' then return nil end
  return value:match('^%s*(.-)%s*$')
end

local function _addUniqueString(out, seen, value)
  local v = _trim(value)
  if not v or v == '' then return end
  if not seen[v] then
    seen[v] = true
    out[#out + 1] = v
  end
end

local function _collectTypesFromBuilder(builder)
  local out = {}
  if type(builder) ~= 'function' then return out end
  local ok, template = pcall(builder, { x = 0, y = 0, z = 0 }, 0)
  if not ok or type(template) ~= 'table' then return out end
  local units = template.units
  if type(units) ~= 'table' then return out end
  local seen = {}
  for _,unit in pairs(units) do
    if type(unit) == 'table' then
      _addUniqueString(out, seen, unit.type)
    end
  end
  return out
end

local _unitTypeCache = {}

local function _tableHasEntries(tbl)
  if type(tbl) ~= 'table' then return false end
  for _,_ in pairs(tbl) do return true end
  return false
end

local function _tableSize(tbl)
  if type(tbl) ~= 'table' then return 0 end
  local count = 0
  for _,_ in pairs(tbl) do count = count + 1 end
  return count
end

local function _isUnitDatabaseReady()
  local dbRoot = rawget(_G, 'db')
  if type(dbRoot) ~= 'table' then return false, 'missing' end
  local unitByType = dbRoot.unit_by_type
  if type(unitByType) ~= 'table' then return false, 'no_unit_by_type' end
  if _tableHasEntries(unitByType) then return true, 'ok' end
  if _tableHasEntries(dbRoot.units) or _tableHasEntries(dbRoot.Units) then
    -- Older builds expose data under units/Units before unit_by_type is populated
    return true, 'ok'
  end
  return false, 'empty'
end

local function _unitTypeExists(typeName)
  local key = _trim(typeName)
  if not key or key == '' then return false end
  if _unitTypeCache[key] ~= nil then return _unitTypeCache[key] end

  local exists = false
  local visited = {}

  local dbRoot = rawget(_G, 'db')

  -- Fast-path: common lookup table exposed by DCS
  if type(dbRoot) == 'table' and type(dbRoot.unit_by_type) == 'table' then
    if dbRoot.unit_by_type[key] ~= nil then
      _unitTypeCache[key] = true
      return true
    end
  end

  local function walk(tbl)
    if exists or type(tbl) ~= 'table' or visited[tbl] then return end
    visited[tbl] = true

    if tbl.type == key or tbl.Type == key or tbl.unitType == key or tbl.typeName == key or tbl.Name == key then
      exists = true
      return
    end

    for k,v in pairs(tbl) do
      if type(k) == 'string' and k == key then
        exists = true
        return
      end
      if type(v) == 'string' then
        if (k == 'type' or k == 'Type' or k == 'unitType' or k == 'typeName' or k == 'Name') and v == key then
          exists = true
          return
        end
      elseif type(v) == 'table' then
        walk(v)
        if exists then return end
      end
    end
  end

  if type(dbRoot) == 'table' then
    if dbRoot.units then walk(dbRoot.units) end
    if not exists and dbRoot.Units then walk(dbRoot.Units) end
    if not exists and dbRoot.unit_by_type then walk(dbRoot.unit_by_type) end
  end

  _unitTypeCache[key] = exists
  return exists
end

-- Spatial indexing helpers for performance optimization
local function _getSpatialGridKey(x, z)
  local gridSize = CTLD._spatialGridSize or 500
  local gx = math.floor(x / gridSize)
  local gz = math.floor(z / gridSize)
  return string.format("%d_%d", gx, gz)
end

local function _addToSpatialGrid(name, meta, itemType)
  if not meta or not meta.point then return end
  local key = _getSpatialGridKey(meta.point.x, meta.point.z)
  CTLD._spatialGrid[key] = CTLD._spatialGrid[key] or { crates = {}, troops = {} }
  if itemType == 'crate' then
    CTLD._spatialGrid[key].crates[name] = meta
  elseif itemType == 'troops' then
    CTLD._spatialGrid[key].troops[name] = meta
  end
end

local function _removeFromSpatialGrid(name, point, itemType)
  if not point then return end
  local key = _getSpatialGridKey(point.x, point.z)
  local cell = CTLD._spatialGrid[key]
  if cell then
    if itemType == 'crate' then
      cell.crates[name] = nil
    elseif itemType == 'troops' then
      cell.troops[name] = nil
    end
    -- Clean up empty cells
    if not next(cell.crates) and not next(cell.troops) then
      CTLD._spatialGrid[key] = nil
    end
  end
end

local function _getNearbyFromSpatialGrid(x, z, maxDistance)
  local gridSize = CTLD._spatialGridSize or 500
  local cellRadius = math.ceil(maxDistance / gridSize) + 1
  local centerGX = math.floor(x / gridSize)
  local centerGZ = math.floor(z / gridSize)
  
  local nearby = { crates = {}, troops = {} }
  for dx = -cellRadius, cellRadius do
    for dz = -cellRadius, cellRadius do
      local key = string.format("%d_%d", centerGX + dx, centerGZ + dz)
      local cell = CTLD._spatialGrid[key]
      if cell then
        for name, meta in pairs(cell.crates) do
          nearby.crates[name] = meta
        end
        for name, meta in pairs(cell.troops) do
          nearby.troops[name] = meta
        end
      end
    end
  end
  return nearby
end

local function _isIn(list, value)
  for _,v in ipairs(list or {}) do if v == value then return true end end
  return false
end

local function _vec3(x, y, z)
  return { x = x, y = y, z = z }
end

local function _distance3d(a, b)
  if not a or not b then return math.huge end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  local dz = (a.z or 0) - (b.z or 0)
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function _unitHasAttribute(unit, attr)
  if not unit or not attr then return false end
  local ok, res = pcall(function() return unit:hasAttribute(attr) end)
  return ok and res == true
end

local function _isDcsInfantry(unit)
  if not unit then return false end
  local tn = string.lower(unit:getTypeName() or '')
  if tn:find('infantry') or tn:find('soldier') or tn:find('paratrooper') or tn:find('manpad') then
    return true
  end
  return _unitHasAttribute(unit, 'Infantry')
end

local function _hasLineOfSight(fromPos, toPos)
  if not (fromPos and toPos) then return false end
  local p1 = _vec3(fromPos.x, (fromPos.y or 0) + 2.0, fromPos.z)
  local p2 = _vec3(toPos.x, (toPos.y or 0) + 2.0, toPos.z)
  local ok, visible = pcall(function() return land.isVisible(p1, p2) end)
  return ok and visible == true
end

local function _jtacTargetScore(unit)
  if not unit then return -1 end
  if _unitHasAttribute(unit, 'SAM SR') or _unitHasAttribute(unit, 'SAM TR') or _unitHasAttribute(unit, 'SAM CC') or _unitHasAttribute(unit, 'SAM LN') then
    return 120
  end
  if _unitHasAttribute(unit, 'Air Defence') or _unitHasAttribute(unit, 'AAA') then
    return 100
  end
  if _unitHasAttribute(unit, 'IR Guided SAM') or _unitHasAttribute(unit, 'SAM') then
    return 95
  end
  if _unitHasAttribute(unit, 'Artillery') or _unitHasAttribute(unit, 'MLRS') then
    return 80
  end
  if _unitHasAttribute(unit, 'Armor') or _unitHasAttribute(unit, 'Tanks') then
    return 70
  end
  if _unitHasAttribute(unit, 'APC') or _unitHasAttribute(unit, 'IFV') then
    return 60
  end
  if _isDcsInfantry(unit) then
    return 20
  end
  return 40
end

local function _jtacTargetScoreProfiled(unit, profile)
  -- Base score first
  local base = _jtacTargetScore(unit)
  local mult = 1.0
  local attribs = {
    sam = _unitHasAttribute(unit, 'SAM') or _unitHasAttribute(unit, 'SAM SR') or _unitHasAttribute(unit, 'SAM TR') or _unitHasAttribute(unit, 'SAM LN') or _unitHasAttribute(unit, 'IR Guided SAM'),
    aaa = _unitHasAttribute(unit, 'Air Defence') or _unitHasAttribute(unit, 'AAA'),
    armor = _unitHasAttribute(unit, 'Armor') or _unitHasAttribute(unit, 'Tanks'),
    ifv = _unitHasAttribute(unit, 'APC') or _unitHasAttribute(unit, 'Infantry Fighting Vehicle'),
    arty = _unitHasAttribute(unit, 'Artillery') or _unitHasAttribute(unit, 'MLRS'),
    inf = _isDcsInfantry(unit)
  }
  if profile == 'threat' then
    if attribs.sam then mult = 1.6 elseif attribs.aaa then mult = 1.4 elseif attribs.armor then mult = 1.25 elseif attribs.ifv then mult = 1.15 elseif attribs.arty then mult = 1.1 elseif attribs.inf then mult = 0.8 end
  elseif profile == 'armor' then
    if attribs.armor then mult = 1.5 elseif attribs.ifv then mult = 1.3 elseif attribs.sam then mult = 1.25 elseif attribs.aaa then mult = 1.2 elseif attribs.arty then mult = 1.1 elseif attribs.inf then mult = 0.85 end
  elseif profile == 'soft' then
    if attribs.aaa then mult = 1.5 elseif attribs.arty then mult = 1.4 elseif attribs.inf then mult = 1.2 elseif attribs.ifv then mult = 1.1 elseif attribs.armor then mult = 1.0 elseif attribs.sam then mult = 0.9 end
  elseif profile == 'inf_last' then
    if attribs.inf then mult = 0.6 end
  else
    -- balanced; slight bump to SAM/AAA
    if attribs.sam then mult = 1.3 elseif attribs.aaa then mult = 1.2 end
  end
  return math.floor(base * mult + 0.5)
end

_msgGroup = function(group, text, t)
  if not group then return end
  MESSAGE:New(text, t or CTLD.Config.MessageDuration):ToGroup(group)
end

_msgCoalition = function(side, text, t)
  MESSAGE:New(text, t or CTLD.Config.MessageDuration):ToCoalition(side)
end

-- =========================
-- Logging Helpers
-- =========================
-- Log levels: 0=NONE, 1=ERROR, 2=INFO, 3=VERBOSE, 4=DEBUG
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

_log = function(level, msg)
  local logLevel = CTLD.Config and CTLD.Config.LogLevel or LOG_INFO
  if level > logLevel or level == LOG_NONE then return end
  local label = _logLevelLabels[level] or tostring(level)
  local text = string.format('[Moose_CTLD][%s] %s', label, tostring(msg))
  if env and env.info then
    env.info(text)
  else
    print(text)
  end
end

_logError = function(msg)   _log(LOG_ERROR, msg) end
_logInfo  = function(msg)    _log(LOG_INFO, msg) end
-- Treat VERBOSE as DEBUG-only to reduce noise unless LogLevel is 4
_logVerbose = function(msg) _log(LOG_DEBUG, msg) end
_logDebug   = function(msg) _log(LOG_DEBUG, msg) end

-- Emits tagged messages regardless of configured LogLevel (used by explicit debug toggles)
_logImmediate = function(tag, msg)
  local text = string.format('[Moose_CTLD][%s] %s', tag or 'DEBUG', tostring(msg))
  if env and env.info then
    env.info(text)
  else
    print(text)
  end
end

local function _debugCrateSight(kind, params)
  if not params or not params.unit then return end
  CTLD._debugSightState = CTLD._debugSightState or {}
  local key = string.format('%s:%s', kind, params.unit)
  local state = CTLD._debugSightState[key] or {}
  local now = params.now or timer.getTime()
  local interval = params.interval or 1.0
  local step = params.step or 10.0
  local name = params.name or 'none'
  local distance = params.distance or math.huge
  local crateCount = params.count or 0
  local troopCount = params.troops or 0
  local shouldLog = false

  if not state.lastTime or interval <= 0 or (now - state.lastTime) >= interval then
    shouldLog = true
  end
  if state.lastName ~= name then
    shouldLog = true
  end
  if state.lastCount ~= crateCount or state.lastTroops ~= troopCount then
    shouldLog = true
  end
  if distance ~= math.huge then
    if not state.lastDist or math.abs(distance - state.lastDist) >= step then
      shouldLog = true
    end
  elseif state.lastDist ~= math.huge then
    shouldLog = true
  end

  if not shouldLog then return end

  local distText = (distance ~= math.huge) and string.format('d=%.1f', distance) or 'd=n/a'
  local summaryParts = { string.format('%d crate(s)', crateCount) }
  if troopCount and troopCount > 0 then
    table.insert(summaryParts, string.format('%d troop group(s)', troopCount))
  end
  local summary = table.concat(summaryParts, ', ')
  local noteParts = {}
  if params.radius then table.insert(noteParts, string.format('radius=%dm', math.floor(params.radius))) end
  if params.note then table.insert(noteParts, params.note) end
  local noteText = (#noteParts > 0) and (' [' .. table.concat(noteParts, ' ') .. ']') or ''
  local targetLabel = params.targetLabel or 'nearest'
  local typeHint = params.typeHint and (' type=' .. params.typeHint) or ''
  _logImmediate(kind, string.format('Unit %s tracking %s; %s=%s %s%s%s',
    params.unit, summary, targetLabel, name, distText, typeHint, noteText))

  state.lastTime = now
  state.lastName = name
  state.lastDist = distance
  state.lastCount = crateCount
  state.lastTroops = troopCount
  CTLD._debugSightState[key] = state
end

function CTLD:_collectEntryUnitTypes(entry)
  local collected = {}
  local seen = {}
  if type(entry) ~= 'table' then return collected end
  _addUniqueString(collected, seen, entry.unitType)
  if type(entry.unitTypes) == 'table' then
    for _,v in ipairs(entry.unitTypes) do
      _addUniqueString(collected, seen, v)
    end
  end
  if entry.build then
    local fromBuilder = _collectTypesFromBuilder(entry.build)
    for _,v in ipairs(fromBuilder) do
      _addUniqueString(collected, seen, v)
    end
  end
  return collected
end

function CTLD:_validateCatalogUnitTypes()
  if self._catalogValidated then return end
  if self.Config and self.Config.SkipCatalogValidation then return end

  local dbReady, dbReason = _isUnitDatabaseReady()
  if not dbReady then
    if not self._catalogValidationDebugLogged then
      self._catalogValidationDebugLogged = true
      local dbRoot = rawget(_G, 'db')
      local unitByTypeType = dbRoot and type(dbRoot.unit_by_type) or 'nil'
      local unitsType = dbRoot and type(dbRoot.units) or 'nil'
      local unitsAltType = dbRoot and type(dbRoot.Units) or 'nil'
      local sampleKey = 'Soldier M4'
      local sampleValue = (dbRoot and type(dbRoot.unit_by_type) == 'table') and dbRoot.unit_by_type[sampleKey] or nil
      _logDebug(string.format('Catalog validation DB probe: reason=%s db=%s unit_by_type=%s units=%s Units=%s sample[%s]=%s',
        tostring(dbReason), type(dbRoot), unitByTypeType, unitsType, unitsAltType, sampleKey, tostring(sampleValue)))
    end
    if dbReason == 'missing' or dbReason == 'no_unit_by_type' then
      _logInfo('Catalog validation skipped: DCS mission scripting environment does not expose the global unit database (db/unit_by_type)')
      self._catalogValidated = true
      return
    end

    self._catalogValidationRetries = (self._catalogValidationRetries or 0) + 1
    local retry = self._catalogValidationRetries
    local retryLimit = 60
    if retry > retryLimit then
      _logError('Catalog validation skipped: DCS unit database not available after repeated attempts')
      self._catalogValidated = true
      self._catalogValidationScheduled = nil
      return
    end
    if timer and timer.scheduleFunction and timer.getTime then
      if not self._catalogValidationScheduled then
        self._catalogValidationScheduled = true
        local delay = math.min(10, 1 + retry)
        local instance = self
        timer.scheduleFunction(function()
          instance._catalogValidationScheduled = nil
          instance._catalogValidated = nil
          instance:_validateCatalogUnitTypes()
          return nil
        end, {}, timer.getTime() + delay)
      end
      if retry == 1 or (retry % 5 == 0) then
        _logInfo(string.format('Catalog validation deferred: DCS unit database not ready yet (retry %d/%d)', retry, retryLimit))
      end
    else
      if retry == 1 then
        _logInfo('Catalog validation deferred: DCS unit database not ready and timer API unavailable')
      end
      if retry >= 3 then
        _logError('Catalog validation skipped: cannot access DCS unit database or schedule retries')
        self._catalogValidated = true
      end
    end
    return
  end

  if self._catalogValidationRetries and self._catalogValidationRetries > 0 then
    _unitTypeCache = {}
  end
  self._catalogValidationRetries = 0

  local missing = {}

  local function markMissing(typeName, source)
    local key = _trim(typeName)
    if not key or key == '' then return end
    local list = missing[key]
    if not list then
      list = {}
      missing[key] = list
    end
    for _,ref in ipairs(list) do
      if ref == source then return end
    end
    list[#list + 1] = source
  end

  for key,entry in pairs(self.Config.CrateCatalog or {}) do
    local types = self:_collectEntryUnitTypes(entry)
    for _,unitType in ipairs(types) do
      if not _unitTypeExists(unitType) then
        markMissing(unitType, 'crate:'..tostring(key))
      end
    end
  end

  local troopDefs = (self.Config.Troops and self.Config.Troops.TroopTypes) or {}
  for label,def in pairs(troopDefs) do
    local function check(list, suffix)
      for _,unitType in ipairs(list or {}) do
        if not _unitTypeExists(unitType) then
          markMissing(unitType, string.format('troop:%s:%s', tostring(label), suffix))
        end
      end
    end
    check(def.unitsBlue, 'blue')
    check(def.unitsRed, 'red')
    check(def.units, 'fallback')
  end

  if next(missing) then
    for typeName, sources in pairs(missing) do
      _logError(string.format('Catalog validation: unknown unit type "%s" referenced by %s', typeName, table.concat(sources, ', ')))
    end
  else
    _logInfo('Catalog validation: all referenced unit types resolved in DCS database')
  end

  self._catalogValidated = true
end

-- =========================
-- Zone and Unit Utilities
-- =========================

local function _findZone(z)
  if z.name then
    local mz = ZONE:FindByName(z.name)
    if mz then return mz end
  end
  if z.coord then
    local r = z.radius or 150
    -- Create a Vec2 in a way that works even if MOOSE VECTOR2 class isn't available
    local function _mkVec2(x, z)
      if VECTOR2 and VECTOR2.New then return VECTOR2:New(x, z) end
      -- DCS uses Vec2 with fields x and y
      return { x = x, y = z }
    end
    local v = _mkVec2(z.coord.x, z.coord.z)
    return ZONE_RADIUS:New(z.name or ('CTLD_ZONE_'..math.random(10000,99999)), v, r)
  end
  return nil
end

local function _getUnitType(unit)
  local ud = unit and unit:GetDesc() or nil
  return ud and ud.typeName or unit and unit:GetTypeName()
end

-- Get aircraft capacity limits for crates and troops
-- Returns { maxCrates, maxTroops, maxWeightKg } for the given unit
-- Falls back to DefaultCapacity if aircraft type not specifically configured
local function _getAircraftCapacity(unit)
  if not unit then 
    return { 
      maxCrates = CTLD.Config.DefaultCapacity.maxCrates or 4,
      maxTroops = CTLD.Config.DefaultCapacity.maxTroops or 12,
      maxWeightKg = CTLD.Config.DefaultCapacity.maxWeightKg or 2000
    }
  end
  
  local unitType = _getUnitType(unit)
  local capacities = CTLD.Config.AircraftCapacities or {}
  local specific = capacities[unitType]
  
  if specific then
    return {
      maxCrates = specific.maxCrates or 0,
      maxTroops = specific.maxTroops or 0,
      maxWeightKg = specific.maxWeightKg or 0
    }
  end
  
  -- Fallback to defaults
  local defaults = CTLD.Config.DefaultCapacity or {}
  return {
    maxCrates = defaults.maxCrates or 4,
    maxTroops = defaults.maxTroops or 12,
    maxWeightKg = defaults.maxWeightKg or 2000
  }
end

-- Check if a unit is in the air (flying/hovering, not landed)
-- Based on original CTLD logic: uses DCS InAir() API plus velocity threshold
-- Returns: true if airborne, false if landed/grounded
local function _isUnitInAir(unit)
  if not unit then return false end
  
  -- First check: DCS API InAir() - if it says we're on ground, trust it
  if not unit:InAir() then
    return false
  end
  
  -- Second check: velocity threshold (handles edge cases where InAir() is true but we're stationary on ground)
  -- Less than 0.05 m/s (~0.1 knots) = essentially stopped = consider landed
  -- NOTE: AI can hold perfect hover, so only apply this check for player-controlled units
  local vel = unit:GetVelocity()
  if vel and unit:GetPlayerName() then
    local vx = vel.x or 0
    local vz = vel.z or 0
    local groundSpeed = math.sqrt((vx * vx) + (vz * vz)) -- horizontal speed in m/s
    if groundSpeed < 0.05 then
      return false -- stopped on ground
    end
  end
  
  return true -- airborne
end

-- Get ground speed in m/s for a unit
local function _getGroundSpeed(unit)
  if not unit then return 0 end
  local vel = unit:GetVelocity()
  if not vel or not vel.x or not vel.z then return 0 end
  return math.sqrt(vel.x * vel.x + vel.z * vel.z)
end

-- Calculate height above ground level for a unit (meters)
local function _getUnitAGL(unit)
  if not unit then return math.huge end
  local pos = unit:GetPointVec3()
  if not pos then return math.huge end
  local terrain = 0
  if land and land.getHeight then
    local success, h = pcall(land.getHeight, { x = pos.x, y = pos.z })
    if success and type(h) == 'number' then
      terrain = h
    end
  end
  return pos.y - terrain
end

local function _nearestZonePoint(unit, list)
  if not unit or not unit:IsAlive() then return nil end
  -- Get unit position using DCS API to avoid dependency on MOOSE point methods
  local uname = unit:GetName()
  local du = Unit.getByName and Unit.getByName(uname) or nil
  if not du or not du:getPoint() then return nil end
  local up = du:getPoint()
  local ux, uz = up.x, up.z

  local best, bestd = nil, nil
  for _, z in ipairs(list or {}) do
    local mz = _findZone(z)
    local zx, zz
    if z and z.name and trigger and trigger.misc and trigger.misc.getZone then
      local tz = trigger.misc.getZone(z.name)
      if tz and tz.point then zx, zz = tz.point.x, tz.point.z end
    end
    if (not zx) and mz and mz.GetPointVec3 then
      local zp = mz:GetPointVec3()
      -- Try to read numeric fields directly to avoid method calls
      if zp and type(zp) == 'table' and zp.x and zp.z then zx, zz = zp.x, zp.z end
    end
    if (not zx) and z and z.coord then
      zx, zz = z.coord.x, z.coord.z
    end

    if zx and zz then
      local dx = (zx - ux)
      local dz = (zz - uz)
      local d = math.sqrt(dx*dx + dz*dz)
      if (not bestd) or d < bestd then best, bestd = mz, d end
    end
  end
  if not best then return nil, nil end
  return best, bestd
end

-- Check if a unit is inside a Pickup Zone. Returns (inside:boolean, zone, dist, radius)
function CTLD:_isUnitInsidePickupZone(unit, activeOnly)
  if not unit or not unit:IsAlive() then return false, nil, nil, nil end
  local zone, dist
  if activeOnly then
    zone, dist = self:_nearestActivePickupZone(unit)
  else
    local defs = self.Config and self.Config.Zones and self.Config.Zones.PickupZones or {}
    zone, dist = _nearestZonePoint(unit, defs)
  end
  if not zone or not dist then return false, nil, nil, nil end
  local r = self:_getZoneRadius(zone)
  if not r then return false, zone, dist, nil end
  return dist <= r, zone, dist, r
end

-- Helper: get nearest ACTIVE pickup zone (by configured list), respecting CTLD's active flags
function CTLD:_collectActivePickupDefs()
  local out = {}
  local added = {}  -- Track added zone names to prevent duplicates
  
  -- From config-defined zones
  local defs = (self.Config and self.Config.Zones and self.Config.Zones.PickupZones) or {}
  for _, z in ipairs(defs) do
    local n = z.name
    if (not n) or self._ZoneActive.Pickup[n] ~= false then 
      table.insert(out, z)
      if n then added[n] = true end
    end
  end
  
  -- From MOOSE zone objects if present (skip if already added from config)
  if self.PickupZones and #self.PickupZones > 0 then
    for _, mz in ipairs(self.PickupZones) do
      if mz and mz.GetName then
        local n = mz:GetName()
        if self._ZoneActive.Pickup[n] ~= false and not added[n] then 
          table.insert(out, { name = n })
          added[n] = true
        end
      end
    end
  end
  return out
end

function CTLD:_nearestActivePickupZone(unit)
  return _nearestZonePoint(unit, self:_collectActivePickupDefs())
end

local function _defaultCountryForSide(side)
  if not (country and country.id) then return nil end
  if side == coalition.side.BLUE then
    return country.id.USA or country.id.CJTF_BLUE
  elseif side == coalition.side.RED then
    return country.id.RUSSIA or country.id.CJTF_RED
  elseif side == coalition.side.NEUTRAL then
    return country.id.UN or country.id.CJTF_NEUTRAL or country.id.USA
  end
  return nil
end

local function _coalitionAddGroup(side, category, groupData, ctldConfig)
  -- Enforce side/category in groupData just to be safe
  groupData.category = category
  local countryId = ctldConfig and ctldConfig.CountryId
  if not countryId then
    countryId = _defaultCountryForSide(side)
    if ctldConfig then ctldConfig.CountryId = countryId end
  end
  if countryId then
    groupData.country = countryId
  end
  
  -- Apply air-spawn altitude adjustment for AIRPLANE category if DroneAirSpawn is enabled
  if category == Group.Category.AIRPLANE and ctldConfig and ctldConfig.DroneAirSpawn and ctldConfig.DroneAirSpawn.Enabled then
    if groupData.units and #groupData.units > 0 then
      local altAGL = ctldConfig.DroneAirSpawn.AltitudeMeters or 3048
      local speed = ctldConfig.DroneAirSpawn.SpeedMps or 120
      
      for _, unit in ipairs(groupData.units) do
        -- Get terrain height at spawn location
        local terrainHeight = land.getHeight({x = unit.x, y = unit.y})
        -- Set altitude ASL (Above Sea Level)
        unit.alt = terrainHeight + altAGL
        unit.speed = speed
        -- Ensure unit has appropriate spawn type set
        unit.alt_type = "BARO"  -- Barometric altitude
      end
    end
  end
  
  local addCountry = countryId or side
  return coalition.addGroup(addCountry, category, groupData)
end

local function _spawnStaticCargo(side, point, cargoType, name)
  local static = {
    name = name,
    type = cargoType,
    x = point.x,
    y = point.z,
    heading = 0,
    canCargo = true,
  }
  return coalition.addStaticObject(side, static)
end

local function _vec3FromUnit(unit)
  local p = unit:GetPointVec3()
  return { x = p.x, y = p.y, z = p.z }
end

-- Update DCS internal cargo weight based on loaded crates and troops
-- This affects aircraft performance (hover, fuel consumption, speed, etc.)
local function _updateCargoWeight(group)
  if not group then return end
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  local gname = group:GetName()
  local totalWeight = 0
  
  -- Add weight from loaded crates
  local crateData = CTLD._loadedCrates[gname]
  if crateData and crateData.totalWeightKg then
    totalWeight = totalWeight + crateData.totalWeightKg
  end
  
  -- Add weight from loaded troops
  local troopData = CTLD._troopsLoaded[gname]
  if troopData and troopData.weightKg then
    totalWeight = totalWeight + troopData.weightKg
  end
  
  -- Call DCS API to set internal cargo weight (affects flight model)
  local unitName = unit:GetName()
  if unitName and trigger and trigger.action and trigger.action.setUnitInternalCargo then
    pcall(function()
      trigger.action.setUnitInternalCargo(unitName, totalWeight)
    end)
  end
end

-- Unique id generator for map markups (lines/circles/text)
local function _nextMarkupId()
  CTLD._NextMarkupId = (CTLD._NextMarkupId or 10000) + 1
  return CTLD._NextMarkupId
end

local function _spawnCrateSmoke(position, color, config, crateId)
  if not position or not color then return end

  -- Parse config with defaults
  local enabled = true
  local autoRefresh = false
  local refreshInterval = 240
  local maxRefreshDuration = 600
  local offsetMeters = 5
  local offsetRandom = true
  local offsetVertical = 2

  if config then
    enabled = (config.Enabled ~= false)  -- default true
    autoRefresh = (config.AutoRefresh == true)
    refreshInterval = tonumber(config.RefreshInterval) or 240
    maxRefreshDuration = tonumber(config.MaxRefreshDuration) or 600
    offsetMeters = tonumber(config.OffsetMeters) or 5
    offsetRandom = (config.OffsetRandom ~= false)  -- default true
    offsetVertical = tonumber(config.OffsetVertical) or 2
  end

  if not enabled then return end

  -- Compute ground-adjusted position with offsets
  local sx, sz = position.x, position.z
  local sy = position.y or 0
  if sy == 0 and land and land.getHeight then
    local ok, h = pcall(land.getHeight, { x = sx, y = sz })
    if ok and type(h) == 'number' then sy = h end
  end

  -- Apply lateral and vertical offsets
  local ox, oz = 0, 0
  if offsetMeters > 0 then
    local angle = offsetRandom and (math.random() * 2 * math.pi) or 0
    ox = offsetMeters * math.cos(angle)
    oz = offsetMeters * math.sin(angle)
  end
  local smokePos = { x = sx + ox, y = sy + offsetVertical, z = sz + oz }

  -- Emit smoke now
  local coord = COORDINATE:New(smokePos.x, smokePos.y, smokePos.z)
  if coord and coord.Smoke then
    if color == trigger.smokeColor.Green then
      coord:SmokeGreen()
    elseif color == trigger.smokeColor.Red then
      coord:SmokeRed()
    elseif color == trigger.smokeColor.White then
      coord:SmokeWhite()
    elseif color == trigger.smokeColor.Orange then
      coord:SmokeOrange()
    elseif color == trigger.smokeColor.Blue then
      coord:SmokeBlue()
    else
      coord:SmokeGreen()
    end
  else
    trigger.action.smoke(smokePos, color)
  end

  -- Record smoke meta for global refresh loop instead of per-crate timer
  if autoRefresh and crateId and refreshInterval > 0 and maxRefreshDuration > 0 then
    CTLD._crates = CTLD._crates or {}
    local meta = CTLD._crates[crateId]
    if meta then
      meta._smoke = meta._smoke or {}
      if not meta._smoke.enabled then
        meta._smoke.enabled = true
      end
      meta._smoke.auto = true
      meta._smoke.startTime = timer.getTime()
      meta._smoke.nextTime = timer.getTime() + refreshInterval
      meta._smoke.interval = refreshInterval
      meta._smoke.maxDuration = maxRefreshDuration
      meta._smoke.color = color
      meta._smoke.offsetMeters = offsetMeters
      meta._smoke.offsetRandom = offsetRandom
      meta._smoke.offsetVertical = offsetVertical

      -- Ensure background ticker(s) are running
      if CTLD._ensureBackgroundTasks then
        CTLD:_ensureBackgroundTasks()
      end
    end
  end
end

-- Clean up smoke refresh schedule for a crate
local function _cleanupCrateSmoke(crateId)
  if not crateId then return end
  -- Clear legacy per-crate schedule if present
  CTLD._smokeRefreshSchedules = CTLD._smokeRefreshSchedules or {}
  if CTLD._smokeRefreshSchedules[crateId] then
    if CTLD._smokeRefreshSchedules[crateId].funcId then
      pcall(timer.removeFunction, CTLD._smokeRefreshSchedules[crateId].funcId)
    end
    CTLD._smokeRefreshSchedules[crateId] = nil
  end
  -- Clear new smoke meta so the global loop stops refreshing
  if CTLD._crates and CTLD._crates[crateId] then
    CTLD._crates[crateId]._smoke = nil
  end
end

-- Central schedule registry helpers
function CTLD:_registerSchedule(key, funcId)
  self._schedules = self._schedules or {}
  if self._schedules[key] then
    pcall(timer.removeFunction, self._schedules[key])
  end
  self._schedules[key] = funcId
end

function CTLD:_cancelSchedule(key)
  if self._schedules and self._schedules[key] then
    pcall(timer.removeFunction, self._schedules[key])
    self._schedules[key] = nil
  end
end

-- Track one-shot timers for cleanup
local function _trackOneShotTimer(id)
  if id and CTLD._pendingTimers then
    CTLD._pendingTimers[id] = timer.getTime() + 300 -- Store timestamp for cleanup
  end
  return id
end

-- Remove timer from tracking immediately when it fires
local function _untrackTimer(id)
  if id and CTLD._pendingTimers then
    CTLD._pendingTimers[id] = nil
  end
end

-- Clean up one-shot timers when they execute
local function _wrapOneShotCallback(callback, timerId)
  return function(...)
    local result = callback(...)
    -- If callback returns nil or not a number, it's one-shot - remove from tracking
    if not result or type(result) ~= 'number' then
      _untrackTimer(timerId)
    end
    return result
  end
end

local function _removeMenuHandle(menu)
  if not menu or type(menu) ~= 'table' then return end

  local function _menuIsRegistered(m)
    if not MENU_INDEX then return true end
    if not m.Group or not m.MenuText then return true end
    local okPath, path = pcall(function()
      return MENU_INDEX:ParentPath(m.ParentMenu, m.MenuText)
    end)
    if not okPath or not path then
      return false
    end
    local okHas, registered = pcall(function()
      return MENU_INDEX:HasGroupMenu(m.Group, path)
    end)
    if not okHas then
      return false
    end
    return registered == m
  end

  if menu.Remove and _menuIsRegistered(menu) then
    local ok, err = pcall(function() menu:Remove() end)
    if not ok then
      _logVerbose(string.format('[MenuCleanup] Failed to remove menu %s: %s', tostring(menu.MenuText), tostring(err)))
    end
  end

  if menu.Destroy then pcall(function() menu:Destroy() end) end
  if menu.Delete then pcall(function() menu:Delete() end) end
end

local function _countTableEntries(t)
  if not t then return 0 end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function _cleanupGroupMenus(ctld, groupName)
  if not (ctld and groupName) then return end
  if ctld.MenusByGroup and ctld.MenusByGroup[groupName] then
    _removeMenuHandle(ctld.MenusByGroup[groupName])
    ctld.MenusByGroup[groupName] = nil
  end
  if CTLD._inStockMenus and CTLD._inStockMenus[groupName] then
    for _, menu in pairs(CTLD._inStockMenus[groupName]) do
      _removeMenuHandle(menu)
    end
    CTLD._inStockMenus[groupName] = nil
  end
end

local function _clearPerGroupCaches(groupName)
  if not groupName then return end
  local caches = {
    CTLD._troopsLoaded,
    CTLD._loadedCrates,
    CTLD._loadedTroopTypes,
    CTLD._deployedTroops,
    CTLD._buildConfirm,
    CTLD._buildCooldown,
    CTLD._medevacUnloadStates,
    CTLD._medevacLoadStates,
    CTLD._medevacEnrouteStates,
    CTLD._coachOverride,
  }
  for _, tbl in ipairs(caches) do
    if tbl then tbl[groupName] = nil end
  end
  if CTLD._msgState then
    CTLD._msgState['GRP:'..groupName] = nil
  end
  
  -- Note: One-shot timers are now self-cleaning via wrapper, but we log for visibility
  _logVerbose(string.format('[CTLD] Cleared caches for group %s', groupName))
end

local function _clearPerUnitCachesForGroup(group)
  if not group then return end
  local units
  local ok, res = pcall(function() return group:GetUnits() end)
  if ok and type(res) == 'table' then
    units = res
  else
    local okUnit, unit = pcall(function() return group:GetUnit(1) end)
    if okUnit and unit then units = { unit } end
  end
  if not units then return end
  for _, unit in ipairs(units) do
    if unit then
      local uname = unit.GetName and unit:GetName()
      if uname then
        if CTLD._hoverState then CTLD._hoverState[uname] = nil end
        if CTLD._unitLast then CTLD._unitLast[uname] = nil end
        if CTLD._coachState then CTLD._coachState[uname] = nil end
        if CTLD._groundLoadState then CTLD._groundLoadState[uname] = nil end
      end
    end
  end
end

local function _groupHasAliveTransport(group, allowedTypes)
  if not (group and allowedTypes) then return false end
  local units
  local ok, res = pcall(function() return group:GetUnits() end)
  if ok and type(res) == 'table' then
    units = res
  else
    local okUnit, unit = pcall(function() return group:GetUnit(1) end)
    if okUnit and unit then units = { unit } end
  end
  if not units then return false end
  for _, unit in ipairs(units) do
    if unit and unit.IsAlive and unit:IsAlive() then
      local typ = _getUnitType(unit)
      if typ and _isIn(allowedTypes, typ) then
        return true
      end
    end
  end
  return false
end

function CTLD:_cleanupTransportGroup(group, groupName)
  local gname = groupName
  if not gname and group and group.GetName then
    gname = group:GetName()
  end
  if not gname then return end

  _cleanupGroupMenus(self, gname)
  _clearPerGroupCaches(gname)

  if group then
    _clearPerUnitCachesForGroup(group)
  else
    local mooseGroup = nil
    if GROUP and GROUP.FindByName then
      local ok, res = pcall(function() return GROUP:FindByName(gname) end)
      if ok then mooseGroup = res end
    end
    if mooseGroup then _clearPerUnitCachesForGroup(mooseGroup) end
  end

  -- Cleanup JTAC registry if this group had JTAC registered
  if self._jtacRegistry and self._jtacRegistry[gname] then
    self:_cleanupJTACEntry(gname)
  end

  _logDebug(string.format('[MenuCleanup] Cleared CTLD state for group %s', gname))
end

function CTLD:_removeDynamicSalvageZone(zoneName, reason)
  if not zoneName then return end

  if self.SalvageDropZones then
    for idx = #self.SalvageDropZones, 1, -1 do
      local zone = self.SalvageDropZones[idx]
      if zone and zone.GetName and zone:GetName() == zoneName then
        table.remove(self.SalvageDropZones, idx)
      end
    end
  end

  if self._ZoneDefs and self._ZoneDefs.SalvageDropZones then
    self._ZoneDefs.SalvageDropZones[zoneName] = nil
  end

  if self._ZoneActive and self._ZoneActive.SalvageDrop then
    self._ZoneActive.SalvageDrop[zoneName] = nil
  end

  if self._DynamicSalvageZones then
    self._DynamicSalvageZones[zoneName] = nil
  end

  if self._DynamicSalvageQueue then
    for idx = #self._DynamicSalvageQueue, 1, -1 do
      if self._DynamicSalvageQueue[idx] == zoneName then
        table.remove(self._DynamicSalvageQueue, idx)
      end
    end
  end

  self:_removeZoneDrawing('SalvageDrop', zoneName)
  _logInfo(string.format('[SlingLoadSalvage] Removed dynamic salvage zone %s (%s)', zoneName, reason or 'cleanup'))
  local ok, err = pcall(function() self:DrawZonesOnMap() end)
  if not ok then
    _logError(string.format('[SlingLoadSalvage] DrawZonesOnMap failed after removing %s: %s', zoneName, tostring(err)))
  end
end

function CTLD:_enforceDynamicSalvageZoneLimit()
  local cfg = self.Config and self.Config.SlingLoadSalvage or nil
  if not cfg or not cfg.Enabled then return end

  local zones = self._DynamicSalvageZones
  if not zones then return end

  local lifetime = tonumber(cfg.DynamicZoneLifetime or 0) or 0
  local maxZones = tonumber(cfg.MaxDynamicZones or 0) or 0
  local now = timer and timer.getTime and timer.getTime() or 0

  if lifetime > 0 then
    local expired = {}
    for name, meta in pairs(zones) do
      if meta then
        local expiresAt = meta.expiresAt
        if not expiresAt and meta.createdAt then
          expiresAt = meta.createdAt + lifetime
        end
        if expiresAt and now >= expiresAt then
          table.insert(expired, name)
        end
      end
    end
    for _, zname in ipairs(expired) do
      self:_removeDynamicSalvageZone(zname, 'expired')
    end
  end

  if maxZones > 0 and self._DynamicSalvageQueue then
    while #self._DynamicSalvageQueue > maxZones do
      local oldest = table.remove(self._DynamicSalvageQueue, 1)
      if oldest and zones[oldest] then
        self:_removeDynamicSalvageZone(oldest, 'max-cap')
      end
    end
  end
end

-- Global smoke refresh ticker (single loop for all crates)
function CTLD:_ensureGlobalSmokeTicker()
  if self._schedules and self._schedules.smokeTicker then return end

  local function tick()
    local now = timer.getTime()
    if CTLD and CTLD._crates then
      for name, meta in pairs(CTLD._crates) do
        if meta and meta._smoke and meta._smoke.auto and meta.point then
          local s = meta._smoke
          if (now - (s.startTime or now)) > (s.maxDuration or 0) then
            meta._smoke = nil
          elseif now >= (s.nextTime or 0) then
            -- Spawn another puff
            local pos = { x = meta.point.x, y = 0, z = meta.point.z }
            if land and land.getHeight then
              local ok, h = pcall(land.getHeight, { x = pos.x, y = pos.z })
              if ok and type(h) == 'number' then pos.y = h end
            end
            _spawnCrateSmoke(pos, s.color or trigger.smokeColor.Green, {
              Enabled = true,
              AutoRefresh = false,  -- avoid recursion; we manage nextTime here
              OffsetMeters = s.offsetMeters or 0,
              OffsetRandom = s.offsetRandom ~= false,
              OffsetVertical = s.offsetVertical or 0,
            }, name)
            s.nextTime = now + (s.interval or 240)
          end
        end
      end
    end
    return timer.getTime() + 10  -- tick every 10s
  end

  local id = timer.scheduleFunction(tick, nil, timer.getTime() + 10)
  self:_registerSchedule('smokeTicker', id)
end

-- Periodic GC to prune stale messaging/coach entries and smoke meta
function CTLD:_ensurePeriodicGC()
  if self._schedules and self._schedules.periodicGC then return end

  local function gcTick()
    local now = timer.getTime()
    
    -- Coach state: remove units that no longer exist
    if CTLD and CTLD._coachState then
      for uname, _ in pairs(CTLD._coachState) do
        local u = Unit.getByName(uname)
        if not u then CTLD._coachState[uname] = nil end
      end
    end

    -- Message throttle state: remove dead/missing groups
    if CTLD and CTLD._msgState then
      for scope, _ in pairs(CTLD._msgState) do
        local gname = string.match(scope, '^GRP:(.+)$')
        if gname then
          local g = Group.getByName(gname)
          if not g then CTLD._msgState[scope] = nil end
        end
      end
    end

    -- Smoke meta: prune crates without points or exceeded duration
    if CTLD and CTLD._crates then
      for name, meta in pairs(CTLD._crates) do
        if meta and meta._smoke then
          local s = meta._smoke
          if (not meta.point) or ((now - (s.startTime or now)) > (s.maxDuration or 0)) then
            meta._smoke = nil
          end
        end
      end
    end

    -- Enforce MEDEVAC crew limit (keep last 100 requests)
    if CTLD and CTLD._medevacCrews then
      local crewCount = 0
      local crewList = {}
      for crewName, crewData in pairs(CTLD._medevacCrews) do
        crewCount = crewCount + 1
        table.insert(crewList, { name = crewName, time = crewData.requestTime or 0 })
      end
      if crewCount > 100 then
        table.sort(crewList, function(a, b) return a.time < b.time end)
        local toRemove = crewCount - 100
        for i = 1, toRemove do
          local crewName = crewList[i].name
          local crewData = CTLD._medevacCrews[crewName]
          if crewData and crewData.markerID then
            pcall(function() trigger.action.removeMark(crewData.markerID) end)
          end
          CTLD._medevacCrews[crewName] = nil
        end
        env.info(string.format('[CTLD][GC] Pruned %d old MEDEVAC crew entries', toRemove))
      end
    end

    -- Enforce salvage crate limit (keep last 50 active crates per side)
    if CTLD and CTLD._salvageCrates then
      local crateBySide = { [coalition.side.BLUE] = {}, [coalition.side.RED] = {} }
      for crateName, crateData in pairs(CTLD._salvageCrates) do
        if crateData.side then
          table.insert(crateBySide[crateData.side], { name = crateName, time = crateData.spawnTime or 0 })
        end
      end
      for side, crates in pairs(crateBySide) do
        if #crates > 50 then
          table.sort(crates, function(a, b) return a.time < b.time end)
          local toRemove = #crates - 50
          for i = 1, toRemove do
            local crateName = crates[i].name
            local crateData = CTLD._salvageCrates[crateName]
            if crateData and crateData.staticObject and crateData.staticObject.destroy then
              pcall(function() crateData.staticObject:destroy() end)
            end
            CTLD._salvageCrates[crateName] = nil
          end
          local sideName = (side == coalition.side.BLUE and 'BLUE') or 'RED'
          env.info(string.format('[CTLD][GC] Pruned %d old %s salvage crates', toRemove, sideName))
        end
      end
    end

    -- Clean up stale pending timer references based on timestamp
    if CTLD and CTLD._pendingTimers then
      local now = timer.getTime()
      local timerCount = 0
      local cleaned = 0
      for timerId, expireTime in pairs(CTLD._pendingTimers) do
        timerCount = timerCount + 1
        -- Remove timers that should have fired more than 60 seconds ago
        if type(expireTime) == 'number' and now > expireTime + 60 then
          CTLD._pendingTimers[timerId] = nil
          cleaned = cleaned + 1
        end
      end
      if cleaned > 0 then
        env.info(string.format('[CTLD][GC] Cleaned %d stale timer references (total: %d)', cleaned, timerCount))
      end
      -- Emergency cleanup if we still have too many
      if timerCount > 300 then
        env.info(string.format('[CTLD][GC] Emergency clearing %d timer references', timerCount))
        CTLD._pendingTimers = {}
      end
    end

    -- Force garbage collection
    collectgarbage('step', 1000)

    return timer.getTime() + 300  -- every 5 minutes
  end

  local id = timer.scheduleFunction(gcTick, nil, timer.getTime() + 300)
  self:_registerSchedule('periodicGC', id)
end

function CTLD:_ensureBackgroundTasks()
  if self._bgStarted then return end
  self._bgStarted = true
  self:_ensureGlobalSmokeTicker()
  self:_ensurePeriodicGC()
  self:_ensureAdaptiveBackgroundLoop()
  self:_ensureSlingLoadEventHandler()
  self:_startHourlyDiagnostics()
end

function CTLD:_startHoverScheduler()
  local coachCfg = CTLD.HoverCoachConfig or {}
  if not coachCfg.enabled or self.HoverSched then return end
  local interval = coachCfg.interval or 0.75
  local startDelay = coachCfg.startDelay or interval
  local gcCounter = 0
  self.HoverSched = SCHEDULER:New(nil, function()
    local ok, err = pcall(function() self:ScanHoverPickup() end)
    if not ok then _logError('HoverSched ScanHoverPickup error: '..tostring(err)) end
    -- Incremental GC every 50 iterations (~37 seconds at 0.75s interval)
    gcCounter = gcCounter + 1
    if gcCounter >= 50 then
      collectgarbage('step', 100)
      gcCounter = 0
    end
  end, {}, startDelay, interval)
end

function CTLD:_startGroundLoadScheduler()
  local groundCfg = CTLD.GroundAutoLoadConfig or {}
  if not groundCfg.Enabled or self.GroundLoadSched then return end
  local interval = 1.0 -- check every second for ground load conditions
  local gcCounter = 0
  self.GroundLoadSched = SCHEDULER:New(nil, function()
    local ok, err = pcall(function() self:ScanGroundAutoLoad() end)
    if not ok then _logError('GroundLoadSched ScanGroundAutoLoad error: '..tostring(err)) end
    -- Incremental GC every 60 iterations (60 seconds)
    gcCounter = gcCounter + 1
    if gcCounter >= 60 then
      collectgarbage('step', 100)
      gcCounter = 0
    end
  end, {}, interval, interval)
end

-- Adaptive background loop consolidating salvage checks and periodic pruning
function CTLD:_ensureAdaptiveBackgroundLoop()
  if self._schedules and self._schedules.backgroundLoop then return end

  local function backgroundTick()
    local now = timer.getTime()

    -- Salvage crate housekeeping
    local cfg = self.Config.SlingLoadSalvage
    local activeCrates = 0
    if cfg and cfg.Enabled then
      for _, meta in pairs(CTLD._salvageCrates) do
        if meta and meta.side == self.Side then
          activeCrates = activeCrates + 1
        end
      end

      -- Run the standard checker to handle delivery/expiration
      local ok, err = pcall(function() self:_CheckSlingLoadSalvageCrates() end)
      if not ok then
        _logError('[SlingLoadSalvage] backgroundTick error: '..tostring(err))
      end

      -- Stale crate cleanup: destroy any crate that lost its static object reference
      for cname, meta in pairs(CTLD._salvageCrates) do
        if meta and (not meta.staticObject or (meta.staticObject.destroy and not meta.staticObject:isExist())) then
          CTLD._salvageCrates[cname] = nil
        end
      end

      -- Dynamic salvage zone lifetime enforcement
      self:_enforceDynamicSalvageZoneLimit()
    end

    -- Hover coach cleanup: remove entries for missing units
    if CTLD._coachState then
      for uname, _ in pairs(CTLD._coachState) do
        if not Unit.getByName(uname) then
          CTLD._coachState[uname] = nil
        end
      end
    end

    -- Ensure the hover scan scheduler matches active transport presence
    local hasTransports = false
    for gname, _ in pairs(self.MenusByGroup or {}) do
      local grp = nil
      if GROUP and GROUP.FindByName then
        local ok, res = pcall(function() return GROUP:FindByName(gname) end)
        if ok then grp = res end
      end
      if grp and grp:IsAlive() then
        hasTransports = true
        break
      end
      if not grp and Group and Group.getByName then
        local ok, dcsGrp = pcall(function() return Group.getByName(gname) end)
        if ok and dcsGrp and dcsGrp:isExist() then
          hasTransports = true
          break
        end
      end
    end

    if hasTransports then
      if (not self.HoverSched) and self._startHoverScheduler then
        pcall(function() self:_startHoverScheduler() end)
      end
    else
      if self.HoverSched and self.HoverSched.Stop then
        pcall(function() self.HoverSched:Stop() end)
      end
      self.HoverSched = nil
    end

    -- Determine next wake interval based on active salvage crates
    local baseInterval = (cfg and cfg.DetectionInterval) or 5
    local adaptive = (cfg and cfg.AdaptiveIntervals) or {}
    local nextInterval
    if activeCrates == 0 then
      nextInterval = adaptive.idle or math.max(baseInterval * 2, 10)
    elseif activeCrates <= 20 then
      nextInterval = adaptive.low or math.max(baseInterval * 2, 10)
    elseif activeCrates <= 35 then
      nextInterval = adaptive.medium or math.max(baseInterval * 3, 15)
    else
      nextInterval = adaptive.high or math.max(baseInterval * 4, 20)
    end
    nextInterval = math.min(nextInterval, 30)

    CTLD._lastSalvageInterval = nextInterval

    return now + nextInterval
  end

  local id = timer.scheduleFunction(function()
    local nextTime = backgroundTick()
    return nextTime
  end, nil, timer.getTime() + 2)
  self:_registerSchedule('backgroundLoop', id)
end

function CTLD:_ensureSlingLoadEventHandler()
  -- No event handler needed - we use inAir() checks like original CTLD.lua
  if self._slingHandlerRegistered then return end
  self._slingHandlerRegistered = true
end

function CTLD:_startHourlyDiagnostics()
  if not (timer and timer.scheduleFunction) then return end
  if self._schedules and self._schedules.hourlyDiagnostics then return end

  local function diagTick()
    local salvageCount = 0
    for _, _ in ipairs(self.SalvageDropZones or {}) do salvageCount = salvageCount + 1 end
    local menuCount = _countTableEntries(self.MenusByGroup)
    local dynamicCount = _countTableEntries(self._DynamicSalvageZones)
    local sideLabel = (self.Side == coalition.side.BLUE and 'BLUE')
      or (self.Side == coalition.side.RED and 'RED')
      or (self.Side == coalition.side.NEUTRAL and 'NEUTRAL')
      or tostring(self.Side)
    
    -- Comprehensive memory usage stats
    local cratesCount = _countTableEntries(CTLD._crates)
    local medevacCrewsCount = _countTableEntries(CTLD._medevacCrews)
    local salvageCratesCount = _countTableEntries(CTLD._salvageCrates)
    local coachStateCount = _countTableEntries(CTLD._coachState)
    local hoverStateCount = _countTableEntries(CTLD._hoverState)
    local pendingTimersCount = _countTableEntries(CTLD._pendingTimers)
    local msgStateCount = _countTableEntries(CTLD._msgState)
    
    env.info(string.format('[CTLD][SoakTest][%s] salvageZones=%d dynamicZones=%d menus=%d',
      sideLabel, salvageCount, dynamicCount, menuCount))
    env.info(string.format('[CTLD][Memory][%s] crates=%d medevacCrews=%d salvageCrates=%d coachState=%d hoverState=%d pendingTimers=%d msgState=%d',
      sideLabel, cratesCount, medevacCrewsCount, salvageCratesCount, coachStateCount, hoverStateCount, pendingTimersCount, msgStateCount))
    
    return timer.getTime() + 3600
  end

  local id = timer.scheduleFunction(function()
    return diagTick()
  end, nil, timer.getTime() + 3600)
  self:_registerSchedule('hourlyDiagnostics', id)
end

local function _ctldHelperGet()
  local ctldClass = _G._MOOSE_CTLD or CTLD
  if not ctldClass then
    env.info('[CTLD] Runtime helper unavailable: CTLD not loaded')
    return nil
  end
  return ctldClass
end

local function _ctldSideName(side)
  if side == coalition.side.BLUE then return 'BLUE' end
  if side == coalition.side.RED then return 'RED' end
  if side == coalition.side.NEUTRAL then return 'NEUTRAL' end
  return tostring(side or 'nil')
end

local function _ctldFormatSeconds(secs)
  if not secs or secs <= 0 then return '0s' end
  local minutes = math.floor(secs / 60)
  local seconds = math.floor(secs % 60)
  if minutes > 0 then
    return string.format('%dm%02ds', minutes, seconds)
  end
  return string.format('%ds', seconds)
end

if not _G.CTLD_DumpRuntimeStats then
  function _G.CTLD_DumpRuntimeStats()
    local ctldClass = _ctldHelperGet()
    if not ctldClass then return end

    local now = timer and timer.getTime and timer.getTime() or 0
    local salvageBySide = {}
    local oldestBySide = {}
    for name, meta in pairs(ctldClass._salvageCrates or {}) do
      if meta and meta.side then
        salvageBySide[meta.side] = (salvageBySide[meta.side] or 0) + 1
        if meta.spawnTime then
          local age = now - meta.spawnTime
          if age > (oldestBySide[meta.side] or 0) then
            oldestBySide[meta.side] = age
          end
        end
      end
    end

    local medevacCount = 0
    for _ in pairs(ctldClass._medevacCrews or {}) do
      medevacCount = medevacCount + 1
    end

    env.info(string.format('[CTLD] Active salvage crates: BLUE=%d RED=%d',
      salvageBySide[coalition.side.BLUE] or 0,
      salvageBySide[coalition.side.RED] or 0))
    env.info(string.format('[CTLD] Oldest salvage crate age: BLUE=%s RED=%s',
      _ctldFormatSeconds(oldestBySide[coalition.side.BLUE] or 0),
      _ctldFormatSeconds(oldestBySide[coalition.side.RED] or 0)))
    env.info(string.format('[CTLD] Active MEDEVAC crews: %d', medevacCount))

    local totalSchedules = 0
    local instanceCount = 0
    for _, inst in ipairs(ctldClass._instances or {}) do
      instanceCount = instanceCount + 1
      if inst._schedules then
        for _ in pairs(inst._schedules) do
          totalSchedules = totalSchedules + 1
        end
      end
      for key, value in pairs(inst) do
        if type(value) == 'table' and value.Stop and key:match('Sched') then
          totalSchedules = totalSchedules + 1
        end
      end
    end

    env.info(string.format('[CTLD] Instances: %d, scheduler objects (approx): %d', instanceCount, totalSchedules))
    env.info(string.format('[CTLD] Last salvage loop interval: %s', _ctldFormatSeconds(ctldClass._lastSalvageInterval or 0)))
  end
end

if not _G.CTLD_DumpCrateAges then
  function _G.CTLD_DumpCrateAges()
    local ctldClass = _ctldHelperGet()
    if not ctldClass then return end

    local crates = {}
    local now = timer and timer.getTime and timer.getTime() or 0
    local lifetime = (ctldClass.Config and ctldClass.Config.SlingLoadSalvage and ctldClass.Config.SlingLoadSalvage.CrateLifetime) or 0
    for name, meta in pairs(ctldClass._salvageCrates or {}) do
      local age = meta.spawnTime and (now - meta.spawnTime) or 0
      table.insert(crates, {
        name = name,
        side = meta.side,
        age = age,
        remaining = math.max(0, lifetime - age),
        weight = meta.weight or 0,
      })
    end

    table.sort(crates, function(a, b) return a.age > b.age end)

    env.info(string.format('[CTLD] Listing %d salvage crates (lifetime=%ss)', #crates, tostring(lifetime)))
    for i = 1, math.min(#crates, 25) do
      local c = crates[i]
      env.info(string.format('[CTLD] #%02d %s side=%s weight=%dkg age=%s remaining=%s',
        i, c.name, _ctldSideName(c.side), c.weight,
        _ctldFormatSeconds(c.age), _ctldFormatSeconds(c.remaining)))
    end
  end
end

if not _G.CTLD_ListSchedules then
  function _G.CTLD_ListSchedules()
    local ctldClass = _ctldHelperGet()
    if not ctldClass then return end

    local instances = ctldClass._instances or {}
    if #instances == 0 then
      env.info('[CTLD] No CTLD instances registered')
      return
    end

    for idx, inst in ipairs(instances) do
      local sideLabel = _ctldSideName(inst.Side)
      env.info(string.format('[CTLD] Instance #%d side=%s', idx, sideLabel))

      if inst._schedules then
        for key, funcId in pairs(inst._schedules) do
          env.info(string.format('  [timer] key=%s funcId=%s', tostring(key), tostring(funcId)))
        end
      end

      for key, value in pairs(inst) do
        if type(value) == 'table' and value.Stop and key:match('Sched') then
          local running = 'unknown'
          if type(value.IsRunning) == 'function' then
            local ok, res = pcall(value.IsRunning, value)
            if ok then running = tostring(res) end
          end
          env.info(string.format('  [sched] key=%s running=%s', tostring(key), running))
        end
      end
    end
  end
end

-- Spawn smoke for MEDEVAC crews with offset system
-- position: {x, y, z} table
-- smokeColor: trigger.smokeColor enum value
-- config: MEDEVAC config table (for offset settings)
local function _spawnMEDEVACSmoke(position, smokeColor, config)
  if not position or not smokeColor then return end
  
  -- Apply smoke offset system
  local smokePos = { 
    x = position.x, 
    y = land.getHeight({x = position.x, y = position.z}), 
    z = position.z 
  }
  
  local offsetMeters = (config and config.SmokeOffsetMeters) or 5
  local offsetRandom = (not config or config.SmokeOffsetRandom ~= false)  -- default true
  local offsetVertical = (config and config.SmokeOffsetVertical) or 2
  
  if offsetMeters > 0 then
    local angle = 0  -- North by default
    if offsetRandom then
      angle = math.random() * 2 * math.pi  -- Random direction
    end
    smokePos.x = smokePos.x + offsetMeters * math.cos(angle)
    smokePos.z = smokePos.z + offsetMeters * math.sin(angle)
  end
  smokePos.y = smokePos.y + offsetVertical
  
  -- Spawn smoke using MOOSE COORDINATE (better appearance) or fallback to trigger.action.smoke
  local coord = COORDINATE:New(smokePos.x, smokePos.y, smokePos.z)
  if coord and coord.Smoke then
    if smokeColor == trigger.smokeColor.Green then
      coord:SmokeGreen()
    elseif smokeColor == trigger.smokeColor.Red then
      coord:SmokeRed()
    elseif smokeColor == trigger.smokeColor.White then
      coord:SmokeWhite()
    elseif smokeColor == trigger.smokeColor.Orange then
      coord:SmokeOrange()
    elseif smokeColor == trigger.smokeColor.Blue then
      coord:SmokeBlue()
    else
      coord:SmokeRed()  -- default
    end
  else
    trigger.action.smoke(smokePos, smokeColor)
  end
end

-- Resolve a zone's center (vec3) and radius (meters).
-- Accepts a MOOSE ZONE object returned by _findZone/ZONE:FindByName/ZONE_RADIUS:New
function CTLD:_getZoneCenterAndRadius(mz)
  if not mz then return nil, nil end
  local name = mz.GetName and mz:GetName() or nil
  -- Prefer Mission Editor zone data if available
  if name and trigger and trigger.misc and trigger.misc.getZone then
    local z = trigger.misc.getZone(name)
    if z and z.point and z.radius then
      local p = { x = z.point.x, y = z.point.y or 0, z = z.point.z }
      return p, z.radius
    end
  end
  -- Fall back to MOOSE zone center
  local pv = mz.GetPointVec3 and mz:GetPointVec3() or nil
  local p = pv and { x = pv.x, y = pv.y or 0, z = pv.z } or nil
  -- Try to fetch a configured radius from our zone defs
  local r
  if name and self._ZoneDefs then
    local d = self._ZoneDefs.PickupZones and self._ZoneDefs.PickupZones[name]
            or self._ZoneDefs.DropZones and self._ZoneDefs.DropZones[name]
            or self._ZoneDefs.FOBZones and self._ZoneDefs.FOBZones[name]
            or self._ZoneDefs.MASHZones and self._ZoneDefs.MASHZones[name]
    if d and d.radius then r = d.radius end
  end
  r = r or (mz.GetRadius and mz:GetRadius()) or 150
  return p, r
end

-- Draw a circle and label for a zone on the F10 map for this coalition.
-- kind: 'Pickup' | 'Drop' | 'FOB' | 'MASH'
function CTLD:_drawZoneCircleAndLabel(kind, mz, opts)
  if not (trigger and trigger.action and trigger.action.circleToAll and trigger.action.textToAll) then return end
  opts = opts or {}
  local p, r = self:_getZoneCenterAndRadius(mz)
  if not p or not r then return end
  local side = (opts.ForAll and -1) or self.Side
  local outline = opts.OutlineColor or {0,1,0,0.85}
  local fill = opts.FillColor or {0,1,0,0.15}
  local lineType = opts.LineType or 1
  local readOnly = (opts.ReadOnly ~= false)
  local fontSize = opts.FontSize or 18
  local labelPrefix = opts.LabelPrefix or 'Zone'
  local zname = (mz.GetName and mz:GetName()) or '(zone)'
  local circleId = _nextMarkupId()
  local textId = _nextMarkupId()
  trigger.action.circleToAll(side, circleId, p, r, outline, fill, lineType, readOnly, "")
  local label = string.format('%s: %s', labelPrefix, zname)
  -- Place label centered above the circle (12 o'clock). Horizontal nudge via LabelOffsetX.
  -- Simple formula: extra offset from edge = r * ratio + fromEdge
  local extra = (r * (opts.LabelOffsetRatio or 0.0)) + (opts.LabelOffsetFromEdge or 30)
  local nx = p.x + (opts.LabelOffsetX or 0)
  local nz = p.z - (r + (extra or 0))
  local textPos = { x = nx, y = 0, z = nz }
  trigger.action.textToAll(side, textId, textPos, {1,1,1,0.9}, {0,0,0,0}, fontSize, readOnly, label)
  -- Track ids so they can be cleared later
  self._MapMarkup = self._MapMarkup or { Pickup = {}, Drop = {}, FOB = {}, MASH = {}, SalvageDrop = {} }
  self._MapMarkup[kind] = self._MapMarkup[kind] or {}
  self._MapMarkup[kind][zname] = { circle = circleId, text = textId }
end

function CTLD:ClearMapDrawings()
  if not (self._MapMarkup and trigger and trigger.action and trigger.action.removeMark) then return end
  for _, byName in pairs(self._MapMarkup) do
    for _, ids in pairs(byName) do
      if ids.circle then pcall(trigger.action.removeMark, ids.circle) end
      if ids.text then pcall(trigger.action.removeMark, ids.text) end
    end
  end
  self._MapMarkup = { Pickup = {}, Drop = {}, FOB = {}, MASH = {}, SalvageDrop = {} }
end

function CTLD:_updateMobileMASHDrawing(mashId)
  local data = CTLD._mashZones and CTLD._mashZones[mashId]
  if not data or data.side ~= self.Side or not data.isMobile then return end
  if not (self.Config.MapDraw and self.Config.MapDraw.Enabled and self.Config.MapDraw.DrawMASHZones) then return end
  
  local zoneName = data.displayName or mashId
  if self._ZoneActive.MASH[zoneName] == false then return end
  
  -- Remove old drawing
  self:_removeZoneDrawing('MASH', zoneName)
  
  -- Redraw at new position
  local md = self.Config.MapDraw
  local opts = {
    OutlineColor = md.OutlineColor,
    LineType = (md.LineTypes and md.LineTypes.MASH) or md.LineType or 1,
    FillColor = (md.FillColors and md.FillColors.MASH) or nil,
    FontSize = md.FontSize,
    ReadOnly = (md.ReadOnly ~= false),
    LabelPrefix = (md.LabelPrefixes and md.LabelPrefixes.MASH) or 'MASH',
    LabelOffsetX = md.LabelOffsetX,
    LabelOffsetFromEdge = md.LabelOffsetFromEdge,
    LabelOffsetRatio = md.LabelOffsetRatio,
    ForAll = (md.ForAll == true),
  }
  if data.zone then
    self:_drawZoneCircleAndLabel('MASH', data.zone, opts)
  end
end

function CTLD:_removeZoneDrawing(kind, zname)
  if not (self._MapMarkup and self._MapMarkup[kind] and self._MapMarkup[kind][zname]) then return end
  local ids = self._MapMarkup[kind][zname]
  if ids.circle then pcall(trigger.action.removeMark, ids.circle) end
  if ids.text then pcall(trigger.action.removeMark, ids.text) end
  self._MapMarkup[kind][zname] = nil
end

-- Public: set a specific zone active/inactive by kind and name
function CTLD:SetZoneActive(kind, name, active, silent)
  if not (kind and name) then return end
  local k = (kind == 'Pickup' or kind == 'Drop' or kind == 'FOB' or kind == 'MASH') and kind or nil
  if not k then return end
  self._ZoneActive = self._ZoneActive or { Pickup = {}, Drop = {}, FOB = {}, MASH = {} }
  self._ZoneActive[k][name] = (active ~= false)
  -- Update drawings for this one zone only
  if self.Config.MapDraw and self.Config.MapDraw.Enabled then
    -- Find the MOOSE zone object by name
    local list = (k=='Pickup' and self.PickupZones) or (k=='Drop' and self.DropZones) or (k=='FOB' and self.FOBZones) or (k=='MASH' and self.MASHZones) or {}
    local mz
    for _,z in ipairs(list or {}) do if z and z.GetName and z:GetName() == name then mz = z break end end
    if self._ZoneActive[k][name] then
      if mz then
        local md = self.Config.MapDraw
        local opts = {
          OutlineColor = md.OutlineColor,
          FillColor = (md.FillColors and md.FillColors[k]) or nil,
          LineType = (md.LineTypes and md.LineTypes[k]) or md.LineType or 1,
          FontSize = md.FontSize,
          ReadOnly = (md.ReadOnly ~= false),
          LabelOffsetX = md.LabelOffsetX,
          LabelOffsetFromEdge = md.LabelOffsetFromEdge,
          LabelOffsetRatio = md.LabelOffsetRatio,
          LabelPrefix = ((md.LabelPrefixes and md.LabelPrefixes[k])
                        or (k=='Pickup' and md.LabelPrefix)
                        or (k..' Zone'))
        }
        self:_drawZoneCircleAndLabel(k, mz, opts)
      end
    else
      self:_removeZoneDrawing(k, name)
    end
  end
  -- Optional messaging
  local stateStr = self._ZoneActive[k][name] and 'ACTIVATED' or 'DEACTIVATED'
  _logVerbose(string.format('Zone %s %s (%s)', tostring(name), stateStr, k))
  if not silent then
    local msgKey = self._ZoneActive[k][name] and 'zone_activated' or 'zone_deactivated'
    _eventSend(self, nil, self.Side, msgKey, { kind = k, zone = name })
  end
end

function CTLD:DrawZonesOnMap()
  local md = self.Config and self.Config.MapDraw or {}
  if not md.Enabled then return end
  -- Clear previous drawings before re-drawing
  self:ClearMapDrawings()
  local opts = {
    OutlineColor = md.OutlineColor,
    LineType = md.LineType,
    FontSize = md.FontSize,
    ReadOnly = (md.ReadOnly ~= false),
    LabelPrefix = md.LabelPrefix or 'Zone',
    LabelOffsetX = md.LabelOffsetX,
    LabelOffsetFromEdge = md.LabelOffsetFromEdge,
    LabelOffsetRatio = md.LabelOffsetRatio,
    ForAll = (md.ForAll == true),
  }
  if md.DrawPickupZones then
    for _,mz in ipairs(self.PickupZones or {}) do
      local name = mz:GetName()
      if self._ZoneActive.Pickup[name] ~= false then
      opts.LabelPrefix = (md.LabelPrefixes and md.LabelPrefixes.Pickup) or md.LabelPrefix or 'Pickup Zone'
      opts.LineType = (md.LineTypes and md.LineTypes.Pickup) or md.LineType or 1
  opts.FillColor = (md.FillColors and md.FillColors.Pickup) or nil
      self:_drawZoneCircleAndLabel('Pickup', mz, opts)
      end
    end
  end
  if md.DrawDropZones then
    for _,mz in ipairs(self.DropZones or {}) do
      local name = mz:GetName()
      if self._ZoneActive.Drop[name] ~= false then
      opts.LabelPrefix = (md.LabelPrefixes and md.LabelPrefixes.Drop) or 'Drop Zone'
      opts.LineType = (md.LineTypes and md.LineTypes.Drop) or md.LineType or 1
  opts.FillColor = (md.FillColors and md.FillColors.Drop) or nil
      self:_drawZoneCircleAndLabel('Drop', mz, opts)
      end
    end
  end
  if md.DrawFOBZones then
    for _,mz in ipairs(self.FOBZones or {}) do
      local name = mz:GetName()
      if self._ZoneActive.FOB[name] ~= false then
      opts.LabelPrefix = (md.LabelPrefixes and md.LabelPrefixes.FOB) or 'FOB Zone'
      opts.LineType = (md.LineTypes and md.LineTypes.FOB) or md.LineType or 1
  opts.FillColor = (md.FillColors and md.FillColors.FOB) or nil
      self:_drawZoneCircleAndLabel('FOB', mz, opts)
      end
    end
  end
  if md.DrawMASHZones then
    for _,mz in ipairs(self.MASHZones or {}) do
      local name = mz:GetName()
      if self._ZoneActive.MASH[name] ~= false then
      opts.LabelPrefix = (md.LabelPrefixes and md.LabelPrefixes.MASH) or 'MASH'
      opts.LineType = (md.LineTypes and md.LineTypes.MASH) or md.LineType or 1
  opts.FillColor = (md.FillColors and md.FillColors.MASH) or nil
      self:_drawZoneCircleAndLabel('MASH', mz, opts)
      end
    end
    if CTLD._mashZones then
      for mashId, data in pairs(CTLD._mashZones) do
        if data and data.side == self.Side and data.isMobile then
          local zoneName = data.displayName or mashId
          if self._ZoneActive.MASH[zoneName] ~= false then
      opts.LabelPrefix = (md.LabelPrefixes and md.LabelPrefixes.MASH) or 'MASH'
      opts.LineType = (md.LineTypes and md.LineTypes.MASH) or md.LineType or 1
  opts.FillColor = (md.FillColors and md.FillColors.MASH) or nil
            local zoneObj = data.zone
            if not (zoneObj and zoneObj.GetPointVec3 and zoneObj.GetRadius) then
              local pos = data.position or { x = 0, z = 0 }
              if ZONE_RADIUS and VECTOR2 then
                local v2 = (VECTOR2 and VECTOR2.New) and VECTOR2:New(pos.x, pos.z) or { x = pos.x, y = pos.z }
                zoneObj = ZONE_RADIUS:New(zoneName, v2, data.radius or 500)
              else
                -- Create zone that references data.position directly for live updates
                zoneObj = {}
                function zoneObj:GetName()
                  return zoneName
                end
                function zoneObj:GetPointVec3()
                  local currentPos = data.position or { x = 0, z = 0 }
                  return { x = currentPos.x, y = 0, z = currentPos.z }
                end
                function zoneObj:GetRadius()
                  return data.radius or 500
                end
              end
              data.zone = zoneObj
            end
            if zoneObj then
              self:_drawZoneCircleAndLabel('MASH', zoneObj, opts)
            end
          end
        end
      end
    end
  end
  if md.DrawSalvageZones then
    for _,mz in ipairs(self.SalvageDropZones or {}) do
      local name = mz:GetName()
      if self._ZoneActive.SalvageDrop[name] ~= false then
        opts.LabelPrefix = (md.LabelPrefixes and md.LabelPrefixes.SalvageDrop) or 'Salvage Zone'
        opts.LineType = (md.LineTypes and md.LineTypes.SalvageDrop) or md.LineType or 1
        opts.FillColor = (md.FillColors and md.FillColors.SalvageDrop) or self.Config.SlingLoadSalvage.ZoneColors.fill
        self:_drawZoneCircleAndLabel('SalvageDrop', mz, opts)
      end
    end
  end
end

-- Unit preference detection and unit-aware formatting
local function _getPlayerIsMetric(unit)
  local ok, isMetric = pcall(function()
    local pname = unit and unit.GetPlayerName and unit:GetPlayerName() or nil
    if pname and CTLD and CTLD._playerUnitPrefs then
      local pref = CTLD._playerUnitPrefs[pname]
      if pref == 'metric' then return true end
      if pref == 'imperial' then return false end
    end
    if pname and type(SETTINGS) == 'table' and SETTINGS.Set then
      local ps = SETTINGS:Set(pname)
      if ps and ps.IsMetric then return ps:IsMetric() end
    end
    if _SETTINGS and _SETTINGS.IsMetric then return _SETTINGS:IsMetric() end
    return true
  end)
  return (ok and isMetric) and true or false
end

function CTLD:_SetGroupUnitPreference(group, mode)
  if not group or not group:IsAlive() then return end
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then
    _msgGroup(group, 'No active player unit to bind preference.')
    return
  end
  local pname = unit.GetPlayerName and unit:GetPlayerName() or nil
  if not pname or pname == '' then
    _msgGroup(group, 'Unit preference requires a player-controlled slot.')
    return
  end
  if mode ~= 'metric' and mode ~= 'imperial' and mode ~= nil then
    _msgGroup(group, 'Invalid units selection requested.')
    return
  end
  self._playerUnitPrefs = self._playerUnitPrefs or {}
  if mode then
    self._playerUnitPrefs[pname] = mode
  else
    self._playerUnitPrefs[pname] = nil
  end
  local label
  if mode == 'metric' then
    label = 'metric (meters)'
  elseif mode == 'imperial' then
    label = 'imperial (nautical miles / feet)'
  else
    label = 'mission default'
  end
  _msgGroup(group, string.format('CTLD units preference set to %s for %s.', label, pname))
end

function CTLD:_ShowGroupUnitPreference(group)
  if not group or not group:IsAlive() then return end
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then
    _msgGroup(group, 'No active player unit to inspect preference.')
    return
  end
  local pname = unit.GetPlayerName and unit:GetPlayerName() or nil
  if not pname or pname == '' then
    _msgGroup(group, 'Unit preference requires a player-controlled slot.')
    return
  end
  local prefs = self._playerUnitPrefs or {}
  local explicit = prefs[pname]
  local effective = _getPlayerIsMetric(unit) and 'metric (meters)' or 'imperial (nautical miles / feet)'
  local source = explicit and 'CTLD preference' or 'mission default'
  if explicit == 'metric' then
    effective = 'metric (meters)'
  elseif explicit == 'imperial' then
    effective = 'imperial (nautical miles / feet)'
  end
  _msgGroup(group, string.format('%s units setting: %s (source: %s).', pname, effective, source))
end

local function _round(n, prec)
  local m = 10^(prec or 0)
  return math.floor(n * m + 0.5) / m
end

local function _fmtDistance(meters, isMetric)
  if isMetric then
    local v = math.max(0, _round(meters, 0))
    return v, 'm'
  else
    local ft = meters * 3.28084
    -- snap to 5 ft increments for readability
    ft = math.max(0, math.floor((ft + 2.5) / 5) * 5)
    return ft, 'ft'
  end
end

local function _fmtRange(meters, isMetric)
  meters = math.max(0, meters or 0)
  if isMetric then
    if meters >= 1000 then
      local km = meters / 1000
      local prec = (km >= 10) and 0 or 1
      return _round(km, prec), 'km'
    end
    return _round(meters, 0), 'm'
  else
    local nm = meters / 1852
    local prec = (nm >= 10) and 0 or 1
    return _round(nm, prec), 'NM'
  end
end

local function _fmtSpeed(mps, isMetric)
  if isMetric then
    return _round(mps, 1), 'm/s'
  else
    local fps = mps * 3.28084
    return math.max(0, math.floor(fps + 0.5)), 'ft/s'
  end
end

local function _fmtAGL(meters, isMetric)
  return _fmtDistance(meters, isMetric)
end

-- Coalition utility: return opposite side (BLUE<->RED); NEUTRAL returns RED by default
local function _enemySide(side)
  if coalition and coalition.side then
    if side == coalition.side.BLUE then return coalition.side.RED end
    if side == coalition.side.RED then return coalition.side.BLUE end
  end
  return coalition.side.RED
end

-- Find nearest enemy-held base within radius; returns {point=vec3, name=string, dist=meters}
function CTLD:_findNearestEnemyBase(point, radius)
  local enemy = _enemySide(self.Side)
  local ok, bases = pcall(function()
    if coalition and coalition.getAirbases then return coalition.getAirbases(enemy) end
    return {}
  end)
  if not ok or not bases then return nil end
  local best
  for _,ab in ipairs(bases) do
    local p = ab:getPoint()
    local dx = (p.x - point.x); local dz = (p.z - point.z)
    local d = math.sqrt(dx*dx + dz*dz)
    if d <= radius and ((not best) or d < best.dist) then
      best = { point = { x = p.x, z = p.z }, name = ab:getName() or 'Base', dist = d }
    end
  end
  return best
end

-- Find nearest enemy ground group centroid within radius; returns {point=vec3, group=GROUP|nil, dcsGroupName=string, dist=meters, type=string}
function CTLD:_findNearestEnemyGround(point, radius)
  local enemy = _enemySide(self.Side)
  local best
  -- Use MOOSE SET_GROUP to enumerate enemy ground groups
  local set = SET_GROUP:New():FilterCoalitions(enemy):FilterCategories(Group.Category.GROUND):FilterActive(true):FilterStart()
  set:ForEachGroup(function(g)
    local alive = g:IsAlive()
    if alive then
      local c = g:GetCoordinate()
      if c then
        local v3 = c:GetVec3()
        local dx = (v3.x - point.x); local dz = (v3.z - point.z)
        local d = math.sqrt(dx*dx + dz*dz)
        if d <= radius and ((not best) or d < best.dist) then
          -- Try to infer a type label from first unit
          local ut = 'unit'
          local u1 = g:GetUnit(1)
          if u1 then ut = _getUnitType(u1) or ut end
          best = { point = { x = v3.x, z = v3.z }, group = g, dcsGroupName = g:GetName(), dist = d, type = ut }
        end
      end
    end
  end)
  return best
end

-- Order a ground group by name to move toward target point at a given speed (km/h). Uses MOOSE route when available.
function CTLD:_orderGroundGroupToPointByName(groupName, targetPoint, speedKmh)
  if not groupName or not targetPoint then return end
  -- Pure-MOOSE movement: schedule a small delay so the dynamic group has
  -- time to be fully registered in the MOOSE database before we attempt
  -- to route it. DCS AI will handle targeting when enemies come into LOS;
  -- we only care about advancing toward the chosen objective area.

  local delay = 2 -- seconds
  local dest = { x = targetPoint.x, z = targetPoint.z }
  timer.scheduleFunction(function()
    local mg
    local ok = pcall(function() mg = GROUP:FindByName(groupName) end)
    if not (ok and mg and mg:IsAlive()) then 
      _logError(string.format("ATTACK AI: Failed to find group '%s' for routing", groupName or 'nil'))
      return 
    end

    _logDebug(string.format("ATTACK AI: Routing group '%s' to target (%.1f, %.1f) at %d km/h", 
      groupName, dest.x, dest.z, speedKmh or 25))

    local vec2
    if VECTOR2 and VECTOR2.New then
      vec2 = VECTOR2:New(dest.x, dest.z)
    else
      vec2 = { x = dest.x, y = dest.z }
    end

    local success = pcall(function()
      -- Set ROE to allow engaging targets
      if mg.OptionROEOpenFire then
        mg:OptionROEOpenFire()
        _logDebug(string.format("ATTACK AI: Set ROE OpenFire for '%s'", groupName))
      end
      -- Set alarm state to Auto (alert and ready)
      if mg.OptionAlarmStateAuto then
        mg:OptionAlarmStateAuto()
        _logDebug(string.format("ATTACK AI: Set AlarmState Auto for '%s'", groupName))
      end
      
      -- Create a temporary zone at the target point for TaskRouteToZone
      -- This is the proven method used by DynamicGroundBattle plugin
      local targetCoord = COORDINATE:New(dest.x, 0, dest.z)
      local tempZone = ZONE_RADIUS:New("CTLD_TEMP_TARGET_" .. groupName, targetCoord:GetVec2(), 100)
      
      -- Use TaskRouteToZone with randomization (same as working DGB plugin)
      mg:TaskRouteToZone(tempZone, true)
      _logDebug(string.format("ATTACK AI: TaskRouteToZone issued for '%s' to (%.1f, %.1f)", groupName, dest.x, dest.z))
    end)
    
    if not success then
      _logError(string.format("ATTACK AI: Failed to issue route commands for group '%s'", groupName))
    end
  end, {}, timer.getTime() + delay)
end

-- Assign attack behavior to a newly spawned ground group by name
function CTLD:_assignAttackBehavior(groupName, originPoint, isVehicle)
  if not (self.Config.AttackAI and self.Config.AttackAI.Enabled) then 
    _logDebug(string.format("ATTACK AI: Disabled or not configured for group '%s'", groupName or 'nil'))
    return 
  end
  
  _logDebug(string.format("ATTACK AI: Assigning attack behavior to group '%s' (%s)", 
    groupName or 'nil', isVehicle and 'vehicle' or 'troops'))
  
  local radius = isVehicle and (self.Config.AttackAI.VehicleSearchRadius or 5000) or (self.Config.AttackAI.TroopSearchRadius or 3000)
  local prioBase = (self.Config.AttackAI.PrioritizeEnemyBases ~= false)
  local speed = isVehicle and (self.Config.AttackAI.VehicleAdvanceSpeedKmh or 35) or (self.Config.AttackAI.TroopAdvanceSpeedKmh or 20)
  local player = 'Player'
  
  _logDebug(string.format("ATTACK AI: Search radius=%.0fm, prioritizeBase=%s, speed=%d km/h", 
    radius, tostring(prioBase), speed))
  
  -- Try to infer last requesting player from crate/troop context is complex; caller should pass announcements separately when needed.
  -- Target selection
  -- SmartTargeting: always use omniscient nearest-target logic within radius, ignoring LOS.
  -- We still optionally prioritize bases, but we no longer allow LOS/detection quirks to
  -- prevent movement when enemies truly exist in the search area.
  local target
  local pickedBase

  local smart = (self.Config.AttackAI and self.Config.AttackAI.SmartTargeting ~= false)

  if prioBase then
    local base = self:_findNearestEnemyBase(originPoint, radius)
    if base then
      target = { point = base.point, name = base.name, kind = 'base', dist = base.dist }
      pickedBase = base
      _logDebug(string.format("ATTACK AI: Found enemy base '%s' at %.0fm", base.name, base.dist))
    end
  end

  if not target then
    -- Primary omniscient search: nearest enemy ground group within radius.
    local eg = self:_findNearestEnemyGround(originPoint, radius)
    if eg then
      target = { point = eg.point, name = eg.dcsGroupName, kind = 'enemy', dist = eg.dist, etype = eg.type }
      _logDebug(string.format("ATTACK AI: Found enemy ground '%s' (%s) at %.0fm", eg.dcsGroupName, eg.type or 'unknown', eg.dist))
    end
  end
  
  if not target then
    _logDebug(string.format("ATTACK AI: No targets found within %.0fm for group '%s'", radius, groupName))
  end

  -- If SmartTargeting is disabled, simply honor the first hit (base or ground) and allow
  -- the caller to fall back to defend when target is nil.
  -- When SmartTargeting is enabled (default), we *only* fall back to defend when there are
  -- truly no valid enemy bases or ground groups inside the configured radius.
  -- (The actual omniscient search is already implemented in _findNearestEnemyBase/_findNearestEnemyGround.)
  -- Order movement if we have a target
  if target then
    self:_orderGroundGroupToPointByName(groupName, target.point, speed)
  end
  return target -- caller will handle announcement
end

local function _bearingDeg(from, to)
  local dx = (to.x - from.x)
  local dz = (to.z - from.z)
  -- Use math.atan2 for LuaJIT/Lua 5.1 (DCS environment), fallback to math.atan for Lua 5.4+
  local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
  local ang = atan2(dx, dz) * (180 / math.pi) -- 0=N, +CW
  if ang < 0 then ang = ang + 360 end
  return math.floor(ang + 0.5)
end

-- Normalize MOOSE/DCS heading to both radians and degrees consistently.
-- Some environments may yield degrees; others radians. This returns (rad, deg).
local function _headingRadDeg(unit)
  local h = (unit and unit.GetHeading and unit:GetHeading()) or 0
  local hrad, hdeg
  if h and h > (2*math.pi + 0.1) then
    -- Looks like degrees
    hdeg = h % 360
    hrad = math.rad(hdeg)
  else
    -- Radians (normalize into [0, 2pi))
    hrad = (h or 0) % (2*math.pi)
    hdeg = math.deg(hrad)
  end
  return hrad, hdeg
end

local function _projectToBodyFrame(dx, dz, hdg)
  -- world (east=X=dx, north=Z=dz) to body frame (fwd/right)
  local fwd = dx * math.sin(hdg) + dz * math.cos(hdg)
  local right = dx * math.cos(hdg) - dz * math.sin(hdg)
  return right, fwd
end

local function _playerNameFromGroup(group)
  if not group then return 'Player' end
  local unit = group:GetUnit(1)
  local pname = unit and unit.GetPlayerName and unit:GetPlayerName()
  if pname and pname ~= '' then return pname end
  return group:GetName() or 'Player'
end

local function _coachSend(self, group, unitName, key, data, isCoach)
  local cfg = CTLD.HoverCoachConfig or {}
  if cfg.enabled and (not self.HoverSched) then
    if self._startHoverScheduler then
      self:_startHoverScheduler()
    end
  end
  local now = timer.getTime()
  CTLD._coachState[unitName] = CTLD._coachState[unitName] or { lastKeyTimes = {} }
  local st = CTLD._coachState[unitName]
  local last = st.lastKeyTimes[key] or 0
  local minGap = isCoach and ((cfg.throttle and cfg.throttle.coachUpdate) or 1.5) or ((cfg.throttle and cfg.throttle.generic) or 3.0)
  local repeatGap = (cfg.throttle and cfg.throttle.repeatSame) or (minGap * 2)
  if last > 0 and (now - last) < minGap then return end
  -- prevent repeat spam of identical key too fast (only after first send)
  if last > 0 and (now - last) < repeatGap then return end
  local tpl = CTLD.Messages and CTLD.Messages[key]
  if not tpl then return end
  local text = _fmtTemplate(tpl, data)
  if text and text ~= '' then
    _msgGroup(group, text)
    st.lastKeyTimes[key] = now
  end
end

local _groundLoadFallbacks = {
  Start = "Ground crew on it—{count} crate(s) ready in {seconds}s.",
  Progress = "Loading steady—{remaining}s to go.",
  Complete = "Ground load complete—{count} crate(s) secure.",
}

local function _prepareGroundLoadMessage(self, category, data)
  data = data or {}
  local comms = self.GroundLoadComms or {}
  local pool = comms and comms[category]
  local tpl
  if pool and #pool > 0 then
    tpl = pool[math.random(#pool)]
  else
    tpl = _groundLoadFallbacks[category]
  end
  data.ground_line = _fmtTemplate(tpl or '', data)
  return data
end

local function _eventSend(self, group, side, key, data)
  local now = timer.getTime()
  local scopeKey
  if group then scopeKey = 'GRP:'..group:GetName() else scopeKey = 'COAL:'..tostring(side or self.Side) end
  CTLD._msgState[scopeKey] = CTLD._msgState[scopeKey] or { lastKeyTimes = {} }
  local st = CTLD._msgState[scopeKey]
  local last = st.lastKeyTimes[key] or 0
  local cfg = CTLD.HoverCoachConfig
  local minGap = (cfg and cfg.throttle and cfg.throttle.generic) or 3.0
  local repeatGap = (cfg and cfg.throttle and cfg.throttle.repeatSame) or (minGap * 2)
  if last > 0 and (now - last) < minGap then return end
  if last > 0 and (now - last) < repeatGap then return end
  local tpl = CTLD.Messages and CTLD.Messages[key]
  if not tpl then return end
  local text = _fmtTemplate(tpl, data)
  if not text or text == '' then return end
  if group then _msgGroup(group, text) else _msgCoalition(side or self.Side, text) end
  st.lastKeyTimes[key] = now
end

-- Format helpers for menu labels and recipe info
function CTLD:_recipeTotalCrates(def)
  if not def then return 1 end
  if type(def.requires) == 'table' then
    local n = 0
    for _,qty in pairs(def.requires) do n = n + (qty or 0) end
    return math.max(1, n)
  end
  return math.max(1, def.required or 1)
end

function CTLD:_friendlyNameForKey(key)
  local d = self.Config and self.Config.CrateCatalog and self.Config.CrateCatalog[key]
  if not d then return tostring(key) end
  return (d.menu or d.description or key)
end

function CTLD:_formatMenuLabelWithCrates(key, def)
  local base = (def and (def.menu or def.description)) or key
  local total = self:_recipeTotalCrates(def)
  local suffix = (total == 1) and '1 crate' or (tostring(total)..' crates')
  -- Optionally append stock for UX; uses nearest pickup zone dynamically
  if self.Config.Inventory and self.Config.Inventory.ShowStockInMenu then
    local group = nil
    -- Try to find any active group menu owner to infer nearest zone; if none, skip hint
    for gname,_ in pairs(self.MenusByGroup or {}) do group = GROUP:FindByName(gname); if group then break end end
    if group and group:IsAlive() then
      local unit = group:GetUnit(1)
      if unit and unit:IsAlive() then
        local zone, dist = _nearestZonePoint(unit, self.Config.Zones and self.Config.Zones.PickupZones or {})
        if zone and dist and dist <= (self.Config.PickupZoneMaxDistance or 10000) then
          local zname = zone:GetName()
          -- For composite recipes, show bundle availability based on component stock; otherwise show per-key stock
          if def and type(def.requires) == 'table' then
            local stockTbl = CTLD._stockByZone[zname] or {}
            local bundles = math.huge
            for reqKey, qty in pairs(def.requires) do
              local have = tonumber(stockTbl[reqKey] or 0) or 0
              local need = tonumber(qty or 0) or 0
              if need > 0 then bundles = math.min(bundles, math.floor(have / need)) end
            end
            if bundles == math.huge then bundles = 0 end
            return string.format('%s (%s) [%s: %d bundle%s]', base, suffix, zname, bundles, (bundles==1 and '' or 's'))
          else
            local stock = (CTLD._stockByZone[zname] and CTLD._stockByZone[zname][key]) or 0
            return string.format('%s (%s) [%s: %d]', base, suffix, zname, stock)
          end
        end
      end
    end
  end
  return string.format('%s (%s)', base, suffix)
end

function CTLD:_formatRecipeInfo(key, def)
  local lines = {}
  local title = self:_friendlyNameForKey(key)
  table.insert(lines, string.format('%s', title))
  if def and def.isFOB then table.insert(lines, '(FOB recipe)') end
  if def and type(def.requires) == 'table' then
    local total = self:_recipeTotalCrates(def)
    table.insert(lines, string.format('Requires: %d crate(s) total', total))
    table.insert(lines, 'Breakdown:')
    -- stable order
    local items = {}
    for k,qty in pairs(def.requires) do table.insert(items, {k=k, q=qty}) end
    table.sort(items, function(a,b) return tostring(a.k) < tostring(b.k) end)
    for _,it in ipairs(items) do
      local fname = self:_friendlyNameForKey(it.k)
      table.insert(lines, string.format('- %dx %s', it.q or 1, fname))
    end
  else
    local n = self:_recipeTotalCrates(def)
    table.insert(lines, string.format('Requires: %d crate(s)', n))
  end
  if def and def.dcsCargoType then
    table.insert(lines, string.format('Cargo type: %s', tostring(def.dcsCargoType)))
  end
  return table.concat(lines, '\n')
end

-- Determine an approximate radius for a ZONE. Tries MOOSE radius, then trigger zone radius, then configured radius.
function CTLD:_getZoneRadius(zone)
  if zone and zone.Radius then return zone.Radius end
  local name = zone and zone.GetName and zone:GetName() or nil
  if name and trigger and trigger.misc and trigger.misc.getZone then
    local z = trigger.misc.getZone(name)
    if z and z.radius then return z.radius end
  end
  if name and self._ZoneDefs and self._ZoneDefs.FOBZones and self._ZoneDefs.FOBZones[name] then
    local d = self._ZoneDefs.FOBZones[name]
    if d and d.radius then return d.radius end
  end
  return 150
end

-- Check if a 2D point (x,z) lies within any FOB zone; returns (bool, zone)
function CTLD:IsPointInFOBZones(point)
  for _,z in ipairs(self.FOBZones or {}) do
    local pz = z:GetPointVec3()
    local r = self:_getZoneRadius(z)
    local dx = (pz.x - point.x)
    local dz = (pz.z - point.z)
    if (dx*dx + dz*dz) <= (r*r) then return true, z end
  end
  return false, nil
end

--#endregion Utilities

-- =========================
-- Construction
-- =========================
--#region Construction
function CTLD:New(cfg)
  local o = setmetatable({}, self)
  o.Config = DeepCopy(CTLD.Config)
  if cfg then o.Config = DeepMerge(o.Config, cfg) end
  
  -- Debug: check if MASH zones survived the merge
  _logDebug('After config merge:')
  _logDebug('  o.Config.Zones exists: '..tostring(o.Config.Zones ~= nil))
  if o.Config.Zones then
    _logDebug('  o.Config.Zones.MASHZones exists: '..tostring(o.Config.Zones.MASHZones ~= nil))
    if o.Config.Zones.MASHZones then
      _logDebug('  o.Config.Zones.MASHZones count: '..tostring(#o.Config.Zones.MASHZones))
    end
  end
  
  o.Side = o.Config.CoalitionSide
  o.CountryId = o.Config.CountryId or _defaultCountryForSide(o.Side)
  o.Config.CountryId = o.CountryId
  o.MenuRoots = {}
  o.MenusByGroup = {}
  o._DynamicSalvageZones = {}
  o._DynamicSalvageQueue = {}
  o._jtacRegistry = {}

  -- Ground auto-load state tracking
  CTLD._groundLoadState = CTLD._groundLoadState or {}
  CTLD._groundLoadTimers = CTLD._groundLoadTimers or {}

  -- If caller disabled builtin catalog, clear it before merging any globals
  if o.Config.UseBuiltinCatalog == false then
    o.Config.CrateCatalog = {}
  end

  -- If a global catalog was loaded earlier (via DO SCRIPT FILE), merge it automatically
  -- Supported globals: _CTLD_EXTRACTED_CATALOG (our extractor), CTLD_CATALOG, MOOSE_CTLD_CATALOG
  do
    local globalsToCheck = { '_CTLD_EXTRACTED_CATALOG', 'CTLD_CATALOG', 'MOOSE_CTLD_CATALOG' }
    for _,gn in ipairs(globalsToCheck) do
      local t = rawget(_G, gn)
      if type(t) == 'table' then
        o:MergeCatalog(t)
        _logInfo('Merged crate catalog from global '..gn)
      end
    end
  end
  
  -- Load troop types from catalog if available
  do
    local troopTypes = rawget(_G, '_CTLD_TROOP_TYPES')
    if type(troopTypes) == 'table' and next(troopTypes) then
      o.Config.Troops.TroopTypes = troopTypes
      _logInfo('Loaded troop types from _CTLD_TROOP_TYPES')
    else
      -- Fallback: catalog not loaded, warn user and provide minimal defaults
      _logError('WARNING: _CTLD_TROOP_TYPES not found. Catalog may not be loaded. Using minimal troop fallbacks.')
      _logError('Please ensure catalog file is loaded via DO SCRIPT FILE *before* creating CTLD instances.')
      -- Minimal fallback troop types to prevent spawning wrong units
      o.Config.Troops.TroopTypes = {
        AS = { label = 'Assault Squad', size = 8, unitsBlue = { 'Soldier M4' }, unitsRed = { 'Infantry AK' }, units = { 'Infantry AK' } },
        AA = { label = 'MANPADS Team', size = 4, unitsBlue = { 'Soldier stinger' }, unitsRed = { 'SA-18 Igla-S manpad' }, units = { 'Infantry AK' } },
        AT = { label = 'AT Team', size = 4, unitsBlue = { 'Soldier M136' }, unitsRed = { 'Soldier RPG' }, units = { 'Infantry AK' } },
        AR = { label = 'Mortar Team', size = 4, unitsBlue = { '2B11 mortar' }, unitsRed = { '2B11 mortar' }, units = { '2B11 mortar' } },
      }
    end
  end
  
  -- Run unit type validation after catalogs/troop types load so issues surface early
  o:_validateCatalogUnitTypes()
  
  o:InitZones()
  -- Validate configured zones and warn if missing
  o:ValidateZones()
  -- Optional: draw configured zones on the F10 map
  if o.Config.MapDraw and o.Config.MapDraw.Enabled then
    -- Defer a tiny bit to ensure mission environment is fully up
    timer.scheduleFunction(function()
      pcall(function() o:DrawZonesOnMap() end)
    end, {}, timer.getTime() + 1)
  end
  -- Optional: bind zone activation to mission flags (merge from config table and per-zone flag fields)
  do
    local merged = {}
    -- Collect from explicit bindings (backward compatible)
    if o.Config.ZoneEventBindings then
      for _,b in ipairs(o.Config.ZoneEventBindings) do table.insert(merged, b) end
    end
    -- Collect from per-zone entries (preferred)
    local function pushFromZones(kind, list)
      for _,z in ipairs(list or {}) do
        if z and z.name and z.flag then
          table.insert(merged, { kind = kind, name = z.name, flag = z.flag, activeWhen = z.activeWhen or 1 })
        end
      end
    end
    pushFromZones('Pickup', o.Config.Zones and o.Config.Zones.PickupZones)
    pushFromZones('Drop',   o.Config.Zones and o.Config.Zones.DropZones)
    pushFromZones('FOB',    o.Config.Zones and o.Config.Zones.FOBZones)
    pushFromZones('MASH',   o.Config.Zones and o.Config.Zones.MASHZones)
    pushFromZones('SalvageDrop', o.Config.Zones and o.Config.Zones.SalvageDropZones)

    o._BindingsMerged = merged
    if o._BindingsMerged and #o._BindingsMerged > 0 then
      o._ZoneFlagState = {}
      o._ZoneFlagsPrimed = false
      o.ZoneFlagSched = SCHEDULER:New(nil, function()
        local ok, err = pcall(function()
          if not o._ZoneFlagsPrimed then
            -- Prime states on first run without spamming messages
            for _,b in ipairs(o._BindingsMerged) do
              if b and b.flag and b.kind and b.name then
                local val = (trigger and trigger.misc and trigger.misc.getUserFlag) and trigger.misc.getUserFlag(b.flag) or 0
                local activeWhen = (b.activeWhen ~= nil) and b.activeWhen or 1
                local shouldBeActive = (val == activeWhen)
                local key = tostring(b.kind)..'|'..tostring(b.name)
                o._ZoneFlagState[key] = shouldBeActive
                o:SetZoneActive(b.kind, b.name, shouldBeActive, true)
              end
            end
            o._ZoneFlagsPrimed = true
            return
          end
          -- Subsequent runs: announce changes
          for _,b in ipairs(o._BindingsMerged) do
            if b and b.flag and b.kind and b.name then
              local val = (trigger and trigger.misc and trigger.misc.getUserFlag) and trigger.misc.getUserFlag(b.flag) or 0
              local activeWhen = (b.activeWhen ~= nil) and b.activeWhen or 1
              local shouldBeActive = (val == activeWhen)
              local key = tostring(b.kind)..'|'..tostring(b.name)
              if o._ZoneFlagState[key] ~= shouldBeActive then
                o._ZoneFlagState[key] = shouldBeActive
                o:SetZoneActive(b.kind, b.name, shouldBeActive, false)
              end
            end
          end
        end)
        if not ok then _logError('ZoneFlagSched error: '..tostring(err)) end
      end, {}, 1, 1)
    end
  end
  o:InitMenus()

  -- Initialize inventory for configured pickup zones (seed from catalog initialStock)
  if o.Config.Inventory and o.Config.Inventory.Enabled then
    pcall(function() o:InitInventory() end)
  end
  
  -- Initialize MEDEVAC system
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled then
    pcall(function() o:InitMEDEVAC() end)
  end
  
  -- Initialize FARP system
  if CTLD.FARPConfig and CTLD.FARPConfig.Enabled then
    pcall(function() o:InitFARP() end)
  end
  
  -- Initialize manual salvage crates (scan mission editor for pre-placed cargo)
  if o.Config.SlingLoadSalvage and o.Config.SlingLoadSalvage.Enabled and o.Config.SlingLoadSalvage.EnableManualCrates then
    pcall(function() o:ScanAndRegisterManualSalvageCrates() end)
  end

  -- Periodic cleanup for crates
  o.Sched = SCHEDULER:New(nil, function()
    local ok, err = pcall(function() o:CleanupCrates() end)
    if not ok then _logError('CleanupCrates scheduler error: '..tostring(err)) end
    collectgarbage('step', 200)  -- GC after cleanup
  end, {}, 60, 60)

  -- Periodic cleanup for deployed troops (remove dead/missing groups)
  o.TroopCleanupSched = SCHEDULER:New(nil, function()
    local ok, err = pcall(function() o:CleanupDeployedTroops() end)
    if not ok then _logError('CleanupDeployedTroops scheduler error: '..tostring(err)) end
    collectgarbage('step', 200)  -- GC after cleanup
  end, {}, 30, 30)

  -- Periodic comprehensive state maintenance (prune orphaned entries)
  o.StateMaintSched = SCHEDULER:New(nil, function()
    local ok, err = pcall(function() o:PruneOrphanedState() end)
    if not ok then _logError('PruneOrphanedState scheduler error: '..tostring(err)) end
    collectgarbage('step', 300)  -- GC after state pruning
  end, {}, 120, 120)  -- Run every 2 minutes

  -- Optional: auto-build FOBs inside FOB zones when crates present
  if o.Config.AutoBuildFOBInZones then
    o.AutoFOBSched = SCHEDULER:New(nil, function()
      local ok, err = pcall(function() o:AutoBuildFOBCheck() end)
      if not ok then _logError('AutoBuildFOBCheck scheduler error: '..tostring(err)) end
    end, {}, 10, 10) -- check every 10 seconds (tunable)
  end

  -- Optional: hover pickup scanner
  local coachCfg = CTLD.HoverCoachConfig or {}
  if coachCfg.enabled then
    o.HoverSched = nil
    o:_startHoverScheduler()
  end

  -- Optional: ground auto-load scanner
  local groundCfg = CTLD.GroundAutoLoadConfig or {}
  if groundCfg.Enabled then
    o.GroundLoadSched = nil
    o:_startGroundLoadScheduler()
  end

  -- MEDEVAC auto-pickup and auto-unload scheduler
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled then
    local checkInterval = (CTLD.MEDEVAC.AutoPickup and CTLD.MEDEVAC.AutoPickup.CheckInterval) or 3
    o.MEDEVACSched = SCHEDULER:New(nil, function()
      local ok, err = pcall(function() o:ScanMEDEVACAutoActions() end)
      if not ok then _logError('MEDEVAC auto-actions scheduler error: '..tostring(err)) end
    end, {}, checkInterval, checkInterval)
  end

  if o.Config.JTAC and o.Config.JTAC.Enabled then
    local jtacInterval = 5
    if o.Config.JTAC.AutoLase then
      local refresh = tonumber(o.Config.JTAC.AutoLase.RefreshSeconds) or 15
      local idle = tonumber(o.Config.JTAC.AutoLase.IdleRescanSeconds) or 30
      jtacInterval = math.max(2, math.min(refresh, idle, 10))
    end
    o.JTACSched = SCHEDULER:New(nil, function()
      local ok, err = pcall(function() o:_tickJTACs() end)
      if not ok then _logError('JTAC tick scheduler error: '..tostring(err)) end
    end, {}, jtacInterval, jtacInterval)
    _logInfo(string.format('JTAC init: Enabled=TRUE AutoLase=%s SearchRadius=%s Refresh=%s IdleRescan=%s LockType=%s Verbose=%s Interval=%.1f',
      tostring(o.Config.JTAC.AutoLase and o.Config.JTAC.AutoLase.Enabled ~= false),
      tostring(o.Config.JTAC.AutoLase and o.Config.JTAC.AutoLase.SearchRadius),
      tostring(o.Config.JTAC.AutoLase and o.Config.JTAC.AutoLase.RefreshSeconds),
      tostring(o.Config.JTAC.AutoLase and o.Config.JTAC.AutoLase.IdleRescanSeconds),
      tostring(o.Config.JTAC.LockType),
      tostring(o.Config.JTAC.Verbose),
      jtacInterval))
  end

  table.insert(CTLD._instances, o)
  o:_ensureBackgroundTasks()
  local versionLabel = CTLD.Version or 'unknown'
  _msgCoalition(o.Side, string.format('CTLD %s initialized for coalition', versionLabel))
  return o
end

function CTLD:InitZones()
  self.PickupZones = {}
  self.DropZones = {}
  self.FOBZones = {}
  self.MASHZones = {}
  self.SalvageDropZones = {}
  self._ZoneDefs = { PickupZones = {}, DropZones = {}, FOBZones = {}, MASHZones = {}, SalvageDropZones = {} }
  self._ZoneActive = { Pickup = {}, Drop = {}, FOB = {}, MASH = {}, SalvageDrop = {} }
  for _,z in ipairs(self.Config.Zones.PickupZones or {}) do
    local mz = _findZone(z)
    if mz then
      table.insert(self.PickupZones, mz)
      local name = mz:GetName()
      self._ZoneDefs.PickupZones[name] = z
      if self._ZoneActive.Pickup[name] == nil then self._ZoneActive.Pickup[name] = (z.active ~= false) end
    end
  end
  for _,z in ipairs(self.Config.Zones.DropZones or {}) do
    local mz = _findZone(z)
    if mz then
      table.insert(self.DropZones, mz)
      local name = mz:GetName()
      self._ZoneDefs.DropZones[name] = z
      if self._ZoneActive.Drop[name] == nil then self._ZoneActive.Drop[name] = (z.active ~= false) end
    end
  end
  for _,z in ipairs(self.Config.Zones.FOBZones or {}) do
    local mz = _findZone(z)
    if mz then
      table.insert(self.FOBZones, mz)
      local name = mz:GetName()
      self._ZoneDefs.FOBZones[name] = z
      if self._ZoneActive.FOB[name] == nil then self._ZoneActive.FOB[name] = (z.active ~= false) end
    end
  end
  for _,z in ipairs(self.Config.Zones.MASHZones or {}) do
    local mz = _findZone(z)
    if mz then
      table.insert(self.MASHZones, mz)
      local name = mz:GetName()
      self._ZoneDefs.MASHZones[name] = z
      if self._ZoneActive.MASH[name] == nil then self._ZoneActive.MASH[name] = (z.active ~= false) end
    end
  end
  for _,z in ipairs(self.Config.Zones.SalvageDropZones or {}) do
    local mz = _findZone(z)
    if mz then
      table.insert(self.SalvageDropZones, mz)
      local name = mz:GetName()
      if z and z.side == nil then z.side = self.Side end
      self._ZoneDefs.SalvageDropZones[name] = z
      if self._ZoneActive.SalvageDrop[name] == nil then self._ZoneActive.SalvageDrop[name] = (z.active ~= false) end
    end
  end
end

-- Validate configured zone names exist in the mission; warn coalition if any are missing.
function CTLD:ValidateZones()
  local function zoneExistsByName(name)
    if not name or name == '' then return false end
    if trigger and trigger.misc and trigger.misc.getZone then
      local z = trigger.misc.getZone(name)
      if z then return true end
    end
    if ZONE and ZONE.FindByName then
      local mz = ZONE:FindByName(name)
      if mz then return true end
    end
    return false
  end

  local function sideToStr(s)
    if coalition and coalition.side then
      if s == coalition.side.BLUE then return 'BLUE' end
      if s == coalition.side.RED then return 'RED' end
      if s == coalition.side.NEUTRAL then return 'NEUTRAL' end
    end
    return tostring(s)
  end

  local function join(t)
    local s = ''
    for i,name in ipairs(t) do s = s .. (i>1 and ', ' or '') .. tostring(name) end
    return s
  end

  local missing = { Pickup = {}, Drop = {}, FOB = {}, MASH = {}, SalvageDrop = {} }
  local found =   { Pickup = {}, Drop = {}, FOB = {}, MASH = {}, SalvageDrop = {} }
  local coords =  { Pickup = 0, Drop = 0, FOB = 0, MASH = 0, SalvageDrop = 0 }

  for _,z in ipairs(self.Config.Zones.PickupZones or {}) do
    if z.name then
      if zoneExistsByName(z.name) then table.insert(found.Pickup, z.name) else table.insert(missing.Pickup, z.name) end
    elseif z.coord then
      coords.Pickup = coords.Pickup + 1
    end
  end
  for _,z in ipairs(self.Config.Zones.DropZones or {}) do
    if z.name then
      if zoneExistsByName(z.name) then table.insert(found.Drop, z.name) else table.insert(missing.Drop, z.name) end
    elseif z.coord then
      coords.Drop = coords.Drop + 1
    end
  end
  for _,z in ipairs(self.Config.Zones.FOBZones or {}) do
    if z.name then
      if zoneExistsByName(z.name) then table.insert(found.FOB, z.name) else table.insert(missing.FOB, z.name) end
    elseif z.coord then
      coords.FOB = coords.FOB + 1
    end
  end
  for _,z in ipairs(self.Config.Zones.MASHZones or {}) do
    if z.name then
      if zoneExistsByName(z.name) then table.insert(found.MASH, z.name) else table.insert(missing.MASH, z.name) end
    elseif z.coord then
      coords.MASH = coords.MASH + 1
    end
  end
  for _,z in ipairs(self.Config.Zones.SalvageDropZones or {}) do
    if z.name then
      if zoneExistsByName(z.name) then table.insert(found.SalvageDrop, z.name) else table.insert(missing.SalvageDrop, z.name) end
    elseif z.coord then
      coords.SalvageDrop = coords.SalvageDrop + 1
    end
  end

  -- Log a concise summary to dcs.log
  local sideStr = sideToStr(self.Side)
  _logVerbose(string.format('[ZoneValidation][%s] Pickup: configured=%d (named=%d, coord=%d) found=%d missing=%d',
    sideStr,
    #(self.Config.Zones.PickupZones or {}), #found.Pickup + #missing.Pickup, coords.Pickup, #found.Pickup, #missing.Pickup))
  _logVerbose(string.format('[ZoneValidation][%s] Drop  : configured=%d (named=%d, coord=%d) found=%d missing=%d',
    sideStr,
    #(self.Config.Zones.DropZones or {}),   #found.Drop + #missing.Drop,   coords.Drop,   #found.Drop,   #missing.Drop))
  _logVerbose(string.format('[ZoneValidation][%s] FOB   : configured=%d (named=%d, coord=%d) found=%d missing=%d',
    sideStr,
    #(self.Config.Zones.FOBZones or {}),    #found.FOB + #missing.FOB,     coords.FOB,    #found.FOB,    #missing.FOB))
  _logVerbose(string.format('[ZoneValidation][%s] MASH  : configured=%d (named=%d, coord=%d) found=%d missing=%d',
    sideStr,
    #(self.Config.Zones.MASHZones or {}),   #found.MASH + #missing.MASH,   coords.MASH,   #found.MASH,   #missing.MASH))
  _logVerbose(string.format('[ZoneValidation][%s] Salvage: configured=%d (named=%d, coord=%d) found=%d missing=%d',
    sideStr,
    #(self.Config.Zones.SalvageDropZones or {}), #found.SalvageDrop + #missing.SalvageDrop, coords.SalvageDrop, #found.SalvageDrop, #missing.SalvageDrop))

  local anyMissing = (#missing.Pickup > 0) or (#missing.Drop > 0) or (#missing.FOB > 0) or (#missing.MASH > 0) or (#missing.SalvageDrop > 0)
  if anyMissing then
    if #missing.Pickup > 0 then
      local msg = 'CTLD config warning: Missing Pickup Zones: '..join(missing.Pickup)
      _msgCoalition(self.Side, msg); _logError('[ZoneValidation]['..sideStr..'] '..msg)
    end
    if #missing.Drop > 0 then
      local msg = 'CTLD config warning: Missing Drop Zones: '..join(missing.Drop)
      _msgCoalition(self.Side, msg); _logError('[ZoneValidation]['..sideStr..'] '..msg)
    end
    if #missing.FOB > 0 then
      local msg = 'CTLD config warning: Missing FOB Zones: '..join(missing.FOB)
      _msgCoalition(self.Side, msg); _logError('[ZoneValidation]['..sideStr..'] '..msg)
    end
    if #missing.MASH > 0 then
      local msg = 'CTLD config warning: Missing MASH Zones: '..join(missing.MASH)
      _msgCoalition(self.Side, msg); _logError('[ZoneValidation]['..sideStr..'] '..msg)
    end
    if #missing.SalvageDrop > 0 then
      local msg = 'CTLD config warning: Missing Salvage Drop Zones: '..join(missing.SalvageDrop)
      _msgCoalition(self.Side, msg); _logError('[ZoneValidation]['..sideStr..'] '..msg)
    end
  else
    _logVerbose(string.format('[ZoneValidation][%s] All configured zone names resolved successfully.', sideStr))
  end

  self._MissingZones = missing
end
--#endregion Construction

-- =========================
-- Menus
-- =========================
--#region Menus
function CTLD:InitMenus()
  if self.Config.UseGroupMenus then
    -- Create placeholder menu at mission start to reserve F10 position if requested
    if self.Config.CreateMenuAtMissionStart then
      -- Create a coalition-level placeholder that will be replaced by per-group menus on birth
      self.PlaceholderMenu = MENU_COALITION:New(self.Side, self.Config.RootMenuName or 'CTLD')
      MENU_COALITION_COMMAND:New(self.Side, 'Spawn in an aircraft to see options', self.PlaceholderMenu, function()
        _msgCoalition(self.Side, 'CTLD menus will appear when you spawn in a transport aircraft.')
      end)
    end
    self:WireBirthHandler()
    -- No coalition-level root when using per-group menus; Admin/Help is nested under each group's CTLD menu
  else
    self.MenuRoot = MENU_COALITION:New(self.Side, self.Config.RootMenuName or 'CTLD')
    self:BuildCoalitionMenus(self.MenuRoot)
    self:InitCoalitionAdminMenu()
  end
end

function CTLD:WireBirthHandler()
  local handler = EVENTHANDLER:New()
  handler:HandleEvent(EVENTS.Birth)
  handler:HandleEvent(EVENTS.Dead)
  handler:HandleEvent(EVENTS.Crash)
  handler:HandleEvent(EVENTS.PilotDead)
  handler:HandleEvent(EVENTS.Ejection)
  handler:HandleEvent(EVENTS.PlayerLeaveUnit)
  local selfref = self

  local function hasTrackedState(gname)
    if not gname then return false end
    if selfref.MenusByGroup and selfref.MenusByGroup[gname] then return true end
    local tbls = {
      CTLD._inStockMenus,
      CTLD._loadedCrates,
      CTLD._troopsLoaded,
      CTLD._loadedTroopTypes,
      CTLD._deployedTroops,
      CTLD._buildConfirm,
      CTLD._buildCooldown,
      CTLD._coachOverride,
      CTLD._medevacUnloadStates,
      CTLD._medevacLoadStates,
      CTLD._medevacEnrouteStates,
    }
    for _, tbl in ipairs(tbls) do
      if tbl and tbl[gname] then return true end
    end
    if CTLD._msgState and CTLD._msgState['GRP:'..gname] then return true end
    return false
  end

  local function teardownIfGroupInactive(eventData, reason)
    if not eventData then return end
    local unit = eventData.IniUnit
    local group = eventData.IniGroup or (unit and unit.GetGroup and unit:GetGroup()) or nil
    if not group or not group.GetName then return end
    if group.GetCoalition and group:GetCoalition() ~= selfref.Side then return end
    local gname = group:GetName()
    if not gname or gname == '' then return end
    if not hasTrackedState(gname) then return end
    local allowed = selfref.Config and selfref.Config.AllowedAircraft or {}
    if _groupHasAliveTransport(group, allowed) then return end
    selfref:_cleanupTransportGroup(group, gname)
    if reason then
      _logDebug(string.format('[MenuCleanup] Group %s removed due to %s', gname, reason))
    end
  end

  local function scheduleDeferredCleanup(group)
    if not (group and group.GetName) then return end
    local gname = group:GetName()
    if not gname or gname == '' then return end
    if not hasTrackedState(gname) then return end
    if not (timer and timer.scheduleFunction) then return end
    timer.scheduleFunction(function(arg)
      local name = arg and arg.groupName or nil
      if not name then return nil end
      if not selfref then return nil end
      local grp = GROUP and GROUP:FindByName(name) or nil
      local allowed = selfref.Config and selfref.Config.AllowedAircraft or {}
      if grp and _groupHasAliveTransport(grp, allowed) then
        return nil
      end
      selfref:_cleanupTransportGroup(grp, name)
      _logDebug(string.format('[MenuCleanup] Group %s cleaned up after player left', name))
      return nil
    end, { groupName = gname }, timer.getTime() + 3)
  end

  function handler:OnEventBirth(eventData)
    local unit = eventData.IniUnit
    if not unit or not unit:IsAlive() then return end
    if unit:GetCoalition() ~= selfref.Side then return end
    local typ = _getUnitType(unit)
    if not _isIn(selfref.Config.AllowedAircraft, typ) then return end
    local grp = unit:GetGroup()
    if not grp then return end
    local gname = grp:GetName()
    if selfref.MenusByGroup[gname] then return end
    selfref.MenusByGroup[gname] = selfref:BuildGroupMenus(grp)
    _msgGroup(grp, 'CTLD menu available (F10)')
  end

  function handler:OnEventDead(eventData)
    teardownIfGroupInactive(eventData, 'Dead')
  end

  function handler:OnEventCrash(eventData)
    teardownIfGroupInactive(eventData, 'Crash')
  end

  function handler:OnEventPilotDead(eventData)
    teardownIfGroupInactive(eventData, 'PilotDead')
  end

  function handler:OnEventEjection(eventData)
    teardownIfGroupInactive(eventData, 'Ejection')
  end

  function handler:OnEventPlayerLeaveUnit(eventData)
    local unit = eventData and eventData.IniUnit
    if not unit then return end
    if unit.GetCoalition and unit:GetCoalition() ~= selfref.Side then return end
    local group = unit.GetGroup and unit:GetGroup() or nil
    if not group then return end
    scheduleDeferredCleanup(group)
  end

  self.BirthHandler = handler
end

function CTLD:BuildGroupMenus(group)
  local root = MENU_GROUP:New(group, self.Config.RootMenuName or 'CTLD')
  -- Safe menu command helper: wraps callbacks to prevent silent errors
  local function CMD(title, parent, cb)
    return MENU_GROUP_COMMAND:New(group, title, parent, function()
      local ok, err = pcall(cb)
      if not ok then
        _logError('Menu error: '..tostring(err))
        MESSAGE:New('CTLD menu error: '..tostring(err), 8):ToGroup(group)
      end
    end)
  end

  -- Initialize per-player coach preference from default
  local gname = group:GetName()
  CTLD._coachOverride = CTLD._coachOverride or {}
  if CTLD._coachOverride[gname] == nil then
    local coachCfg = CTLD.HoverCoachConfig or {}
    CTLD._coachOverride[gname] = coachCfg.coachOnByDefault
  end

  -- Top-level roots per requested structure
  local opsRoot   = MENU_GROUP:New(group, 'Operations', root)
  local logRoot   = MENU_GROUP:New(group, 'Logistics', root)
  local toolsRoot = MENU_GROUP:New(group, 'Field Tools', root)
  local navRoot   = MENU_GROUP:New(group, 'Navigation', root)
  local adminRoot = MENU_GROUP:New(group, 'Admin/Help', root)

  local prefsMenu = MENU_GROUP:New(group, 'Preferences', adminRoot)
  CMD('Use Metric Units', prefsMenu, function() self:_SetGroupUnitPreference(group, 'metric') end)
  CMD('Use Imperial Units', prefsMenu, function() self:_SetGroupUnitPreference(group, 'imperial') end)
  CMD('Use Mission Default Units', prefsMenu, function() self:_SetGroupUnitPreference(group, nil) end)
  CMD('Show My Units Setting', prefsMenu, function() self:_ShowGroupUnitPreference(group) end)

  -- Admin/Help -> Player Guides (moved to top of Admin/Help)
  local help = MENU_GROUP:New(group, 'Player Guides', adminRoot)
  MENU_GROUP_COMMAND:New(group, 'CTLD Basics (2-minute tour)', help, function()
    local lines = {}
    table.insert(lines, 'CTLD Basics - 2 minute tour')
    table.insert(lines, '')
    table.insert(lines, 'Loop: Request -> Deliver -> Build -> Fight')
    table.insert(lines, '- Request crates at an ACTIVE Supply Zone (Pickup).')
    table.insert(lines, '- Deliver crates to the build point (within Build Radius).')
    table.insert(lines, '- Build units or sites with "Build Here" (confirm + cooldown).')
    table.insert(lines, '- Optional: set Attack or Defend behavior when building.')
    table.insert(lines, '')
    table.insert(lines, 'Key concepts:')
    table.insert(lines, '- Zones: Pickup (supply), Drop (mission targets), FOB (forward supply).')
    table.insert(lines, '- Inventory: stock is tracked per zone; requests consume stock there.')
    table.insert(lines, '- FOBs: building one creates a local supply point with seeded stock.')
    table.insert(lines, '- Advanced: SAM site repair crates, AI attack orders, EWR/JTAC support.')
    MESSAGE:New(table.concat(lines, '\n'), 35):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'Zones - Guide', help, function()
    local lines = {}
    table.insert(lines, 'CTLD Zones - Guide')
    table.insert(lines, '')
    table.insert(lines, 'Zone types:')
    table.insert(lines, '- Pickup (Supply): Request crates and load troops here. Crate requests require proximity to an ACTIVE pickup zone (default within 10 km).')
    table.insert(lines, '- Drop: Mission-defined delivery or rally areas. Some missions may require delivery or deployment at these zones (see briefing).')
    table.insert(lines, '- FOB: Forward Operating Base areas. Some recipes (FOB Site) can be built here; if FOB restriction is enabled, FOB-only builds must be inside an FOB zone.')
    table.insert(lines, '')
    table.insert(lines, 'Colors and map marks:')
    table.insert(lines, '- Pickup zone crate spawns are marked with smoke in the configured color. Admin/Help -> Draw CTLD Zones on Map draws zone circles and labels on F10.')
    table.insert(lines, '- Use Admin/Help -> Clear CTLD Map Drawings to remove the drawings. Drawings are read-only if configured.')
    table.insert(lines, '')
    table.insert(lines, 'How to use zones:')
    table.insert(lines, '- To request crates: move within the pickup zone distance and use CTLD -> Request Crate.')
    table.insert(lines, '- To load troops: must be inside a Pickup zone if troop loading restriction is enabled.')
    table.insert(lines, '- Navigation: CTLD -> Coach & Nav -> Vectors to Nearest Pickup Zone gives bearing and range.')
    table.insert(lines, '- Activation: Zones can be active/inactive per mission logic; inactive pickup zones block crate requests.')
    table.insert(lines, '')
    table.insert(lines, string.format('Build Radius: about %d m to collect nearby crates when building.', self.Config.BuildRadius or 100))
    table.insert(lines, string.format('Pickup Zone Max Distance: about %d m to request crates.', self.Config.PickupZoneMaxDistance or 10000))
    MESSAGE:New(table.concat(lines, '\n'), 40):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'Inventory - How It Works', help, function()
    local inv = self.Config.Inventory or {}
    local enabled = inv.Enabled ~= false
    local showHint = inv.ShowStockInMenu == true
    local fobPct = math.floor(((inv.FOBStockFactor or 0.25) * 100) + 0.5)
    local lines = {}
    table.insert(lines, 'CTLD Inventory - How It Works')
    table.insert(lines, '')
    table.insert(lines, 'Overview:')
    table.insert(lines, '- Inventory is tracked per Supply (Pickup) Zone and per FOB. Requests consume stock at that location.')
    table.insert(lines, string.format('- Inventory is %s.', enabled and 'ENABLED' or 'DISABLED'))
    table.insert(lines, '')
    table.insert(lines, 'Starting stock:')
    table.insert(lines, '- Each configured Supply Zone is seeded from the catalog initialStock for every crate type at mission start.')
    table.insert(lines, string.format('- When you build a FOB, it creates a small Supply Zone with stock seeded at ~%d%% of initialStock.', fobPct))
    table.insert(lines, '')
    table.insert(lines, 'Requesting crates:')
    table.insert(lines, '- You must be within range of an ACTIVE Supply Zone to request crates; stock is decremented on spawn.')
    table.insert(lines, '- If out of stock for a type at that zone, requests are denied for that type until resupplied (mission logic).')
    table.insert(lines, '')
    table.insert(lines, 'UI hints:')
    table.insert(lines, string.format('- Show stock in menu labels: %s.', showHint and 'ON' or 'OFF'))
    table.insert(lines, '- Some missions may include an "In Stock Here" list showing only items available at the nearest zone.')
    MESSAGE:New(table.concat(lines, '\n'), 40):ToGroup(group)
  end)

  MENU_GROUP_COMMAND:New(group, 'Troop Transport & JTAC Use', help, function()
    local lines = {}
    table.insert(lines, 'Troop Transport & JTAC Use')
    table.insert(lines, '')
    table.insert(lines, 'Troops:')
    table.insert(lines, '- Load inside an ACTIVE Supply Zone (if mission enforces it).')
    table.insert(lines, '- Deploy with Defend (hold) or Attack (advance to targets/bases).')
    table.insert(lines, '- Attack uses a search radius and moves at configured speed.')
    table.insert(lines, '')
    table.insert(lines, 'JTAC:')
    table.insert(lines, '- Build JTAC units (MRAP/Tigr or drones) to support target marking.')
    table.insert(lines, '- JTAC helps with target designation/SA; details depend on mission setup.')
    MESSAGE:New(table.concat(lines, '\n'), 35):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'Crates 101: Requesting and Handling', help, function()
    local lines = {}
    table.insert(lines, 'Crates 101 - Requesting and Handling')
    table.insert(lines, '')
    table.insert(lines, '- Request crates near an ACTIVE Supply Zone; max distance is configurable.')
    table.insert(lines, '- Menu labels show the total crates required for a recipe.')
    table.insert(lines, '- Drop crates close together but avoid overlap; smoke marks spawns.')
    table.insert(lines, '- Use Coach & Nav tools: vectors to nearest pickup zone, re-mark crate with smoke.')
    MESSAGE:New(table.concat(lines, '\n'), 35):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'Hover Pickup & Slingloading', help, function()
    local coachCfg = CTLD.HoverCoachConfig or {}
    local aglMin = (coachCfg.thresholds and coachCfg.thresholds.aglMin) or 5
    local aglMax = (coachCfg.thresholds and coachCfg.thresholds.aglMax) or 20
    local capGS = (coachCfg.thresholds and coachCfg.thresholds.captureGS) or (4/3.6)
    local hold = (coachCfg.thresholds and coachCfg.thresholds.stabilityHold) or 1.8
    local lines = {}
    table.insert(lines, 'Hover Pickup & Slingloading')
    table.insert(lines, '')
    table.insert(lines, string.format('- Hover pickup: hold AGL %d-%d m, speed < %.1f m/s, for ~%.1f s to auto-load.', aglMin, aglMax, capGS, hold))
    table.insert(lines, '- Keep steady within ~15 m of the crate; Hover Coach gives cues if enabled.')
    table.insert(lines, '- Slingloading tips: avoid rotor wash over stacks; approach from upwind; re-mark crate with smoke if needed.')
    MESSAGE:New(table.concat(lines, '\n'), 35):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'Build System: Build Here and Advanced', help, function()
    local br = self.Config.BuildRadius or 100
    local win = self.Config.BuildConfirmWindowSeconds or 10
    local cd = self.Config.BuildCooldownSeconds or 60
    local lines = {}
    table.insert(lines, 'Build System - Build Here and Advanced')
    table.insert(lines, '')
    table.insert(lines, string.format('- Build Here collects crates within ~%d m. Double-press within %d s to confirm.', br, win))
    table.insert(lines, string.format('- Cooldown: about %d s per group after a successful build.', cd))
    table.insert(lines, '- Advanced Build lets you choose Defend (hold) or Attack (move).')
    table.insert(lines, '- Static or unsuitable units will hold even if Attack is chosen.')
    table.insert(lines, '- FOB-only recipes must be inside an FOB zone when restriction is enabled.')
    MESSAGE:New(table.concat(lines, '\n'), 40):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'FOBs: Forward Supply & Why They Matter', help, function()
    local fobPct = math.floor(((self.Config.Inventory and self.Config.Inventory.FOBStockFactor or 0.25) * 100) + 0.5)
    local lines = {}
    table.insert(lines, 'FOBs - Forward Supply and Why They Matter')
    table.insert(lines, '')
    table.insert(lines, '- Build a FOB by assembling its crate recipe (see Recipe Info).')
    table.insert(lines, string.format('- A new local Supply Zone is created and seeded at ~%d%% of initial stock.', fobPct))
    table.insert(lines, '- FOBs shorten logistics legs and increase throughput toward the front.')
    table.insert(lines, '- If enabled, FOB-only builds must occur inside FOB zones.')
    MESSAGE:New(table.concat(lines, '\n'), 35):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'SAM Sites: Building, Repairing, and Augmenting', help, function()
    local br = self.Config.BuildRadius or 100
    local lines = {}
    table.insert(lines, 'SAM Sites - Building, Repairing, and Augmenting')
    table.insert(lines, '')
    table.insert(lines, 'Build:')
    table.insert(lines, '- Assemble site recipes using the required component crates (see menu labels). Build Here will place the full site.')
    table.insert(lines, '')
    table.insert(lines, 'Repair/Augment (merged):')
    table.insert(lines, '- Request the matching "Repair/Launcher +1" crate for your site type (HAWK, Patriot, KUB, BUK).')
    table.insert(lines, string.format('- Drop repair crate(s) within ~%d m of the site, then use Build Here (confirm window applies).', br))
    table.insert(lines, '- The nearest matching site (within a local search) is respawned fully repaired; +1 launcher per crate, up to caps.')
    table.insert(lines, '- Caps: HAWK 6, Patriot 6, KUB 3, BUK 6. Extra crates beyond the cap are not consumed.')
    table.insert(lines, '- Must match coalition and site type; otherwise no changes are applied.')
    table.insert(lines, '- Respawn is required to apply repairs/augmentation due to DCS limitations.')
    table.insert(lines, '')
    table.insert(lines, 'Placement tips:')
    table.insert(lines, '- Space launchers to avoid masking; keep radars with good line-of-sight; avoid fratricide arcs.')
    MESSAGE:New(table.concat(lines, '\n'), 45):ToGroup(group)
  end)
  MENU_GROUP_COMMAND:New(group, 'MASH & Salvage System', help, function()
    local lines = {}
    table.insert(lines, 'MASH & Salvage System - Player Guide')
    table.insert(lines, '')
    table.insert(lines, 'What is it?')
    table.insert(lines, '- MASH (Mobile Army Surgical Hospital) zones accept MEDEVAC crew deliveries.')
    table.insert(lines, '- When ground vehicles are destroyed, crews spawn nearby and call for rescue.')
    table.insert(lines, '- Rescuing crews and delivering them to MASH earns Salvage Points for your coalition.')
    table.insert(lines, '- Salvage Points let you build out-of-stock items, keeping logistics flowing.')
    table.insert(lines, '')
    table.insert(lines, 'How MEDEVAC works:')
    table.insert(lines, '- Vehicle destroyed → crew spawns after delay with invulnerability period.')
    table.insert(lines, '- MEDEVAC request announced with grid coordinates and salvage value.')
    table.insert(lines, '- Crews have a time limit (default 60 minutes); failure = crew KIA and vehicle lost.')
    table.insert(lines, '')
    table.insert(lines, 'Pickup Methods:')
    table.insert(lines, '- AUTO: Land within 500m of crew - they will run to you and board automatically!')
    table.insert(lines, '- HOVER: Fly close, hover nearby, load troops normally - system detects MEDEVAC crew.')
    table.insert(lines, '- Original vehicle respawns when crew is picked up (if enabled).')
    table.insert(lines, '')
    table.insert(lines, 'Delivering to MASH:')
    table.insert(lines, '- AUTO: Land in any MASH zone - crews unload automatically after 2 seconds.')
    table.insert(lines, '- MANUAL: Deploy troops inside MASH zone - salvage points awarded automatically.')
    table.insert(lines, '- Coalition message shows points earned and new total.')
    table.insert(lines, '')
    table.insert(lines, 'Using Salvage Points:')
    table.insert(lines, '- When crate requests fail (out of stock), salvage auto-applies if available.')
    table.insert(lines, '- Each catalog item has a salvage cost (usually matches its value).')
    table.insert(lines, '- Check current salvage: Coach & Nav -> MEDEVAC Status.')
    table.insert(lines, '')
    table.insert(lines, 'Mobile MASH:')
    table.insert(lines, '- Build Mobile MASH crates to deploy field hospitals anywhere.')
    table.insert(lines, '- Mobile MASH creates a new delivery zone with radio beacon.')
    table.insert(lines, '- Multiple mobile MASHs can be deployed for forward operations.')
    table.insert(lines, '')
    table.insert(lines, 'Best practices:')
    table.insert(lines, '- Monitor MEDEVAC requests: Coach & Nav -> Vectors to Nearest MEDEVAC Crew.')
    table.insert(lines, '- Prioritize high-value vehicles (armor, AA) for maximum salvage.')
    table.insert(lines, '- Deploy Mobile MASH near active combat zones to reduce delivery time.')
    table.insert(lines, '- Coordinate with team: share MEDEVAC locations and salvage status.')
    table.insert(lines, '- Watch for warnings: 15min and 5min alerts before crew timeout.')
    MESSAGE:New(table.concat(lines, '\n'), 50):ToGroup(group)
  end)

  -- Operations -> Troop Transport
  local troopsRoot = MENU_GROUP:New(group, 'Troop Transport', opsRoot)
  CMD('Load Troops', troopsRoot, function() self:LoadTroops(group) end)
  -- Optional typed troop loading submenu
  do
    local typedRoot = MENU_GROUP:New(group, 'Load Troops (Type)', troopsRoot)
    local tcfg = (self.Config.Troops and self.Config.Troops.TroopTypes) or {}
    -- Stable order per common roles
    local order = { 'AS', 'AA', 'AT', 'AR' }
    local seen = {}
    local function addItem(key)
      local def = tcfg[key]
      if not def then return end
      local label = (def.label or key)
      local size = def.size or 6
      CMD(string.format('%s (%d)', label, size), typedRoot, function()
        self:LoadTroops(group, { typeKey = key })
      end)
      seen[key] = true
    end
    for _,k in ipairs(order) do addItem(k) end
    -- Add any additional custom types not in the default order
    for k,_ in pairs(tcfg) do if not seen[k] then addItem(k) end end
  end
  do
    local tr = (self.Config.AttackAI and self.Config.AttackAI.TroopSearchRadius) or 3000
    CMD('Deploy [Hold Position]', troopsRoot, function() self:UnloadTroops(group, { behavior = 'defend' }) end)
    CMD(string.format('Deploy [Attack (%dm)]', tr), troopsRoot, function() self:UnloadTroops(group, { behavior = 'attack' }) end)
  end

  -- Operations -> JTAC
  do
    local jtacRoot = MENU_GROUP:New(group, 'JTAC', opsRoot)
    -- Track per-group active JTAC selection
    CTLD._activeJTACByGroup = CTLD._activeJTACByGroup or {}

    -- Select Active JTAC: cycle to nearest or next if already selected
    CMD('Select Active JTAC (cycle nearest)', jtacRoot, function() self:JTAC_SelectActiveForGroup(group, { mode = 'nearest' }) end)

    -- Control submenu
    local ctl = MENU_GROUP:New(group, 'Control', jtacRoot)
    CMD('Pause/Resume Auto-Lase', ctl, function() self:JTAC_TogglePause(group) end)
    CMD('Release Current Target', ctl, function() self:JTAC_ReleaseTarget(group) end)
    CMD('Force Rescan / Reacquire', ctl, function() self:JTAC_ForceRescan(group) end)

    -- Targeting submenu
    local tgt = MENU_GROUP:New(group, 'Targeting', jtacRoot)
    local lock = MENU_GROUP:New(group, 'Lock Filter', tgt)
    CMD('All', lock, function() self:JTAC_SetLockFilter(group, 'all') end)
    CMD('Vehicles only', lock, function() self:JTAC_SetLockFilter(group, 'vehicle') end)
    CMD('Troops only', lock, function() self:JTAC_SetLockFilter(group, 'troop') end)
    local prof = MENU_GROUP:New(group, 'Priority Profile', tgt)
    CMD('Threat (SAM>AAA>Armor>IFV>Arty>Inf)', prof, function() self:JTAC_SetPriority(group, 'threat') end)
    CMD('Armor-first', prof, function() self:JTAC_SetPriority(group, 'armor') end)
    CMD('Soft-first', prof, function() self:JTAC_SetPriority(group, 'soft') end)
    CMD('Infantry-last', prof, function() self:JTAC_SetPriority(group, 'inf_last') end)

    -- Range & Effects submenu
    local rng = MENU_GROUP:New(group, 'Range & Effects', jtacRoot)
    local sr = MENU_GROUP:New(group, 'Search Radius', rng)
    for _,km in ipairs({4,6,8,10,12}) do
      CMD(string.format('%d km', km), sr, function() self:JTAC_SetSearchRadius(group, km*1000) end)
    end
    local sm = MENU_GROUP:New(group, 'Smoke', rng)
    CMD('Toggle Smoke On/Off', sm, function() self:JTAC_ToggleSmoke(group) end)
    CMD('Color: Blue', sm, function() self:JTAC_SetSmokeColor(group, 'blue') end)
    CMD('Color: Orange', sm, function() self:JTAC_SetSmokeColor(group, 'orange') end)

    -- Comms & Laser submenu
    local comm = MENU_GROUP:New(group, 'Comms & Laser', jtacRoot)
    CMD('Announcements On/Off', comm, function() self:JTAC_ToggleAnnouncements(group) end)
    -- Laser code management can be added in phase 2

    -- Utilities
    local util = MENU_GROUP:New(group, 'Utilities', jtacRoot)
    CMD('Mark Current Target on Map', util, function() self:JTAC_MarkCurrentTarget(group) end)
    -- Rename/Dismiss can be added in phase 2

    -- Status & Diagnostics (keep at bottom of JTAC)
    CMD('List JTAC Status', jtacRoot, function() self:ListJTACStatus(group) end)
    CMD('JTAC Diagnostics', jtacRoot, function() self:JTACDiagnostics(group) end)
  end

  -- Operations -> MEDEVAC
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled then
    local medevacRoot = MENU_GROUP:New(group, 'MEDEVAC', opsRoot)
    CMD('Show Onboard Manifest', medevacRoot, function() self:ShowOnboardManifest(group) end)
    
    -- List Active MEDEVAC Requests
    CMD('List Active MEDEVAC Requests', medevacRoot, function() self:ListActiveMEDEVACRequests(group) end)
    
    -- Nearest MEDEVAC Location
    CMD('Nearest MEDEVAC Location', medevacRoot, function() self:NearestMEDEVACLocation(group) end)
    
    -- Coalition Salvage Points
    CMD('Coalition Salvage Points', medevacRoot, function() self:ShowSalvagePoints(group) end)
    
    -- Vectors to Nearest MEDEVAC
    CMD('Vectors to Nearest MEDEVAC', medevacRoot, function() self:VectorsToNearestMEDEVAC(group) end)
    
    -- MASH Locations
    CMD('MASH Locations', medevacRoot, function() self:ListMASHLocations(group) end)
    
    -- Pop Smoke at Crew Locations
    CMD('Pop Smoke at Crew Locations', medevacRoot, function() self:PopSmokeAtMEDEVACSites(group) end)
    
    -- Pop Smoke at MASH Zones
    CMD('Pop Smoke at MASH Zones', medevacRoot, function() self:PopSmokeAtMASHZones(group) end)
    
    -- Duplicate guide from Admin/Help -> Player Guides for quick access
    MENU_GROUP_COMMAND:New(group, 'MASH & Salvage System - Guide', medevacRoot, function()
      local lines = {}
      table.insert(lines, 'MASH & Salvage System - Player Guide')
      table.insert(lines, '')
      table.insert(lines, 'What is it?')
      table.insert(lines, '- MASH (Mobile Army Surgical Hospital) zones accept MEDEVAC crew deliveries.')
      table.insert(lines, '- When ground vehicles are destroyed, crews spawn nearby and call for rescue.')
      table.insert(lines, '- Rescuing crews and delivering them to MASH earns Salvage Points for your coalition.')
      table.insert(lines, '- Salvage Points let you build out-of-stock items, keeping logistics flowing.')
      table.insert(lines, '')
      table.insert(lines, 'How MEDEVAC works:')
      table.insert(lines, '- Vehicle destroyed → crew spawns after delay with invulnerability period.')
      table.insert(lines, '- MEDEVAC request announced with grid coordinates and salvage value.')
      table.insert(lines, '- Crews have a time limit (default 60 minutes); failure = crew KIA and vehicle lost.')
      table.insert(lines, '')
      table.insert(lines, 'Pickup Methods:')
      table.insert(lines, '- AUTO: Land within 500m of crew - they will run to you and board automatically!')
      table.insert(lines, '- HOVER: Fly close, hover nearby, load troops normally - system detects MEDEVAC crew.')
      table.insert(lines, '- Original vehicle respawns when crew is picked up (if enabled).')
      table.insert(lines, '')
      table.insert(lines, 'Delivering to MASH:')
      table.insert(lines, '- AUTO: Land in any MASH zone - crews unload automatically after 2 seconds.')
      table.insert(lines, '- MANUAL: Deploy troops inside MASH zone - salvage points awarded automatically.')
      table.insert(lines, '- Coalition message shows points earned and new total.')
      table.insert(lines, '')
      table.insert(lines, 'Using Salvage Points:')
      table.insert(lines, '- When crate requests fail (out of stock), salvage auto-applies if available.')
      table.insert(lines, '- Each catalog item has a salvage cost (usually matches its value).')
      table.insert(lines, '- Check current salvage: Coach & Nav -> MEDEVAC Status.')
      table.insert(lines, '')
      table.insert(lines, 'Mobile MASH:')
      table.insert(lines, '- Build Mobile MASH crates to deploy field hospitals anywhere.')
      table.insert(lines, '- Mobile MASH creates a new delivery zone with radio beacon.')
      table.insert(lines, '- Multiple mobile MASHs can be deployed for forward operations.')
      table.insert(lines, '')
      table.insert(lines, 'Best practices:')
      table.insert(lines, '- Monitor MEDEVAC requests: Coach & Nav -> Vectors to Nearest MEDEVAC Crew.')
      table.insert(lines, '- Prioritize high-value vehicles (armor, AA) for maximum salvage.')
      table.insert(lines, '- Deploy Mobile MASH near active combat zones to reduce delivery time.')
      table.insert(lines, '- Coordinate with team: share MEDEVAC locations and salvage status.')
      table.insert(lines, '- Watch for warnings: 15min and 5min alerts before crew timeout.')
      MESSAGE:New(table.concat(lines, '\n'), 50):ToGroup(group)
    end)
    
    -- Admin/Settings submenu
    local medevacAdminRoot = MENU_GROUP:New(group, 'Admin/Settings', medevacRoot)
    CMD('Clear All MEDEVAC Missions', medevacAdminRoot, function() self:ClearAllMEDEVACMissions(group) end)
  end
  
  -- Operations -> FARP
  if CTLD.FARPConfig and CTLD.FARPConfig.Enabled then
    local farpRoot = MENU_GROUP:New(group, 'FARP', opsRoot)
    
    -- Upgrade FOB to FARP
    CMD('Upgrade FOB to FARP', farpRoot, function() self:RequestFARPUpgrade(group) end)
    
    -- Show FARP Status
    CMD('Show FARP Status', farpRoot, function() self:ShowFARPStatus(group) end)
    
    -- Show Salvage Points
    CMD('Coalition Salvage Points', farpRoot, function() self:ShowSalvagePoints(group) end)
    
    -- FARP System Guide
    MENU_GROUP_COMMAND:New(group, 'FARP System - Guide', farpRoot, function()
      local lines = {}
      table.insert(lines, 'FARP System - Player Guide')
      table.insert(lines, '')
      table.insert(lines, 'What is FARP?')
      table.insert(lines, '- FARP = Forward Arming and Refueling Point')
      table.insert(lines, '- Upgrade FOBs into operational FARPs with rearm/refuel capability')
      table.insert(lines, '- Progressive stages add equipment and expand services')
      table.insert(lines, '- Uses coalition salvage points earned from MEDEVAC and salvage collection')
      table.insert(lines, '')
      table.insert(lines, 'How to Upgrade:')
      table.insert(lines, '1. Build a FOB using normal CTLD mechanics')
      table.insert(lines, '2. Earn salvage points (deliver MEDEVAC crews to MASH, sling-load enemy wreckage)')
      table.insert(lines, '3. Fly to the FOB pickup zone')
      table.insert(lines, '4. Use: Operations -> FARP -> Upgrade FOB to FARP')
      table.insert(lines, '5. Each upgrade costs salvage and adds new equipment/services')
      table.insert(lines, '')
      table.insert(lines, 'FARP Stages:')
      table.insert(lines, '')
      table.insert(lines, 'Stage 1: Basic FARP Pad (3 salvage)')
      table.insert(lines, '- Landing pad with command post')
      table.insert(lines, '- Personnel tents and basic supplies')
      table.insert(lines, '- Fuel drums and generators')
      table.insert(lines, '- Perimeter security (sandbags)')
      table.insert(lines, '')
      table.insert(lines, 'Stage 2: Operational FARP (5 salvage, 8 total)')
      table.insert(lines, '- 2x HEMTT Fuel Trucks - REFUEL CAPABILITY!')
      table.insert(lines, '- Large fuel bladders and storage')
      table.insert(lines, '- Upgraded command post')
      table.insert(lines, '- Defensive barriers (Hesco walls)')
      table.insert(lines, '- Support vehicles and power distribution')
      table.insert(lines, '- Expanded equipment and tools')
      table.insert(lines, '')
      table.insert(lines, 'Stage 3: Full Forward Airbase (8 salvage, 16 total)')
      table.insert(lines, '- 2x Ammunition Trucks - REARM CAPABILITY!')
      table.insert(lines, '- Communications tower (SKP-11 ATC)')
      table.insert(lines, '- Large maintenance shelter')
      table.insert(lines, '- Complete defensive perimeter')
      table.insert(lines, '- Watch tower for security')
      table.insert(lines, '- Multiple supply depots')
      table.insert(lines, '- Vehicle park with support trucks')
      table.insert(lines, '- Unit identification markers')
      table.insert(lines, '- Full workshop facilities')
      table.insert(lines, '')
      table.insert(lines, 'Services Available:')
      table.insert(lines, '- Stage 1: Landing zone only')
      table.insert(lines, '- Stage 2: Refuel for helicopters & ground vehicles')
      table.insert(lines, '- Stage 3: Rearm, Refuel, Repair for all units')
      table.insert(lines, '')
      table.insert(lines, 'Using FARPs:')
      table.insert(lines, '- Land or park within service radius (50-80m depending on stage)')
      table.insert(lines, '- Services are automatic for friendly units')
      table.insert(lines, '- Helicopters can hover-refuel at Stage 2+')
      table.insert(lines, '- Ground vehicles automatically rearm/refuel when stopped in zone')
      table.insert(lines, '')
      table.insert(lines, 'Strategy Tips:')
      table.insert(lines, '- Build FOBs in strategic locations before upgrading')
      table.insert(lines, '- Pool salvage as a team for critical FARP upgrades')
      table.insert(lines, '- Upgrade forward FOBs to Stage 2 for quick helicopter turnaround')
      table.insert(lines, '- Stage 3 FARPs support sustained ground operations')
      table.insert(lines, '- Protect your FARPs - they become high-value targets!')
      table.insert(lines, '- Check status before upgrading: Operations -> FARP -> Show FARP Status')
      table.insert(lines, '')
      table.insert(lines, 'Dual Coalition:')
      table.insert(lines, '- Each coalition has separate salvage pools')
      table.insert(lines, '- FARPs are coalition-specific and only service friendly units')
      table.insert(lines, '- Capture enemy territory to deny their FARP network')
      MESSAGE:New(table.concat(lines, '\n'), 60):ToGroup(group)
    end)
  end

  -- Operations (root) -> List JTAC Status (placed at bottom of Operations)
  CMD('List JTAC Status', opsRoot, function() self:ListJTACStatus(group) end)
  CMD('JTAC Diagnostics', opsRoot, function() self:JTACDiagnostics(group) end)

    -- Logistics -> Crates, Build, and Recipe Details
    CMD('Show Onboard Manifest', logRoot, function() self:ShowOnboardManifest(group) end)
    local reqRoot = MENU_GROUP:New(group, 'Request Crate', logRoot)

    local crateMgmt = MENU_GROUP:New(group, 'Crate Management', logRoot)
    CMD('Drop One Loaded Crate', crateMgmt, function() self:DropLoadedCrates(group, 1) end)
    CMD('Drop All Loaded Crates', crateMgmt, function() self:DropLoadedCrates(group, -1) end)
    self:_BuildOrRefreshLoadedCrateMenu(group, crateMgmt)
    CMD('Re-mark Nearest Crate (Smoke)', crateMgmt, function()
      local unit = group:GetUnit(1)
      if not unit or not unit:IsAlive() then return end
      local p = unit:GetPointVec3()
      local here = { x = p.x, z = p.z }
      local bestName, bestMeta, bestd
      for name,meta in pairs(CTLD._crates) do
        if meta.side == self.Side then
          local dx = (meta.point.x - here.x)
          local dz = (meta.point.z - here.z)
          local d = math.sqrt(dx*dx + dz*dz)
          if (not bestd) or d < bestd then
            bestName, bestMeta, bestd = name, meta, d
          end
        end
      end
      if bestName and bestMeta then
        local sx, sz = bestMeta.point.x, bestMeta.point.z
        local sy = 0
        if land and land.getHeight then
          local ok, h = pcall(land.getHeight, { x = sx, y = sz })
          if ok and type(h) == 'number' then sy = h end
        end
        local smokeColor = self.Config.PickupZoneSmokeColor
        _spawnCrateSmoke({ x = sx, y = sy, z = sz }, smokeColor, self.Config.CrateSmoke, bestName)
        _eventSend(self, group, nil, 'crate_re_marked', { id = bestName, mark = 'smoke' })
      else
        _msgGroup(group, 'No friendly crates found to mark.')
      end
    end)

    local buildRoot = MENU_GROUP:New(group, 'Build Menu', logRoot)
    local cd = tonumber(self.Config.BuildCooldownSeconds) or 0
    local buildHereLabel
    if cd <= 0 then
      buildHereLabel = 'Build All Here'
    else
      buildHereLabel = string.format('Build Here (w/%ds throttle)', cd)
    end
    CMD(buildHereLabel, buildRoot, function() self:BuildAtGroup(group) end)
    self:_BuildOrRefreshBuildAdvancedMenu(group, buildRoot)
    MENU_GROUP_COMMAND:New(group, 'Refresh Buildable List', buildRoot, function()
      self:_BuildOrRefreshBuildAdvancedMenu(group, buildRoot)
      MESSAGE:New('Buildable list refreshed.', 6):ToGroup(group)
    end)

    local infoRoot = MENU_GROUP:New(group, 'Recipe Info', logRoot)
    if self.Config.UseCategorySubmenus then
      local reqSubmenus = {}
      local function getRequestSub(catLabel)
        if not reqSubmenus[catLabel] then
          reqSubmenus[catLabel] = MENU_GROUP:New(group, catLabel, reqRoot)
        end
        return reqSubmenus[catLabel]
      end

      local infoSubs = {}
      local function getInfoSub(catLabel)
        if not infoSubs[catLabel] then
          infoSubs[catLabel] = MENU_GROUP:New(group, catLabel, infoRoot)
        end
        return infoSubs[catLabel]
      end

      local replacementQueue = {}
      for key,def in pairs(self.Config.CrateCatalog) do
        if not (def and def.hidden) then
          local sideOk = (not def.side) or def.side == self.Side
          if sideOk then
            local catLabel = (def and def.menuCategory) or 'Other'
            local reqParent = getRequestSub(catLabel)
            local label = self:_formatMenuLabelWithCrates(key, def)

            if def and type(def.requires) == 'table' then
              CMD(label, reqParent, function() self:RequestRecipeBundleForGroup(group, key) end)
              for reqKey,_ in pairs(def.requires) do
                local compDef = self.Config.CrateCatalog[reqKey]
                local compSideOk = (not compDef) or (not compDef.side) or compDef.side == self.Side
                if compDef and compDef.hidden and compSideOk then
                  local queue = replacementQueue[catLabel]
                  if not queue then
                    queue = { list = {}, seen = {} }
                    replacementQueue[catLabel] = queue
                  end
                  if not queue.seen[reqKey] then
                    queue.seen[reqKey] = true
                    table.insert(queue.list, { key = reqKey, def = compDef })
                  end
                end
              end
            else
              CMD(label, reqParent, function() self:RequestCrateForGroup(group, key) end)
            end

            local infoParent = getInfoSub(catLabel)
            CMD((def and (def.menu or def.description)) or key, infoParent, function()
              local text = self:_formatRecipeInfo(key, def)
              _msgGroup(group, text)
            end)
          end
        end
      end

      for catLabel,queue in pairs(replacementQueue) do
        if queue and queue.list and #queue.list > 0 then
          table.sort(queue.list, function(a,b)
            local la = (a.def and (a.def.menu or a.def.description)) or a.key
            local lb = (b.def and (b.def.menu or b.def.description)) or b.key
            return tostring(la) < tostring(lb)
          end)
          local reqParent = getRequestSub(catLabel)
          local replMenu = MENU_GROUP:New(group, 'Replacement Crates', reqParent)
          for _,entry in ipairs(queue.list) do
            local replLabel = string.format('Replacement: %s', self:_formatMenuLabelWithCrates(entry.key, entry.def))
            CMD(replLabel, replMenu, function() self:RequestCrateForGroup(group, entry.key) end)
          end
        end
      end
    else
      local replacementList = {}
      local replacementSeen = {}
      for key,def in pairs(self.Config.CrateCatalog) do
        if not (def and def.hidden) then
          local sideOk = (not def.side) or def.side == self.Side
          if sideOk then
            local label = self:_formatMenuLabelWithCrates(key, def)
            if def and type(def.requires) == 'table' then
              CMD(label, reqRoot, function() self:RequestRecipeBundleForGroup(group, key) end)
              for reqKey,_ in pairs(def.requires) do
                local compDef = self.Config.CrateCatalog[reqKey]
                local compSideOk = (not compDef) or (not compDef.side) or compDef.side == self.Side
                if compDef and compDef.hidden and compSideOk and not replacementSeen[reqKey] then
                  replacementSeen[reqKey] = true
                  table.insert(replacementList, { key = reqKey, def = compDef })
                end
              end
            else
              CMD(label, reqRoot, function() self:RequestCrateForGroup(group, key) end)
            end

            CMD((def and (def.menu or def.description)) or key, infoRoot, function()
              local text = self:_formatRecipeInfo(key, def)
              _msgGroup(group, text)
            end)
          end
        end
      end

      if #replacementList > 0 then
        table.sort(replacementList, function(a,b)
          local la = (a.def and (a.def.menu or a.def.description)) or a.key
          local lb = (b.def and (b.def.menu or b.def.description)) or b.key
          return tostring(la) < tostring(lb)
        end)
        local replMenu = MENU_GROUP:New(group, 'Replacement Crates', reqRoot)
        for _,entry in ipairs(replacementList) do
          local replLabel = string.format('Replacement: %s', self:_formatMenuLabelWithCrates(entry.key, entry.def))
          CMD(replLabel, replMenu, function() self:RequestCrateForGroup(group, entry.key) end)
        end
      end
    end

    -- Logistics -> Show Inventory at Nearest Pickup Zone/FOB
    CMD('Show Inventory at Nearest Zone', logRoot, function() self:ShowNearestZoneInventory(group) end)

  -- Field Tools
  CMD('Create Drop Zone (AO)', toolsRoot, function() self:CreateDropZoneAtGroup(group) end)
  
  -- Salvage Collection Zones submenu
  if self.Config.SlingLoadSalvage and self.Config.SlingLoadSalvage.Enabled then
    local salvageZoneRoot = MENU_GROUP:New(group, 'Salvage Collection Zones', toolsRoot)
    CMD('Create Salvage Zone Here', salvageZoneRoot, function() self:CreateSalvageZoneAtGroup(group) end)
    CMD('Show Active Salvage Zones', salvageZoneRoot, function() self:ShowActiveSalvageZones(group) end)
    CMD('Retire Oldest Salvage Zone', salvageZoneRoot, function() self:RetireOldestDynamicSalvageZone(group) end)
    -- Dynamic per-zone management will be added by _rebuildSalvageZoneMenus
  end
  
  local smokeRoot = MENU_GROUP:New(group, 'Smoke My Location', toolsRoot)
  local function smokeHere(color)
    local unit = group:GetUnit(1)
    if not unit or not unit:IsAlive() then return end
    local p = unit:GetPointVec3()
    -- Use full Vec3 to ensure correct placement
    trigger.action.smoke({ x = p.x, y = p.y, z = p.z }, color)
  end
  MENU_GROUP_COMMAND:New(group, 'Green', smokeRoot, function() smokeHere(trigger.smokeColor.Green) end)
  MENU_GROUP_COMMAND:New(group, 'Red', smokeRoot, function() smokeHere(trigger.smokeColor.Red) end)
  MENU_GROUP_COMMAND:New(group, 'White', smokeRoot, function() smokeHere(trigger.smokeColor.White) end)
  MENU_GROUP_COMMAND:New(group, 'Orange', smokeRoot, function() smokeHere(trigger.smokeColor.Orange) end)
  MENU_GROUP_COMMAND:New(group, 'Blue', smokeRoot, function() smokeHere(trigger.smokeColor.Blue) end)

  -- Navigation
  local gname = group:GetName()
  CMD('Request Vectors to Nearest Crate', navRoot, function()
    local unit = group:GetUnit(1)
    if not unit or not unit:IsAlive() then return end
    local p = unit:GetPointVec3()
    local here = { x = p.x, z = p.z }
    local bestName, bestMeta, bestd
    for name,meta in pairs(CTLD._crates) do
      if meta.side == self.Side then
        local dx = (meta.point.x - here.x)
        local dz = (meta.point.z - here.z)
        local d = math.sqrt(dx*dx + dz*dz)
        if (not bestd) or d < bestd then
          bestName, bestMeta, bestd = name, meta, d
        end
      end
    end
    if bestName and bestMeta then
      local brg = _bearingDeg(here, bestMeta.point)
      local isMetric = _getPlayerIsMetric(unit)
      local rngV, rngU = _fmtRange(bestd, isMetric)
      _eventSend(self, group, nil, 'vectors_to_crate', { id = bestName, brg = brg, rng = rngV, rng_u = rngU })
    else
      _msgGroup(group, 'No friendly crates found.')
    end
  end)
  
  -- Sling-Load Salvage vectors
  if self.Config.SlingLoadSalvage and self.Config.SlingLoadSalvage.Enabled then
    CMD('Vectors to Nearest Salvage Crate', navRoot, function() self:ShowNearestSalvageCrate(group) end)
  end
  
  CMD('Vectors to Nearest Pickup Zone', navRoot, function()
    local unit = group:GetUnit(1)
    if not unit or not unit:IsAlive() then return end
    local zone = nil
    local dist = nil
    local list = nil
    if self.Config and self.Config.Zones and self.Config.Zones.PickupZones then
      list = {}
      for _,z in ipairs(self.Config.Zones.PickupZones) do
        if (not z.name) or self._ZoneActive.Pickup[z.name] ~= false then table.insert(list, z) end
      end
    elseif self.PickupZones and #self.PickupZones > 0 then
      list = {}
      for _,mz in ipairs(self.PickupZones) do
        if mz and mz.GetName then
          local n = mz:GetName()
          if self._ZoneActive.Pickup[n] ~= false then table.insert(list, { name = n }) end
        end
      end
    else
      list = {}
    end
    zone, dist = _nearestZonePoint(unit, list)
    if not zone then
      local allDefs = self.Config and self.Config.Zones and self.Config.Zones.PickupZones or {}
      if allDefs and #allDefs > 0 then
        local fbZone, fbDist = _nearestZonePoint(unit, allDefs)
        if fbZone then
          local up = unit:GetPointVec3(); local zp = fbZone:GetPointVec3()
          local from = { x = up.x, z = up.z }
          local to = { x = zp.x, z = zp.z }
          local brg = _bearingDeg(from, to)
          local isMetric = _getPlayerIsMetric(unit)
          local rngV, rngU = _fmtRange(fbDist or 0, isMetric)
          _eventSend(self, group, nil, 'vectors_to_pickup_zone', { zone = fbZone:GetName(), brg = brg, rng = rngV, rng_u = rngU })
          return
        end
      end
      _eventSend(self, group, nil, 'no_pickup_zones', {})
      return
    end
    local up = unit:GetPointVec3()
    local zp = zone:GetPointVec3()
    local from = { x = up.x, z = up.z }
    local to = { x = zp.x, z = zp.z }
    local brg = _bearingDeg(from, to)
    local isMetric = _getPlayerIsMetric(unit)
    local rngV, rngU = _fmtRange(dist, isMetric)
    _eventSend(self, group, nil, 'vectors_to_pickup_zone', { zone = zone:GetName(), brg = brg, rng = rngV, rng_u = rngU })
  end)

  -- Navigation -> Smoke Nearest Zone (Pickup/Drop/FOB)
  CMD('Smoke Nearest Zone (Pickup/Drop/FOB/MASH)', navRoot, function()
    local unit = group:GetUnit(1)
    if not unit or not unit:IsAlive() then return end

    -- Build lists of active zones by kind in a format usable by _nearestZonePoint
    local function collectActive(kind)
      if kind == 'Pickup' then
        return self:_collectActivePickupDefs()
      elseif kind == 'Drop' then
        local out = {}
        for _, mz in ipairs(self.DropZones or {}) do
          if mz and mz.GetName then
            local n = mz:GetName()
            if (self._ZoneActive and self._ZoneActive.Drop and self._ZoneActive.Drop[n] ~= false) then
              table.insert(out, { name = n })
            end
          end
        end
        return out
      elseif kind == 'FOB' then
        local out = {}
        for _, mz in ipairs(self.FOBZones or {}) do
          if mz and mz.GetName then
            local n = mz:GetName()
            if (self._ZoneActive and self._ZoneActive.FOB and self._ZoneActive.FOB[n] ~= false) then
              table.insert(out, { name = n })
            end
          end
        end
        return out
      elseif kind == 'MASH' then
        local out = {}
        if CTLD._mashZones then
          for name, data in pairs(CTLD._mashZones) do
            if data and data.side == self.Side and data.zone then
              table.insert(out, { name = name })
            end
          end
        end
        return out
      end
      return {}
    end

    local bestKind, bestZone, bestDist
    for _, k in ipairs({ 'Pickup', 'Drop', 'FOB', 'MASH' }) do
      local list = collectActive(k)
      if list and #list > 0 then
        local z, d = _nearestZonePoint(unit, list)
        if z and d and ((not bestDist) or d < bestDist) then
          bestKind, bestZone, bestDist = k, z, d
        end
      end
    end

    if not bestZone then
      _msgGroup(group, 'No zones available to smoke.')
      return
    end

    -- Determine smoke point (zone center)
    -- _getZoneCenterAndRadius returns (center, radius); call directly to capture center
    local center
    if self._getZoneCenterAndRadius then center = select(1, self:_getZoneCenterAndRadius(bestZone)) end
    if not center then
      local v3 = bestZone:GetPointVec3()
      center = { x = v3.x, y = v3.y or 0, z = v3.z }
    else
      center = { x = center.x, y = center.y or 0, z = center.z }
    end

    -- Choose smoke color per kind
    local color = trigger.smokeColor.Green  -- default
    if bestKind == 'Pickup' then
      color = self.Config.PickupZoneSmokeColor or trigger.smokeColor.Green
    elseif bestKind == 'Drop' then
      color = trigger.smokeColor.Red
    elseif bestKind == 'FOB' then
      color = trigger.smokeColor.White
    elseif bestKind == 'MASH' then
      color = trigger.smokeColor.Orange
    end

    -- Apply smoke offset system (use crate smoke config settings)
    local smokeConfig = self.Config.CrateSmoke or {}
    local smokePos = {
      x = center.x,
      y = land.getHeight({x = center.x, y = center.z}),
      z = center.z
    }
    local offsetMeters = tonumber(smokeConfig.OffsetMeters) or 5
    local offsetRandom = (smokeConfig.OffsetRandom ~= false)  -- default true
    local offsetVertical = tonumber(smokeConfig.OffsetVertical) or 2
    
    if offsetMeters > 0 then
      local angle = 0
      if offsetRandom then
        angle = math.random() * 2 * math.pi
      end
      smokePos.x = smokePos.x + offsetMeters * math.cos(angle)
      smokePos.z = smokePos.z + offsetMeters * math.sin(angle)
    end
    smokePos.y = smokePos.y + offsetVertical

    -- Use MOOSE COORDINATE smoke for better appearance (tall, thin smoke like cargo smoke)
    local coord = COORDINATE:New(smokePos.x, smokePos.y, smokePos.z)
    if coord and coord.Smoke then
      if color == trigger.smokeColor.Green then
        coord:SmokeGreen()
      elseif color == trigger.smokeColor.Red then
        coord:SmokeRed()
      elseif color == trigger.smokeColor.White then
        coord:SmokeWhite()
      elseif color == trigger.smokeColor.Orange then
        coord:SmokeOrange()
      elseif color == trigger.smokeColor.Blue then
        coord:SmokeBlue()
      else
        coord:SmokeGreen()
      end
      local distKm = bestDist / 1000
      local distNm = bestDist / 1852
      _msgGroup(group, string.format('Smoked nearest %s zone: %s (%.1f km / %.1f nm)', bestKind, bestZone:GetName(), distKm, distNm))
    elseif trigger and trigger.action and trigger.action.smoke then
      -- Fallback to trigger.action.smoke if MOOSE COORDINATE not available
      trigger.action.smoke(smokePos, color)
      local distKm = bestDist / 1000
      local distNm = bestDist / 1852
      _msgGroup(group, string.format('Smoked nearest %s zone: %s (%.1f km / %.1f nm)', bestKind, bestZone:GetName(), distKm, distNm))
    else
      _msgGroup(group, 'Smoke not available in this environment.')
    end
  end)

  -- Smoke all nearby zones within range
  CMD('Smoke All Nearby Zones (5km)', navRoot, function()
    local unit = group:GetUnit(1)
    if not unit or not unit:IsAlive() then return end
    
    local maxRange = 5000  -- 5km in meters
    
    -- Get unit position
    local uname = unit:GetName()
    local du = Unit.getByName and Unit.getByName(uname) or nil
    if not du or not du:getPoint() then
      _msgGroup(group, 'Unable to determine your position.')
      return
    end
    local up = du:getPoint()
    local ux, uz = up.x, up.z
    
    -- Helper function to calculate distance and smoke a zone if in range
    local function smokeZoneIfInRange(zoneName, zoneObj, zoneType, smokeColor)
      if not zoneObj then return false end
      
      -- Get zone center
      local center
      if self._getZoneCenterAndRadius then 
        center = select(1, self:_getZoneCenterAndRadius(zoneObj)) 
      end
      if not center and zoneObj.GetPointVec3 then
        local v3 = zoneObj:GetPointVec3()
        center = { x = v3.x, y = v3.y or 0, z = v3.z }
      end
      
      if not center then return false end
      
      -- Calculate distance
      local dx = center.x - ux
      local dz = center.z - uz
      local dist = math.sqrt(dx*dx + dz*dz)
      
      if dist <= maxRange then
        -- Apply smoke offset system
        local smokeConfig = self.Config.CrateSmoke or {}
        local smokePos = {
          x = center.x,
          y = land.getHeight({x = center.x, y = center.z}),
          z = center.z
        }
        local offsetMeters = tonumber(smokeConfig.OffsetMeters) or 5
        local offsetRandom = (smokeConfig.OffsetRandom ~= false)
        local offsetVertical = tonumber(smokeConfig.OffsetVertical) or 2
        
        if offsetMeters > 0 then
          local angle = 0
          if offsetRandom then
            angle = math.random() * 2 * math.pi
          end
          smokePos.x = smokePos.x + offsetMeters * math.cos(angle)
          smokePos.z = smokePos.z + offsetMeters * math.sin(angle)
        end
        smokePos.y = smokePos.y + offsetVertical
        
        -- Spawn smoke
        local coord = COORDINATE:New(smokePos.x, smokePos.y, smokePos.z)
        if coord and coord.Smoke then
          if smokeColor == trigger.smokeColor.Green then
            coord:SmokeGreen()
          elseif smokeColor == trigger.smokeColor.Red then
            coord:SmokeRed()
          elseif smokeColor == trigger.smokeColor.White then
            coord:SmokeWhite()
          elseif smokeColor == trigger.smokeColor.Orange then
            coord:SmokeOrange()
          elseif smokeColor == trigger.smokeColor.Blue then
            coord:SmokeBlue()
          else
            coord:SmokeGreen()
          end
        else
          trigger.action.smoke(smokePos, smokeColor)
        end
        
        return true, dist
      end
      
      return false, dist
    end
    
    -- Helper to get color name
    local function getColorName(color)
      if color == trigger.smokeColor.Green then return "Green"
      elseif color == trigger.smokeColor.Red then return "Red"
      elseif color == trigger.smokeColor.White then return "White"
      elseif color == trigger.smokeColor.Orange then return "Orange"
      elseif color == trigger.smokeColor.Blue then return "Blue"
      else return "Unknown" end
    end
    
    local count = 0
    local zones = {}
    
    -- Check Pickup zones
    local pickupDefs = self:_collectActivePickupDefs()
    for _, def in ipairs(pickupDefs or {}) do
      local mz = _findZone(def)
      if mz then
        -- Check for zone-specific smoke override, then fall back to config default
        local zdef = self._ZoneDefs and self._ZoneDefs.PickupZones and self._ZoneDefs.PickupZones[def.name]
        local smokeColor = (zdef and zdef.smoke) or self.Config.PickupZoneSmokeColor or trigger.smokeColor.Green
        local smoked, dist = smokeZoneIfInRange(def.name, mz, 'Pickup', smokeColor)
        if smoked then
          count = count + 1
          local zp = mz:GetPointVec3()
          local brg = _bearingDeg({ x = ux, z = uz }, { x = zp.x, z = zp.z })
          table.insert(zones, string.format('Pickup: %s - %.1f km @ %03d° (%s)', def.name, dist/1000, brg, getColorName(smokeColor)))
        end
      end
    end
    
    -- Check Drop zones
    for _, mz in ipairs(self.DropZones or {}) do
      if mz and mz.GetName then
        local n = mz:GetName()
        if (self._ZoneActive and self._ZoneActive.Drop and self._ZoneActive.Drop[n] ~= false) then
          local smokeColor = trigger.smokeColor.Red
          local smoked, dist = smokeZoneIfInRange(n, mz, 'Drop', smokeColor)
          if smoked then
            count = count + 1
            local zp = mz:GetPointVec3()
            local brg = _bearingDeg({ x = ux, z = uz }, { x = zp.x, z = zp.z })
            table.insert(zones, string.format('Drop: %s - %.1f km @ %03d° (%s)', n, dist/1000, brg, getColorName(smokeColor)))
          end
        end
      end
    end
    
    -- Check FOB zones
    for _, mz in ipairs(self.FOBZones or {}) do
      if mz and mz.GetName then
        local n = mz:GetName()
        if (self._ZoneActive and self._ZoneActive.FOB and self._ZoneActive.FOB[n] ~= false) then
          local smokeColor = trigger.smokeColor.White
          local smoked, dist = smokeZoneIfInRange(n, mz, 'FOB', smokeColor)
          if smoked then
            count = count + 1
            local zp = mz:GetPointVec3()
            local brg = _bearingDeg({ x = ux, z = uz }, { x = zp.x, z = zp.z })
            table.insert(zones, string.format('FOB: %s - %.1f km @ %03d° (%s)', n, dist/1000, brg, getColorName(smokeColor)))
          end
        end
      end
    end
    
    -- Check MASH zones
    if CTLD._mashZones then
      for name, data in pairs(CTLD._mashZones) do
        if data and data.side == self.Side and data.zone then
          local smokeColor = trigger.smokeColor.Orange
          local smoked, dist = smokeZoneIfInRange(name, data.zone, 'MASH', smokeColor)
          if smoked then
            count = count + 1
            local zp = data.zone:GetPointVec3()
            local brg = _bearingDeg({ x = ux, z = uz }, { x = zp.x, z = zp.z })
            table.insert(zones, string.format('MASH: %s - %.1f km @ %03d° (%s)', name, dist/1000, brg, getColorName(smokeColor)))
          end
        end
      end
    end

    -- Check Salvage Drop zones
    for _, mz in ipairs(self.SalvageDropZones or {}) do
      if mz and mz.GetName then
        local n = mz:GetName()
        local isActive = true
        if self._ZoneActive and self._ZoneActive.SalvageDrop then
          isActive = (self._ZoneActive.SalvageDrop[n] ~= false)
        end
        if isActive then
          local zdef = self._ZoneDefs and self._ZoneDefs.SalvageDropZones and self._ZoneDefs.SalvageDropZones[n]
          local smokeColor = (zdef and zdef.smoke) or trigger.smokeColor.Orange
          local smoked, dist = smokeZoneIfInRange(n, mz, 'SalvageDrop', smokeColor)
          if smoked then
            count = count + 1
            local zp = mz:GetPointVec3()
            local brg = _bearingDeg({ x = ux, z = uz }, { x = zp.x, z = zp.z })
            table.insert(zones, string.format('Salvage: %s - %.1f km @ %03d° (%s)', n, dist/1000, brg, getColorName(smokeColor)))
          end
        end
      end
    end
    
    if count == 0 then
      _msgGroup(group, string.format('No zones found within %.1f km.', maxRange/1000), 10)
    else
      local msg = string.format('Smoked %d zone(s) within %.1f km:\n%s', count, maxRange/1000, table.concat(zones, '\n'))
      _msgGroup(group, msg, 15)
    end
  end)

  -- Navigation -> MEDEVAC menu items (if MEDEVAC enabled)
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled then
    CMD('Vectors to Nearest MEDEVAC Crew', navRoot, function()
      local unit = group:GetUnit(1)
      if not unit or not unit:IsAlive() then return end
      
      local pos = unit:GetPointVec3()
      local isMetric = _getPlayerIsMetric(unit)
      local nearest = nil
      local nearestDist = math.huge
      
      -- Find nearest crew of same coalition
      for crewName, crewData in pairs(CTLD._medevacCrews or {}) do
        if crewData.side == self.Side and not crewData.pickedUp then
          local dx = crewData.position.x - pos.x
          local dz = crewData.position.z - pos.z
          local dist = math.sqrt(dx*dx + dz*dz)
          
          if dist < nearestDist then
            nearestDist = dist
            nearest = crewData
          end
        end
      end
      
      if not nearest then
        _msgGroup(group, 'No active MEDEVAC requests.')
        return
      end
      
      local brg = _bearingDeg({ x = pos.x, z = pos.z }, { x = nearest.position.x, z = nearest.position.z })
      local v, u = _fmtRange(nearestDist, isMetric)
      
      -- Calculate time remaining until timeout
      local cfg = CTLD.MEDEVAC
      local timeoutAt = nearest.spawnTime + (cfg.CrewTimeout or 3600)
      local timeRemain = math.max(0, math.floor((timeoutAt - timer.getTime()) / 60))
      
      _msgGroup(group, _fmtTemplate(CTLD.Messages.medevac_vectors, {
        vehicle = nearest.vehicleType,
        brg = brg,
        rng = v,
        rng_u = u,
        time_remain = timeRemain
      }))
    end)
    
    CMD('Vectors to Nearest MASH', navRoot, function()
      local unit = group:GetUnit(1)
      if not unit or not unit:IsAlive() then return end
      
      local pos = unit:GetPointVec3()
      local isMetric = _getPlayerIsMetric(unit)
      local nearest = nil
      local nearestDist = math.huge
      
      -- Find nearest MASH of same coalition
      for _, mashData in pairs(CTLD._mashZones or {}) do
        if mashData.side == self.Side then
          local dx = mashData.position.x - pos.x
          local dz = mashData.position.z - pos.z
          local dist = math.sqrt(dx*dx + dz*dz)
          
          if dist < nearestDist then
            nearestDist = dist
            nearest = mashData
          end
        end
      end
      
      if not nearest then
        _msgGroup(group, 'No active MASH zones.')
        return
      end
      
      local brg = _bearingDeg({ x = pos.x, z = pos.z }, { x = nearest.position.x, z = nearest.position.z })
      local v, u = _fmtRange(nearestDist, isMetric)
      local mashName = nearest.isMobile and ('Mobile MASH ' .. (nearest.id:match('_(%d+)$') or '?')) or nearest.catalogKey
      
      _msgGroup(group, string.format('Nearest MASH: %s, bearing %d°, range %s %s', mashName, brg, v, u))
    end)
  end

  -- Hover Coach (at end of Navigation submenu)
  CMD('Hover Coach: Enable', navRoot, function()
    CTLD._coachOverride = CTLD._coachOverride or {}
    CTLD._coachOverride[gname] = true
    _eventSend(self, group, nil, 'coach_enabled', {})
  end)
  CMD('Hover Coach: Disable', navRoot, function()
    CTLD._coachOverride = CTLD._coachOverride or {}
    CTLD._coachOverride[gname] = false
    _eventSend(self, group, nil, 'coach_disabled', {})
  end)

  -- Admin/Help
  -- Status & map controls
  CMD('Show CTLD Status', adminRoot, function()
    local crates = 0
    for _ in pairs(CTLD._crates) do crates = crates + 1 end
    local msg = string.format('CTLD Status:\nActive crates: %d\nPickup zones: %d\nDrop zones: %d\nFOB zones: %d\nBuild Confirm: %s (%ds window)\nBuild Cooldown: %s (%ds)'
      , crates, #(self.PickupZones or {}), #(self.DropZones or {}), #(self.FOBZones or {})
      , self.Config.BuildConfirmEnabled and 'ON' or 'OFF', self.Config.BuildConfirmWindowSeconds or 0
      , self.Config.BuildCooldownEnabled and 'ON' or 'OFF', self.Config.BuildCooldownSeconds or 0)
    
    -- Add MEDEVAC info if enabled
    if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled then
      local activeRequests = 0
      for _, data in pairs(CTLD._medevacCrews or {}) do
        if data.side == self.Side and not data.pickedUp then
          activeRequests = activeRequests + 1
        end
      end
      local salvage = CTLD._salvagePoints[self.Side] or 0
      local mashCount = 0
      for _, m in pairs(CTLD._mashZones or {}) do
        if m.side == self.Side then mashCount = mashCount + 1 end
      end
      msg = msg .. string.format('\n\nMEDEVAC:\nActive requests: %d\nMASH zones: %d\nSalvage points: %d', 
        activeRequests, mashCount, salvage)
    end
    
    MESSAGE:New(msg, 20):ToGroup(group)
  end)
  CMD('Draw CTLD Zones on Map', adminRoot, function()
    self:DrawZonesOnMap()
    MESSAGE:New('CTLD zones drawn on F10 map.', 8):ToGroup(group)
  end)
  CMD('Clear CTLD Map Drawings', adminRoot, function()
    self:ClearMapDrawings()
    MESSAGE:New('CTLD map drawings cleared.', 8):ToGroup(group)
  end)
  
  -- MEDEVAC Statistics (if enabled)
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled and CTLD.MEDEVAC.Statistics and CTLD.MEDEVAC.Statistics.Enabled then
    CMD('Show MEDEVAC Statistics', adminRoot, function()
      local stats = CTLD._medevacStats[self.Side] or {}
      local lines = {}
      table.insert(lines, 'MEDEVAC Statistics:')
      table.insert(lines, '')
      table.insert(lines, string.format('Crews spawned: %d', stats.spawned or 0))
      table.insert(lines, string.format('Crews rescued: %d', stats.rescued or 0))
      table.insert(lines, string.format('Delivered to MASH: %d', stats.delivered or 0))
      table.insert(lines, string.format('Timed out: %d', stats.timedOut or 0))
      table.insert(lines, string.format('Killed in action: %d', stats.killed or 0))
      table.insert(lines, '')
      table.insert(lines, string.format('Vehicles respawned: %d', stats.vehiclesRespawned or 0))
      table.insert(lines, string.format('Salvage earned: %d', stats.salvageEarned or 0))
      table.insert(lines, string.format('Salvage used: %d', stats.salvageUsed or 0))
      table.insert(lines, string.format('Current salvage: %d', CTLD._salvagePoints[self.Side] or 0))
      
      MESSAGE:New(table.concat(lines, '\n'), 30):ToGroup(group)
    end)
  end

  -- Admin/Help -> Debug
  local debugMenu = MENU_GROUP:New(group, 'Debug', adminRoot)
  CMD('Enable verbose logging', debugMenu, function()
    self.Config.LogLevel = LOG_DEBUG
    _logInfo(string.format('[%s] Verbose/Debug logging ENABLED via Admin menu', tostring(self.Side)))
    MESSAGE:New('CTLD verbose logging ENABLED (LogLevel=4)', 8):ToGroup(group)
  end)
  CMD('Normal logging (INFO)', debugMenu, function()
    self.Config.LogLevel = LOG_INFO
    _logInfo(string.format('[%s] Logging set to INFO level via Admin menu', tostring(self.Side)))
    MESSAGE:New('CTLD logging set to INFO (LogLevel=2)', 8):ToGroup(group)
  end)
  CMD('Minimal logging (ERRORS only)', debugMenu, function()
    self.Config.LogLevel = LOG_ERROR
    _logInfo(string.format('[%s] Logging set to ERROR-only via Admin menu', tostring(self.Side)))
    MESSAGE:New('CTLD logging set to ERRORS only (LogLevel=1)', 8):ToGroup(group)
  end)
  CMD('Disable all logging', debugMenu, function()
    self.Config.LogLevel = LOG_NONE
    MESSAGE:New('CTLD logging DISABLED (LogLevel=0)', 8):ToGroup(group)
  end)

  -- Admin/Help -> Player Guides (moved earlier)

  return root
end

-- Create or refresh the filtered "In Stock Here" menu for a group.
-- If rootMenu is provided, (re)create under that. Otherwise, reuse previous stored root.
function CTLD:_BuildOrRefreshInStockMenu(group, rootMenu)
  if not (self.Config.Inventory and self.Config.Inventory.Enabled and self.Config.Inventory.HideZeroStockMenu) then return end
  if not group or not group:IsAlive() then return end
  local gname = group:GetName()
  -- remove previous menu if present and rootMenu not explicitly provided
  local existing = CTLD._inStockMenus[gname]
  if existing and existing.menu and (rootMenu == nil) then
    pcall(function() existing.menu:Remove() end)
    CTLD._inStockMenus[gname] = nil
  end

  local parent = rootMenu or (self.MenusByGroup and self.MenusByGroup[gname])
  if not parent then return end

  -- Create a fresh submenu root
  local inRoot = MENU_GROUP:New(group, 'Request Crate (In Stock Here)', parent)
  CTLD._inStockMenus[gname] = { menu = inRoot }

  -- Find nearest active pickup zone
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  local zone, dist = self:_nearestActivePickupZone(unit)
  if not zone then
    MENU_GROUP_COMMAND:New(group, 'No active supply zone nearby', inRoot, function()
      -- Inform and also provide vectors to nearest configured zone if any
      _eventSend(self, group, nil, 'no_pickup_zones', {})
      -- Fallback: try any configured pickup zone (ignoring active state) for helpful vectors
      local list = self.Config and self.Config.Zones and self.Config.Zones.PickupZones or {}
      if list and #list > 0 then
        local unit = group:GetUnit(1)
        if unit and unit:IsAlive() then
          local fallbackZone, fallbackDist = _nearestZonePoint(unit, list)
          if fallbackZone then
            local up = unit:GetPointVec3(); local zp = fallbackZone:GetPointVec3()
            local brg = _bearingDeg({x=up.x,z=up.z}, {x=zp.x,z=zp.z})
            local isMetric = _getPlayerIsMetric(unit)
            local rngV, rngU = _fmtRange(fallbackDist or 0, isMetric)
            _eventSend(self, group, nil, 'vectors_to_pickup_zone', { zone = fallbackZone:GetName(), brg = brg, rng = rngV, rng_u = rngU })
          end
        end
      end
    end)
    -- Still add a refresh item
    MENU_GROUP_COMMAND:New(group, 'Refresh In-Stock List', inRoot, function() self:_BuildOrRefreshInStockMenu(group) end)
    return
  end
  local zname = zone:GetName()
  local maxd = self.Config.PickupZoneMaxDistance or 10000
  if not dist or dist > maxd then
    MENU_GROUP_COMMAND:New(group, string.format('Nearest zone %s is beyond limit (%.0f m).', zname, dist or 0), inRoot, function()
      local isMetric = _getPlayerIsMetric(unit)
      local v, u = _fmtRange(math.max(0, (dist or 0) - maxd), isMetric)
      local up = unit:GetPointVec3(); local zp = zone:GetPointVec3()
      local brg = _bearingDeg({x=up.x,z=up.z}, {x=zp.x,z=zp.z})
      _eventSend(self, group, nil, 'pickup_zone_required', { zone_dist = v, zone_dist_u = u, zone_brg = brg })
    end)
    MENU_GROUP_COMMAND:New(group, 'Refresh In-Stock List', inRoot, function() self:_BuildOrRefreshInStockMenu(group) end)
    return
  end

  -- Info and refresh commands at top
  MENU_GROUP_COMMAND:New(group, string.format('Nearest Supply: %s', zname), inRoot, function()
    local up = unit:GetPointVec3(); local zp = zone:GetPointVec3()
    local brg = _bearingDeg({x=up.x,z=up.z}, {x=zp.x,z=zp.z})
    local isMetric = _getPlayerIsMetric(unit)
    local rngV, rngU = _fmtRange(dist or 0, isMetric)
    _eventSend(self, group, nil, 'vectors_to_pickup_zone', { zone = zname, brg = brg, rng = rngV, rng_u = rngU })
  end)
  MENU_GROUP_COMMAND:New(group, 'Refresh In-Stock List', inRoot, function() self:_BuildOrRefreshInStockMenu(group) end)

  -- Build commands for items with stock > 0 at this zone; single-unit entries only
  local inStock = {}
  local stock = CTLD._stockByZone[zname] or {}
  for key,def in pairs(self.Config.CrateCatalog or {}) do
    local sideOk = (not def.side) or def.side == self.Side
    local isSingle = (type(def.requires) ~= 'table')
    if sideOk and isSingle then
      local cnt = tonumber(stock[key] or 0) or 0
      if cnt > 0 then
        table.insert(inStock, { key = key, def = def, cnt = cnt })
      end
    end
  end
  -- Stable sort by menu label for consistency
  table.sort(inStock, function(a,b)
    local la = (a.def and (a.def.menu or a.def.description)) or a.key
    local lb = (b.def and (b.def.menu or b.def.description)) or b.key
    return tostring(la) < tostring(lb)
  end)

  if #inStock == 0 then
    MENU_GROUP_COMMAND:New(group, 'None in stock at this zone', inRoot, function()
      _msgGroup(group, string.format('No crates in stock at %s.', zname))
    end)
  else
    for _,it in ipairs(inStock) do
      local base = (it.def and (it.def.menu or it.def.description)) or it.key
      local total = self:_recipeTotalCrates(it.def)
      local suffix = (total == 1) and '1 crate' or (tostring(total)..' crates')
      local label = string.format('%s (%s) [%d available]', base, suffix, it.cnt)
      MENU_GROUP_COMMAND:New(group, label, inRoot, function()
        self:RequestCrateForGroup(group, it.key)
        -- After requesting, refresh to reflect the decremented stock
        local id = timer.scheduleFunction(function() self:_BuildOrRefreshInStockMenu(group) end, {}, timer.getTime() + 0.1)
        _trackOneShotTimer(id)
      end)
    end
  end
end

-- Create or refresh the dynamic Build (Advanced) menu for a group.
function CTLD:_BuildOrRefreshBuildAdvancedMenu(group, rootMenu)
  if not group or not group:IsAlive() then return end
  -- Clear previous dynamic children if any by recreating the submenu root when rootMenu passed
  -- We'll remove and recreate inner items by making a temporary child root
  local gname = group:GetName()
  -- Remove existing dynamic children by creating a fresh inner menu under the provided root
  local dynRoot = MENU_GROUP:New(group, 'Buildable Near You', rootMenu)

  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  local p = unit:GetPointVec3()
  local here = { x = p.x, z = p.z }
  local hdgRad, _ = _headingRadDeg(unit)
  local buildOffset = math.max(0, tonumber(self.Config.BuildSpawnOffset or 0) or 0)
  local spawnAt = (buildOffset > 0) and { x = here.x + math.sin(hdgRad) * buildOffset, z = here.z + math.cos(hdgRad) * buildOffset } or { x = here.x, z = here.z }
  local radius = self.Config.BuildRadius or 100
  local nearby = self:GetNearbyCrates(here, radius)
  local filtered = {}
  for _,c in ipairs(nearby) do if c.meta.side == self.Side then table.insert(filtered, c) end end
  nearby = filtered
  -- Count by key
  local counts = {}
  for _,c in ipairs(nearby) do counts[c.meta.key] = (counts[c.meta.key] or 0) + 1 end
  -- Include carried crates if allowed
  if self.Config.BuildRequiresGroundCrates ~= true then
    local gname = group:GetName()
    local carried = CTLD._loadedCrates[gname]
    if carried and carried.byKey then
      for k,v in pairs(carried.byKey) do counts[k] = (counts[k] or 0) + v end
    end
  end
  -- FOB restriction context
  local insideFOBZone = select(1, self:IsPointInFOBZones(here))

  -- Build list of buildable recipes
  local items = {}
  for key,cat in pairs(self.Config.CrateCatalog or {}) do
    local sideOk = (not cat.side) or cat.side == self.Side
    if sideOk and cat and cat.build then
      local ok = false
      if type(cat.requires) == 'table' then
        ok = true
        for reqKey,qty in pairs(cat.requires) do if (counts[reqKey] or 0) < (qty or 0) then ok = false; break end end
      else
        ok = ((counts[key] or 0) >= (cat.required or 1))
      end
      if ok then
        if not (cat.isFOB and self.Config.RestrictFOBToZones and not insideFOBZone) then
          table.insert(items, { key = key, def = cat })
        end
      end
    end
  end

  if #items == 0 then
    MENU_GROUP_COMMAND:New(group, 'None buildable here. Drop required crates close to your aircraft.', dynRoot, function()
      MESSAGE:New('No buildable items with nearby crates. Use Recipe Info to check requirements.', 10):ToGroup(group)
    end)
    return
  end

  -- Stable ordering by label
  table.sort(items, function(a,b)
    local la = (a.def and (a.def.menu or a.def.description)) or a.key
    local lb = (b.def and (b.def.menu or b.def.description)) or b.key
    return tostring(la) < tostring(lb)
  end)

  -- Create per-item submenus
  local function CMD(title, parent, cb)
    return MENU_GROUP_COMMAND:New(group, title, parent, function()
      local ok, err = pcall(cb)
      if not ok then _logVerbose('BuildAdv menu error: '..tostring(err)); MESSAGE:New('CTLD menu error: '..tostring(err), 8):ToGroup(group) end
    end)
  end

  for _,it in ipairs(items) do
    local label = (it.def and (it.def.menu or it.def.description)) or it.key
    local perItem = MENU_GROUP:New(group, label, dynRoot)
    local cd = tonumber(self.Config.BuildCooldownSeconds) or 0
    local holdTitle, attackTitle
    if cd <= 0 then
      holdTitle = 'Build All [Hold Position]'
      attackTitle = string.format('Build All [Attack (%dm)]', (self.Config.AttackAI and self.Config.AttackAI.VehicleSearchRadius) or 5000)
    else
      holdTitle = string.format('Build (w/%ds throttle) [Hold Position]', cd)
      attackTitle = string.format('Build (w/%ds throttle) [Attack (%dm)]', cd, (self.Config.AttackAI and self.Config.AttackAI.VehicleSearchRadius) or 5000)
    end
    -- Hold Position
    CMD(holdTitle, perItem, function()
      self:BuildSpecificAtGroup(group, it.key, { behavior = 'defend' })
    end)
    -- Attack variant (render even if canAttackMove=false; we message accordingly)
    local vr = (self.Config.AttackAI and self.Config.AttackAI.VehicleSearchRadius) or 5000
    CMD(attackTitle, perItem, function()
      if it.def and it.def.canAttackMove == false then
        MESSAGE:New('This unit is static or not suited to move; it will hold position.', 8):ToGroup(group)
        self:BuildSpecificAtGroup(group, it.key, { behavior = 'defend' })
      else
        self:BuildSpecificAtGroup(group, it.key, { behavior = 'attack' })
      end
    end)
  end
end

-- Build a specific recipe at the group position if crates permit; supports behavior opts
function CTLD:BuildSpecificAtGroup(group, recipeKey, opts)
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  local ctld = self
  -- Reuse Build cooldown/confirm logic
  local now = timer.getTime()
  local gname = group:GetName()
  if self.Config.BuildCooldownEnabled then
    local cd = tonumber(self.Config.BuildCooldownSeconds) or 0
    if cd > 0 then
      local last = CTLD._buildCooldown[gname]
      if last and (now - last) < cd then
        local rem = math.max(0, math.ceil(cd - (now - last)))
        _msgGroup(group, string.format('Build on cooldown. Try again in %ds.', rem))
        return
      end
    end
  end
  if self.Config.BuildConfirmEnabled then
    local first = CTLD._buildConfirm[gname]
    local win = self.Config.BuildConfirmWindowSeconds or 10
    if not first or (now - first) > win then
      CTLD._buildConfirm[gname] = now
      _msgGroup(group, string.format('Confirm build: select again within %ds to proceed.', win))
      return
    else
      CTLD._buildConfirm[gname] = nil
    end
  end

  local def = self.Config.CrateCatalog[recipeKey]
  if not def or not def.build then _msgGroup(group, 'Unknown or unbuildable recipe: '..tostring(recipeKey)); return end

  local p = unit:GetPointVec3()
  local here = { x = p.x, z = p.z }
  local hdgRad, hdgDeg = _headingRadDeg(unit)
  local buildOffset = math.max(0, tonumber(self.Config.BuildSpawnOffset or 0) or 0)
  local spawnAt = (buildOffset > 0) and { x = here.x + math.sin(hdgRad) * buildOffset, z = here.z + math.cos(hdgRad) * buildOffset } or { x = here.x, z = here.z }
  local radius = self.Config.BuildRadius or 100
  local nearby = self:GetNearbyCrates(here, radius)
  local filtered = {}
  for _,c in ipairs(nearby) do if c.meta.side == self.Side then table.insert(filtered, c) end end
  nearby = filtered
  if #nearby == 0 and self.Config.BuildRequiresGroundCrates ~= true then
    -- still can build using carried crates
  elseif #nearby == 0 then
    _eventSend(self, group, nil, 'build_insufficient_crates', { build = def.description or recipeKey })
    return
  end

  -- Count by key
  local counts = {}
  for _,c in ipairs(nearby) do counts[c.meta.key] = (counts[c.meta.key] or 0) + 1 end
  -- Include carried crates
  local carried = CTLD._loadedCrates[gname]
  if self.Config.BuildRequiresGroundCrates ~= true then
    if carried and carried.byKey then for k,v in pairs(carried.byKey) do counts[k] = (counts[k] or 0) + v end end
  end

  -- Helper to consume crates of a given key/qty (prefers carried when allowed)
  local function consumeCrates(key, qty)
    local removed = 0
    if self.Config.BuildRequiresGroundCrates ~= true then
      if carried and carried.byKey and (carried.byKey[key] or 0) > 0 then
        local take = math.min(qty, carried.byKey[key])
        carried.byKey[key] = carried.byKey[key] - take
        if carried.byKey[key] <= 0 then carried.byKey[key] = nil end
        carried.total = math.max(0, (carried.total or 0) - take)
        removed = removed + take
        if take > 0 then ctld:_scheduleLoadedCrateMenuRefresh(group) end
      end
    end
    for _,c in ipairs(nearby) do
      if removed >= qty then break end
      if c.meta.key == key then
        local obj = StaticObject.getByName(c.name)
        if obj then obj:destroy() end
        _cleanupCrateSmoke(c.name)  -- Clean up smoke refresh schedule
        if c.meta and c.meta.point then
          _removeFromSpatialGrid(c.name, c.meta.point, 'crate')  -- prune hover pickup spatial cache
        end
        CTLD._crates[c.name] = nil
        removed = removed + 1
      end
    end
  end

  -- FOB restriction check
  if def.isFOB and self.Config.RestrictFOBToZones then
    local inside = select(1, self:IsPointInFOBZones(here))
    if not inside then _eventSend(self, group, nil, 'fob_restricted', {}); return end
  end

  -- Special-case: SAM Site Repair/Augment entries (isRepair)
  if def.isRepair == true or tostring(recipeKey):find('_REPAIR', 1, true) then
    -- Map recipe key family to a template definition
    local function identifyTemplate(key)
      if key:find('HAWK', 1, true) then
        return {
          name='HAWK', side=def.side or self.Side,
          baseUnits={ {type='Hawk sr', dx=12, dz=8}, {type='Hawk tr', dx=-12, dz=8}, {type='Hawk pcp', dx=18, dz=12}, {type='Hawk cwar', dx=-18, dz=12} },
          launcherType='Hawk ln', launcherStart={dx=0, dz=0}, launcherStep={dx=6, dz=0}, maxLaunchers=6
        }
      elseif key:find('PATRIOT', 1, true) then
        return {
          name='PATRIOT', side=def.side or self.Side,
          baseUnits={ {type='Patriot str', dx=14, dz=10}, {type='Patriot ECS', dx=-14, dz=10} },
          launcherType='Patriot ln', launcherStart={dx=0, dz=0}, launcherStep={dx=8, dz=0}, maxLaunchers=6
        }
      elseif key:find('KUB', 1, true) then
        return {
          name='KUB', side=def.side or self.Side,
          baseUnits={ {type='Kub 1S91 str', dx=12, dz=8} },
          launcherType='Kub 2P25 ln', launcherStart={dx=0, dz=0}, launcherStep={dx=6, dz=0}, maxLaunchers=3
        }
      elseif key:find('BUK', 1, true) then
        return {
          name='BUK', side=def.side or self.Side,
          baseUnits={ {type='SA-11 Buk SR 9S18M1', dx=12, dz=8}, {type='SA-11 Buk CC 9S470M1', dx=-12, dz=8} },
          launcherType='SA-11 Buk LN 9A310M1', launcherStart={dx=0, dz=0}, launcherStep={dx=6, dz=0}, maxLaunchers=6
        }
      end
      return nil
    end

    local tpl = identifyTemplate(tostring(recipeKey))
    if not tpl then _msgGroup(group, 'No matching SAM site type for repair: '..tostring(recipeKey)); return end

    -- Determine how many repair crates to apply
    local cratesAvail = counts[recipeKey] or 0
    if cratesAvail <= 0 then _eventSend(self, group, nil, 'build_insufficient_crates', { build = def.description or recipeKey }); return end

    -- Find nearest existing site group that matches template
    local function vec2(u)
      local p = u:getPoint(); return { x = p.x, z = p.z }
    end
    local function dist2(a,b)
      local dx, dz = a.x-b.x, a.z-b.z; return math.sqrt(dx*dx+dz*dz)
    end
    local searchR = math.max(250, (self.Config.BuildRadius or 100) * 10)
    local groups = coalition.getGroups(tpl.side, Group.Category.GROUND) or {}
    local here2 = { x = here.x, z = here.z }
    local bestG, bestD, bestInfo = nil, 1e9, nil
    for _,g in ipairs(groups) do
      if g and g:isExist() then
        local units = g:getUnits() or {}
        if #units > 0 then
          -- Compute center and count types
          local cx, cz = 0, 0
          local byType = {}
          for _,u in ipairs(units) do
            local pt = u:getPoint(); cx = cx + pt.x; cz = cz + pt.z
            local tname = u:getTypeName() or ''
            byType[tname] = (byType[tname] or 0) + 1
          end
          cx = cx / #units; cz = cz / #units
          local d = dist2(here2, { x = cx, z = cz })
          if d <= searchR then
            -- Check presence of base units (at least 1 each)
            local ok = true
            for _,u in ipairs(tpl.baseUnits) do if (byType[u.type] or 0) < 1 then ok = false; break end end
            -- Require at least 1 launcher or allow 0 (initial repair to full base)? we'll allow 0 too.
            if ok then
              if d < bestD then
                bestG, bestD = g, d
                bestInfo = { byType = byType, center = { x = cx, z = cz }, headingDeg = function()
                  local h = 0; local leader = units[1]; if leader and leader.isExist and leader:isExist() then h = math.deg(leader:getHeading() or 0) end; return h
                end }
              end
            end
          end
        end
      end
    end

    if not bestG then
      _msgGroup(group, 'No matching SAM site found nearby to repair/augment.')
      return
    end

    -- Current launchers in site
    local curLaunchers = (bestInfo and bestInfo.byType and bestInfo.byType[tpl.launcherType]) or 0
    local maxL = tpl.maxLaunchers or (curLaunchers + cratesAvail)
    local canAdd = math.max(0, (maxL - curLaunchers))
    if canAdd <= 0 then
      _msgGroup(group, 'SAM site is already at max launchers.')
      return
    end
    local addNum = math.min(cratesAvail, canAdd)

    -- Build new group composition: base units + (curLaunchers + addNum) launchers
    local function buildSite(point, headingDeg, side, launcherCount)
      local hdg = math.rad(headingDeg or 0)
      local function off(dx, dz)
        -- rotate offsets by heading
        local s, c = math.sin(hdg), math.cos(hdg)
        local rx = dx * c + dz * s
        local rz = -dx * s + dz * c
        return { x = point.x + rx, z = point.z + rz }
      end
      local units = {}
      -- Place launchers in a row starting at launcherStart and stepping by launcherStep
      for i=0, (launcherCount-1) do
        local dx = (tpl.launcherStart.dx or 0) + (tpl.launcherStep.dx or 0) * i
        local dz = (tpl.launcherStart.dz or 0) + (tpl.launcherStep.dz or 0) * i
        local p = off(dx, dz)
        table.insert(units, { type = tpl.launcherType, name = string.format('CTLD-%s-%d', tpl.launcherType, math.random(100000,999999)), x = p.x, y = p.z, heading = hdg })
      end
      -- Place base units at their template offsets
      for _,u in ipairs(tpl.baseUnits) do
        local p = off(u.dx or 0, u.dz or 0)
        table.insert(units, { type = u.type, name = string.format('CTLD-%s-%d', u.type, math.random(100000,999999)), x = p.x, y = p.z, heading = hdg })
      end
      return { visible=false, lateActivation=false, tasks={}, task='Ground Nothing', route={}, units=units, name=string.format('CTLD_SITE_%d', math.random(100000,999999)) }
    end

    _eventSend(self, group, nil, 'build_started', { build = def.description or recipeKey })
    -- Destroy old group, spawn new one
    local oldName = bestG:getName()
    local newLauncherCount = curLaunchers + addNum
    local center = bestInfo and bestInfo.center
    if not center then
      _msgGroup(group, 'Failed to determine SAM site center position.')
      return
    end
    local headingDeg = (bestInfo and bestInfo.headingDeg and bestInfo.headingDeg()) or 0
    if Group.getByName(oldName) then pcall(function() Group.getByName(oldName):destroy() end) end
    local gdata = buildSite({ x = center.x, z = center.z }, headingDeg, tpl.side, newLauncherCount)
    local newG = _coalitionAddGroup(tpl.side, Group.Category.GROUND, gdata, self.Config)
    if not newG then _eventSend(self, group, nil, 'build_failed', { reason = 'DCS group spawn error' }); return end
    -- Consume used repair crates
    consumeCrates(recipeKey, addNum)
    _eventSend(self, nil, self.Side, 'build_success_coalition', { build = (def.description or recipeKey), player = _playerNameFromGroup(group) })
    if self.Config.BuildCooldownEnabled then CTLD._buildCooldown[gname] = now end
    return
  end

  -- Verify counts and build (supports multi-build when cooldown is zero)
  if type(def.requires) == 'table' then
    local cd = tonumber(self.Config.BuildCooldownSeconds) or 0
    local maxCopies = 1
    if cd <= 0 then
      maxCopies = math.huge
      for reqKey,qty in pairs(def.requires) do
        if (qty or 0) > 0 then
          local available = counts[reqKey] or 0
          local copiesForKey = math.floor(available / (qty or 1))
          if copiesForKey < maxCopies then maxCopies = copiesForKey end
        end
      end
      if maxCopies < 1 or maxCopies == math.huge then
        _eventSend(self, group, nil, 'build_insufficient_crates', { build = def.description or recipeKey })
        return
      end
    else
      for reqKey,qty in pairs(def.requires) do
        if (counts[reqKey] or 0) < (qty or 0) then
          _eventSend(self, group, nil, 'build_insufficient_crates', { build = def.description or recipeKey })
          return
        end
      end
      maxCopies = 1
    end

    local built = 0
    while built < maxCopies do
	  local gdata = def.build({ x = spawnAt.x, z = spawnAt.z }, hdgDeg, def.side or self.Side)
      _eventSend(self, group, nil, 'build_started', { build = def.description or recipeKey })
      local g = _coalitionAddGroup(def.side or self.Side, def.category or Group.Category.GROUND, gdata, self.Config)
      if not g then
        _eventSend(self, group, nil, 'build_failed', { reason = 'DCS group spawn error' })
        break
      end
      if self.Config.JTAC and self.Config.JTAC.Verbose then
        _logInfo(string.format('JTAC pre: post-build (composite) key=%s group=%s', tostring(recipeKey), tostring(g:getName())))
      end
	  self:_maybeRegisterJTAC(recipeKey, def, g)
      for reqKey,qty in pairs(def.requires) do
        consumeCrates(reqKey, qty or 0)
        counts[reqKey] = (counts[reqKey] or 0) - (qty or 0)
      end
      _eventSend(self, nil, self.Side, 'build_success_coalition', { build = def.description or recipeKey, player = _playerNameFromGroup(group) })
      _logInfo(string.format('[BUILD_DEBUG] Built key=%s desc=%s isFOB=%s isMobileMASH=%s', tostring(recipeKey), tostring(def.description), tostring(def.isFOB), tostring(def.isMobileMASH)))
      if def.isFOB then pcall(function() self:_CreateFOBPickupZone({ x = spawnAt.x, z = spawnAt.z }, def, hdg) end) end
      if def.isMobileMASH then
        _logInfo(string.format('[MobileMASH] BuildSpecificAtGroup invoking _CreateMobileMASH for key %s at (%.1f, %.1f)', tostring(recipeKey), spawnAt.x or -1, spawnAt.z or -1))
        local ok, err = pcall(function() self:_CreateMobileMASH(g, { x = spawnAt.x, z = spawnAt.z }, def) end)
        if not ok then
          _logError(string.format('[MobileMASH] _CreateMobileMASH invocation failed: %s', tostring(err)))
        end
      end
      -- behavior (applied for each built group)
      local behavior = opts and opts.behavior or nil
      if behavior == 'attack' and (def.canAttackMove ~= false) and self.Config.AttackAI and self.Config.AttackAI.Enabled then
        local t = self:_assignAttackBehavior(g:getName(), spawnAt, true)
        local isMetric = _getPlayerIsMetric(group:GetUnit(1))
        if t and t.kind == 'base' then
          local brg = _bearingDeg(spawnAt, t.point)
          local v, u = _fmtRange(t.dist or 0, isMetric)
          _eventSend(self, nil, self.Side, 'attack_base_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), base_name = t.name, brg = brg, rng = v, rng_u = u })
        elseif t and t.kind == 'enemy' then
          local brg = _bearingDeg(spawnAt, t.point)
          local v, u = _fmtRange(t.dist or 0, isMetric)
          _eventSend(self, nil, self.Side, 'attack_enemy_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), enemy_type = t.etype or 'unit', brg = brg, rng = v, rng_u = u })
        else
          local v, u = _fmtRange((self.Config.AttackAI and self.Config.AttackAI.VehicleSearchRadius) or 5000, isMetric)
          _eventSend(self, nil, self.Side, 'attack_no_targets', { unit_name = g:getName(), player = _playerNameFromGroup(group), rng = v, rng_u = u })
        end
      elseif behavior == 'attack' and def.canAttackMove == false then
        MESSAGE:New('This unit is static or not suited to move; it will hold position.', 8):ToGroup(group)
      end

      built = built + 1
      if cd > 0 then break end
    end

    if self.Config.BuildCooldownEnabled and cd > 0 then CTLD._buildCooldown[gname] = now end
    return
  else
    -- single-key
    local need = def.required or 1
    local cd = tonumber(self.Config.BuildCooldownSeconds) or 0
    local maxCopies = 1
    if cd <= 0 then
      local available = counts[recipeKey] or 0
      maxCopies = math.floor(available / need)
      if maxCopies < 1 then
        _eventSend(self, group, nil, 'build_insufficient_crates', { build = def.description or recipeKey })
        return
      end
    else
      if (counts[recipeKey] or 0) < need then _eventSend(self, group, nil, 'build_insufficient_crates', { build = def.description or recipeKey }); return end
      maxCopies = 1
    end

    local built = 0
    while built < maxCopies do
	  local gdata = def.build({ x = spawnAt.x, z = spawnAt.z }, hdgDeg, def.side or self.Side)
      _eventSend(self, group, nil, 'build_started', { build = def.description or recipeKey })
      local g = _coalitionAddGroup(def.side or self.Side, def.category or Group.Category.GROUND, gdata, self.Config)
      if not g then _eventSend(self, group, nil, 'build_failed', { reason = 'DCS group spawn error' }); break end
      if self.Config.JTAC and self.Config.JTAC.Verbose then
        _logInfo(string.format('JTAC pre: post-build (single) key=%s group=%s', tostring(recipeKey), tostring(g:getName())))
      end
	  self:_maybeRegisterJTAC(recipeKey, def, g)
      consumeCrates(recipeKey, need)
      counts[recipeKey] = (counts[recipeKey] or 0) - need
      _eventSend(self, nil, self.Side, 'build_success_coalition', { build = def.description or recipeKey, player = _playerNameFromGroup(group) })
      -- behavior
      local behavior = opts and opts.behavior or nil
      if behavior == 'attack' and (def.canAttackMove ~= false) and self.Config.AttackAI and self.Config.AttackAI.Enabled then
        local t = self:_assignAttackBehavior(g:getName(), spawnAt, true)
        local isMetric = _getPlayerIsMetric(group:GetUnit(1))
        if t and t.kind == 'base' then
          local brg = _bearingDeg(spawnAt, t.point)
          local v, u = _fmtRange(t.dist or 0, isMetric)
          _eventSend(self, nil, self.Side, 'attack_base_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), base_name = t.name, brg = brg, rng = v, rng_u = u })
        elseif t and t.kind == 'enemy' then
          local brg = _bearingDeg(spawnAt, t.point)
          local v, u = _fmtRange(t.dist or 0, isMetric)
          _eventSend(self, nil, self.Side, 'attack_enemy_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), enemy_type = t.etype or 'unit', brg = brg, rng = v, rng_u = u })
        else
          local v, u = _fmtRange((self.Config.AttackAI and self.Config.AttackAI.VehicleSearchRadius) or 5000, isMetric)
          _eventSend(self, nil, self.Side, 'attack_no_targets', { unit_name = g:getName(), player = _playerNameFromGroup(group), rng = v, rng_u = u })
        end
      elseif behavior == 'attack' and def.canAttackMove == false then
        MESSAGE:New('This unit is static or not suited to move; it will hold position.', 8):ToGroup(group)
      end

      built = built + 1
      if cd > 0 then break end
    end

    if self.Config.BuildCooldownEnabled and cd > 0 then CTLD._buildCooldown[gname] = now end
    return
  end
end

function CTLD:_definitionIsJTAC(def)
  if not def then return false end
  if def.isJTAC == true then return true end
  if type(def.jtac) == 'table' and def.jtac.enabled ~= false then return true end
  if type(def.roles) == 'table' then
    for _, role in ipairs(def.roles) do
      if tostring(role):upper() == 'JTAC' then
        return true
      end
    end
  end
  return false
end

function CTLD:_maybeRegisterJTAC(recipeKey, def, dcsGroup)
  if not (self.Config.JTAC and self.Config.JTAC.Enabled) then
    if self.Config and self.Config.JTAC and self.Config.JTAC.Verbose then
      _logInfo('JTAC check: JTAC disabled in config; skipping registration')
    end
    return
  end
  if not self:_definitionIsJTAC(def) then
    if self.Config and self.Config.JTAC and self.Config.JTAC.Verbose then
      local hasRoles = (def and type(def.roles) == 'table') and table.concat((function(r) local t={} for i,v in ipairs(r) do t[i]=tostring(v) end return t end)(def.roles),'|') or '(none)'
      local hasJTAC = (def and type(def.jtac) == 'table') and 'yes' or 'no'
      _logInfo(string.format('JTAC check: definition not JTAC. key=%s jtacTable=%s roles=%s isJTAC=%s', tostring(recipeKey), hasJTAC, hasRoles, tostring(def and def.isJTAC)))
    end
    return
  end
  if not dcsGroup then
    if self.Config and self.Config.JTAC and self.Config.JTAC.Verbose then
      _logInfo(string.format('JTAC check: no DCS group to register. key=%s', tostring(recipeKey)))
    end
    return
  end
  if self.Config.JTAC and self.Config.JTAC.Verbose then
    _logInfo(string.format('JTAC check: attempting registration. key=%s unitType=%s group=%s', tostring(recipeKey), tostring(def and def.unitType or def and def.description or 'n/a'), tostring(dcsGroup and dcsGroup.getName and dcsGroup:getName() or '')))
  end
  self:_registerJTACGroup(recipeKey, def, dcsGroup)
end

function CTLD:_reserveJTACCode(side, groupName)
  local pool = self.Config.JTAC and self.Config.JTAC.LaserCodes or { '1688' }
  if not CTLD._jtacReservedCodes then
    CTLD._jtacReservedCodes = { [coalition.side.BLUE] = {}, [coalition.side.RED] = {}, [coalition.side.NEUTRAL] = {} }
  end
  CTLD._jtacReservedCodes[side] = CTLD._jtacReservedCodes[side] or {}
  for _, code in ipairs(pool) do
    code = tostring(code)
    if not CTLD._jtacReservedCodes[side][code] then
      CTLD._jtacReservedCodes[side][code] = groupName
      return code
    end
  end
  local fallback = tostring(pool[1] or '1688')
  _logVerbose(string.format('JTAC laser code pool exhausted for side %s, reusing %s', tostring(side), fallback))
  return fallback
end

function CTLD:_releaseJTACCode(side, code, groupName)
  if not code then return end
  code = tostring(code)
  if CTLD._jtacReservedCodes and CTLD._jtacReservedCodes[side] then
    if CTLD._jtacReservedCodes[side][code] == groupName then
      CTLD._jtacReservedCodes[side][code] = nil
    end
  end
end

function CTLD:_registerJTACGroup(recipeKey, def, dcsGroup)
  if not (dcsGroup and dcsGroup.getName) then return end
  local groupName = dcsGroup:getName()
  if not groupName then return end

  self:_cleanupJTACEntry(groupName) -- ensure stale entry cleared

  local side = dcsGroup:getCoalition() or self.Side
  local code = self:_reserveJTACCode(side, groupName)
  local platform = 'ground'
  if def and def.jtac and def.jtac.platform then
    platform = tostring(def.jtac.platform)
  elseif def and def.category == Group.Category.AIRPLANE then
    platform = 'air'
  end
  local cfgSmoke = self.Config.JTAC and self.Config.JTAC.Smoke or {}
  local smokeColor = (side == coalition.side.BLUE) and cfgSmoke.ColorBlue or cfgSmoke.ColorRed

  local entry = {
    groupName = groupName,
    recipeKey = recipeKey,
    def = def,
    side = side,
    code = code,
    platform = platform,
    smokeColor = smokeColor,
    nextScan = timer.getTime() + 2,
    smokeNext = 0,
    lockType = def and def.jtac and def.jtac.lock,
  }

  local friendlyName = (def and self:_friendlyNameForKey(recipeKey)) or groupName
  entry.displayName = friendlyName
  entry.lastState = 'onstation'

  self._jtacRegistry[groupName] = entry

  self:_announceJTAC('jtac_onstation', entry, {
    jtac = friendlyName,
    code = code,
  })

  _logInfo(string.format('JTAC registered: group=%s friendlyName=%s code=%s platform=%s verbose=%s', tostring(groupName), tostring(friendlyName), tostring(code), tostring(platform), tostring(self.Config.JTAC and self.Config.JTAC.Verbose)))
end

function CTLD:_announceJTAC(msgKey, entry, payload)
  if not entry then return end
  local cfg = self.Config.JTAC and self.Config.JTAC.Announcements
  local allowed = true
  if entry and entry.announceOverride ~= nil then
    allowed = entry.announceOverride == true
  else
    allowed = (cfg and cfg.Enabled ~= false)
  end
  if not allowed then return end
  local tpl = CTLD.Messages[msgKey]
  if not tpl then return end
  local data = payload or {}
  data.jtac = data.jtac or entry.displayName or entry.groupName
  data.code = data.code or entry.code
  local text = _fmtTemplate(tpl, data)
  if text and text ~= '' then
    _msgCoalition(entry.side or self.Side, text, cfg.Duration or self.Config.MessageDuration)
  end
end

function CTLD:_cleanupJTACEntry(groupName)
  local entry = self._jtacRegistry and self._jtacRegistry[groupName]
  if not entry then return end
  self:_cancelJTACSpots(entry)
  self:_releaseJTACCode(entry.side or self.Side, entry.code, groupName)
  self._jtacRegistry[groupName] = nil
end

function CTLD:_cancelJTACSpots(entry)
  if not entry then return end
  if entry.laserSpot then
    pcall(function() Spot.destroy(entry.laserSpot) end)
    entry.laserSpot = nil
  end
  if entry.irSpot then
    pcall(function() Spot.destroy(entry.irSpot) end)
    entry.irSpot = nil
  end
end

function CTLD:_tickJTACs()
  if not self._jtacRegistry then return end
  if not next(self._jtacRegistry) then return end
  local now = timer.getTime()
  for groupName, entry in pairs(self._jtacRegistry) do
    if not entry.nextScan or now >= entry.nextScan then
      local ok, err = pcall(function()
        self:_processJTACEntry(groupName, entry, now)
      end)
      if not ok then
        _logError(string.format('JTAC tick error for %s: %s', tostring(groupName), tostring(err)))
        entry.nextScan = now + 10
      end
    end
  end
end

function CTLD:_processJTACEntry(groupName, entry, now)
  local cfg = self.Config.JTAC or {}
  local autoCfg = cfg.AutoLase or {}
  if autoCfg.Enabled == false then
    self:_cancelJTACSpots(entry)
    entry.nextScan = now + 30
    return
  end
  if entry.paused then
    self:_cancelJTACSpots(entry)
    entry.nextScan = now + 30
    entry.lastState = 'paused'
    return
  end
  local group = Group.getByName(groupName)
  if not group or not group:isExist() then
    self:_cleanupJTACEntry(groupName)
    return
  end

  local units = group:getUnits() or {}
  if #units == 0 then
    self:_cancelJTACSpots(entry)
    entry.nextScan = now + (autoCfg.TransportHoldSeconds or 10)
    return
  end

  local jtacUnit = units[1]
  if not jtacUnit or jtacUnit:getLife() <= 0 or not jtacUnit:isActive() then
    self:_cleanupJTACEntry(groupName)
    return
  end

  entry.jtacUnitName = entry.jtacUnitName or jtacUnit:getName()
  entry.displayName = entry.displayName or entry.jtacUnitName or groupName

  local jtacPoint = jtacUnit:getPoint()
  local searchRadius = tonumber(entry.searchRadiusOverride or autoCfg.SearchRadius) or 8000
  if cfg.Verbose then
    _logInfo(string.format('JTAC tick: group=%s unit=%s radius=%.0f pos=(%.0f,%.0f,%.0f)', tostring(groupName), tostring(entry.jtacUnitName or jtacUnit:getName()), searchRadius, jtacPoint.x or -1, jtacPoint.y or -1, jtacPoint.z or -1))
  end

  local current = entry.currentTarget
  local targetUnit = nil
  local targetStatus = nil

  if current and current.name then
    local candidate = Unit.getByName(current.name)
    if candidate and candidate:isExist() and candidate:getLife() > 0 then
      local tgtPoint = candidate:getPoint()
      local dist = _distance3d(tgtPoint, jtacPoint)
      if dist <= searchRadius and _hasLineOfSight(jtacPoint, tgtPoint) then
        targetUnit = candidate
        current.lastSeen = now
        current.distance = dist
      else
        targetStatus = 'lost'
      end
    else
      targetStatus = 'destroyed'
    end
    if targetStatus then
      if targetStatus == 'destroyed' then
        if entry.lastState ~= 'destroyed' then
          self:_announceJTAC('jtac_target_destroyed', entry, {
            jtac = entry.displayName,
            target = current.label or current.name,
            code = entry.code,
          })
          entry.lastState = 'destroyed'
        end
      else
        if entry.lastState ~= 'lost' then
          self:_announceJTAC('jtac_target_lost', entry, {
            jtac = entry.displayName,
            target = current.label or current.name,
          })
          entry.lastState = 'lost'
        end
      end
      entry.currentTarget = nil
      targetUnit = nil
      self:_cancelJTACSpots(entry)
      entry.nextScan = now + (targetStatus == 'lost' and (autoCfg.LostRetrySeconds or 10) or 5)
    end
  end

  if not targetUnit then
    local lockPref = entry.lockType or cfg.LockType or 'all'
    local selection = self:_findJTACNewTarget(entry, jtacPoint, searchRadius, lockPref)
    if cfg.Verbose then
      _logInfo(string.format('JTAC scan: group=%s lock=%s found=%s', tostring(groupName), tostring(lockPref), selection and (selection.unit and selection.unit:getTypeName()) or 'nil'))
    end
    if selection then
      targetUnit = selection.unit
      entry.currentTarget = {
        name = targetUnit:getName(),
        label = targetUnit:getTypeName(),
        firstSeen = now,
        lastSeen = now,
        distance = selection.distance,
      }
      local grid = self:_GetMGRSString(targetUnit:getPoint())
      local newState = 'target:'..(entry.currentTarget.name or '')
      if entry.lastState ~= newState then
        self:_announceJTAC('jtac_new_target', entry, {
          jtac = entry.displayName,
          target = targetUnit:getTypeName(),
          code = entry.code,
          grid = grid,
        })
        entry.lastState = newState
      end
    end
  end

  if targetUnit then
    self:_updateJTACSpots(entry, jtacUnit, targetUnit)
    entry.nextScan = now + (autoCfg.RefreshSeconds or 15)
    if cfg.Verbose then
      _logInfo(string.format('JTAC lase: group=%s target=%s code=%s', tostring(groupName), tostring(targetUnit and targetUnit:getTypeName()), tostring(entry.code)))
    end
  else
    self:_cancelJTACSpots(entry)
    entry.nextScan = now + (autoCfg.IdleRescanSeconds or 30)
    if entry.lastState ~= 'idle' then
      self:_announceJTAC('jtac_idle', entry, {
        jtac = entry.displayName,
      })
      entry.lastState = 'idle'
    end
  end
end

function CTLD:ListJTACStatus(group)
  local lines = {}
  table.insert(lines, 'JTAC Status')
  table.insert(lines, '')
  if not self._jtacRegistry or not next(self._jtacRegistry) then
    table.insert(lines, '(none registered)')
  else
    local now = timer.getTime()
    for gname, entry in pairs(self._jtacRegistry) do
      local tgt = entry.currentTarget and entry.currentTarget.label or '(idle)'
      local age = entry.currentTarget and (now - (entry.currentTarget.firstSeen or now)) or 0
      local nextScan = entry.nextScan and (entry.nextScan - now) or -1
      table.insert(lines, string.format('- %s code=%s plat=%s state=%s target=%s age=%.0fs nextScan=%.0fs',
        entry.displayName or gname, tostring(entry.code), tostring(entry.platform), tostring(entry.lastState), tgt, age, nextScan))
    end
  end
  local text = table.concat(lines, '\n')
  if group and group:IsAlive() then
    MESSAGE:New(text, 20):ToGroup(group)
  else
    _msgCoalition(self.Side, text, 20)
  end
end

function CTLD:JTACDiagnostics(group)
  local lines = {}
  table.insert(lines, 'JTAC Diagnostics')
  local cfg = self.Config.JTAC or {}
  table.insert(lines, string.format('Enabled=%s Verbose=%s LockType=%s', tostring(cfg.Enabled), tostring(cfg.Verbose), tostring(cfg.LockType)))
  local auto = cfg.AutoLase or {}
  table.insert(lines, string.format('AutoLase Enabled=%s Radius=%s Refresh=%s IdleRescan=%s LostRetry=%s', tostring(auto.Enabled), tostring(auto.SearchRadius), tostring(auto.RefreshSeconds), tostring(auto.IdleRescanSeconds), tostring(auto.LostRetrySeconds)))
  local countCatalog = 0
  local jtacKeys = {}
  for key,def in pairs(self.Config.CrateCatalog or {}) do
    if self:_definitionIsJTAC(def) then
      countCatalog = countCatalog + 1
      table.insert(jtacKeys, key)
    end
  end
  table.insert(lines, string.format('Catalog JTAC Definitions: %d', countCatalog))
  if #jtacKeys > 0 then
    table.insert(lines, 'Keys: '..table.concat(jtacKeys, ', '))
  end
  local regCount = 0
  for _ in pairs(self._jtacRegistry or {}) do regCount = regCount + 1 end
  table.insert(lines, string.format('Registered JTAC Groups: %d', regCount))
  if regCount > 0 then
    for gname, entry in pairs(self._jtacRegistry) do
      table.insert(lines, string.format(' Reg: %s code=%s state=%s', gname, tostring(entry.code), tostring(entry.lastState)))
    end
  end
  local text = table.concat(lines, '\n')
  if group and group:IsAlive() then
    MESSAGE:New(text, 25):ToGroup(group)
  else
    _msgCoalition(self.Side, text, 25)
  end
end

-- =========================
-- JTAC Controls (per-group active selection)
-- =========================

function CTLD:_getActiveJTAC(group)
  local gname = group and group:GetName()
  if not gname then return nil end
  CTLD._activeJTACByGroup = CTLD._activeJTACByGroup or {}
  local key = CTLD._activeJTACByGroup[gname]
  if key and self._jtacRegistry and self._jtacRegistry[key] then
    return self._jtacRegistry[key]
  end
  return nil
end

local function _unitVec2(unit)
  local p = unit:GetPointVec3(); return { x = p.x, z = p.z }
end

function CTLD:JTAC_SelectActiveForGroup(group, opts)
  local entries = {}
  for name, entry in pairs(self._jtacRegistry or {}) do table.insert(entries, entry) end
  if #entries == 0 then MESSAGE:New('No JTACs registered yet.', 8):ToGroup(group); return end
  -- choose nearest to player unit
  table.sort(entries, function(a,b)
    local u = group:GetUnit(1); if not u then return false end
    local up = _unitVec2(group:GetUnit(1))
    local function d(e)
      local g = Group.getByName(e.groupName); if not g then return 1e12 end
      local gu = g:getUnits(); if not gu or #gu==0 then return 1e12 end
      local p = gu[1]:getPoint(); local dx = (p.x - up.x); local dz=(p.z - up.z); return math.sqrt(dx*dx+dz*dz)
    end
    return d(a) < d(b)
  end)
  local chosen = entries[1]
  CTLD._activeJTACByGroup = CTLD._activeJTACByGroup or {}
  CTLD._activeJTACByGroup[group:GetName()] = chosen.groupName
  MESSAGE:New(string.format('Active JTAC set to %s (code %s).', chosen.displayName or chosen.groupName, tostring(chosen.code)), 10):ToGroup(group)
end

function CTLD:JTAC_TogglePause(group)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  e.paused = not e.paused
  local msg = e.paused and 'paused' or 'resumed'
  MESSAGE:New(string.format('JTAC %s %s.', e.displayName or e.groupName, msg), 8):ToGroup(group)
end

function CTLD:JTAC_ReleaseTarget(group)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  self:_cancelJTACSpots(e)
  e.currentTarget = nil
  e.nextScan = timer.getTime() + 1
  e.lastState = 'released'
  MESSAGE:New('JTAC target released.', 6):ToGroup(group)
end

function CTLD:JTAC_ForceRescan(group)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  e.currentTarget = nil
  e.nextScan = timer.getTime() + 0.5
  e.lastState = 'rescan'
  MESSAGE:New('JTAC rescan queued.', 6):ToGroup(group)
end

function CTLD:JTAC_SetLockFilter(group, mode)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  e.lockType = (mode or 'all')
  e.currentTarget = nil; e.nextScan = timer.getTime() + 0.5
  MESSAGE:New(string.format('JTAC lock filter set to %s.', mode), 6):ToGroup(group)
end

function CTLD:JTAC_SetPriority(group, profile)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  e.priorityProfile = profile or 'balanced'
  e.currentTarget = nil; e.nextScan = timer.getTime() + 0.5
  MESSAGE:New(string.format('JTAC priority set: %s', profile), 6):ToGroup(group)
end

function CTLD:JTAC_SetSearchRadius(group, meters)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  e.searchRadiusOverride = tonumber(meters)
  e.currentTarget = nil; e.nextScan = timer.getTime() + 0.5
  MESSAGE:New(string.format('JTAC search radius set to %dm.', meters or 0), 6):ToGroup(group)
end

function CTLD:JTAC_ToggleSmoke(group)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  if e.smokeEnabledOverride == nil then
    e.smokeEnabledOverride = not ((self.Config.JTAC and self.Config.JTAC.Smoke and self.Config.JTAC.Smoke.Enabled) ~= false)
  else
    e.smokeEnabledOverride = not e.smokeEnabledOverride
  end
  local state = e.smokeEnabledOverride and 'ON' or 'OFF'
  MESSAGE:New('JTAC smoke '..state..'.', 6):ToGroup(group)
end

function CTLD:JTAC_SetSmokeColor(group, which)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  if which == 'blue' then
    e.smokeColor = trigger.smokeColor.Blue
  elseif which == 'orange' then
    e.smokeColor = trigger.smokeColor.Orange
  end
  MESSAGE:New('JTAC smoke color set.', 6):ToGroup(group)
end

function CTLD:JTAC_ToggleAnnouncements(group)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  if e.announceOverride == nil then
    local cfg = self.Config.JTAC and self.Config.JTAC.Announcements
    e.announceOverride = not (cfg and cfg.Enabled ~= false)
  else
    e.announceOverride = not e.announceOverride
  end
  MESSAGE:New('JTAC announcements '..(e.announceOverride and 'ON' or 'OFF')..'.', 6):ToGroup(group)
end

function CTLD:JTAC_MarkCurrentTarget(group)
  local e = self:_getActiveJTAC(group); if not e then self:JTAC_SelectActiveForGroup(group); e=self:_getActiveJTAC(group) end; if not e then return end
  if not e.currentTarget or not e.currentTarget.name then MESSAGE:New('No current target to mark.', 6):ToGroup(group); return end
  local u = Unit.getByName(e.currentTarget.name); if not u or not u:isExist() then MESSAGE:New('Target no longer valid.', 6):ToGroup(group); return end
  local p = u:getPoint()
  CTLD._markId = (CTLD._markId or 900000) + 1
  local text = string.format('JTAC %s target: %s (code %s)', e.displayName or e.groupName, e.currentTarget.label or e.currentTarget.name, tostring(e.code))
  local side = (group and group.GetCoalition and group:GetCoalition()) or e.side or coalition.side.BLUE
  pcall(function() trigger.action.markToCoalition(CTLD._markId, text, {x=p.x, y=p.y, z=p.z}, side) end)
  MESSAGE:New('Marked current target on map.', 6):ToGroup(group)
end

function CTLD:_findJTACNewTarget(entry, jtacPoint, radius, lockType)
  local enemy = _enemySide(entry and entry.side or self.Side)
  local best
  local lock = (lockType or 'all'):lower()
  local profile = entry and entry.priorityProfile or 'balanced'
  local ok, groups = pcall(function()
    return coalition.getGroups(enemy, Group.Category.GROUND) or {}
  end)
  if not ok then
    groups = {}
  end

  for _, grp in ipairs(groups) do
    if grp and grp:isExist() then
      local units = grp:getUnits()
      if units then
        for _, unit in ipairs(units) do
          if unit and unit:isExist() and unit:isActive() and unit:getLife() > 0 then
            local skip = false
            if lock == 'troop' and not _isDcsInfantry(unit) then skip = true end
            if lock == 'vehicle' and _isDcsInfantry(unit) then skip = true end
            if not skip then
              local pos = unit:getPoint()
              local dist = _distance3d(pos, jtacPoint)
              if dist <= radius and _hasLineOfSight(jtacPoint, pos) then
                local score = _jtacTargetScoreProfiled(unit, profile)
                if not best or score > best.score or (score == best.score and dist < best.distance) then
                  best = { unit = unit, score = score, distance = dist }
                end
              end
            end
          end
        end
      end
    end
  end

  return best
end

function CTLD:_updateJTACSpots(entry, jtacUnit, targetUnit)
  if not (entry and jtacUnit and targetUnit) then return end
  local codeNumber = tonumber(entry.code) or 1688
  local targetPoint = targetUnit:getPoint()
  targetPoint = _vec3(targetPoint.x, targetPoint.y + 2.0, targetPoint.z)
  local origin = { x = 0, y = 2.0, z = 0 }

  if not entry.laserSpot or not entry.irSpot then
    local ok, res = pcall(function()
      local spots = {}
      spots.ir = Spot.createInfraRed(jtacUnit, origin, targetPoint)
      spots.laser = Spot.createLaser(jtacUnit, origin, targetPoint, codeNumber)
      return spots
    end)
    if ok and res then
      entry.irSpot = entry.irSpot or res.ir
      entry.laserSpot = entry.laserSpot or res.laser
    else
      _logError(string.format('JTAC spot create failed for %s: %s', tostring(entry.groupName), tostring(res)))
    end
  else
    pcall(function()
      if entry.laserSpot and entry.laserSpot.setPoint then entry.laserSpot:setPoint(targetPoint) end
      if entry.irSpot and entry.irSpot.setPoint then entry.irSpot:setPoint(targetPoint) end
    end)
  end

  local smokeCfg = self.Config.JTAC and self.Config.JTAC.Smoke or {}
  local smokeAllowed = (entry.smokeEnabledOverride ~= nil) and (entry.smokeEnabledOverride == true) or (entry.smokeEnabledOverride == nil and smokeCfg.Enabled)
  if smokeAllowed then
    local now = timer.getTime()
    if not entry.smokeNext or now >= entry.smokeNext then
      local color = entry.smokeColor or smokeCfg.ColorBlue or trigger.smokeColor.White
      local pos = targetUnit:getPoint()
      local offset = tonumber(smokeCfg.OffsetMeters) or 0
      if offset > 0 then
        local ang = math.random() * math.pi * 2
        pos.x = pos.x + math.cos(ang) * offset
        pos.z = pos.z + math.sin(ang) * offset
      end
      pcall(function()
        trigger.action.smoke({ x = pos.x, y = pos.y, z = pos.z }, color)
      end)
      entry.smokeNext = now + (smokeCfg.RefreshSeconds or 300)
    end
  end
end

function CTLD:BuildCoalitionMenus(root)
  -- Optional: implement coalition-level crate spawns at pickup zones
  for key,_ in pairs(self.Config.CrateCatalog) do
    MENU_COALITION_COMMAND:New(self.Side, 'Spawn '..key..' at nearest Pickup Zone', root, function()
      -- Not group-context; skip here
      _msgCoalition(self.Side, 'Group menus recommended for crate requests')
    end)
  end
end

function CTLD:InitCoalitionAdminMenu()
  if self.AdminMenu then return end
  -- Ensure we have a coalition-level CTLD parent menu to nest Admin/Help under
  local rootCaption = (self.Config and self.Config.UseGroupMenus) and 'CTLD Admin' or 'CTLD'
  self.MenuRoot = self.MenuRoot or MENU_COALITION:New(self.Side, rootCaption)
  local root = MENU_COALITION:New(self.Side, 'Admin/Help', self.MenuRoot)
  -- Player Help submenu (moved to top of Admin/Help)
  local helpMenu = MENU_COALITION:New(self.Side, 'Player Help', root)
  -- Removed standalone "Repair - How To" in favor of consolidated SAM Sites help
  MENU_COALITION_COMMAND:New(self.Side, 'Zones - Guide', helpMenu, function()
    local lines = {}
    table.insert(lines, 'CTLD Zones - Guide')
    table.insert(lines, '')
    table.insert(lines, 'Zone types:')
    table.insert(lines, '- Pickup (Supply): Request crates and load troops here. Crate requests require proximity to an ACTIVE pickup zone (default within 10 km).')
    table.insert(lines, '- Drop: Mission-defined delivery or rally areas. Some missions may require delivery or deployment at these zones (see briefing).')
    table.insert(lines, '- FOB: Forward Operating Base areas. Some recipes (FOB Site) can be built here; if FOB restriction is enabled, FOB-only builds must be inside an FOB zone.')
    table.insert(lines, '')
    table.insert(lines, 'Colors and map marks:')
    table.insert(lines, '- Pickup zone crate spawns are marked with smoke in the configured color. Admin/Help -> Draw CTLD Zones on Map draws zone circles and labels on F10.')
    table.insert(lines, '- Use Admin/Help -> Clear CTLD Map Drawings to remove the drawings. Drawings are read-only if configured.')
    table.insert(lines, '')
    table.insert(lines, 'How to use zones:')
    table.insert(lines, '- To request crates: move within the pickup zone distance and use CTLD -> Request Crate.')
    table.insert(lines, '- To load troops: must be inside a Pickup zone if troop loading restriction is enabled.')
    table.insert(lines, '- Navigation: CTLD -> Coach & Nav -> Vectors to Nearest Pickup Zone gives bearing and range.')
    table.insert(lines, '- Activation: Zones can be active/inactive per mission logic; inactive pickup zones block crate requests.')
    table.insert(lines, '')
    table.insert(lines, string.format('- Build Radius: about %d m to collect nearby crates when building.', self.Config.BuildRadius or 100))
    table.insert(lines, string.format('- Pickup Zone Max Distance: about %d m to request crates (configurable).', self.Config.PickupZoneMaxDistance or 10000))
    _msgCoalition(self.Side, table.concat(lines, '\n'), 40)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Inventory - How It Works', helpMenu, function()
    local inv = self.Config.Inventory or {}
    local enabled = inv.Enabled ~= false
    local showHint = inv.ShowStockInMenu == true
    local fobPct = math.floor(((inv.FOBStockFactor or 0.25) * 100) + 0.5)
    local lines = {}
    table.insert(lines, 'CTLD Inventory - How It Works')
    table.insert(lines, '')
    table.insert(lines, 'Overview:')
    table.insert(lines, '- Inventory is tracked per Supply (Pickup) Zone and per FOB. Requests consume stock at that location.')
    table.insert(lines, string.format('- Inventory is %s.', enabled and 'ENABLED' or 'DISABLED'))
    table.insert(lines, '')
    table.insert(lines, 'Starting stock:')
    table.insert(lines, '- Each configured Supply Zone is seeded from the catalog initialStock for every crate type at mission start.')
    table.insert(lines, string.format('- When you build a FOB, it creates a small Supply Zone with stock seeded at ~%d%% of initialStock.', fobPct))
    table.insert(lines, '')
    table.insert(lines, 'Requesting crates:')
    table.insert(lines, '- You must be within range of an ACTIVE Supply Zone to request crates; stock is decremented on spawn.')
    table.insert(lines, '- If out of stock for a type at that zone, requests are denied for that type until resupplied (mission logic).')
    table.insert(lines, '')
    table.insert(lines, 'UI hints:')
    table.insert(lines, string.format('- Show stock in menu labels: %s.', showHint and 'ON' or 'OFF'))
    table.insert(lines, '- Some missions may include an "In Stock Here" list showing only items available at the nearest zone.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 40)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'CTLD Basics (2-minute tour)', helpMenu, function()
    local isMetric = true
    local lines = {}
    table.insert(lines, 'CTLD Basics - 2 minute tour')
    table.insert(lines, '')
    table.insert(lines, 'Loop: Request -> Deliver -> Build -> Fight')
    table.insert(lines, '- Request crates at an ACTIVE Supply Zone (Pickup).')
    table.insert(lines, '- Deliver crates to the build point (within Build Radius).')
    table.insert(lines, '- Build units or sites with "Build Here" (confirm + cooldown).')
    table.insert(lines, '- Optional: set Attack or Defend behavior when building.')
    table.insert(lines, '')
    table.insert(lines, 'Key concepts:')
    table.insert(lines, '- Zones: Pickup (supply), Drop (mission targets), FOB (forward supply).')
    table.insert(lines, '- Inventory: stock is tracked per zone; requests consume stock there.')
    table.insert(lines, '- FOBs: building one creates a local supply point with seeded stock.')
    table.insert(lines, '- Advanced: SAM site repair crates, AI attack orders, EWR/JTAC support.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 35)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Troop Transport & JTAC Use', helpMenu, function()
    local lines = {}
    table.insert(lines, 'Troop Transport & JTAC Use')
    table.insert(lines, '')
    table.insert(lines, 'Troops:')
    table.insert(lines, '- Load inside an ACTIVE Supply Zone (if mission enforces it).')
    table.insert(lines, '- Deploy with Defend (hold) or Attack (advance to targets/bases).')
    table.insert(lines, '- Attack uses a search radius and moves at configured speed.')
    table.insert(lines, '')
    table.insert(lines, 'JTAC:')
    table.insert(lines, '- Build JTAC units (MRAP/Tigr or drones) to support target marking.')
    table.insert(lines, '- JTAC helps with target designation/SA; details depend on mission setup.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 35)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Crates 101: Requesting and Handling', helpMenu, function()
    local lines = {}
    table.insert(lines, 'Crates 101 - Requesting and Handling')
    table.insert(lines, '')
    table.insert(lines, '- Request crates near an ACTIVE Supply Zone; max distance is configurable.')
    table.insert(lines, '- Menu labels show the total crates required for a recipe.')
    table.insert(lines, '- Drop crates close together but avoid overlap; smoke marks spawns.')
    table.insert(lines, '- Use Coach & Nav tools: vectors to nearest pickup zone, re-mark crate with smoke.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 35)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Hover Pickup & Slingloading', helpMenu, function()
    local coachCfg = CTLD.HoverCoachConfig or {}
    local aglMin = (coachCfg.thresholds and coachCfg.thresholds.aglMin) or 5
    local aglMax = (coachCfg.thresholds and coachCfg.thresholds.aglMax) or 20
    local capGS = (coachCfg.thresholds and coachCfg.thresholds.captureGS) or (4/3.6)
    local hold = (coachCfg.thresholds and coachCfg.thresholds.stabilityHold) or 1.8
    local lines = {}
    table.insert(lines, 'Hover Pickup & Slingloading')
    table.insert(lines, '')
    table.insert(lines, string.format('- Hover pickup: hold AGL %d-%d m, speed < %.1f m/s, for ~%.1f s to auto-load.', aglMin, aglMax, capGS, hold))
    table.insert(lines, '- Keep steady within ~15 m of the crate; Hover Coach gives cues if enabled.')
    table.insert(lines, '- Slingloading tips: avoid rotor wash over stacks; approach from upwind; re-mark crate with smoke if needed.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 35)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Build System: Build Here and Advanced', helpMenu, function()
    local br = self.Config.BuildRadius or 100
    local win = self.Config.BuildConfirmWindowSeconds or 10
    local cd = self.Config.BuildCooldownSeconds or 60
    local lines = {}
    table.insert(lines, 'Build System - Build Here and Advanced')
    table.insert(lines, '')
    table.insert(lines, string.format('- Build Here collects crates within ~%d m. Double-press within %d s to confirm.', br, win))
    table.insert(lines, string.format('- Cooldown: about %d s per group after a successful build.', cd))
    table.insert(lines, '- Advanced Build lets you choose Defend (hold) or Attack (move).')
    table.insert(lines, '- Static or unsuitable units will hold even if Attack is chosen.')
    table.insert(lines, '- FOB-only recipes must be inside an FOB zone when restriction is enabled.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 40)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'FOBs: Forward Supply & Why They Matter', helpMenu, function()
    local fobPct = math.floor(((self.Config.Inventory and self.Config.Inventory.FOBStockFactor or 0.25) * 100) + 0.5)
    local lines = {}
    table.insert(lines, 'FOBs - Forward Supply and Why They Matter')
    table.insert(lines, '')
    table.insert(lines, '- Build a FOB by assembling its crate recipe (see Recipe Info).')
    table.insert(lines, string.format('- A new local Supply Zone is created and seeded at ~%d%% of initial stock.', fobPct))
    table.insert(lines, '- FOBs shorten logistics legs and increase throughput toward the front.')
    table.insert(lines, '- If enabled, FOB-only builds must occur inside FOB zones.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 35)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'SAM Sites: Building, Repairing, and Augmenting', helpMenu, function()
    local br = self.Config.BuildRadius or 100
    local lines = {}
    table.insert(lines, 'SAM Sites - Building, Repairing, and Augmenting')
    table.insert(lines, '')
    table.insert(lines, 'Build:')
    table.insert(lines, '- Assemble site recipes using the required component crates (see menu labels). Build Here will place the full site.')
    table.insert(lines, '')
    table.insert(lines, 'Repair/Augment (merged):')
    table.insert(lines, '- Request the matching "Repair/Launcher +1" crate for your site type (HAWK, Patriot, KUB, BUK).')
    table.insert(lines, string.format('- Drop repair crate(s) within ~%d m of the site, then use Build Here (confirm window applies).', br))
    table.insert(lines, '- The nearest matching site (within a local search) is respawned fully repaired; +1 launcher per crate, up to caps.')
    table.insert(lines, '- Caps: HAWK 6, Patriot 6, KUB 3, BUK 6. Extra crates beyond the cap are not consumed.')
    table.insert(lines, '- Must match coalition and site type; otherwise no changes are applied.')
    table.insert(lines, '- Respawn is required to apply repairs/augmentation due to DCS limitations.')
    table.insert(lines, '')
    table.insert(lines, 'Placement tips:')
    table.insert(lines, '- Space launchers to avoid masking; keep radars with good line-of-sight; avoid fratricide arcs.')
    _msgCoalition(self.Side, table.concat(lines, '\n'), 45)
  end)
  
  -- Debug logging controls
  local debugMenu = MENU_COALITION:New(self.Side, 'Debug Logging', root)
  MENU_COALITION_COMMAND:New(self.Side, 'Enable Verbose (LogLevel 4)', debugMenu, function()
    self.Config.LogLevel = LOG_DEBUG
    _logInfo(string.format('[%s] Verbose/Debug logging ENABLED via Admin menu', tostring(self.Side)))
    _msgCoalition(self.Side, 'CTLD verbose logging ENABLED (LogLevel=4)', 8)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Normal INFO (LogLevel 2)', debugMenu, function()
    self.Config.LogLevel = LOG_INFO
    _logInfo(string.format('[%s] Logging set to INFO level via Admin menu', tostring(self.Side)))
    _msgCoalition(self.Side, 'CTLD logging set to INFO (LogLevel=2)', 8)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Errors Only (LogLevel 1)', debugMenu, function()
    self.Config.LogLevel = LOG_ERROR
    _logInfo(string.format('[%s] Logging set to ERROR-only via Admin menu', tostring(self.Side)))
    _msgCoalition(self.Side, 'CTLD logging: ERRORS only (LogLevel=1)', 8)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Disable All (LogLevel 0)', debugMenu, function()
    self.Config.LogLevel = LOG_NONE
    _msgCoalition(self.Side, 'CTLD logging DISABLED (LogLevel=0)', 8)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Show CTLD Status (crates/zones)', root, function()
    local crates = 0
    for _ in pairs(CTLD._crates) do crates = crates + 1 end
    local msg = string.format('CTLD Status:\nActive crates: %d\nPickup zones: %d\nDrop zones: %d\nFOB zones: %d\nBuild Confirm: %s (%ds window)\nBuild Cooldown: %s (%ds)'
      , crates, #(self.PickupZones or {}), #(self.DropZones or {}), #(self.FOBZones or {})
      , self.Config.BuildConfirmEnabled and 'ON' or 'OFF', self.Config.BuildConfirmWindowSeconds or 0
      , self.Config.BuildCooldownEnabled and 'ON' or 'OFF', self.Config.BuildCooldownSeconds or 0)
    _msgCoalition(self.Side, msg, 20)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Show Coalition Summary', root, function()
    self:ShowCoalitionSummary()
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Draw CTLD Zones on Map', root, function()
    self:DrawZonesOnMap()
    _msgCoalition(self.Side, 'CTLD zones drawn on F10 map.', 8)
  end)
  MENU_COALITION_COMMAND:New(self.Side, 'Clear CTLD Map Drawings', root, function()
    self:ClearMapDrawings()
    _msgCoalition(self.Side, 'CTLD map drawings cleared.', 8)
  end)
  -- Player Help submenu (was below; removed there and added above)
  self.AdminMenu = root
end
--#endregion Menus

-- =========================
-- Coalition Summary
-- =========================
--#region Coalition Summary
function CTLD:ShowCoalitionSummary()
  -- Crate counts per type (this coalition)
  local perType = {}
  local total = 0
  for _,meta in pairs(CTLD._crates) do
    if meta.side == self.Side then
      perType[meta.key] = (perType[meta.key] or 0) + 1
      total = total + 1
    end
  end
  local lines = {}
  table.insert(lines, string.format('CTLD Coalition Summary (%s)', (self.Side==coalition.side.BLUE and 'BLUE') or (self.Side==coalition.side.RED and 'RED') or 'NEUTRAL'))
  -- Crate timeout information first (lifetime is in seconds; 0 disables cleanup)
  local lifeSec = tonumber(self.Config.CrateLifetime or 0) or 0
  if lifeSec > 0 then
    local mins = math.floor((lifeSec + 30) / 60)
    table.insert(lines, string.format('Crate Timeout: %d mins (Crates will despawn to prevent clutter)', mins))
  else
    table.insert(lines, 'Crate Timeout: Disabled')
  end
  table.insert(lines, string.format('Active crates: %d', total))
  if next(perType) then
    table.insert(lines, 'Crates by type:')
    -- stable order: sort keys alphabetically
    local keys = {}
    for k,_ in pairs(perType) do table.insert(keys, k) end
    table.sort(keys)
    for _,k in ipairs(keys) do
      table.insert(lines, string.format('  %s: %d', k, perType[k]))
    end
  else
    table.insert(lines, 'Crates by type: (none)')
  end

  -- Nearby buildable recipes for each active player
  table.insert(lines, '\nBuildable near players:')
  local players = coalition.getPlayers(self.Side) or {}
  if #players == 0 then
    table.insert(lines, '  (no active players)')
  else
    for _,u in ipairs(players) do
      local g = u:getGroup()
      local gname = g and g:getName() or u:getName() or 'Group'
      local pos = u:getPoint()
      local here = { x = pos.x, z = pos.z }
      local radius = self.Config.BuildRadius or 100
      local nearby = self:GetNearbyCrates(here, radius)
      local counts = {}
      for _,c in ipairs(nearby) do if c.meta.side == self.Side then counts[c.meta.key] = (counts[c.meta.key] or 0) + 1 end end
      -- include carried crates if allowed
      if self.Config.BuildRequiresGroundCrates ~= true then
        local lc = CTLD._loadedCrates[gname]
        if lc and lc.byKey then for k,v in pairs(lc.byKey) do counts[k] = (counts[k] or 0) + v end end
      end
      local insideFOB, _ = self:IsPointInFOBZones(here)
      local buildable = {}
      -- composite recipes first
      for recipeKey,cat in pairs(self.Config.CrateCatalog) do
        if type(cat.requires) == 'table' and cat.build then
          if not (cat.isFOB and self.Config.RestrictFOBToZones and not insideFOB) then
            local ok = true
            for reqKey,qty in pairs(cat.requires) do if (counts[reqKey] or 0) < qty then ok = false; break end end
            if ok then table.insert(buildable, cat.description or recipeKey) end
          end
        end
      end
      -- single-key
      for key,cat in pairs(self.Config.CrateCatalog) do
        if cat and cat.build and (not cat.requires) then
          if not (cat.isFOB and self.Config.RestrictFOBToZones and not insideFOB) then
            if (counts[key] or 0) >= (cat.required or 1) then table.insert(buildable, cat.description or key) end
          end
        end
      end
      if #buildable == 0 then
        table.insert(lines, string.format('  %s: none', gname))
      else
        -- limit to keep message short
        local maxShow = 6
        local shown = {}
        for i=1, math.min(#buildable, maxShow) do table.insert(shown, buildable[i]) end
        local suffix = (#buildable > maxShow) and string.format(' (+%d more)', #buildable - maxShow) or ''
        table.insert(lines, string.format('  %s: %s%s', gname, table.concat(shown, ', '), suffix))
      end
    end
  end

  -- Quick help card
  table.insert(lines, '\nQuick Help:')
  table.insert(lines, '- Request crates: CTLD → Request Crate (near Pickup Zones).')
  table.insert(lines, '- Build: double-press "Build Here" within '..tostring(self.Config.BuildConfirmWindowSeconds or 10)..'s; cooldown '..tostring(self.Config.BuildCooldownSeconds or 60)..'s per group.')
  table.insert(lines, '- Hover Coach: CTLD → Coach & Nav → Enable/Disable; vectors to crates/zones available.')
  table.insert(lines, '- Manage crates: Drop One/All from CTLD menu; build consumes nearby crates.')

  _msgCoalition(self.Side, table.concat(lines, '\n'), 25)
end
--#endregion Coalition Summary

-- =========================
-- Crates
-- =========================
--#region Crates
-- Note: Menu creation lives in the Menus region; this section handles crate request/spawn/nearby/cleanup only.
function CTLD:RequestCrateForGroup(group, crateKey, opts)
  opts = opts or {}
  local cat = self.Config.CrateCatalog[crateKey]
  if not cat then _msgGroup(group, 'Unknown crate type: '..tostring(crateKey)) return end
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end

  local function _distanceToZone(u, z)
    if not (u and z and z.GetPointVec3) then return nil end
    local up = u:GetPointVec3()
    local zp = z:GetPointVec3()
    local dx = (up.x - zp.x)
    local dz = (up.z - zp.z)
    return math.sqrt(dx*dx + dz*dz)
  end

  local defaultZone, defaultDist = self:_nearestActivePickupZone(unit)
  local zone = opts.zone or defaultZone
  local dist = opts.zoneDist or defaultDist
  if zone and (not dist) then
    dist = _distanceToZone(unit, zone)
  end

  local defs = self:_collectActivePickupDefs()
  local hasPickupZones = (#defs > 0)
  local maxd = (self.Config.PickupZoneMaxDistance or 10000)

  local zoneName = zone and zone:GetName() or (hasPickupZones and 'nearest zone' or 'NO PICKUP ZONES CONFIGURED')
  _eventSend(self, group, nil, 'crate_spawn_requested', { type = tostring(crateKey), zone = zoneName })

  if not hasPickupZones and self.Config.RequirePickupZoneForCrateRequest then
    _eventSend(self, group, nil, 'no_pickup_zones', {})
    return
  end

  local spawnPoint
  if opts.spawnPoint then
    spawnPoint = { x = opts.spawnPoint.x, z = opts.spawnPoint.z }
  elseif zone and dist and dist <= maxd then
    spawnPoint = self:_computeCrateSpawnPoint(zone, {
      minSeparation = opts.minSeparationOverride,
      additionalEdgeBuffer = opts.additionalEdgeBuffer,
      tries = opts.separationTries,
      skipSeparationCheck = opts.skipSeparationCheck,
      ignoreCrates = opts.ignoreCrates,
    })
  else
    if self.Config.RequirePickupZoneForCrateRequest then
      local isMetric = _getPlayerIsMetric(unit)
      local v, u = _fmtRange(math.max(0, (dist or 0) - maxd), isMetric)
      local brg = 0
      if zone then
        local up = unit:GetPointVec3(); local zp = zone:GetPointVec3()
        brg = _bearingDeg({x=up.x,z=up.z}, {x=zp.x,z=zp.z})
      end
      _eventSend(self, group, nil, 'pickup_zone_required', { zone_dist = v, zone_dist_u = u, zone_brg = brg })
      return
    else
      local p = unit:GetPointVec3()
      spawnPoint = { x = p.x + 10, z = p.z + 10 }
    end
  end

  if not spawnPoint and zone and dist and dist <= maxd then
    local centerVec = zone:GetPointVec3()
    if centerVec then
      spawnPoint = { x = centerVec.x, z = centerVec.z }
    end
  end

  if not spawnPoint then
    _msgGroup(group, 'Crate spawn failed: unable to resolve spawn point.')
    return
  end

  local zoneNameForStock = zone and zone:GetName() or nil
  if self.Config.Inventory and self.Config.Inventory.Enabled then
    if not zoneNameForStock then
      _msgGroup(group, 'Crate requests must be at a Supply Zone for stock control.')
      return
    end
    CTLD._stockByZone[zoneNameForStock] = CTLD._stockByZone[zoneNameForStock] or {}
    local cur = tonumber(CTLD._stockByZone[zoneNameForStock][crateKey] or 0) or 0
    if cur <= 0 then
      if self:_TryUseSalvageForCrate(group, crateKey, cat) then
        _logVerbose(string.format('[Salvage] Used salvage to spawn %s', crateKey))
      else
        _msgGroup(group, string.format('Out of stock at %s for %s', zoneNameForStock, self:_friendlyNameForKey(crateKey)))
        return
      end
    else
      CTLD._stockByZone[zoneNameForStock][crateKey] = cur - 1
    end
  end

  local cname = string.format('CTLD_CRATE_%s_%d', crateKey, math.random(100000,999999))
  _spawnStaticCargo(self.Side, { x = spawnPoint.x, z = spawnPoint.z }, cat.dcsCargoType or 'uh1h_cargo', cname)
  CTLD._crates[cname] = {
    key = crateKey,
    side = self.Side,
    spawnTime = timer.getTime(),
    point = { x = spawnPoint.x, z = spawnPoint.z },
    requester = group:GetName(),
  }

  _addToSpatialGrid(cname, CTLD._crates[cname], 'crate')

  if zone and (opts.suppressSmoke ~= true) then
    local zdef = (self._ZoneDefs and self._ZoneDefs.PickupZones) and self._ZoneDefs.PickupZones[zone:GetName()] or nil
    local smokeColor = (zdef and zdef.smoke) or self.Config.PickupZoneSmokeColor
    if smokeColor then
      local sx, sz = spawnPoint.x, spawnPoint.z
      local sy = 0
      if land and land.getHeight then
        local ok, h = pcall(land.getHeight, { x = sx, y = sz })
        if ok and type(h) == 'number' then sy = h end
      end
      _spawnCrateSmoke({ x = sx, y = sy, z = sz }, smokeColor, self.Config.CrateSmoke, cname)
    end
  end

  do
    local unitPos = unit:GetPointVec3()
    local from = { x = unitPos.x, z = unitPos.z }
    local to = { x = spawnPoint.x, z = spawnPoint.z }
    local brg = _bearingDeg(from, to)
    local isMetric = _getPlayerIsMetric(unit)
    local rngMeters = math.sqrt(((to.x-from.x)^2)+((to.z-from.z)^2))
    local rngV, rngU = _fmtRange(rngMeters, isMetric)
    local data = {
      id = cname,
      type = tostring(crateKey),
      brg = brg,
      rng = rngV,
      rng_u = rngU,
    }
    _eventSend(self, group, nil, 'crate_spawned', data)
  end

  return cname, spawnPoint, zone
end

-- Convenience: for composite recipes (def.requires), request all component crates in one go
function CTLD:RequestRecipeBundleForGroup(group, recipeKey)
  local def = self.Config.CrateCatalog[recipeKey]
  if not def or type(def.requires) ~= 'table' then
    -- Fallback to single crate request
    return self:RequestCrateForGroup(group, recipeKey)
  end
  local unit = group and group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  -- Require proximity to an active pickup zone if inventory is enabled or config requires it
  local zone, dist = self:_nearestActivePickupZone(unit)
  local maxd = (self.Config.PickupZoneMaxDistance or 10000)
  if self.Config.RequirePickupZoneForCrateRequest and (not zone or not dist or dist > maxd) then
    local isMetric = _getPlayerIsMetric(unit)
    local v, u = _fmtRange(math.max(0, (dist or 0) - maxd), isMetric)
    local brg = 0
    if zone then
      local up = unit:GetPointVec3(); local zp = zone:GetPointVec3()
      brg = _bearingDeg({x=up.x,z=up.z}, {x=zp.x,z=zp.z})
    end
    _eventSend(self, group, nil, 'pickup_zone_required', { zone_dist = v, zone_dist_u = u, zone_brg = brg })
    return
  end
  if (self.Config.Inventory and self.Config.Inventory.Enabled) then
    if not zone then
      _msgGroup(group, 'Crate bundle requests must be at a Supply Zone for stock control.')
      return
    end
    local zname = zone:GetName()
    local stockTbl = CTLD._stockByZone[zname] or {}
    -- Pre-check: ensure we can fulfill at least one bundle (check stock or salvage)
    for reqKey, qty in pairs(def.requires) do
      local have = tonumber(stockTbl[reqKey] or 0) or 0
      local need = tonumber(qty or 0) or 0
      if need > 0 and have < need then
        -- Try salvage for the shortfall
        local catEntry = self.Config.CrateCatalog[reqKey]
        if not self:_CanUseSalvageForCrate(reqKey, catEntry, need - have) then
          _msgGroup(group, string.format('Out of stock at %s for %s bundle: need %d x %s', zname, self:_friendlyNameForKey(recipeKey), need, self:_friendlyNameForKey(reqKey)))
          return
        end
      end
    end
  end
  -- Flatten bundle components into a deterministic order
  local ordered = {}
  local totalCount = 0
  local keys = {}
  for reqKey,_ in pairs(def.requires) do table.insert(keys, reqKey) end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _,reqKey in ipairs(keys) do
    local qty = tonumber(def.requires[reqKey] or 0) or 0
    for _ = 1, qty do
      table.insert(ordered, reqKey)
      totalCount = totalCount + 1
    end
  end

  if totalCount == 0 then return end

  if totalCount == 1 then
    self:RequestCrateForGroup(group, ordered[1], { zone = zone, zoneDist = dist })
    return
  end

  local baseSeparation = math.max(0, self.Config.CrateSpawnMinSeparation or 7)
  local spacing = self.Config.CrateClusterSpacing or baseSeparation
  if spacing < baseSeparation then spacing = baseSeparation end
  if spacing < 4 then spacing = 4 end

  local offsets, perRow, rows = self:_buildClusterOffsets(totalCount, spacing)
  local clusterPad = math.max(((perRow - 1) * spacing) * 0.5, ((rows - 1) * spacing) * 0.5)
  local anchor = zone and self:_computeCrateSpawnPoint(zone, { additionalEdgeBuffer = clusterPad }) or nil

  if not anchor then
    for _,reqKey in ipairs(ordered) do
      self:RequestCrateForGroup(group, reqKey, { zone = zone, zoneDist = dist })
    end
    return
  end

  local orient = math.random() * 2 * math.pi
  local cosA = math.cos(orient)
  local sinA = math.sin(orient)
  local zoneCenterVec, zoneRadius = self:_getZoneCenterAndRadius(zone)
  local zoneCenter = zoneCenterVec and { x = zoneCenterVec.x, z = zoneCenterVec.z } or nil
  local safeRadius = nil
  if zoneRadius then
    safeRadius = math.max(0, zoneRadius - (self.Config.PickupZoneSpawnEdgeBuffer or 10))
  end

  local spawnPoints = {}
  for idx = 1, totalCount do
    local off = offsets[idx] or { x = 0, z = 0 }
    local rx = off.x * cosA - off.z * sinA
    local rz = off.x * sinA + off.z * cosA
    local point = { x = anchor.x + rx, z = anchor.z + rz }

    if zoneCenter and safeRadius and safeRadius > 0 then
      local dx = point.x - zoneCenter.x
      local dz = point.z - zoneCenter.z
      local distFromCenter = math.sqrt(dx * dx + dz * dz)
      if distFromCenter > safeRadius and distFromCenter > 0 then
        local scale = safeRadius / distFromCenter
        point.x = zoneCenter.x + dx * scale
        point.z = zoneCenter.z + dz * scale
      end
    end

    for name, meta in pairs(CTLD._crates) do
      if meta.side == self.Side then
        local dx = point.x - meta.point.x
        local dz = point.z - meta.point.z
        local distSq = dx * dx + dz * dz
        if distSq < (baseSeparation * baseSeparation) then
          local distNow = math.sqrt(distSq)
          local desired = baseSeparation + 0.5
          if distNow < 0.1 then
            point.x = point.x + desired
          else
            local push = desired - distNow
            point.x = point.x + (dx / distNow) * push
            point.z = point.z + (dz / distNow) * push
          end
          if zoneCenter and safeRadius and safeRadius > 0 then
            local ndx = point.x - zoneCenter.x
            local ndz = point.z - zoneCenter.z
            local ndist = math.sqrt(ndx * ndx + ndz * ndz)
            if ndist > safeRadius and ndist > 0 then
              local scale = safeRadius / ndist
              point.x = zoneCenter.x + ndx * scale
              point.z = zoneCenter.z + ndz * scale
            end
          end
        end
      end
    end

    spawnPoints[idx] = point
  end

  local smokePlaced = false
  for idx, reqKey in ipairs(ordered) do
    local point = spawnPoints[idx]
    self:RequestCrateForGroup(group, reqKey, {
      zone = zone,
      zoneDist = dist,
      spawnPoint = point,
      suppressSmoke = smokePlaced,
    })
    smokePlaced = true
  end
end

function CTLD:GetNearbyCrates(point, radius)
  local result = {}
  for name,meta in pairs(CTLD._crates) do
    local dx = (meta.point.x - point.x)
    local dz = (meta.point.z - point.z)
    local d = math.sqrt(dx*dx + dz*dz)
    if d <= radius then
      table.insert(result, { name = name, meta = meta })
    end
  end
  return result
end

function CTLD:CleanupCrates()
  local now = timer.getTime()
  local life = self.Config.CrateLifetime
  local cleaned = 0
  for name,meta in pairs(CTLD._crates) do
    if now - (meta.spawnTime or now) > life then
      local obj = StaticObject.getByName(name)
      if obj then obj:destroy() end
      _cleanupCrateSmoke(name)  -- Clean up smoke refresh schedule
      _removeFromSpatialGrid(name, meta.point, 'crate')  -- Remove from spatial index
      CTLD._crates[name] = nil
      cleaned = cleaned + 1
      _logDebug('Cleaned up crate '..name)
      -- Notify requester group if still around; else coalition
      local gname = meta.requester
      local group = gname and GROUP:FindByName(gname) or nil
      if group and group:IsAlive() then
        _eventSend(self, group, nil, 'crate_expired', { id = name })
      else
        _eventSend(self, nil, self.Side, 'crate_expired', { id = name })
      end
    end
  end
  -- Trigger garbage collection after cleanup if we removed items
  if cleaned > 5 then
    collectgarbage('step', 500)
  end
end

function CTLD:CleanupDeployedTroops()
  -- Remove any deployed troop groups that are dead or no longer exist
  local cleaned = 0
  for troopGroupName, troopMeta in pairs(CTLD._deployedTroops) do
    if troopMeta.side == self.Side then
      local troopGroup = GROUP:FindByName(troopGroupName)
      if not troopGroup or not troopGroup:IsAlive() then
        -- Remove from spatial grid if point is available
        if troopMeta.point then
          _removeFromSpatialGrid(troopGroupName, troopMeta.point, 'troops')
        end
        CTLD._deployedTroops[troopGroupName] = nil
        cleaned = cleaned + 1
        _logDebug('Cleaned up deployed troop group: '..troopGroupName)
      end
    end
  end
  -- Trigger garbage collection after cleanup if we removed items
  if cleaned > 3 then
    collectgarbage('step', 300)
  end
end

-- Comprehensive state pruning to prevent memory leaks
function CTLD:PruneOrphanedState()
  local pruned = 0
  
  -- 1. Prune spatial grid entries for non-existent crates/troops
  for gridKey, cell in pairs(CTLD._spatialGrid) do
    -- Check crates in this cell
    for crateName, _ in pairs(cell.crates) do
      if not CTLD._crates[crateName] then
        cell.crates[crateName] = nil
        pruned = pruned + 1
      end
    end
    -- Check troops in this cell
    for troopName, _ in pairs(cell.troops) do
      if not CTLD._deployedTroops[troopName] then
        cell.troops[troopName] = nil
        pruned = pruned + 1
      end
    end
    -- Remove empty cells
    if not next(cell.crates) and not next(cell.troops) then
      CTLD._spatialGrid[gridKey] = nil
    end
  end
  
  -- 2. Prune JTAC registry for non-existent groups
  if self._jtacRegistry then
    for gname, _ in pairs(self._jtacRegistry) do
      local g = Group.getByName(gname)
      if not g or not g:isExist() then
        self:_cleanupJTACEntry(gname)
        pruned = pruned + 1
      end
    end
  end
  
  -- 3. Prune hover/coach state for non-existent units
  local function pruneUnitState(stateTbl, label)
    if not stateTbl then return end
    for unitName, _ in pairs(stateTbl) do
      local u = Unit.getByName(unitName)
      if not u or not u:isExist() or u:getLife() <= 0 then
        stateTbl[unitName] = nil
        pruned = pruned + 1
      end
    end
  end
  
  pruneUnitState(CTLD._hoverState, 'hover')
  pruneUnitState(CTLD._coachState, 'coach')
  pruneUnitState(CTLD._groundLoadState, 'groundLoad')
  pruneUnitState(CTLD._unitLast, 'unitLast')
  
  -- 4. Prune group-level state for non-existent groups
  local function pruneGroupState(stateTbl, label)
    if not stateTbl then return end
    for gname, _ in pairs(stateTbl) do
      local g = GROUP:FindByName(gname)
      if not g or not g:IsAlive() then
        stateTbl[gname] = nil
        pruned = pruned + 1
      end
    end
  end
  
  pruneGroupState(CTLD._troopsLoaded, 'troopsLoaded')
  pruneGroupState(CTLD._loadedCrates, 'loadedCrates')
  pruneGroupState(CTLD._loadedTroopTypes, 'loadedTroopTypes')
  pruneGroupState(CTLD._buildConfirm, 'buildConfirm')
  pruneGroupState(CTLD._medevacUnloadStates, 'medevacUnload')
  pruneGroupState(CTLD._medevacLoadStates, 'medevacLoad')
  pruneGroupState(CTLD._medevacEnrouteStates, 'medevacEnroute')
  
  -- 5. Prune _inStockMenus for non-existent groups
  if CTLD._inStockMenus then
    for gname, _ in pairs(CTLD._inStockMenus) do
      local g = GROUP:FindByName(gname)
      if not g or not g:IsAlive() then
        CTLD._inStockMenus[gname] = nil
        pruned = pruned + 1
      end
    end
  end
  
  if pruned > 0 then
    _logVerbose(string.format('[StateMaint] Pruned %d orphaned state entries', pruned))
    -- Trigger garbage collection after significant pruning
    if pruned > 10 then
      collectgarbage('step', 500)
    end
  end
end
--#endregion Crates

-- =========================
-- Build logic
-- =========================
--#region Build logic
function CTLD:BuildAtGroup(group, opts)
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  if self.Config.JTAC and self.Config.JTAC.Verbose then
    _logInfo(string.format('JTAC trace: entering BuildAtGroup for group=%s', tostring(group:GetName())))
  end
  -- Build cooldown/confirmation guardrails
  local now = timer.getTime()
  local gname = group:GetName()
  if self.Config.BuildCooldownEnabled then
    local last = CTLD._buildCooldown[gname]
    if last and (now - last) < (self.Config.BuildCooldownSeconds or 60) then
      local rem = math.max(0, math.ceil((self.Config.BuildCooldownSeconds or 60) - (now - last)))
      _msgGroup(group, string.format('Build on cooldown. Try again in %ds.', rem))
      return
    end
  end
  if self.Config.BuildConfirmEnabled then
    local first = CTLD._buildConfirm[gname]
    local win = self.Config.BuildConfirmWindowSeconds or 10
    if not first or (now - first) > win then
      CTLD._buildConfirm[gname] = now
      _msgGroup(group, string.format('Confirm build: select "Build Here" again within %ds to proceed.', win))
      return
    else
      -- within window; proceed and clear pending
      CTLD._buildConfirm[gname] = nil
    end
  end
  local p = unit:GetPointVec3()
  local here = { x = p.x, z = p.z }
  -- Compute a safe spawn point offset forward from the aircraft to prevent rotor/ground collisions with spawned units
  local hdgRad, hdgDeg = _headingRadDeg(unit)
  local buildOffset = math.max(0, tonumber(self.Config.BuildSpawnOffset or 0) or 0)
  local spawnAt = (buildOffset > 0) and { x = here.x + math.sin(hdgRad) * buildOffset, z = here.z + math.cos(hdgRad) * buildOffset } or { x = here.x, z = here.z }
  local radius = self.Config.BuildRadius
  local nearby = self:GetNearbyCrates(here, radius)
  -- filter crates to coalition side for this CTLD instance
  local filtered = {}
  for _,c in ipairs(nearby) do
    if c.meta.side == self.Side then table.insert(filtered, c) end
  end
  nearby = filtered
  if #nearby == 0 then
    _eventSend(self, group, nil, 'build_insufficient_crates', { build = 'asset' })
    -- Nudge players to use Recipe Info
    _msgGroup(group, 'Tip: Use CTLD → Recipe Info to see exact crate requirements for each build.')
    return
  end

  -- Count by key
  local counts = {}
  for _,c in ipairs(nearby) do
    counts[c.meta.key] = (counts[c.meta.key] or 0) + 1
  end

  -- Include loaded crates carried by this group
  local carried = CTLD._loadedCrates[gname]
  if self.Config.BuildRequiresGroundCrates ~= true then
    if carried and carried.byKey then
      for k,v in pairs(carried.byKey) do
        counts[k] = (counts[k] or 0) + v
      end
    end
  end

  -- Helper to consume crates of a given key/qty
  local function consumeCrates(key, qty)
    local removed = 0
    -- Optionally consume from carried crates
    if self.Config.BuildRequiresGroundCrates ~= true then
      if carried and carried.byKey and (carried.byKey[key] or 0) > 0 then
        local take = math.min(qty, carried.byKey[key])
        carried.byKey[key] = carried.byKey[key] - take
        if carried.byKey[key] <= 0 then carried.byKey[key] = nil end
        carried.total = math.max(0, (carried.total or 0) - take)
        removed = removed + take
        if take > 0 then ctld:_scheduleLoadedCrateMenuRefresh(group) end
      end
    end
    for _,c in ipairs(nearby) do
      if removed >= qty then break end
      if c.meta.key == key then
        local obj = StaticObject.getByName(c.name)
        if obj then obj:destroy() end
        _cleanupCrateSmoke(c.name)  -- Clean up smoke refresh schedule
        CTLD._crates[c.name] = nil
        removed = removed + 1
      end
    end
  end

  local insideFOBZone, fz = self:IsPointInFOBZones(here)
  local fobBlocked = false
  
  -- Build All mode: when BuildCooldownSeconds = 0, loop and build all available assets
  local buildAllMode = (tonumber(self.Config.BuildCooldownSeconds) or 0) == 0
  local builtCount = 0
  local buildLoop = true
  
  -- Helper to calculate dispersed spawn position for Build All mode
  local function getDispersedSpawnPoint(basePoint, isFOB)
    -- FOBs always spawn at the designated point (no dispersion)
    if isFOB then
      return { x = basePoint.x, z = basePoint.z }
    end
    
    -- In Build All mode with dispersion enabled, randomize spawn position
    if buildAllMode and (self.Config.BuildDispersionRadius or 0) > 0 then
      local dispRadius = self.Config.BuildDispersionRadius
      -- Random angle (0-360 degrees)
      local angle = math.random() * 2 * math.pi
      -- Random distance (0 to dispRadius, with bias toward outer ring for better spread)
      local distance = math.sqrt(math.random()) * dispRadius
      return {
        x = basePoint.x + math.cos(angle) * distance,
        z = basePoint.z + math.sin(angle) * distance
      }
    end
    
    -- Default: use base point
    return { x = basePoint.x, z = basePoint.z }
  end
  
  while buildLoop do
    buildLoop = false -- Only loop if we successfully build something in Build All mode
    
    -- Try composite recipes first (requires is a map of key->qty)
    for recipeKey,cat in pairs(self.Config.CrateCatalog) do
      if type(cat.requires) == 'table' and cat.build then
        if cat.isFOB and self.Config.RestrictFOBToZones and not insideFOBZone then
          fobBlocked = true
        else
          -- Build caps disabled: rely solely on inventory/catalog control
          local ok = true
          for reqKey,qty in pairs(cat.requires) do
            if (counts[reqKey] or 0) < qty then ok = false; break end
          end
          if ok then
            -- Calculate spawn position (with dispersion for non-FOB builds in Build All mode)
            local actualSpawn = getDispersedSpawnPoint(spawnAt, cat.isFOB)
            local gdata = cat.build({ x = actualSpawn.x, z = actualSpawn.z }, hdgDeg, cat.side or self.Side)
            _eventSend(self, group, nil, 'build_started', { build = cat.description or recipeKey })
            local g = _coalitionAddGroup(cat.side or self.Side, cat.category or Group.Category.GROUND, gdata, self.Config)
            if g then
              if self.Config.JTAC and self.Config.JTAC.Verbose then
                _logInfo(string.format('JTAC trace: composite build spawned group=%s recipe=%s', tostring(g:getName()), tostring(recipeKey)))
              end
              -- Register JTAC if applicable (composite recipe)
              self:_maybeRegisterJTAC(recipeKey, cat, g)
              for reqKey,qty in pairs(cat.requires) do 
                consumeCrates(reqKey, qty)
                counts[reqKey] = math.max(0, (counts[reqKey] or 0) - qty)
              end
              builtCount = builtCount + 1
              -- No site cap counters when caps are disabled
              _eventSend(self, nil, self.Side, 'build_success_coalition', { build = cat.description or recipeKey, player = _playerNameFromGroup(group) })
              -- If this was a FOB, register a new pickup zone with reduced stock
              if cat.isFOB then
                pcall(function()
                  self:_CreateFOBPickupZone({ x = actualSpawn.x, z = actualSpawn.z }, cat, hdg)
                end)
              end
              -- If this was a Mobile MASH, create the tracking zone
              if cat.isMobileMASH then
                _logInfo(string.format('[MobileMASH] BuildAtGroup invoking _CreateMobileMASH for key %s at (%.1f, %.1f)', tostring(recipeKey), actualSpawn.x or -1, actualSpawn.z or -1))
                local ok, err = pcall(function() self:_CreateMobileMASH(g, { x = actualSpawn.x, z = actualSpawn.z }, cat) end)
                if not ok then
                  _logError(string.format('[MobileMASH] _CreateMobileMASH invocation failed: %s', tostring(err)))
                end
              end
              -- Assign optional behavior for built vehicles/groups
              local behavior = opts and opts.behavior or nil
              if behavior == 'attack' and self.Config.AttackAI and self.Config.AttackAI.Enabled then
                local t = self:_assignAttackBehavior(g:getName(), actualSpawn, true)
                local isMetric = _getPlayerIsMetric(group:GetUnit(1))
                if t and t.kind == 'base' then
                  local brg = _bearingDeg({ x = actualSpawn.x, z = actualSpawn.z }, { x = t.point.x, z = t.point.z })
                  local v, u = _fmtRange(t.dist or 0, isMetric)
                  _eventSend(self, nil, self.Side, 'attack_base_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), base_name = t.name, brg = brg, rng = v, rng_u = u })
                elseif t and t.kind == 'enemy' then
                  local brg = _bearingDeg({ x = actualSpawn.x, z = actualSpawn.z }, { x = t.point.x, z = t.point.z })
                  local v, u = _fmtRange(t.dist or 0, isMetric)
                  _eventSend(self, nil, self.Side, 'attack_enemy_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), enemy_type = t.etype or 'unit', brg = brg, rng = v, rng_u = u })
                else
                  local v, u = _fmtRange((self.Config.AttackAI and self.Config.AttackAI.VehicleSearchRadius) or 5000, isMetric)
                  _eventSend(self, nil, self.Side, 'attack_no_targets', { unit_name = g:getName(), player = _playerNameFromGroup(group), rng = v, rng_u = u })
                end
              end
              if self.Config.BuildCooldownEnabled then CTLD._buildCooldown[gname] = now end
              if buildAllMode then
                buildLoop = true -- Continue building in Build All mode
                break -- Break from recipe loop to restart search
              else
                return -- Single build mode - return after first build
              end
            else
              _eventSend(self, group, nil, 'build_failed', { reason = 'DCS group spawn error' })
              return
            end
          end
    -- continue_composite (Lua 5.1 compatible: no labels)
        end
      end
    end

    -- Then single-key recipes (only if we didn't build a composite)
    if not buildLoop or not buildAllMode then
      for key,count in pairs(counts) do
        local cat = self.Config.CrateCatalog[key]
        if cat and cat.build and (not cat.requires) and count >= (cat.required or 1) then
          if cat.isFOB and self.Config.RestrictFOBToZones and not insideFOBZone then
            fobBlocked = true
          else
            -- Build caps disabled: rely solely on inventory/catalog control
            -- Calculate spawn position (with dispersion for non-FOB builds in Build All mode)
            local actualSpawn = getDispersedSpawnPoint(spawnAt, cat.isFOB)
            local gdata = cat.build({ x = actualSpawn.x, z = actualSpawn.z }, hdgDeg, cat.side or self.Side)
            _eventSend(self, group, nil, 'build_started', { build = cat.description or key })
            local g = _coalitionAddGroup(cat.side or self.Side, cat.category or Group.Category.GROUND, gdata, self.Config)
            if g then
              if self.Config.JTAC and self.Config.JTAC.Verbose then
                _logInfo(string.format('JTAC trace: single build spawned group=%s key=%s', tostring(g:getName()), tostring(key)))
              end
              -- Register JTAC if applicable (single-unit recipe)
              self:_maybeRegisterJTAC(key, cat, g)
              consumeCrates(key, cat.required or 1)
              counts[key] = math.max(0, (counts[key] or 0) - (cat.required or 1))
              builtCount = builtCount + 1
              -- No single-unit cap counters when caps are disabled
              _eventSend(self, nil, self.Side, 'build_success_coalition', { build = cat.description or key, player = _playerNameFromGroup(group) })
              -- Assign optional behavior for built vehicles/groups
              local behavior = opts and opts.behavior or nil
              if behavior == 'attack' and self.Config.AttackAI and self.Config.AttackAI.Enabled then
                local t = self:_assignAttackBehavior(g:getName(), actualSpawn, true)
                local isMetric = _getPlayerIsMetric(group:GetUnit(1))
                if t and t.kind == 'base' then
                  local brg = _bearingDeg({ x = actualSpawn.x, z = actualSpawn.z }, { x = t.point.x, z = t.point.z })
                  local v, u = _fmtRange(t.dist or 0, isMetric)
                  _eventSend(self, nil, self.Side, 'attack_base_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), base_name = t.name, brg = brg, rng = v, rng_u = u })
                elseif t and t.kind == 'enemy' then
                  local brg = _bearingDeg({ x = actualSpawn.x, z = actualSpawn.z }, { x = t.point.x, z = t.point.z })
                  local v, u = _fmtRange(t.dist or 0, isMetric)
                  _eventSend(self, nil, self.Side, 'attack_enemy_announce', { unit_name = g:getName(), player = _playerNameFromGroup(group), enemy_type = t.etype or 'unit', brg = brg, rng = v, rng_u = u })
                else
                  local v, u = _fmtRange((self.Config.AttackAI and self.Config.AttackAI.VehicleSearchRadius) or 5000, isMetric)
                  _eventSend(self, nil, self.Side, 'attack_no_targets', { unit_name = g:getName(), player = _playerNameFromGroup(group), rng = v, rng_u = u })
                end
              end
              if self.Config.BuildCooldownEnabled then CTLD._buildCooldown[gname] = now end
              if buildAllMode then
                buildLoop = true -- Continue building in Build All mode
                break -- Break from counts loop to restart search
              else
                return -- Single build mode - return after first build
              end
            else
              _eventSend(self, group, nil, 'build_failed', { reason = 'DCS group spawn error' })
              return
            end
          end
        end
    -- continue_single (Lua 5.1 compatible: no labels)
      end
    end
  end
  
  -- If we built anything in Build All mode, we're done successfully
  if builtCount > 0 then
    if buildAllMode then
      _msgGroup(group, string.format('Build All complete: deployed %d asset(s).', builtCount))
    end
    return
  end

  if fobBlocked then
    _eventSend(self, group, nil, 'fob_restricted', {})
    return
  end

  -- Helpful hint if building requires ground crates and player is carrying crates
  if self.Config.BuildRequiresGroundCrates == true then
    local carried = CTLD._loadedCrates[gname]
    if carried and (carried.total or 0) > 0 then
      _eventSend(self, group, nil, 'build_requires_ground', { total = carried.total })
      return
    end
  end
  _eventSend(self, group, nil, 'build_insufficient_crates', { build = 'asset' })
  -- Provide a short breakdown of most likely recipes and what is missing
  local suggestions = {}
  local function pushSuggestion(name, missingStr, haveParts, totalParts)
    table.insert(suggestions, { name = name, miss = missingStr, have = haveParts, total = totalParts })
  end
  -- consider composite recipes with at least one matching component nearby
  for rkey,cat in pairs(self.Config.CrateCatalog) do
    if type(cat.requires) == 'table' then
      local have, total, missingList = 0, 0, {}
      for reqKey,qty in pairs(cat.requires) do
        total = total + (qty or 0)
        local haveHere = math.min(qty or 0, counts[reqKey] or 0)
        have = have + haveHere
        local need = math.max(0, (qty or 0) - (counts[reqKey] or 0))
        if need > 0 then
          local fname = self:_friendlyNameForKey(reqKey)
          table.insert(missingList, string.format('%dx %s', need, fname))
        end
      end
      if have > 0 and have < total then
        local name = cat.description or cat.menu or rkey
        pushSuggestion(name, table.concat(missingList, ', '), have, total)
      end
    else
      -- single-key recipe: if some crates present but not enough
      local need = (cat and (cat.required or 1)) or 1
      local have = counts[rkey] or 0
      if have > 0 and have < need then
        local name = cat.description or cat.menu or rkey
        pushSuggestion(name, string.format('%d more crate(s) of %s', need - have, self:_friendlyNameForKey(rkey)), have, need)
      end
    end
  end
  table.sort(suggestions, function(a,b)
    local ra = (a.total > 0) and (a.have / a.total) or 0
    local rb = (b.total > 0) and (b.have / b.total) or 0
    if ra == rb then return (a.total - a.have) < (b.total - b.have) end
    return ra > rb
  end)
  if #suggestions > 0 then
    local maxShow = math.min(2, #suggestions)
    for i=1,maxShow do
      local s = suggestions[i]
      _msgGroup(group, string.format('Missing for %s: %s', s.name, s.miss))
    end
  else
    _msgGroup(group, 'No matching recipe found with nearby crates. Check Recipe Info for requirements.')
  end
end
--#endregion Build logic

-- =========================
-- Loaded crate management
-- =========================
--#region Loaded crate management

-- Update DCS internal cargo weight for a group
function CTLD:_updateCargoWeight(group)
  _updateCargoWeight(group)
end

function CTLD:_addLoadedCrate(group, crateKey)
  local gname = group:GetName()
  CTLD._loadedCrates[gname] = CTLD._loadedCrates[gname] or { total = 0, totalWeightKg = 0, byKey = {} }
  local lc = CTLD._loadedCrates[gname]
  lc.total = lc.total + 1
  lc.byKey[crateKey] = (lc.byKey[crateKey] or 0) + 1
  
  -- Add weight from catalog
  local cat = self.Config.CrateCatalog[crateKey]
  local crateWeight = (cat and cat.weightKg) or 0
  lc.totalWeightKg = (lc.totalWeightKg or 0) + crateWeight
  
  -- Update DCS internal cargo weight
  self:_updateCargoWeight(group)
  
  -- Refresh drop-by-type menu after loading
  self:_scheduleLoadedCrateMenuRefresh(group)
end

function CTLD:_clearLoadedCrateMenuCommands(gname)
  self._loadedCrateMenus = self._loadedCrateMenus or {}
  local state = self._loadedCrateMenus[gname]
  if not state or not state.commands then return end
  for _,cmd in ipairs(state.commands) do
    if cmd and cmd.Remove then
      pcall(function() cmd:Remove() end)
    end
  end
  state.commands = {}
end

function CTLD:_BuildOrRefreshLoadedCrateMenu(group, parentMenu)
  if not group then return end
  self._loadedCrateMenus = self._loadedCrateMenus or {}
  local gname = group:GetName()
  local state = self._loadedCrateMenus[gname] or { commands = {} }
  state.parent = parentMenu
  state.groupName = gname
  self._loadedCrateMenus[gname] = state

  self:_clearLoadedCrateMenuCommands(gname)

  local carried = CTLD._loadedCrates[gname]
  local byKey = (carried and carried.byKey) or {}
  local keys = {}
  for key,count in pairs(byKey) do
    if count and count > 0 then table.insert(keys, key) end
  end

  local ctld = self
  if #keys == 0 then
    local cmd = MENU_GROUP_COMMAND:New(group, 'No crates onboard', parentMenu, function()
      _msgGroup(group, 'No crates loaded to drop individually.')
    end)
    table.insert(state.commands, cmd)
    return
  end

  table.sort(keys, function(a, b)
    local fa = ctld:_friendlyNameForKey(a) or a
    local fb = ctld:_friendlyNameForKey(b) or b
    if fa == fb then return a < b end
    return fa < fb
  end)

  for _,key in ipairs(keys) do
    local count = byKey[key] or 0
    local friendly = ctld:_friendlyNameForKey(key) or key
    local title = string.format('Drop %s (%d)', friendly, count)
    local cmd = MENU_GROUP_COMMAND:New(group, title, parentMenu, function()
      ctld:DropLoadedCrates(group, 1, key)
    end)
    table.insert(state.commands, cmd)
  end
end

function CTLD:_scheduleLoadedCrateMenuRefresh(group)
  if not group then return end
  self._loadedCrateMenus = self._loadedCrateMenus or {}
  local gname = group:GetName()
  local state = self._loadedCrateMenus[gname]
  if not state or not state.parent then return end
  local ctld = self
  local id = timer.scheduleFunction(function()
    local g = GROUP:FindByName(gname)
    if not g then return end
    ctld:_BuildOrRefreshLoadedCrateMenu(g, state.parent)
    return
  end, {}, timer.getTime() + 0.1)
  _trackOneShotTimer(id)
end

function CTLD:DropLoadedCrates(group, howMany, crateKey)
  local gname = group:GetName()
  local lc = CTLD._loadedCrates[gname]
  if not lc or (lc.total or 0) == 0 then _eventSend(self, group, nil, 'no_loaded_crates', {}) return end
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  -- Restrict dropping crates inside Pickup Zones if configured
  if self.Config.ForbidDropsInsidePickupZones then
    local activeOnly = (self.Config.ForbidChecksActivePickupOnly ~= false)
    local inside = false
    local ok, err = pcall(function()
      inside = select(1, self:_isUnitInsidePickupZone(unit, activeOnly))
    end)
    if ok and inside then
      _eventSend(self, group, nil, 'drop_forbidden_in_pickup', {})
      return
    end
  end
  local p = unit:GetPointVec3()
  local here = { x = p.x, z = p.z }
  -- Offset drop point forward of the aircraft to avoid rotor/airframe damage
  local hdgRad, _ = _headingRadDeg(unit)
  local fwd = math.max(0, tonumber(self.Config.DropCrateForwardOffset or 20) or 0)
  local dropPt = (fwd > 0) and { x = here.x + math.sin(hdgRad) * fwd, z = here.z + math.cos(hdgRad) * fwd } or { x = here.x, z = here.z }
  local initialTotal = lc.total or 0
  local requested = (howMany and howMany > 0) and howMany or initialTotal
  
  local dropPlan = {}
  if crateKey then
    local available = lc.byKey[crateKey] or 0
    if available <= 0 then
      local friendly = self:_friendlyNameForKey(crateKey) or crateKey
      _msgGroup(group, string.format('No %s crates loaded.', friendly))
      return
    end
    local qty = math.min(requested, available)
    table.insert(dropPlan, { key = crateKey, count = qty })
  else
    local keys = {}
    for key,_ in pairs(lc.byKey) do table.insert(keys, key) end
    table.sort(keys, function(a, b)
      local fa = self:_friendlyNameForKey(a) or a
      local fb = self:_friendlyNameForKey(b) or b
      if fa == fb then return a < b end
      return fa < fb
    end)
    local remaining = math.min(requested, initialTotal)
    for _,key in ipairs(keys) do
      if remaining <= 0 then break end
      local available = lc.byKey[key] or 0
      if available > 0 then
        local qty = math.min(available, remaining)
        table.insert(dropPlan, { key = key, count = qty })
        remaining = remaining - qty
      end
    end
  end

  local totalToDrop = 0
  for _,entry in ipairs(dropPlan) do totalToDrop = totalToDrop + (entry.count or 0) end
  if totalToDrop <= 0 then
    _msgGroup(group, 'No valid crates selected to drop.')
    return
  end

  _eventSend(self, group, nil, 'drop_initiated', { count = totalToDrop, key = crateKey })
  -- Warn about crate timeout when dropping
  local lifeSec = tonumber(self.Config.CrateLifetime or 0) or 0
  if lifeSec > 0 then
    local mins = math.floor((lifeSec + 30) / 60)
    _msgGroup(group, string.format('Note: Crates will despawn after %d mins to prevent clutter.', mins))
  end
  -- Drop following the prepared plan
  for _,entry in ipairs(dropPlan) do
    local k = entry.key
    local dropNow = entry.count or 0
    if dropNow > 0 then
      local cat = self.Config.CrateCatalog[k]
      local crateWeight = (cat and cat.weightKg) or 0
      for i=1,dropNow do
        local cname = string.format('CTLD_CRATE_%s_%d', k, math.random(100000,999999))
        _spawnStaticCargo(self.Side, dropPt, (cat and cat.dcsCargoType) or 'uh1h_cargo', cname)
        CTLD._crates[cname] = { key = k, side = self.Side, spawnTime = timer.getTime(), point = { x = dropPt.x, z = dropPt.z } }
        -- Add to spatial index
        _addToSpatialGrid(cname, CTLD._crates[cname], 'crate')
        lc.byKey[k] = lc.byKey[k] - 1
        if lc.byKey[k] <= 0 then lc.byKey[k] = nil end
        lc.total = lc.total - 1
        lc.totalWeightKg = (lc.totalWeightKg or 0) - crateWeight
      end
    end
  end
  local actualDropped = initialTotal - (lc.total or 0)
  _eventSend(self, group, nil, 'dropped_crates', { count = actualDropped, key = crateKey })
  
  -- Update DCS internal cargo weight after dropping
  self:_updateCargoWeight(group)
  
  -- Refresh drop-by-type menu after dropping
  self:_scheduleLoadedCrateMenuRefresh(group)
  
  -- Reiterate timeout after drop completes (players may miss the initial warning)
  if lifeSec > 0 then
    local mins = math.floor((lifeSec + 30) / 60)
    _msgGroup(group, string.format('Reminder: Dropped crates will despawn after %d mins to prevent clutter.', mins))
  end
end

-- Show inventory at the nearest pickup zone/FOB
function CTLD:ShowNearestZoneInventory(group)
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  -- Find nearest active pickup zone
  local zone, dist = self:_nearestActivePickupZone(unit)
  
  if not zone then
    _msgGroup(group, 'No active pickup zones found nearby. Move closer to a supply zone.')
    return
  end
  
  local zoneName = zone:GetName()
  local isMetric = _getPlayerIsMetric(unit)
  local rngV, rngU = _fmtRange(dist, isMetric)
  
  -- Get inventory for this zone
  local stockTbl = CTLD._stockByZone[zoneName] or {}
  
  -- Build the inventory display
  local lines = {}
  table.insert(lines, string.format('Inventory at %s', zoneName))
  table.insert(lines, string.format('Distance: %.1f %s', rngV, rngU))
  table.insert(lines, '')
  
  -- Check if inventory system is enabled
  local invEnabled = self.Config.Inventory and self.Config.Inventory.Enabled ~= false
  if not invEnabled then
    table.insert(lines, 'Inventory tracking is disabled - all items available.')
    _msgGroup(group, table.concat(lines, '\n'), 20)
    return
  end
  
  -- Count total items and organize by category
  local totalItems = 0
  local byCategory = {}
  
  for key, count in pairs(stockTbl) do
    if count > 0 then
      local def = self.Config.CrateCatalog[key]
      if def and ((not def.side) or def.side == self.Side) then
        local cat = (def.menuCategory or 'Other')
        byCategory[cat] = byCategory[cat] or {}
        table.insert(byCategory[cat], {
          key = key,
          name = def.menu or def.description or key,
          count = count,
          isRecipe = (type(def.requires) == 'table')
        })
        totalItems = totalItems + count
      end
    end
  end
  
  if totalItems == 0 then
    table.insert(lines, 'No items in stock at this location.')
    table.insert(lines, 'Request resupply or move to another zone.')
  else
    table.insert(lines, string.format('Total items in stock: %d', totalItems))
    table.insert(lines, '')
    
    -- Sort categories for consistent display
    local categories = {}
    for cat, _ in pairs(byCategory) do
      table.insert(categories, cat)
    end
    table.sort(categories)
    
    -- Display items by category
    for _, cat in ipairs(categories) do
      table.insert(lines, string.format('-- %s --', cat))
      local items = byCategory[cat]
      -- Sort items by name
      table.sort(items, function(a, b) return a.name < b.name end)
      for _, item in ipairs(items) do
        if item.isRecipe then
          -- For recipes, calculate available bundles
          local def = self.Config.CrateCatalog[item.key]
          local bundles = math.huge
          if def and def.requires then
            for reqKey, qty in pairs(def.requires) do
              local have = tonumber(stockTbl[reqKey] or 0) or 0
              local need = tonumber(qty or 0) or 0
              if need > 0 then
                bundles = math.min(bundles, math.floor(have / need))
              end
            end
          end
          if bundles == math.huge then bundles = 0 end
          table.insert(lines, string.format('  %s: %d bundle%s', item.name, bundles, (bundles == 1 and '' or 's')))
        else
          table.insert(lines, string.format('  %s: %d', item.name, item.count))
        end
      end
      table.insert(lines, '')
    end
  end
  
  -- Display the inventory
  _msgGroup(group, table.concat(lines, '\n'), 30)
end

--#endregion Loaded crate management

-- =========================
-- Hover pickup scanner
-- =========================
--#region Hover pickup scanner
function CTLD:ScanHoverPickup()
  local coachCfg = CTLD.HoverCoachConfig or { enabled = false }
  if not coachCfg.enabled then return end
  
  -- iterate all groups that have menus (active transports)
  for gname,_ in pairs(self.MenusByGroup or {}) do
    local group = GROUP:FindByName(gname)
    if group and group:IsAlive() then
      local unit = group:GetUnit(1)
      if unit and unit:IsAlive() then
        -- Allowed type check
        local typ = _getUnitType(unit)
        if _isIn(self.Config.AllowedAircraft, typ) then
          local uname = unit:GetName()
          local now = timer.getTime()
          local p3 = unit:GetPointVec3()
          local ground = land and land.getHeight and land.getHeight({ x = p3.x, y = p3.z }) or 0
          local agl = math.max(0, p3.y - ground)

          -- Skip hover coaching if on the ground (let ground auto-load handle it)
          local groundCfg = CTLD.GroundAutoLoadConfig or {}
          local groundContactAGL = groundCfg.GroundContactAGL or 3.5
          if agl <= groundContactAGL then
            -- On ground, clear hover state and skip hover logic
            CTLD._hoverState[uname] = nil
            -- Also, when firmly landed, suppress any completed ground-load state
            -- so returning to this spot without crates won't keep retriggering.
            if CTLD._groundLoadState and CTLD._groundLoadState[uname] and CTLD._groundLoadState[uname].completed then
              CTLD._groundLoadState[uname] = nil
            end
          else
            -- speeds (ground/vertical)
            local last = CTLD._unitLast[uname]
            local gs, vs = 0, 0
            if last and (now > (last.t or 0)) then
              local dt = now - last.t
              if dt > 0 then
                local dx = (p3.x - last.x)
                local dz = (p3.z - last.z)
                gs = math.sqrt(dx*dx + dz*dz) / dt
                if last.agl then vs = (agl - last.agl) / dt end
              end
            end
            CTLD._unitLast[uname] = { x = p3.x, z = p3.z, t = now, agl = agl }

          -- Use spatial indexing to find nearby crates/troops efficiently
            local maxd = coachCfg.autoPickupDistance or 25
            local nearby = _getNearbyFromSpatialGrid(p3.x, p3.z, maxd)

            local friendlyCrateCount = 0
            local friendlyTroopCount = 0
            local bestName, bestMeta, bestd
            local bestType = 'crate'
          
          -- Search nearby crates from spatial grid
            for name, meta in pairs(nearby.crates or {}) do
            if meta.side == self.Side then
              friendlyCrateCount = friendlyCrateCount + 1
              local dx = (meta.point.x - p3.x)
              local dz = (meta.point.z - p3.z)
              local d = math.sqrt(dx*dx + dz*dz)
              if d <= maxd and ((not bestd) or d < bestd) then
                bestName, bestMeta, bestd = name, meta, d
                bestType = 'crate'
              end
            end
          end
          
          -- Search nearby deployed troops from spatial grid
            for troopGroupName, troopMeta in pairs(nearby.troops or {}) do
            if troopMeta.side == self.Side then
              friendlyTroopCount = friendlyTroopCount + 1
              local troopGroup = GROUP:FindByName(troopGroupName)
              if troopGroup and troopGroup:IsAlive() then
                local troopPos = troopGroup:GetCoordinate()
                if troopPos then
                  local tp = troopPos:GetVec3()
                  local dx = (tp.x - p3.x)
                  local dz = (tp.z - p3.z)
                  local d = math.sqrt(dx*dx + dz*dz)
                  if d <= maxd and ((not bestd) or d < bestd) then
                    bestName, bestMeta, bestd = troopGroupName, troopMeta, d
                    bestType = 'troops'
                  end
                end
              else
                -- Group doesn't exist or is dead, remove from tracking
                _removeFromSpatialGrid(troopGroupName, troopMeta.point, 'troops')
                CTLD._deployedTroops[troopGroupName] = nil
              end
            end
          end

            if CTLD.Config and CTLD.Config.DebugHoverCrates and (friendlyCrateCount > 0 or friendlyTroopCount > 0) then
              local debugLabel = bestName or 'none'
              local debugType = bestType
              local debugDist = bestd
              if not bestName and friendlyCrateCount > 0 then
                debugLabel = 'pending'
                debugType = 'crate'
                debugDist = math.huge
              end
              _debugCrateSight('HoverDebug', {
                unit = uname,
                now = now,
                interval = CTLD.Config.DebugHoverCratesInterval,
                step = CTLD.Config.DebugHoverCratesStep,
                name = debugLabel,
                distance = debugDist,
                count = friendlyCrateCount,
                troops = friendlyTroopCount,
                radius = maxd,
                typeHint = debugType,
                note = string.format('coachGS<=%.1f', coachCfg.thresholds.captureGS or (4/3.6)),
              })
            end

            local coachEnabled = coachCfg.enabled
            if CTLD._coachOverride and CTLD._coachOverride[gname] ~= nil then
              coachEnabled = CTLD._coachOverride[gname]
            end

          -- If coach is on, provide phased guidance
            if coachEnabled and bestName and bestMeta then
            local thresholds = coachCfg.thresholds or {}
            local isMetric = _getPlayerIsMetric(unit)

            -- Arrival phase
            if bestd <= (thresholds.arrivalDist or 1000) then
              _coachSend(self, group, uname, 'coach_arrival', {}, false)
            end

            -- Close-in guidance
            if bestd <= (thresholds.closeDist or 100) then
              _coachSend(self, group, uname, 'coach_close', {}, false)
            end

            -- Precision phase
            if bestd <= (thresholds.precisionDist or 30) then
              local hdg, _ = _headingRadDeg(unit)
              local dx = (bestMeta.point.x - p3.x)
              local dz = (bestMeta.point.z - p3.z)
              local right, fwd = _projectToBodyFrame(dx, dz, hdg)

              -- Horizontal hint formatting
              local function hintDir(val, posWord, negWord, toUnits)
                local mag = math.abs(val)
                local v, u = _fmtDistance(mag, isMetric)
                if mag < 0.5 then return nil end
                return string.format("%s %d %s", (val >= 0 and posWord or negWord), v, u)
              end
              local h = {}
              local rHint = hintDir(right, 'Right', 'Left')
              local fHint = hintDir(fwd, 'Forward', 'Back')
              if rHint then table.insert(h, rHint) end
              if fHint then table.insert(h, fHint) end

              -- Vertical hint against AGL window
              local vHint
              local aglMin = thresholds.aglMin or 5
              local aglMax = thresholds.aglMax or 20
              if agl < aglMin then
                local dv, du = _fmtAGL(aglMin - agl, isMetric)
                vHint = string.format("Up %d %s", dv, du)
              elseif agl > aglMax then
                local dv, du = _fmtAGL(agl - aglMax, isMetric)
                vHint = string.format("Down %d %s", dv, du)
              end
              if vHint then table.insert(h, vHint) end

              local hints = table.concat(h, ", ")
              local gsV, gsU = _fmtSpeed(gs, isMetric)
              local data = { hints = (hints ~= '' and (hints..'.') or ''), gs = gsV, gs_u = gsU }

              _coachSend(self, group, uname, 'coach_hint', data, true)

              -- Error prompts (dominant one)
              local maxGS = thresholds.maxGS or (8/3.6)
              local aglMinT = aglMin
              local aglMaxT = aglMax
              if gs > maxGS then
                local v, u = _fmtSpeed(gs, isMetric)
                _coachSend(self, group, uname, 'coach_too_fast', { gs = v, gs_u = u }, false)
              elseif agl > aglMaxT then
                local v, u = _fmtAGL(agl, isMetric)
                _coachSend(self, group, uname, 'coach_too_high', { agl = v, agl_u = u }, false)
              elseif agl < aglMinT then
                local v, u = _fmtAGL(agl, isMetric)
                _coachSend(self, group, uname, 'coach_too_low', { agl = v, agl_u = u }, false)
              end
            end
            end

            -- Auto-load logic using capture thresholds
            local capGS = coachCfg.thresholds.captureGS or (4/3.6)
            local aglMin = coachCfg.thresholds.aglMin or 5
            local aglMax = coachCfg.thresholds.aglMax or 20
            local speedOK = gs <= capGS
            local heightOK = (agl >= aglMin and agl <= aglMax)

            if bestName and bestMeta and speedOK and heightOK then
            local withinRadius = bestd <= (coachCfg.thresholds.captureHoriz or 2)

              if withinRadius then
              local carried = CTLD._loadedCrates[gname]
              local total = carried and carried.total or 0
              local currentWeight = carried and carried.totalWeightKg or 0
              
              -- Get aircraft-specific capacity instead of global setting
              local capacity = _getAircraftCapacity(unit)
              local maxCrates = capacity.maxCrates
              local maxTroops = capacity.maxTroops
              local maxWeight = capacity.maxWeightKg or 0
              
              -- Calculate weight and check capacity based on type
              local itemWeight = 0
              local countOK = false
              local weightOK = false
              
              if bestType == 'crate' then
                -- Picking up a crate
                itemWeight = (bestMeta and self.Config.CrateCatalog[bestMeta.key] and self.Config.CrateCatalog[bestMeta.key].weightKg) or 0
                local wouldBeWeight = currentWeight + itemWeight
                countOK = (total < maxCrates)
                weightOK = (maxWeight <= 0) or (wouldBeWeight <= maxWeight)
              elseif bestType == 'troops' then
                -- Picking up troops - check if we can ADD them to existing load
                itemWeight = bestMeta.weightKg or 0
                local wouldBeWeight = currentWeight + itemWeight
                local troopCount = bestMeta.count or 0
                
                -- Check if we already have troops loaded - if so, check if we can add more
                local currentTroops = CTLD._troopsLoaded[gname]
                local currentTroopCount = currentTroops and currentTroops.count or 0
                local totalTroopCount = currentTroopCount + troopCount
                
                -- Check total capacity (allow mixing different troop types)
                countOK = (totalTroopCount <= maxTroops)
                weightOK = (maxWeight <= 0) or (wouldBeWeight <= maxWeight)
                
                -- Provide feedback if capacity exceeded
                if not countOK then
                  local hs = CTLD._hoverState[uname]
                  if not hs or hs.messageShown ~= true then
                    _msgGroup(group, string.format('Troop capacity exceeded! Current: %d, Adding: %d, Max: %d', 
                      currentTroopCount, troopCount, maxTroops))
                    if not hs then
                      CTLD._hoverState[uname] = { messageShown = true }
                    else
                      hs.messageShown = true
                    end
                  end
                end
              end
              
              -- Check both count AND weight limits
                if countOK and weightOK then
                local hs = CTLD._hoverState[uname]
                if not hs or hs.targetCrate ~= bestName or hs.targetType ~= bestType then
                  CTLD._hoverState[uname] = { targetCrate = bestName, targetType = bestType, startTime = now }
                  if coachEnabled then _coachSend(self, group, uname, 'coach_hold', {}, false) end
                else
                  -- stability hold timer
                  local holdNeeded = coachCfg.thresholds.stabilityHold or 1.8
                  if (now - hs.startTime) >= holdNeeded then
                    -- load it
                    if bestType == 'crate' then
                      -- Use shared loading function
                      local success = self:_loadCrateIntoAircraft(group, bestName, bestMeta)
                      if success then
                        if coachEnabled then
                          _coachSend(self, group, uname, 'coach_loaded', {}, false)
                        else
                          _msgGroup(group, string.format('Loaded %s crate', tostring(bestMeta.key)))
                        end
                      end
                    elseif bestType == 'troops' then
                      -- Pick up the troop group
                      local troopGroup = GROUP:FindByName(bestName)
                      if troopGroup then
                        troopGroup:Destroy()
                      end
                      _removeFromSpatialGrid(bestName, bestMeta.point, 'troops')  -- Remove from spatial index
                      CTLD._deployedTroops[bestName] = nil
                      
                      -- ADD to existing troops if any, don't overwrite
                      local currentTroops = CTLD._troopsLoaded[gname]
                      if currentTroops then
                        -- Add to existing load (supports mixing types)
                        local troopTypes = currentTroops.troopTypes or { { typeKey = currentTroops.typeKey, count = currentTroops.count } }
                        table.insert(troopTypes, { typeKey = bestMeta.typeKey, count = bestMeta.count })
                        
                        CTLD._troopsLoaded[gname] = {
                          count = currentTroops.count + bestMeta.count,
                          typeKey = 'Mixed',  -- Indicate mixed types
                          troopTypes = troopTypes,  -- Store individual type details
                          weightKg = currentTroops.weightKg + bestMeta.weightKg
                        }
                        self:_refreshLoadedTroopSummaryForGroup(gname)
                        _msgGroup(group, string.format('Loaded %d more troops (total: %d)', bestMeta.count, CTLD._troopsLoaded[gname].count))
                      else
                        -- First load
                        CTLD._troopsLoaded[gname] = {
                          count = bestMeta.count,
                          typeKey = bestMeta.typeKey,
                          troopTypes = { { typeKey = bestMeta.typeKey, count = bestMeta.count } },
                          weightKg = bestMeta.weightKg
                        }
                        self:_refreshLoadedTroopSummaryForGroup(gname)
                        if coachEnabled then
                          _msgGroup(group, string.format('Loaded %d troops', bestMeta.count))
                        else
                          _msgGroup(group, string.format('Loaded %d troops', bestMeta.count))
                        end
                      end
                      
                      -- Update cargo weight
                      self:_updateCargoWeight(group)
                    end
                    CTLD._hoverState[uname] = nil
                  end
                end
                else
                -- Aircraft at capacity - notify player with weight/count info
                local aircraftType = _getUnitType(unit) or 'aircraft'
                if not weightOK then
                  -- Weight limit exceeded
                  _msgGroup(group, string.format('Weight capacity reached! Current: %dkg, Item: %dkg, Max: %dkg for %s', 
                    math.floor(currentWeight), math.floor(itemWeight), math.floor(maxWeight), aircraftType))
                elseif bestType == 'crate' then
                  -- Count limit exceeded for crates
                  _eventSend(self, group, nil, 'crate_aircraft_capacity', { current = total, max = maxCrates, aircraft = aircraftType })
                elseif bestType == 'troops' then
                  -- Count limit exceeded for troops
                  _eventSend(self, group, nil, 'troop_aircraft_capacity', { count = bestMeta.count or 0, max = maxTroops, aircraft = aircraftType })
                end
                CTLD._hoverState[uname] = nil
                end
              else
              -- lost precision window
              if coachEnabled then _coachSend(self, group, uname, 'coach_hover_lost', {}, false) end
              CTLD._hoverState[uname] = nil
              end
            else
            -- reset hover state when outside primary envelope
            if CTLD._hoverState[uname] then
              if coachEnabled then _coachSend(self, group, uname, 'coach_abort', {}, false) end
            end
            CTLD._hoverState[uname] = nil
            end
          end
        end
      end
    end
  end
end
--#endregion Hover pickup scanner

-- =========================
-- Ground Auto-Load Scanner
-- =========================
--#region Ground auto-load scanner
function CTLD:ScanGroundAutoLoad()
  local groundCfg = CTLD.GroundAutoLoadConfig or { Enabled = false }
  if not groundCfg.Enabled then return end
  
  local now = timer.getTime()
  local progressMsgInterval = (self.GroundLoadComms and self.GroundLoadComms.ProgressInterval) or 5
  
  -- Iterate all groups that have menus (active transports)
  for gname, _ in pairs(self.MenusByGroup or {}) do
    local group = GROUP:FindByName(gname)
    if group and group:IsAlive() then
      local unit = group:GetUnit(1)
      if unit and unit:IsAlive() then
        local typ = _getUnitType(unit)
        if _isIn(self.Config.AllowedAircraft, typ) then
          local uname = unit:GetName()

          -- Ensure ground-load state table exists
          CTLD._groundLoadState = CTLD._groundLoadState or {}

          -- Check if already carrying crates (skip if at capacity)
          local carried = CTLD._loadedCrates[gname]
          local currentCount = carried and carried.total or 0
          local capacity = _getAircraftCapacity(unit)
          
          if currentCount < capacity.maxCrates then
            -- Check basic requirements: on ground, low speed
            local agl = _getUnitAGL(unit)
            local gs = _getGroundSpeed(unit)
            local onGround = (agl <= (groundCfg.GroundContactAGL or 3.5))
            local slowEnough = (gs <= (groundCfg.MaxGroundSpeed or 2.0))

            -- If a previous ground auto-load completed while we remain effectively stationary
            -- on the ground, avoid auto-starting again until the aircraft has moved or lifted off.
            local state = CTLD._groundLoadState[uname]
            local canProcess = true
            if state and state.completed and onGround and slowEnough then
              local p3 = unit:GetPointVec3()
              local sx = state.completedPosition and state.completedPosition.x or state.startPosition and state.startPosition.x or p3.x
              local sz = state.completedPosition and state.completedPosition.z or state.startPosition and state.startPosition.z or p3.z
              local dx = (p3.x - sx)
              local dz = (p3.z - sz)
              local moved = math.sqrt(dx*dx + dz*dz)
              -- Require a small reposition (e.g., taxi or liftoff) before new auto-load cycles
              if moved < 20 then
                canProcess = false
              end
            end

            if onGround and slowEnough and canProcess then
              -- Check zone requirement
              local inValidZone = false
              if groundCfg.RequirePickupZone then
                local inPickupZone = self:_isUnitInsidePickupZone(unit, true)
                
                if not inPickupZone and groundCfg.AllowInFOBZones then
                  -- Check FOB zones too
                  for _, fobZone in ipairs(self.FOBZones or {}) do
                    local fname = fobZone:GetName()
                    if self._ZoneActive.FOB[fname] ~= false then
                      local fobPoint = fobZone:GetPointVec3()
                      local unitPoint = unit:GetPointVec3()
                      local dx = (fobPoint.x - unitPoint.x)
                      local dz = (fobPoint.z - unitPoint.z)
                      local d = math.sqrt(dx*dx + dz*dz)
                      local fobRadius = self:_getZoneRadius(fobZone)
                      if d <= fobRadius then
                        inValidZone = true
                        break
                      end
                    end
                  end
                else
                  inValidZone = inPickupZone
                end
              else
                inValidZone = true -- no zone requirement
              end
              
              if inValidZone then
                -- Find nearby crates
                local p3 = unit:GetPointVec3()
                local searchRadius = groundCfg.SearchRadius or 50
                local nearby = _getNearbyFromSpatialGrid(p3.x, p3.z, searchRadius)

                local bestGroundCrate, bestGroundDist = nil, math.huge
                local loadableCrates = {}
                for name, meta in pairs(nearby.crates or {}) do
                  if meta.side == self.Side then
                    local dx = (meta.point.x - p3.x)
                    local dz = (meta.point.z - p3.z)
                    local d = math.sqrt(dx*dx + dz*dz)
                    if d <= searchRadius then
                      local entry = { name = name, meta = meta, dist = d }
                      table.insert(loadableCrates, entry)
                      if d < bestGroundDist then
                        bestGroundCrate, bestGroundDist = entry, d
                      end
                    end
                  end
                end

                if CTLD.Config and CTLD.Config.DebugGroundCrates then
                  local shouldReport = true
                  local gst = CTLD._groundLoadState and CTLD._groundLoadState[uname]
                  if gst and gst.reportHold then
                    -- only emit periodic heartbeat during hold
                    local last = gst.reportLast or 0
                    if (now - last) < (CTLD.Config.DebugGroundCratesInterval or 2.0) then
                      shouldReport = false
                    else
                      CTLD._groundLoadState[uname].reportLast = now
                    end
                  end
                  if shouldReport then
                  _debugCrateSight('GroundDebug', {
                    unit = uname,
                    now = now,
                    interval = CTLD.Config.DebugGroundCratesInterval,
                    step = CTLD.Config.DebugGroundCratesStep,
                    name = bestGroundCrate and bestGroundCrate.name or 'none',
                    distance = (bestGroundDist ~= math.huge) and bestGroundDist or nil,
                    count = #loadableCrates,
                    troops = 0,
                    radius = searchRadius,
                    typeHint = 'crate',
                    note = string.format('freeSlots=%d', math.max(0, capacity.maxCrates - currentCount))
                  })
                  end
                end
                
                if #loadableCrates > 0 then
                  -- Sort by distance, load closest first (up to capacity)
                  table.sort(loadableCrates, function(a, b) return a.dist < b.dist end)
                  
                  -- Determine how many we can load
                  local canLoad = math.min(#loadableCrates, capacity.maxCrates - currentCount)
                  local cratesToLoad = {}
                  for i = 1, canLoad do
                    table.insert(cratesToLoad, loadableCrates[i])
                  end
                  
                  if #cratesToLoad > 0 then
                    -- Ground load state machine
                    local state = CTLD._groundLoadState[uname]
                    if not state or not state.loading then
                      -- Start new load sequence
                      CTLD._groundLoadState[uname] = {
                        loading = true,
                        startTime = now,
                        cratesToLoad = cratesToLoad,
                        startPosition = { x = p3.x, z = p3.z },
                        lastCheckTime = now,
                      }
                      local msgData = _prepareGroundLoadMessage(self, 'Start', {
                        seconds = groundCfg.LoadDelay,
                        count = #cratesToLoad,
                      })
                      _coachSend(self, group, uname, 'ground_load_started', msgData, false)
                    else
                      -- Validate that crates in state still exist
                      local validCrates = {}
                      for _, crateInfo in ipairs(state.cratesToLoad or {}) do
                        -- Check if crate still exists in CTLD._crates
                        if CTLD._crates[crateInfo.name] then
                          table.insert(validCrates, crateInfo)
                        end
                      end
                      
                      -- If no valid crates remain, reset state
                      if #validCrates == 0 then
                        CTLD._groundLoadState[uname] = nil
                      else
                        -- Update state with only valid crates
                        state.cratesToLoad = validCrates
                        
                        -- Continue existing sequence
                        local elapsed = now - state.startTime
                        local remaining = (groundCfg.LoadDelay or 15) - elapsed
                        
                        -- Check if moved too much
                        local dx = (p3.x - state.startPosition.x)
                        local dz = (p3.z - state.startPosition.z)
                        local moved = math.sqrt(dx*dx + dz*dz)
                        if moved > 10 then -- moved more than 10m
                          _coachSend(self, group, uname, 'ground_load_aborted', {}, false)
                          CTLD._groundLoadState[uname] = nil
                        else
                          -- Progress message every 5 seconds
                          if (now - state.lastCheckTime) >= progressMsgInterval and remaining > 1 then
                            local msgData = _prepareGroundLoadMessage(self, 'Progress', {
                              remaining = math.max(0, math.ceil(remaining)),
                            })
                            _coachSend(self, group, uname, 'ground_load_progress', msgData, false)
                            state.lastCheckTime = now
                            state.reportHold = true
                          end
                          
                          -- Check if time elapsed
                          if remaining <= 0 then
                            -- Load the crates!
                            local loadedCount = 0
                            for _, crateInfo in ipairs(state.cratesToLoad) do
                              local success = self:_loadCrateIntoAircraft(group, crateInfo.name, crateInfo.meta)
                              if success then
                                loadedCount = loadedCount + 1
                              end
                            end
                            
                            if loadedCount > 0 then
                              local msgData = _prepareGroundLoadMessage(self, 'Complete', {
                                count = loadedCount,
                              })
                              _coachSend(self, group, uname, 'ground_load_complete', msgData, false)
                              -- Mark completion and remember where it happened so we don't
                              -- immediately restart another cycle while still parked.
                              CTLD._groundLoadState[uname] = {
                                completed = true,
                                completedTime = now,
                                completedPosition = { x = p3.x, z = p3.z },
                                reportHold = false,
                              }
                            else
                              -- Nothing actually loaded; clear state fully.
                              CTLD._groundLoadState[uname] = nil
                            end
                          end
                        end
                      end  -- end of validCrates > 0
                    end  -- end of state exists check
                  else
                    CTLD._groundLoadState[uname] = nil
                  end
                else
                  CTLD._groundLoadState[uname] = nil
                end
              else
                -- Not in a valid zone
                local state = CTLD._groundLoadState[uname]
                if state and state.sentZoneWarning ~= true then
                  -- Send zone requirement message (once)
                  local nearestZone, nearestDist = self:_nearestActivePickupZone(unit)
                  if nearestZone and nearestDist then
                    local isMetric = _getPlayerIsMetric(unit)
                    local brg = _bearingTo(unit, nearestZone)
                    local distV, distU = _fmtDistance(nearestDist, isMetric)
                    _coachSend(self, group, uname, 'ground_load_no_zone', {
                      zone_dist = distV,
                      zone_dist_u = distU,
                      zone_brg = brg
                    }, false)
                  end
                  if not state then
                    CTLD._groundLoadState[uname] = { sentZoneWarning = true }
                  else
                    state.sentZoneWarning = true
                  end
                end
              end
            else
              -- Not on ground or moving too fast, reset state
              local state = CTLD._groundLoadState[uname]
              if state and state.loading then
                -- Was loading but now lifted off or moved
                _coachSend(self, group, uname, 'ground_load_aborted', {}, false)
              end
              CTLD._groundLoadState[uname] = nil
            end
          else
            -- At capacity, no need to check
            CTLD._groundLoadState[uname] = nil
          end
        end
      end
    end
  end
end

-- Helper: Load a crate into an aircraft (shared by hover and ground load)
function CTLD:_loadCrateIntoAircraft(group, crateName, crateMeta)
  if not group or not crateName or not crateMeta then return false end
  
  local gname = group:GetName()
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return false end
  
  -- Destroy the static object first
  local obj = StaticObject.getByName(crateName)
  if obj then obj:destroy() end
  
  -- Clean up crate smoke refresh schedule
  _cleanupCrateSmoke(crateName)
  
  -- Remove from spatial grid and tracking
  _removeFromSpatialGrid(crateName, crateMeta.point, 'crate')
  CTLD._crates[crateName] = nil
  
  -- Add to loaded crates using existing method (maintains consistency with rest of code)
  self:_addLoadedCrate(group, crateMeta.key)
  
  -- Update inventory if enabled
  if self.Config.Inventory and self.Config.Inventory.Enabled and crateMeta.spawnZone then
    pcall(function() self:_updateInventoryOnPickup(crateMeta.spawnZone, crateMeta.key) end)
  end
  
  _logDebug(string.format('[Load] Loaded crate %s (%s) into %s', crateName, crateMeta.key, gname))
  return true
end
--#endregion Ground auto-load scanner

-- =========================
-- Troops
-- =========================
--#region Troops
function CTLD:_lookupCrateLabel(crateKey)
  if not crateKey then return 'Unknown Crate' end
  local cat = self.Config and self.Config.CrateCatalog or {}
  local def = cat[crateKey]
  if def then
    return def.menu or def.description or def.name or def.displayName or crateKey
  end
  return crateKey
end

function CTLD:_lookupTroopLabel(typeKey)
  if not typeKey or typeKey == '' then return 'Troops' end
  local cfg = self.Config and self.Config.Troops and self.Config.Troops.TroopTypes
  local def = cfg and cfg[typeKey]
  if def and def.label and def.label ~= '' then
    return def.label
  end
  return typeKey
end

function CTLD:_refreshLoadedTroopSummaryForGroup(groupName)
  if not groupName or groupName == '' then return end
  local load = CTLD._troopsLoaded[groupName]
  if not load or (load.count or 0) == 0 then
    CTLD._loadedTroopTypes[groupName] = nil
    return
  end

  local entries = {}
  if load.troopTypes and #load.troopTypes > 0 then
    entries = load.troopTypes
  else
    entries = { { typeKey = load.typeKey, count = load.count } }
  end

  local summary = { total = 0, byType = {}, labels = {} }
  for _, entry in ipairs(entries) do
    local typeKey = entry.typeKey or load.typeKey or 'Troops'
    local count = entry.count or 0
    if count > 0 then
      summary.byType[typeKey] = (summary.byType[typeKey] or 0) + count
      summary.labels[typeKey] = self:_lookupTroopLabel(typeKey)
      summary.total = summary.total + count
    end
  end

  if summary.total > 0 then
    CTLD._loadedTroopTypes[groupName] = summary
  else
    CTLD._loadedTroopTypes[groupName] = nil
  end
end

function CTLD:LoadTroops(group, opts)
  local gname = group:GetName()
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  -- Check for MEDEVAC crew pickup first
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled then
    local medevacPickedUp = self:CheckMEDEVACPickup(group)
    if medevacPickedUp then
      return -- MEDEVAC crew was picked up, don't continue with normal troop loading
    end
  end

  -- Ground requirement check for troop loading (realistic behavior)
  if self.Config.RequireGroundForTroopLoad then
    local unitType = _getUnitType(unit)
    local capacities = self.Config.AircraftCapacities or {}
    local specific = capacities[unitType]
    
    -- Check per-aircraft override first, then fall back to global config
    local requireGround = (specific and specific.requireGround ~= nil) and specific.requireGround or true
    
    if requireGround then
      -- Must be on the ground
      if _isUnitInAir(unit) then
        local isMetric = _getPlayerIsMetric(unit)
        local maxSpeed = (specific and specific.maxGroundSpeed) or self.Config.MaxGroundSpeedForLoading or 2.0
        local speedVal, speedUnit = _fmtSpeed(maxSpeed, isMetric)
        _eventSend(self, group, nil, 'troop_load_must_land', { max_speed = speedVal, speed_u = speedUnit })
        return
      end
      
      -- Check ground speed (must not be taxiing too fast)
      local groundSpeed = _getGroundSpeed(unit)
      local maxSpeed = (specific and specific.maxGroundSpeed) or self.Config.MaxGroundSpeedForLoading or 2.0
      
      if groundSpeed > maxSpeed then
        local isMetric = _getPlayerIsMetric(unit)
        local currentVal, currentUnit = _fmtSpeed(groundSpeed, isMetric)
        local maxVal, maxUnit = _fmtSpeed(maxSpeed, isMetric)
        _eventSend(self, group, nil, 'troop_load_too_fast', { 
          current_speed = currentVal, 
          max_speed = maxVal, 
          speed_u = maxUnit 
        })
        return
      end
    end
  end

  -- Check for nearby deployed troops first (allow pickup regardless of zone restrictions)
  local p3 = unit:GetPointVec3()
  local maxPickupDistance = 25  -- meters for ground-based troop pickup (matches hover pickup distance)
  local nearby = _getNearbyFromSpatialGrid(p3.x, p3.z, maxPickupDistance)
  
  local nearbyTroopGroup = nil
  local nearbyTroopMeta = nil
  local nearbyTroopDist = nil
  
  -- Search for nearby deployed troops
  for troopGroupName, troopMeta in pairs(nearby.troops) do
    if troopMeta.side == self.Side then
      local troopGroup = GROUP:FindByName(troopGroupName)
      if troopGroup and troopGroup:IsAlive() then
        local troopPos = troopGroup:GetCoordinate()
        if troopPos then
          local tp = troopPos:GetVec3()
          local dx = (tp.x - p3.x)
          local dz = (tp.z - p3.z)
          local d = math.sqrt(dx*dx + dz*dz)
          if d <= maxPickupDistance and ((not nearbyTroopDist) or d < nearbyTroopDist) then
            nearbyTroopGroup = troopGroup
            nearbyTroopMeta = troopMeta
            nearbyTroopDist = d
          end
        end
      end
    end
  end
  
  -- If we found nearby deployed troops, pick them up (bypass zone requirement)
  if nearbyTroopGroup and nearbyTroopMeta then
    -- Load the deployed troops
    local troopCount = nearbyTroopMeta.count or 0
    local typeKey = nearbyTroopMeta.typeKey or 'AS'
    local troopWeight = nearbyTroopMeta.weightKg or 0
    
    -- Check aircraft capacity
    local capacity = _getAircraftCapacity(unit)
    local maxTroops = capacity.maxTroops
    local maxWeight = capacity.maxWeightKg or 0
    
    local currentTroops = CTLD._troopsLoaded[gname]
    local currentTroopCount = currentTroops and currentTroops.count or 0
    local totalTroopCount = currentTroopCount + troopCount
    
    local carried = CTLD._loadedCrates[gname]
    local currentWeight = carried and carried.totalWeightKg or 0
    local wouldBeWeight = currentWeight + troopWeight
    
    -- Check capacity
    if totalTroopCount > maxTroops then
      local aircraftType = _getUnitType(unit) or 'aircraft'
      _msgGroup(group, string.format('Troop capacity exceeded! Current: %d, Adding: %d, Max: %d for %s', 
        currentTroopCount, troopCount, maxTroops, aircraftType))
      return
    end
    
    if maxWeight > 0 and wouldBeWeight > maxWeight then
      local aircraftType = _getUnitType(unit) or 'aircraft'
      _msgGroup(group, string.format('Weight capacity exceeded! Current: %dkg, Troops: %dkg, Max: %dkg for %s', 
        math.floor(currentWeight), math.floor(troopWeight), math.floor(maxWeight), aircraftType))
      return
    end
    
    -- Load the troops and remove from deployed tracking
    if currentTroops then
      local troopTypes = currentTroops.troopTypes or { { typeKey = currentTroops.typeKey, count = currentTroops.count } }
      table.insert(troopTypes, { typeKey = typeKey, count = troopCount })
      
      CTLD._troopsLoaded[gname] = {
        count = totalTroopCount,
        typeKey = 'Mixed',
        troopTypes = troopTypes,
        weightKg = currentTroops.weightKg + troopWeight,
      }
    else
      CTLD._troopsLoaded[gname] = {
        count = troopCount,
        typeKey = typeKey,
        troopTypes = { { typeKey = typeKey, count = troopCount } },
        weightKg = troopWeight,
      }
    end
    
    -- Remove from deployed tracking
    local troopGroupName = nearbyTroopGroup:GetName()
    _removeFromSpatialGrid(troopGroupName, nearbyTroopMeta.point, 'troops')
    CTLD._deployedTroops[troopGroupName] = nil
    
    -- Destroy the troop group
    nearbyTroopGroup:Destroy()
    
    self:_refreshLoadedTroopSummaryForGroup(gname)
    _eventSend(self, group, nil, 'troops_loaded', { count = totalTroopCount })
    _msgGroup(group, string.format('Picked up %d deployed troops (total onboard: %d)', troopCount, totalTroopCount))
    
    return  -- Successfully picked up deployed troops, exit function
  end
  
  -- No nearby deployed troops found, enforce pickup zone requirement for spawning new troops
  if self.Config.RequirePickupZoneForTroopLoad then
    local hasPickupZones = (self.PickupZones and #self.PickupZones > 0) or (self.Config.Zones and self.Config.Zones.PickupZones and #self.Config.Zones.PickupZones > 0)
    if not hasPickupZones then
      _eventSend(self, group, nil, 'no_pickup_zones', {})
      return
    end
    local zone, dist = self:_nearestActivePickupZone(unit)
    if not zone or not dist then
      -- No active pickup zone resolvable; provide helpful vectors to nearest configured zone if any
      local list = {}
      if self.Config and self.Config.Zones and self.Config.Zones.PickupZones then
        for _, z in ipairs(self.Config.Zones.PickupZones) do table.insert(list, z) end
      elseif self.PickupZones and #self.PickupZones > 0 then
        for _, mz in ipairs(self.PickupZones) do if mz and mz.GetName then table.insert(list, { name = mz:GetName() }) end end
      end
      local fbZone, fbDist = _nearestZonePoint(unit, list)
      if fbZone and fbDist then
        local isMetric = _getPlayerIsMetric(unit)
        local rZone = self:_getZoneRadius(fbZone) or 0
        local delta = math.max(0, fbDist - rZone)
        local v, u = _fmtRange(delta, isMetric)
        local up = unit:GetPointVec3(); local zp = fbZone:GetPointVec3()
        local brg = _bearingDeg({ x = up.x, z = up.z }, { x = zp.x, z = zp.z })
        _eventSend(self, group, nil, 'troop_pickup_zone_required', { zone_dist = v, zone_dist_u = u, zone_brg = brg })
      else
        _eventSend(self, group, nil, 'no_pickup_zones', {})
      end
      return
    end
    local inside = false
    if zone then
      local rZone = self:_getZoneRadius(zone) or 0
      if dist and rZone and dist <= rZone then inside = true end
    end
    if not inside then
      local isMetric = _getPlayerIsMetric(unit)
      local rZone = (self:_getZoneRadius(zone) or 0)
      local delta = (dist and rZone) and math.max(0, dist - rZone) or 0
      local v, u = _fmtRange(delta, isMetric)
      -- Bearing from player to zone center
      local up = unit:GetPointVec3()
      local zp = zone and zone:GetPointVec3() or nil
      local brg = 0
      if zp then
        brg = _bearingDeg({ x = up.x, z = up.z }, { x = zp.x, z = zp.z })
      end
      _eventSend(self, group, nil, 'troop_pickup_zone_required', { zone_dist = v, zone_dist_u = u, zone_brg = brg })
      return
    end
  end

  -- Determine troop type and composition
  local requestedType = (opts and (opts.typeKey or opts.type))
                        or (self.Config.Troops and self.Config.Troops.DefaultType)
                        or 'AS'
  local unitsList, label = self:_resolveTroopUnits(requestedType)
  local troopDef = (self.Config.Troops and self.Config.Troops.TroopTypes and self.Config.Troops.TroopTypes[requestedType]) or nil
  
  -- Check if we already have troops (allow mixing different types now)
  local currentTroops = CTLD._troopsLoaded[gname]
  
  -- Check aircraft capacity for troops
  local capacity = _getAircraftCapacity(unit)
  local maxTroops = capacity.maxTroops
  local maxWeight = capacity.maxWeightKg or 0
  local troopCount = #unitsList
  
  -- Calculate troop weight from catalog
  local troopWeight = 0
  if troopDef and troopDef.weightKg then
    troopWeight = troopDef.weightKg
  elseif troopCount > 0 then
    -- Fallback: estimate 100kg per soldier if no weight defined
    troopWeight = troopCount * 100
  end
  
  -- Check current cargo weight and troop count
  local carried = CTLD._loadedCrates[gname]
  local currentWeight = carried and carried.totalWeightKg or 0
  local currentTroopCount = currentTroops and currentTroops.count or 0
  local totalTroopCount = currentTroopCount + troopCount
  local wouldBeWeight = currentWeight + troopWeight
  
  -- Check total troop count limit
  if totalTroopCount > maxTroops then
    -- Aircraft cannot carry this many troops total
    local aircraftType = _getUnitType(unit) or 'aircraft'
    _msgGroup(group, string.format('Troop capacity exceeded! Current: %d, Adding: %d, Max: %d for %s', 
      currentTroopCount, troopCount, maxTroops, aircraftType))
    return
  end
  
  -- Check weight limit (if enabled)
  if maxWeight > 0 and wouldBeWeight > maxWeight then
    -- Weight capacity exceeded
    local aircraftType = _getUnitType(unit) or 'aircraft'
    _msgGroup(group, string.format('Weight capacity exceeded! Current: %dkg, Troops: %dkg, Max: %dkg for %s', 
      math.floor(currentWeight), math.floor(troopWeight), math.floor(maxWeight), aircraftType))
    return
  end
  
  -- ADD to existing troops or create new entry
  if currentTroops then
    -- Add to existing load (supports mixing types)
    local troopTypes = currentTroops.troopTypes or { { typeKey = currentTroops.typeKey, count = currentTroops.count } }
    table.insert(troopTypes, { typeKey = requestedType, count = troopCount })
    
    CTLD._troopsLoaded[gname] = {
      count = totalTroopCount,
      typeKey = 'Mixed',  -- Indicate mixed types
      troopTypes = troopTypes,  -- Store individual type details
      weightKg = currentTroops.weightKg + troopWeight,
    }
    self:_refreshLoadedTroopSummaryForGroup(gname)
    _eventSend(self, group, nil, 'troops_loaded', { count = totalTroopCount })
    _msgGroup(group, string.format('Loaded %d more troops (total: %d)', troopCount, totalTroopCount))
  else
    CTLD._troopsLoaded[gname] = {
      count = troopCount,
      typeKey = requestedType,
      troopTypes = { { typeKey = requestedType, count = troopCount } },
      weightKg = troopWeight,
    }
    self:_refreshLoadedTroopSummaryForGroup(gname)
    _eventSend(self, group, nil, 'troops_loaded', { count = troopCount })
  end
  
  -- Update DCS internal cargo weight
  self:_updateCargoWeight(group)
end

function CTLD:UnloadTroops(group, opts)
  local gname = group:GetName()
  local load = CTLD._troopsLoaded[gname]
  if not load or (load.count or 0) == 0 then _eventSend(self, group, nil, 'no_troops', {}) return end

  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  -- Check for MEDEVAC crew delivery to MASH first
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled then
    local medevacStatus = self:CheckMEDEVACDelivery(group, load)
    if medevacStatus == 'delivered' then
      -- Crew delivered to MASH, clear troops and return
      CTLD._troopsLoaded[gname] = nil
      CTLD._loadedTroopTypes[gname] = nil
      
      -- Update DCS internal cargo weight after delivery
      self:_updateCargoWeight(group)
      
      return
    elseif medevacStatus == 'pending' then
      return
    end
  end
  
  -- Determine if unit is in the air and check for fast-rope capability
  local isInAir = _isUnitInAir(unit)
  local canFastRope = false
  local isFastRope = false
  
  if isInAir then
    -- Unit is airborne - check if fast-rope is enabled and if altitude is safe
    if self.Config.EnableFastRope then
      local p3 = unit:GetPointVec3()
      local ground = land and land.getHeight and land.getHeight({x = p3.x, y = p3.z}) or 0
      local agl = p3.y - ground
      local maxFastRopeAGL = self.Config.FastRopeMaxHeight or 20
      local minFastRopeAGL = self.Config.FastRopeMinHeight or 5
      
      if agl > maxFastRopeAGL then
        -- Too high for fast-rope
        local isMetric = _getPlayerIsMetric(unit)
        local aglDisplay = _fmtAGL(agl, isMetric)
        _eventSend(self, group, nil, 'troop_unload_altitude_too_high', { 
          max_agl = math.floor(maxFastRopeAGL),
          current_agl = math.floor(agl)
        })
        return
      elseif agl < minFastRopeAGL then
        -- Too low for safe fast-rope
        _eventSend(self, group, nil, 'troop_unload_altitude_too_low', { 
          min_agl = math.floor(minFastRopeAGL),
          current_agl = math.floor(agl)
        })
        return
      else
        -- Within safe fast-rope window
        canFastRope = true
        isFastRope = true
      end
    else
      -- Fast-rope disabled - must land
      _msgGroup(group, "Must land to deploy troops. Fast-rope is disabled.", 10)
      return
    end
  end
  
  -- Restrict deploying troops inside Pickup Zones if configured
  if self.Config.ForbidTroopDeployInsidePickupZones then
    local activeOnly = (self.Config.ForbidChecksActivePickupOnly ~= false)
    local inside = false
    local ok, _ = pcall(function()
      inside = select(1, self:_isUnitInsidePickupZone(unit, activeOnly))
    end)
    if ok and inside then
      _eventSend(self, group, nil, 'troop_deploy_forbidden_in_pickup', {})
      return
    end
  end
  
  local p = unit:GetPointVec3()
  local here = { x = p.x, z = p.z }
  local hdgRad, _ = _headingRadDeg(unit)
  -- Offset troop spawn forward to avoid spawning under/near rotors
  local troopOffset = math.max(0, tonumber(self.Config.TroopSpawnOffset or 0) or 0)
  local center = (troopOffset > 0) and { x = here.x + math.sin(hdgRad) * troopOffset, z = here.z + math.cos(hdgRad) * troopOffset } or { x = here.x, z = here.z }

  -- Build the unit composition - handle mixed troop types
  local units = {}
  local spacing = 1.8
  local unitIndex = 0
  
  if load.troopTypes then
    -- Mixed types - spawn each type's units
    for _, troopTypeData in ipairs(load.troopTypes) do
      local comp, _ = self:_resolveTroopUnits(troopTypeData.typeKey)
      for i=1, #comp do
        unitIndex = unitIndex + 1
        local dx = (unitIndex-1) * spacing
        local dz = ((unitIndex % 2) == 0) and 2.0 or -2.0
        table.insert(units, {
          type = tostring(comp[i] or 'Infantry AK'),
          name = string.format('CTLD-TROOP-%d', math.random(100000,999999)),
          x = center.x + dx, y = center.z + dz, heading = hdgRad
        })
      end
    end
  else
    -- Single type (legacy support)
    local comp, _ = self:_resolveTroopUnits(load.typeKey)
    for i=1, #comp do
      unitIndex = unitIndex + 1
      local dx = (unitIndex-1) * spacing
      local dz = ((unitIndex % 2) == 0) and 2.0 or -2.0
      table.insert(units, {
        type = tostring(comp[i] or 'Infantry AK'),
        name = string.format('CTLD-TROOP-%d', math.random(100000,999999)),
        x = center.x + dx, y = center.z + dz, heading = hdgRad
      })
    end
  end
  
  local groupData = {
    visible=false, lateActivation=false, tasks={}, task='Ground Nothing',
    units=units, route={}, name=string.format('CTLD_TROOPS_%d', math.random(100000,999999))
  }
  local spawned = _coalitionAddGroup(self.Side, Group.Category.GROUND, groupData, self.Config)
  if spawned then
    -- Track deployed troop groups for later pickup
    local troopGroupName = spawned:getName()
    CTLD._deployedTroops[troopGroupName] = {
      typeKey = load.typeKey,
      count = load.count,
      side = self.Side,
      spawnTime = timer.getTime(),
      point = { x = center.x, z = center.z },
      weightKg = load.weightKg or 0,
      behavior = opts and opts.behavior or 'defend'
    }
    -- Add to spatial index for efficient hover pickup
    _addToSpatialGrid(troopGroupName, CTLD._deployedTroops[troopGroupName], 'troops')
    
    CTLD._troopsLoaded[gname] = nil
    CTLD._loadedTroopTypes[gname] = nil
    
    -- Update DCS internal cargo weight after unloading troops
    self:_updateCargoWeight(group)
    
    -- Send appropriate message based on deployment method
    if isFastRope then
      local aircraftType = _getUnitType(unit) or 'aircraft'
      _eventSend(self, nil, self.Side, 'troops_fast_roped_coalition', { 
        count = #units, 
        player = _playerNameFromGroup(group),
        aircraft = aircraftType
      })
    else
      _eventSend(self, nil, self.Side, 'troops_unloaded_coalition', { count = #units, player = _playerNameFromGroup(group) })
    end
    
    -- Assign optional behavior
    local behavior = opts and opts.behavior or nil
    _logDebug(string.format("TROOP DEPLOY: Group '%s' spawned with behavior='%s'", 
      spawned:getName(), tostring(behavior)))
    
    if behavior == 'attack' and self.Config.AttackAI and self.Config.AttackAI.Enabled then
      _logDebug(string.format("TROOP DEPLOY: Initiating attack behavior for '%s'", spawned:getName()))
      local t = self:_assignAttackBehavior(spawned:getName(), center, false)
      -- Announce intentions globally
      local isMetric = _getPlayerIsMetric(group:GetUnit(1))
      if t and t.kind == 'base' then
        local brg = _bearingDeg({ x = center.x, z = center.z }, { x = t.point.x, z = t.point.z })
        local v, u = _fmtRange(t.dist or 0, isMetric)
        _eventSend(self, nil, self.Side, 'attack_base_announce', { unit_name = spawned:getName(), player = _playerNameFromGroup(group), base_name = t.name, brg = brg, rng = v, rng_u = u })
      elseif t and t.kind == 'enemy' then
        local brg = _bearingDeg({ x = center.x, z = center.z }, { x = t.point.x, z = t.point.z })
        local v, u = _fmtRange(t.dist or 0, isMetric)
        _eventSend(self, nil, self.Side, 'attack_enemy_announce', { unit_name = spawned:getName(), player = _playerNameFromGroup(group), enemy_type = t.etype or 'unit', brg = brg, rng = v, rng_u = u })
      else
        local v, u = _fmtRange((self.Config.AttackAI and self.Config.AttackAI.TroopSearchRadius) or 3000, isMetric)
        _eventSend(self, nil, self.Side, 'attack_no_targets', { unit_name = spawned:getName(), player = _playerNameFromGroup(group), rng = v, rng_u = u })
      end
    end
  else
    _eventSend(self, group, nil, 'troops_deploy_failed', { reason = 'DCS group spawn error' })
  end
end
--#endregion Troops

-- Internal: resolve troop composition list for a given type key and coalition
function CTLD:_resolveTroopUnits(typeKey)
  local tcfg = (self.Config.Troops and self.Config.Troops.TroopTypes) or {}
  local def = tcfg[typeKey or 'AS'] or {}
  
  -- Log warning if troop types are missing
  if not def or not def.size then
    _logError(string.format('WARNING: Troop type "%s" not found or incomplete. TroopTypes table has %d entries.', 
      typeKey or 'AS', 
      (tcfg and type(tcfg) == 'table') and #tcfg or 0))
  end
  
  local size = tonumber(def.size or 0) or 0
  if size <= 0 then size = 6 end
  local pool
  if self.Side == coalition.side.BLUE then
    pool = def.unitsBlue or def.units
  elseif self.Side == coalition.side.RED then
    pool = def.unitsRed or def.units
  else
    pool = def.units
  end
  if not pool or #pool == 0 then pool = { 'Infantry AK' } end
  
  -- Debug: Log what units will spawn
  local unitList = {}
  for i=1,math.min(size, 3) do 
    table.insert(unitList, pool[((i-1) % #pool) + 1])
  end
  _logDebug(string.format('Spawning %d troops for type "%s": %s%s', 
    size, 
    typeKey or 'AS',
    table.concat(unitList, ', '),
    size > 3 and '...' or ''))
  
  local list = {}
  for i=1,size do list[i] = pool[((i-1) % #pool) + 1] end
  local label = def.label or typeKey or 'Troops'
  return list, label
end

-- =========================
-- Public helpers
-- =========================
-- =========================
-- Auto-build FOB in zones
-- =========================
--#region Auto-build FOB in zones
function CTLD:AutoBuildFOBCheck()
  if not (self.FOBZones and #self.FOBZones > 0) then return end
  -- Find any FOB recipe definitions
  local fobDefs = {}
  for key,def in pairs(self.Config.CrateCatalog) do if def.isFOB and def.build then fobDefs[key] = def end end
  if next(fobDefs) == nil then return end

  for _,zone in ipairs(self.FOBZones) do
    local center = zone:GetPointVec3()
    local radius = self:_getZoneRadius(zone)
    local nearby = self:GetNearbyCrates({ x = center.x, z = center.z }, radius)
    -- filter to this coalition side
    local filtered = {}
    for _,c in ipairs(nearby) do if c.meta.side == self.Side then table.insert(filtered, c) end end
    nearby = filtered

    if #nearby > 0 then
      local counts = {}
      for _,c in ipairs(nearby) do counts[c.meta.key] = (counts[c.meta.key] or 0) + 1 end

      local function consumeCrates(key, qty)
        local removed = 0
        for _,c in ipairs(nearby) do
          if removed >= qty then break end
          if c.meta.key == key then
            local obj = StaticObject.getByName(c.name)
            if obj then obj:destroy() end
            _cleanupCrateSmoke(c.name)  -- Clean up smoke refresh schedule
            CTLD._crates[c.name] = nil
            removed = removed + 1
          end
        end
      end

      local built = false

      -- Prefer composite recipes
      for recipeKey,cat in pairs(fobDefs) do
        if type(cat.requires) == 'table' then
          local ok = true
          for reqKey,qty in pairs(cat.requires) do if (counts[reqKey] or 0) < qty then ok = false; break end end
          if ok then
            local gdata = cat.build({ x = center.x, z = center.z }, 0, cat.side or self.Side)
            local g = _coalitionAddGroup(cat.side or self.Side, cat.category or Group.Category.GROUND, gdata, self.Config)
            if g then
              for reqKey,qty in pairs(cat.requires) do consumeCrates(reqKey, qty) end
              _msgCoalition(self.Side, string.format('FOB auto-built at %s', zone:GetName()))
              built = true
              break -- move to next zone; avoid multiple builds per tick
            end
          end
        end
      end

      -- Then single-key FOB recipes
      if not built then
        for key,cat in pairs(fobDefs) do
          if not cat.requires and (counts[key] or 0) >= (cat.required or 1) then
            local gdata = cat.build({ x = center.x, z = center.z }, 0, cat.side or self.Side)
            local g = _coalitionAddGroup(cat.side or self.Side, cat.category or Group.Category.GROUND, gdata, self.Config)
            if g then
              consumeCrates(key, cat.required or 1)
              _msgCoalition(self.Side, string.format('FOB auto-built at %s', zone:GetName()))
              built = true
              break
            end
          end
        end
      end
      -- next zone iteration continues automatically
    end
  end
end
--#endregion Auto-build FOB in zones

-- =========================
-- Public helpers
-- =========================
--#region Public helpers
function CTLD:RegisterCrate(key, def)
  self.Config.CrateCatalog[key] = def
end

function CTLD:MergeCatalog(tbl)
  for k,v in pairs(tbl or {}) do self.Config.CrateCatalog[k] = v end
end

-- =========================
-- Inventory helpers
-- =========================
--#region Inventory helpers
function CTLD:InitInventory()
  if not (self.Config.Inventory and self.Config.Inventory.Enabled) then return end
  -- Seed stock for each configured pickup zone (by name only)
  for _,z in ipairs(self.PickupZones or {}) do
    local name = z:GetName()
    self:_SeedZoneStock(name, 1.0)
  end
end

function CTLD:_SeedZoneStock(zoneName, factor)
  if not zoneName then return end
  CTLD._stockByZone[zoneName] = CTLD._stockByZone[zoneName] or {}
  local f = factor or 1.0
  for key,def in pairs(self.Config.CrateCatalog or {}) do
    local n = tonumber(def.initialStock or 0) or 0
    n = math.max(0, math.floor(n * f + 0.0001))
    -- Only seed if not already present (avoid overwriting saved/progress state)
    if CTLD._stockByZone[zoneName][key] == nil then
      CTLD._stockByZone[zoneName][key] = n
    end
  end
end

function CTLD:_CreateFOBPickupZone(point, cat, hdg)
  -- Create a small pickup zone at the FOB to act as a supply point
  local name = string.format('FOB_PZ_%d', math.random(100000,999999))
  local v2 = (VECTOR2 and VECTOR2.New) and VECTOR2:New(point.x, point.z) or { x = point.x, y = point.z }
  local r = 150
  local z = ZONE_RADIUS:New(name, v2, r)
  table.insert(self.PickupZones, z)
  self._ZoneDefs.PickupZones[name] = { name = name, radius = r, active = true }
  self._ZoneActive.Pickup[name] = true
  table.insert(self.Config.Zones.PickupZones, { name = name, radius = r, active = true })
  -- Seed FOB stock at fraction of initial pickup stock
  local f = (self.Config.Inventory and self.Config.Inventory.FOBStockFactor) or 0.25
  self:_SeedZoneStock(name, f)
  _msgCoalition(self.Side, string.format('FOB supply established: %s (stock seeded at %d%%)', name, math.floor(f*100+0.5)))
  -- Auto-refresh map drawings so the new FOB pickup zone is visible immediately
  if self.Config.MapDraw and self.Config.MapDraw.Enabled then
    local ok, err = pcall(function() self:DrawZonesOnMap() end)
    if not ok then
      _logError(string.format('DrawZonesOnMap failed after FOB creation: %s', tostring(err)))
    end
  end
end
--#endregion Inventory helpers

-- =========================
-- FARP System
-- =========================
--#region FARP

-- Initialize FARP system (called from CTLD:New)
function CTLD:InitFARP()
  if not (CTLD.FARPConfig and CTLD.FARPConfig.Enabled) then return end
  _logInfo('FARP system initialized')
  
  -- Initialize unit ID counter for spawning service units
  CTLD._farpUnitIdCounter = CTLD._farpUnitIdCounter or 50000
end

-- Get next unique unit ID for FARP service units
function CTLD:GetNextUnitId()
  CTLD._farpUnitIdCounter = (CTLD._farpUnitIdCounter or 50000) + 1
  return CTLD._farpUnitIdCounter
end

-- Get FARP data for a FOB zone
function CTLD:GetFARPData(zoneName)
  if not zoneName then return nil end
  return CTLD._farpData[zoneName]
end

-- Find nearest FOB pickup zone to a point
function CTLD:FindNearestFOBZone(point)
  local nearestZone = nil
  local nearestDist = math.huge
  
  for _, zone in ipairs(self.PickupZones or {}) do
    local zname = zone:GetName()
    -- Check if this is a FOB zone (starts with FOB_PZ_)
    if zname and zname:match('^FOB_PZ_') then
      local zoneCenter = zone:GetVec2()
      local dist = ((point.x - zoneCenter.x)^2 + (point.z - zoneCenter.y)^2)^0.5
      local radius = self:_getZoneRadius(zone)
      
      if dist < (radius + 50) and dist < nearestDist then
        nearestZone = zone
        nearestDist = dist
      end
    end
  end
  
  return nearestZone, nearestDist
end

-- Spawn static objects for a FARP stage
function CTLD:SpawnFARPStatics(zoneName, stage, centerPoint, coalitionId)
  if not (CTLD.FARPConfig and CTLD.FARPConfig.StageLayouts[stage]) then
    _logError(string.format('Invalid FARP stage %d or missing layout config', stage))
    return false
  end
  
  local layout = CTLD.FARPConfig.StageLayouts[stage]
  local farpData = CTLD._farpData[zoneName] or { stage = 0, statics = {}, coalition = coalitionId }
  
  _logInfo(string.format('Spawning FARP Stage %d statics for zone %s (coalition %d)', stage, zoneName, coalitionId))
  
  -- Get coalition name for DCS
  -- Note: 'coalitionId' parameter is a number (1=red, 2=blue), not the coalition table
  local coalitionName = (coalitionId == 2) and 'blue' or 'red'
  
  -- Service vehicle types that need to be spawned as ground units, not statics
  local serviceVehicles = {
    ["M978 HEMTT Tanker"] = true,      -- Refuel service
    ["Ural-375 PBU"] = true,           -- Fuel support
    ["Ural-4320 APA-5D"] = true,       -- Ammo truck for rearm
    ["M1043 HMMWV Armament"] = true,   -- Command/coordination
    ["GAZ-66"] = true,                 -- Support vehicle
  }
  
  for _, obj in ipairs(layout) do
    -- Calculate world position from relative offset
    local worldX = centerPoint.x + obj.x
    local worldZ = centerPoint.z + obj.z
    local worldY = land.getHeight({x = worldX, y = worldZ})
    
    -- Check if this should be a service unit instead of static
    if serviceVehicles[obj.type] then
      -- Spawn as ground unit for FARP services
      local unitName = string.format('FARP_%s_S%d_%s_%d', zoneName, stage, obj.type:gsub('%s+', '_'), math.random(10000, 99999))
      local groupName = unitName .. '_Group'
      
      local groupData = {
        ["visible"] = false,
        ["taskSelected"] = true,
        ["route"] = {
          ["points"] = {
            [1] = {
              ["alt"] = 0,
              ["type"] = "Turning Point",
              ["action"] = "Off Road",
              ["alt_type"] = "BARO",
              ["form"] = "Off Road",
              ["y"] = worldZ,
              ["x"] = worldX,
              ["speed"] = 0,
              ["task"] = {
                ["id"] = "ComboTask",
                ["params"] = {
                  ["tasks"] = {}
                }
              }
            }
          }
        },
        ["hidden"] = false,
        ["units"] = {
          [1] = {
            ["transportable"] = {["randomTransportable"] = false},
            ["skill"] = "Average",
            ["type"] = obj.type,
            ["unitId"] = self:GetNextUnitId(),
            ["y"] = worldZ,
            ["x"] = worldX,
            ["name"] = unitName,
            ["heading"] = math.rad(obj.heading or 0),
            ["playerCanDrive"] = false
          }
        },
        ["y"] = worldZ,
        ["x"] = worldX,
        ["name"] = groupName,
        ["start_time"] = 0
      }
      
      local success, spawnedGroup = pcall(function()
        return coalition.addGroup(coalitionId, Group.Category.GROUND, groupData)
      end)
      
      if success and spawnedGroup then
        table.insert(farpData.statics, unitName)
        _logDebug(string.format('Spawned FARP service unit: %s at (%.1f, %.1f)', unitName, worldX, worldZ))
      else
        _logError(string.format('Failed to spawn FARP service unit: %s (%s)', obj.type, tostring(spawnedGroup)))
      end
    else
      -- Spawn as static object (decorative)
      local staticName = string.format('FARP_%s_S%d_%s_%d', zoneName, stage, obj.type:gsub('%s+', '_'), math.random(10000, 99999))
      
      -- Determine category and shape_name based on object type
      local category = "Fortifications"
      local shapeName = ""
      local linkUnit = nil
      local linkOffset = false
      local callsignID = math.random(1, 99)
      
      if obj.type == "FARP" then
        category = "Heliports"
        shapeName = "FARP"
        linkUnit = 0
        linkOffset = true
      end
      
      -- Create static object data
      local staticData = {
        ["type"] = obj.type,
        ["name"] = staticName,
        ["heading"] = math.rad(obj.heading or 0),
        ["x"] = worldX,
        ["y"] = worldZ,
        ["category"] = category,
        ["canCargo"] = false,
        ["shape_name"] = shapeName,
        ["rate"] = 100,
      }
      
      -- Add FARP-specific data
      if obj.type == "FARP" then
        staticData["linkUnit"] = linkUnit
        staticData["linkOffset"] = linkOffset
        staticData["callsign_id"] = callsignID
        staticData["frequencyList"] = {127.5, 129.5, 121.5}
        staticData["modulation"] = 0
      end
      
      -- Spawn the static
      local success, staticObj = pcall(function()
        return coalition.addStaticObject(coalitionId, staticData)
      end)
      
      if success and staticObj then
        table.insert(farpData.statics, staticName)
        _logDebug(string.format('Spawned FARP static: %s at (%.1f, %.1f)', staticName, worldX, worldZ))
      else
        _logError(string.format('Failed to spawn FARP static: %s (%s)', obj.type, tostring(staticObj)))
      end
    end
  end
  
  farpData.stage = stage
  farpData.coalition = coalitionId
  CTLD._farpData[zoneName] = farpData
  
  _logInfo(string.format('FARP Stage %d complete for zone %s - spawned %d statics', stage, zoneName, #farpData.statics))
  return true
end

-- FARP services are provided by DCS engine via F8 Ground Crew menu
-- The FARP static object (spawned at stage 3) provides built-in services when helicopters:
--   1. Land within the FARP's service radius (handled by DCS)
--   2. Open F8 menu -> Ground Crew
--   3. Request Refuel, Rearm, or Repair
-- Scripting cannot intercept or automate these services due to DCS API limitations

-- Upgrade a FOB to the next FARP stage
function CTLD:UpgradeFARP(group, zoneName)
  if not (CTLD.FARPConfig and CTLD.FARPConfig.Enabled) then
    MESSAGE:New('FARP system is disabled.', 10):ToGroup(group)
    return
  end
  
  local farpData = CTLD._farpData[zoneName] or { stage = 0, statics = {}, coalition = self.Side }
  local currentStage = farpData.stage or 0
  local nextStage = currentStage + 1
  
  -- Check if already maxed
  if nextStage > 3 then
    _eventSend(self, group, nil, 'farp_already_maxed', {})
    return
  end
  
  -- Get upgrade cost
  local upgradeCost = CTLD.FARPConfig.StageCosts[nextStage]
  if not upgradeCost then
    MESSAGE:New(string.format('Invalid FARP stage %d', nextStage), 10):ToGroup(group)
    return
  end
  
  -- Check salvage points
  local currentSalvage = CTLD._salvagePoints[self.Side] or 0
  if currentSalvage < upgradeCost then
    _eventSend(self, group, nil, 'farp_upgrade_insufficient_salvage', {
      stage = nextStage,
      need = upgradeCost,
      current = currentSalvage
    })
    return
  end
  
  -- Find the zone to get center point
  local zone = nil
  for _, z in ipairs(self.PickupZones or {}) do
    if z:GetName() == zoneName then
      zone = z
      break
    end
  end
  
  if not zone then
    MESSAGE:New('FOB zone not found!', 10):ToGroup(group)
    return
  end
  
  local center = zone:GetVec2()
  -- Offset FARP 80m north from FOB zone center to avoid spawned trucks
  local centerPoint = { x = center.x, z = center.y + 80 }
  
  -- Deduct salvage
  CTLD._salvagePoints[self.Side] = currentSalvage - upgradeCost
  
  _eventSend(self, group, nil, 'farp_upgrade_started', { stage = nextStage })
  
  local success = false
  
  -- Stage 3 uses MOOSE functional FARP, earlier stages use visual statics only
  if nextStage == 3 then
    success = self:SpawnFunctionalFARP(zoneName, centerPoint, self.Side)
  else
    success = self:SpawnFARPStatics(zoneName, nextStage, centerPoint, self.Side)
  end
  
  if success then
    local msgKey = (nextStage == 3) and 'farp_upgrade_complete_stage3' or 'farp_upgrade_complete'
    _eventSend(self, nil, self.Side, msgKey, {
      player = _playerNameFromGroup(group),
      stage = nextStage
    })
    
    _logInfo(string.format('%s upgraded FOB %s to FARP Stage %d (cost: %d salvage)', 
      _playerNameFromGroup(group), zoneName, nextStage, upgradeCost))
  else
    -- Refund salvage on failure
    CTLD._salvagePoints[self.Side] = currentSalvage
    MESSAGE:New('FARP upgrade failed! Salvage refunded.', 15):ToGroup(group)
  end
end

-- Spawn a functional FARP using MOOSE utilities (Stage 3 only)
function CTLD:SpawnFunctionalFARP(zoneName, centerPoint, coalitionId)
  _logInfo(string.format('Spawning functional FARP for zone %s (coalition %d)', zoneName, coalitionId))
  
  -- Convert coalition ID to country
  local countryId = (coalitionId == 2) and country.id.USA or country.id.RUSSIA
  
  -- Generate unique FARP name and frequency
  CTLD._farpCounter = (CTLD._farpCounter or 0) + 1
  local farpNameNumber = ((CTLD._farpCounter - 1) % 10) + 1
  local farpFreq = 129 + CTLD._farpCounter
  
  local farpClearNames = {
    [1]="London", [2]="Dallas", [3]="Paris", [4]="Moscow", [5]="Berlin",
    [6]="Rome", [7]="Madrid", [8]="Warsaw", [9]="Dublin", [10]="Perth",
  }
  
  local clearName = farpClearNames[farpNameNumber] or "Outpost"
  local farpName = string.format("%s FARP %dAM", clearName, farpFreq)
  
  -- Create coordinate from centerPoint
  local coord = COORDINATE:New(centerPoint.x, land.getHeight({x = centerPoint.x, y = centerPoint.z}), centerPoint.z)
  
  -- Spawn functional FARP using MOOSE utility
  -- This creates a FARP with actual service capability
  local success = pcall(function()
    UTILS.SpawnFARPAndFunctionalStatics(
      farpName,                      -- FARP name
      coord,                         -- Coordinate
      ENUMS.FARPType.FARP,          -- FARP type (visible)
      coalitionId,                   -- Coalition
      countryId,                     -- Country
      farpNameNumber,                -- Callsign number
      farpFreq,                      -- Frequency
      radio.modulation.AM,           -- Modulation
      nil,                           -- Link unit (auto)
      nil,                           -- Loadout type (default)
      nil,                           -- Resources (default)
      20,                            -- Fuel tons (20 tons each type)
      50                             -- Equipment quantity
    )
  end)
  
  if success then
    -- Store FARP data
    local farpData = CTLD._farpData[zoneName] or { stage = 0, statics = {}, coalition = coalitionId }
    farpData.stage = 3
    farpData.farpName = farpName
    farpData.frequency = farpFreq
    CTLD._farpData[zoneName] = farpData
    
    _logInfo(string.format('Functional FARP %s created at freq %dAM', farpName, farpFreq))
    
    -- Also add decorative statics around it from Stage 1 and 2 layouts
    self:SpawnFARPDecorations(zoneName, centerPoint, coalitionId)
    
    return true
  else
    _logError(string.format('Failed to spawn functional FARP for %s', zoneName))
    return false
  end
end

-- Spawn decorative statics around the functional FARP
function CTLD:SpawnFARPDecorations(zoneName, centerPoint, coalitionId)
  -- Decorative objects forming outermost square perimeter (120m from center)
  -- Functional FARP auto-spawns service objects in the center, these decorations complete the base
  local decorations = {
    -- North side - Command and operations
    { type = "FARP CP Blindage", x = 0, z = 120, heading = 180 },
    { type = "FARP Tent", x = -40, z = 120, heading = 180 },
    { type = "FARP Tent", x = 40, z = 120, heading = 180 },
    { type = "Shelter", x = -80, z = 120, heading = 180 },
    { type = "Windsock", x = 80, z = 120, heading = 0 },
    
    -- South side - Logistics and storage
    { type = "container_40ft", x = 0, z = -120, heading = 0 },
    { type = "FARP Tent", x = -50, z = -120, heading = 0 },
    { type = "FARP Tent", x = 50, z = -120, heading = 0 },
    { type = "FARP Ammo Dump Coating", x = -90, z = -120, heading = 0 },
    { type = "FARP Ammo Dump Coating", x = 90, z = -120, heading = 0 },
    
    -- East side - Fuel and support
    { type = "FARP Fuel Depot", x = 120, z = 40, heading = 270 },
    { type = "FARP Fuel Depot", x = 120, z = -40, heading = 270 },
    { type = "FARP Tent", x = 120, z = 0, heading = 270 },
    { type = "GeneratorF", x = 120, z = 80, heading = 270 },
    
    -- West side - Power and maintenance
    { type = "FARP Tent", x = -120, z = 40, heading = 90 },
    { type = "FARP Tent", x = -120, z = -40, heading = 90 },
    { type = "Electric power box", x = -120, z = 0, heading = 90 },
    { type = "GeneratorF", x = -120, z = 80, heading = 90 },
    
    -- Corner positions - Perimeter markers
    { type = "container_20ft", x = 110, z = 110, heading = 225 },
    { type = "container_20ft", x = -110, z = 110, heading = 135 },
    { type = "container_20ft", x = 110, z = -110, heading = 315 },
    { type = "container_20ft", x = -110, z = -110, heading = 45 },
  }
  
  for _, obj in ipairs(decorations) do
    local worldX = centerPoint.x + obj.x
    local worldZ = centerPoint.z + obj.z
    local staticName = string.format('FARP_%s_Decor_%s_%d', zoneName, obj.type:gsub('%s+', '_'), math.random(10000, 99999))
    
    local staticData = {
      ["type"] = obj.type,
      ["name"] = staticName,
      ["heading"] = math.rad(obj.heading or 0),
      ["x"] = worldX,
      ["y"] = worldZ,
      ["category"] = "Fortifications",
      ["canCargo"] = false,
      ["rate"] = 100,
    }
    
    pcall(function()
      coalition.addStaticObject(coalitionId, staticData)
    end)
  end
end

-- Show FARP status for nearby FOB
function CTLD:ShowFARPStatus(group)
  local unit = group:GetUnit(1)
  if not unit then return end
  
  local pos = unit:GetVec3()
  local point = { x = pos.x, z = pos.z }
  
  local fobZone, dist = self:FindNearestFOBZone(point)
  
  if not fobZone then
    _eventSend(self, group, nil, 'farp_not_at_fob', {})
    return
  end
  
  local zoneName = fobZone:GetName()
  local farpData = CTLD._farpData[zoneName] or { stage = 0 }
  local currentStage = farpData.stage or 0
  
  if currentStage >= 3 then
    -- Fully upgraded
    MESSAGE:New('FOB + FARP Status: Stage 3/3 (FULLY UPGRADED)\nFunctional FARP operational - use F8 Ground Crew menu\nFOB logistics: ACTIVE', 15):ToGroup(group)
  elseif currentStage > 0 then
    -- Partially upgraded
    local nextStage = currentStage + 1
    local nextCost = CTLD.FARPConfig.StageCosts[nextStage] or 0
    
    local statusMsg = string.format('FOB + FARP Status: Stage %d/3', currentStage)
    statusMsg = statusMsg .. '\nInfrastructure only - upgrade to Stage 3 for services'
    statusMsg = statusMsg .. '\nFOB logistics: ACTIVE'
    if nextStage <= 3 then
      statusMsg = statusMsg .. string.format('\nNext upgrade: %d salvage (Stage %d)', nextCost, nextStage)
    end
    
    MESSAGE:New(statusMsg, 15):ToGroup(group)
  else
    -- Base FOB, not yet upgraded
    local nextCost = CTLD.FARPConfig.StageCosts[1] or 0
    MESSAGE:New(string.format('FOB Status: Base FOB (not upgraded)\nUpgrade to FARP Stage 1 for %d salvage points.\n\nCurrent salvage: %d', 
      nextCost, CTLD._salvagePoints[self.Side] or 0), 15):ToGroup(group)
  end
end

-- Request FARP upgrade from menu
function CTLD:RequestFARPUpgrade(group)
  local unit = group:GetUnit(1)
  if not unit then return end
  
  local pos = unit:GetVec3()
  local point = { x = pos.x, z = pos.z }
  
  local fobZone, dist = self:FindNearestFOBZone(point)
  
  if not fobZone then
    _eventSend(self, group, nil, 'farp_not_at_fob', {})
    return
  end
  
  local zoneName = fobZone:GetName()
  self:UpgradeFARP(group, zoneName)
end

--#endregion FARP

-- =========================
-- Sling-Load Salvage - Manual Crate Support
-- =========================
--#region Manual Salvage Crates

-- Scan mission editor for pre-placed cargo statics and register them as salvage
function CTLD:ScanAndRegisterManualSalvageCrates()
  local cfg = self.Config.SlingLoadSalvage
  if not (cfg and cfg.Enabled and cfg.EnableManualCrates) then return end
  
  local prefix = cfg.ManualCratePrefix or 'SALVAGE-'
  local registered = 0
  
  _logInfo('[ManualSalvage] Scanning for pre-placed salvage crates...')
  
  -- Get all static objects in the mission
  local allStatics = {}
  for _, coalitionSide in pairs({coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL}) do
    local groups = coalition.getStaticObjects(coalitionSide) or {}
    for _, static in pairs(groups) do
      table.insert(allStatics, {obj = static, side = coalitionSide})
    end
  end
  
  for _, staticData in ipairs(allStatics) do
    local static = staticData.obj
    local staticSide = staticData.side
    
    if static and static:isExist() then
      local staticName = static:getName()
      
      -- Check if name starts with salvage prefix
      if staticName and staticName:sub(1, #prefix) == prefix then
        -- Check if it's a slingloadable cargo type
        local typeName = static:getTypeName()
        local isCargo = false
        for _, cargoType in ipairs(cfg.CargoTypes or {}) do
          if typeName == cargoType then
            isCargo = true
            break
          end
        end
        
        if isCargo then
          -- Parse the name to extract information
          -- Expected format: SALVAGE-{B|R}-{WEIGHT}KG-{ID}
          -- Example: SALVAGE-B-2000KG-CRASH01
          local sideChar, weightStr, id = staticName:match('^SALVAGE%-([BR])%-(%d+)KG%-(.+)$')
          
          if sideChar and weightStr then
            local collectingSide = (sideChar == 'B') and coalition.side.BLUE or coalition.side.RED
            local weight = tonumber(weightStr) or 1000
            
            -- Calculate reward based on weight class
            local rewardPer500kg = 3 -- default medium rate
            for _, wc in ipairs(cfg.WeightClasses or {}) do
              if weight >= wc.min and weight <= wc.max then
                rewardPer500kg = wc.rewardPer500kg or 3
                break
              end
            end
            local rewardValue = math.floor((weight / 500) * rewardPer500kg)
            
            -- Get position
            local pos = static:getPoint()
            local position = {x = pos.x, z = pos.z}
            
            -- Register the crate (no expiration for manual crates)
            CTLD._salvageCrates[staticName] = {
              side = collectingSide,
              weight = weight,
              spawnTime = timer.getTime(),
              position = position,
              initialHealth = 1.0,
              rewardValue = rewardValue,
              warningsSent = {},
              staticObject = static,
              crateClass = 'Manual',
              isManual = true,  -- Flag to skip expiration checks
            }
            
            registered = registered + 1
            _logInfo(string.format('[ManualSalvage] Registered: %s (Side=%s, Weight=%dkg, Reward=%dpts)', 
              staticName, sideChar, weight, rewardValue))
          else
            _logVerbose(string.format('[ManualSalvage] Skipping %s - invalid name format (use: SALVAGE-{B|R}-####KG-ID)', staticName))
          end
        else
          _logVerbose(string.format('[ManualSalvage] Skipping %s - not a cargo type (found: %s)', staticName, tostring(typeName)))
        end
      end
    end
  end
  
  if registered > 0 then
    _logInfo(string.format('[ManualSalvage] Registered %d manual salvage crate(s)', registered))
    _msgCoalition(self.Side, _fmtTemplate(self.Messages.slingload_manual_crates_registered, {count = registered}))
  else
    _logInfo('[ManualSalvage] No manual salvage crates found')
  end
end

--#endregion Manual Salvage Crates

-- =========================
-- MEDEVAC System
-- =========================
--#region MEDEVAC

-- Initialize MEDEVAC system (called from CTLD:New)
function CTLD:InitMEDEVAC()
  if not (CTLD.MEDEVAC and CTLD.MEDEVAC.Enabled) then return end
  
  -- Initialize salvage pools
  if CTLD.MEDEVAC.Salvage and CTLD.MEDEVAC.Salvage.Enabled then
    local before = CTLD._salvagePoints[self.Side]
    -- Check instance config for InitialSalvage override
    local initialValue = (self.Config.MEDEVAC and self.Config.MEDEVAC.InitialSalvage) or 0
    CTLD._salvagePoints[self.Side] = CTLD._salvagePoints[self.Side] or initialValue
    local after = CTLD._salvagePoints[self.Side]
    env.info(string.format('[InitMEDEVAC] Side=%s Salvage BEFORE=%s InitialValue=%s AFTER=%s', tostring(self.Side), tostring(before), tostring(initialValue), tostring(after)))
  end
  
  -- Setup event handler for unit deaths
  local handler = EVENTHANDLER:New()
  handler:HandleEvent(EVENTS.Dead)
  local selfref = self
  
  function handler:OnEventDead(eventData)
    -- First check if this is an invulnerable MEDEVAC crew member that needs respawning
    local unit = eventData.IniUnit
    if unit then
      local unitName = unit:GetName()
      if unitName then
        for crewGroupName, crewData in pairs(CTLD._medevacCrews) do
          if unitName:find(crewGroupName, 1, true) then
            local now = timer.getTime()
            if crewData.invulnerable and now < crewData.invulnerableUntil then
              _logVerbose(string.format('[MEDEVAC] Invulnerable crew member %s killed, respawning...', unitName))
              -- Respawn this crew member
              local id = timer.scheduleFunction(function()
                local grp = Group.getByName(crewGroupName)
                if grp and grp:isExist() then
                  local cfg = CTLD.MEDEVAC
                  local crewUnitType = cfg.CrewUnitTypes[crewData.side] or ((crewData.side == coalition.side.BLUE) and 'Soldier M4' or 'Paratrooper RPG-16')
                  -- Use the stored country ID from the original spawn
                  local countryId = crewData.countryId or ((crewData.side == coalition.side.BLUE) and (country.id.USA or 2) or 18)
                  
                  -- Random position near spawn point
                  local angle = math.random() * 2 * math.pi
                  local radius = 3 + math.random() * 5
                  local spawnX = crewData.position.x + math.cos(angle) * radius
                  local spawnZ = crewData.position.z + math.sin(angle) * radius
                  
                  local newUnitData = {
                    type = crewUnitType,
                    name = unitName..'_respawn',
                    x = spawnX,
                    y = spawnZ,
                    heading = math.random() * 2 * math.pi
                  }
                  
                  coalition.addGroup(crewData.side, Group.Category.GROUND, {
                    visible = false,
                    lateActivation = false,
                    tasks = {},
                    task = 'Ground Nothing',
                    route = {},
                    units = {newUnitData},
                    name = unitName..'_respawn_grp',
                    country = countryId
                  })
                  
                  _logVerbose(string.format('[MEDEVAC] Respawned invulnerable crew member %s', unitName))
                end
              end, nil, timer.getTime() + 1)
              _trackOneShotTimer(id)
              return -- Don't process as normal death
            end
          end
        end
      end
      
      -- Next check if this death wiped out an active MEDEVAC crew group
      -- Be defensive: unit may be a Moose wrapper or raw DCS unit, and
      -- not all objects will expose a "GetGroup" method.
      local dcsGroup = (unit and unit.GetGroup and unit:GetGroup()) or (unit and unit.getGroup and unit:getGroup()) or nil
      if dcsGroup then
        local gName = dcsGroup:GetName()
        if gName and CTLD._medevacCrews[gName] then
          local anyAlive = false
          local units = dcsGroup:GetUnits()
          if units then
            for _, u in ipairs(units) do
              if u and u:IsAlive() then
                anyAlive = true
                break
              end
            end
          end
          if not anyAlive then
            selfref:_RemoveMEDEVACCrew(gName, 'killed')
            return
          end
        end
      end
    end
    
    -- Normal death processing for vehicle spawning MEDEVAC crews
    if not unit then 
      _logDebug('[MEDEVAC] OnEventDead: No unit in eventData')
      return 
    end
    
    -- Get the underlying DCS unit to safely extract data
    local dcsUnit = unit.DCSUnit or unit
    if not dcsUnit then 
      _logDebug('[MEDEVAC] OnEventDead: No DCS unit')
      return 
    end
    
    -- Extract coalition from event data if available, otherwise from unit
    local unitCoalition = eventData.IniCoalition
    if not unitCoalition and unit and unit.GetCoalition then
      local success, result = pcall(function() return unit:GetCoalition() end)
      if success then
        unitCoalition = result
      end
    end
    
    if not unitCoalition then
      _logDebug('[MEDEVAC] OnEventDead: Could not determine coalition')
      return
    end
    
    if unitCoalition ~= selfref.Side then 
      _logDebug(string.format('[MEDEVAC] OnEventDead: Wrong coalition (unit: %s, CTLD: %s)', tostring(unitCoalition), tostring(selfref.Side)))
      return 
    end
    
    -- Extract category from event data if available
    local unitCategory = eventData.IniCategory or (unit.GetCategory and unit:GetCategory())
    if not unitCategory then
      _logDebug('[MEDEVAC] OnEventDead: Could not determine category')
      return
    end
    
    if unitCategory ~= Unit.Category.GROUND_UNIT then 
      _logDebug(string.format('[MEDEVAC] OnEventDead: Not a ground unit (category: %s)', tostring(unitCategory)))
      return 
    end
    
    -- Extract unit type name
    local unitType = eventData.IniTypeName or (unit.GetTypeName and unit:GetTypeName())
    if not unitType then 
      _logDebug('[MEDEVAC] OnEventDead: Could not determine unit type')
      return 
    end
    
    _logVerbose(string.format('[MEDEVAC] OnEventDead: Ground unit destroyed - %s', unitType))
    
    -- Check if this unit type is eligible for MEDEVAC
    local catalogEntry = selfref:_FindCatalogEntryByUnitType(unitType)
    
    if catalogEntry and catalogEntry.MEDEVAC == true then
      _logVerbose(string.format('[MEDEVAC] OnEventDead: %s is MEDEVAC eligible, spawning crew', unitType))
      -- Pass eventData instead of unit to get position/heading safely
      selfref:_SpawnMEDEVACCrew(eventData, catalogEntry)
    else
      if catalogEntry then
        _logDebug(string.format('[MEDEVAC] OnEventDead: %s found in catalog but MEDEVAC=%s', unitType, tostring(catalogEntry.MEDEVAC)))
      else
        _logDebug(string.format('[MEDEVAC] OnEventDead: %s not found in catalog', unitType))
      end
    end
    
    -- Sling-Load Salvage: Check if we should spawn a salvage crate for the OPPOSING coalition
    if selfref.Config.SlingLoadSalvage and selfref.Config.SlingLoadSalvage.Enabled then
      -- Get unit position
      local unitPos = nil
      if eventData.initiator and eventData.initiator.getPoint then
        local success, point = pcall(function() return eventData.initiator:getPoint() end)
        if success and point then
          unitPos = point
        end
      end
      
      if unitPos then
        -- Determine enemy coalition (who can collect this salvage)
        local enemySide = (selfref.Side == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
        selfref:_SpawnSlingLoadSalvageCrate(unitPos, unitType, enemySide, eventData)
      else
        _logDebug('[SlingLoadSalvage] Could not get unit position for salvage spawn')
      end
    end
  end
  
  self.MEDEVACHandler = handler
  
  -- Add hit event handler to prevent damage to invulnerable crews
  local hitHandler = EVENTHANDLER:New()
  hitHandler:HandleEvent(EVENTS.Hit)
  
  function hitHandler:OnEventHit(eventData)
    local unit = eventData.TgtUnit
    if not unit then return end
    
    local unitName = unit:GetName()
    if not unitName then return end
    
    -- Check if this unit belongs to an invulnerable MEDEVAC crew
    for crewGroupName, crewData in pairs(CTLD._medevacCrews) do
      if unitName:find(crewGroupName, 1, true) then
        -- This unit is part of a MEDEVAC crew, check invulnerability
        local now = timer.getTime()
        if crewData.invulnerable and now < crewData.invulnerableUntil then
          _logVerbose(string.format('[MEDEVAC] Unit %s is invulnerable, preventing damage', unitName))
          -- Can't directly prevent damage in DCS, but log it
          -- Infantry is fragile anyway, so invulnerability is more of a "hope they survive" thing
          return
        end
      end
    end
  end
  
  self.MEDEVACHitHandler = hitHandler
  
  -- Start crew timeout checker (runs every 30 seconds)
  self.MEDEVACSched = SCHEDULER:New(nil, function()
    local ok, err = pcall(function() selfref:_CheckMEDEVACTimeouts() end)
    if not ok then _logError('MEDEVAC timeout scheduler error: '..tostring(err)) end
  end, {}, 30, 30)
  
  -- Sling-load salvage is handled by adaptive background loop
  if self.Config.SlingLoadSalvage and self.Config.SlingLoadSalvage.Enabled then
    _logInfo('Sling-Load Salvage system initialized for coalition '..tostring(self.Side))
  end
  
  -- Initialize MASH zones from config
  self:_InitMASHZones()
  
  _logInfo('MEDEVAC system initialized for coalition '..tostring(self.Side))
end

-- Find catalog entry that spawns a given unit type
function CTLD:_FindCatalogEntryByUnitType(unitType)
  local catalog = self.Config.CrateCatalog or {}
  local catalogSize = 0
  for _ in pairs(catalog) do catalogSize = catalogSize + 1 end
  
  _logDebug(string.format('[MEDEVAC] Searching catalog for unit type: %s (catalog has %d entries)', unitType, catalogSize))
  
  for key, def in pairs(catalog) do
    -- Check if this catalog entry builds the unit type
    if def.build then
      -- Check global lookup table that maps build functions to unit types
      if type(def.build) == 'function' and _CTLD_BUILD_UNIT_TYPES and _CTLD_BUILD_UNIT_TYPES[def.build] then
        local buildUnitType = _CTLD_BUILD_UNIT_TYPES[def.build]
        _logDebug(string.format('[MEDEVAC] Catalog entry %s has unitType=%s (from global lookup)', key, tostring(buildUnitType)))
        if buildUnitType == unitType then
          _logDebug(string.format('[MEDEVAC] Found catalog entry for %s via global lookup: key=%s', unitType, key))
          return def
        end
      end
      
      -- Fallback: Try to extract unit type from build function string (legacy compatibility)
      local buildStr = tostring(def.build)
      if buildStr:find(unitType, 1, true) then
        _logDebug(string.format('[MEDEVAC] Found catalog entry for %s via string search: key=%s', unitType, key))
        return def
      end
    else
      _logDebug(string.format('[MEDEVAC] Catalog entry %s has no build function', key))
    end
    
    -- Also check if catalog entry has a unitType field directly
    if def.unitType and def.unitType == unitType then
      _logDebug(string.format('[MEDEVAC] Found catalog entry for %s via def.unitType field: key=%s', unitType, key))
      return def
    end
  end
  
  _logDebug(string.format('[MEDEVAC] No catalog entry found for unit type: %s', unitType))
  return nil
end

-- Spawn MEDEVAC crew when vehicle destroyed
function CTLD:_SpawnMEDEVACCrew(eventData, catalogEntry)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end
  
  -- Probability check: does the crew survive to request rescue?
  -- Use coalition-specific survival chance
  local survivalChance = 0.02 -- default fallback
  if cfg.CrewSurvivalChance then
    if type(cfg.CrewSurvivalChance) == 'table' then
      -- Per-coalition config
      survivalChance = cfg.CrewSurvivalChance[self.Side] or 0.02
    else
      -- Legacy single value config (backward compatibility)
      local chanceValue = cfg.CrewSurvivalChance
      if type(chanceValue) == 'number' then
        survivalChance = chanceValue
      end
    end
  end
  
  local roll = math.random()
  if roll > survivalChance then
    -- Crew did not survive
    _logVerbose(string.format('[MEDEVAC] Crew did not survive (roll: %.4f > %.4f)', roll, survivalChance))
    return
  end
  _logVerbose(string.format('[MEDEVAC] Crew survived! (roll: %.4f <= %.4f) - will spawn in 5 minutes after battle clears', roll, survivalChance))
  
  -- Extract data from eventData instead of calling methods on dead unit
  local unit = eventData.IniUnit
  local unitType = eventData.IniTypeName or (unit and unit.GetTypeName and unit:GetTypeName())
  local unitName = eventData.IniUnitName or (unit and unit.GetName and unit:GetName()) or 'Unknown'
  
  -- Get position - the unit is dead, so we need to get position from the DCS initiator object
  local pos = nil
  
  -- Try the raw DCS initiator object (this should have the last known position)
  if eventData.initiator then
    _logVerbose('[MEDEVAC] Trying DCS initiator object')
    local dcsUnit = eventData.initiator
    if dcsUnit and dcsUnit.getPoint then
      local success, point = pcall(function() return dcsUnit:getPoint() end)
      if success and point then
        pos = point
        _logVerbose(string.format('[MEDEVAC] Got position from DCS initiator:getPoint(): %.0f, %.0f, %.0f', pos.x, pos.y, pos.z))
      end
    end
    if not pos and dcsUnit and dcsUnit.getPosition then
      local success, position = pcall(function() return dcsUnit:getPosition() end)
      if success and position and position.p then
        pos = position.p
        _logVerbose(string.format('[MEDEVAC] Got position from DCS initiator:getPosition().p: %.0f, %.0f, %.0f', pos.x, pos.y, pos.z))
      end
    end
  end
  
  -- Try IniDCSUnit
  if not pos and eventData.IniDCSUnit then
    _logVerbose('[MEDEVAC] Trying IniDCSUnit')
    local dcsUnit = eventData.IniDCSUnit
    if dcsUnit and dcsUnit.getPoint then
      local success, point = pcall(function() return dcsUnit:getPoint() end)
      if success and point then
        pos = point
        _logVerbose(string.format('[MEDEVAC] Got position from IniDCSUnit:getPoint(): %.0f, %.0f, %.0f', pos.x, pos.y, pos.z))
      end
    end
  end
  
  if not pos or not unitType then
    _logVerbose(string.format('[MEDEVAC] Cannot spawn crew - missing position (pos=%s) or unit type (type=%s)', tostring(pos), tostring(unitType)))
    return
  end
  
  -- Get heading if possible
  local heading = 0
  if unit and unit.GetHeading then
    local success, result = pcall(function() return unit:GetHeading() end)
    if success and result then
      heading = result
    end
  end
  
  -- Determine crew size
  local crewSize = catalogEntry.crewSize or cfg.CrewDefaultSize or 2
  
  -- Determine salvage value
  local salvageValue = catalogEntry.salvageValue
  if not salvageValue then
    salvageValue = catalogEntry.required or cfg.Salvage.DefaultValue or 1
  end
  
  -- Find nearest enemy to spawn crew toward them
  local spawnPoint = { x = pos.x, z = pos.z }
  local enemySide = (self.Side == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
  local nearestEnemy = self:_findNearestEnemyGround({ x = pos.x, z = pos.z }, 2000) -- 2km search
  
  if nearestEnemy and nearestEnemy.point then
    -- Calculate direction toward enemy
    local dx = nearestEnemy.point.x - pos.x
    local dz = nearestEnemy.point.z - pos.z
    local dist = math.sqrt(dx*dx + dz*dz)
    if dist > 0 then
      local dirX = dx / dist
      local dirZ = dz / dist
      local offset = cfg.CrewSpawnOffset or 15
      spawnPoint.x = pos.x + dirX * offset
      spawnPoint.z = pos.z + dirZ * offset
    end
  else
    -- No enemy found, spawn at random offset
    local angle = math.random() * 2 * math.pi
    local offset = cfg.CrewSpawnOffset or 15
    spawnPoint.x = pos.x + math.cos(angle) * offset
    spawnPoint.z = pos.z + math.sin(angle) * offset
  end
  
  -- Prepare spawn data but delay actual spawning by 5 minutes (300 seconds)
  local spawnDelay = cfg.CrewSpawnDelay or 300 -- 5 minutes default
  local selfref = self
  
  _logVerbose(string.format('[MEDEVAC] Crew will spawn in %d seconds after battle clears', spawnDelay))
  
  local spawnTimerId = timer.scheduleFunction(function()
    -- Now spawn the crew after battle has cleared
    local crewGroupName = string.format('MEDEVAC_Crew_%s_%d', unitType, math.random(100000, 999999))
    local crewUnitType = catalogEntry.crewType or cfg.CrewUnitTypes[selfref.Side] or ((selfref.Side == coalition.side.BLUE) and 'Soldier M4' or 'Infantry AK')
    
    _logVerbose(string.format('[MEDEVAC] Coalition: %s, CrewUnitType selected: %s, catalogEntry.crewType=%s, cfg.CrewUnitTypes[side]=%s',
      (selfref.Side == coalition.side.BLUE and 'BLUE' or 'RED'),
      crewUnitType,
      tostring(catalogEntry.crewType),
      tostring(cfg.CrewUnitTypes and cfg.CrewUnitTypes[selfref.Side])
    ))
    
    -- Determine if crew gets a MANPADS
    -- Use coalition-specific MANPADS spawn chance
    local manPadChance = 0.1 -- default fallback
    if cfg.ManPadSpawnChance then
      if type(cfg.ManPadSpawnChance) == 'table' then
        -- Per-coalition config
        manPadChance = cfg.ManPadSpawnChance[selfref.Side] or 0.1
      else
        -- Legacy single value config (backward compatibility)
        local chanceValue = cfg.ManPadSpawnChance
        if type(chanceValue) == 'number' then
          manPadChance = chanceValue
        end
      end
    end
    local spawnManPad = math.random() <= manPadChance
    local manPadIndex = nil
    if spawnManPad and crewSize > 1 then
      manPadIndex = math.random(1, crewSize) -- Random crew member gets the MANPADS
      _logVerbose(string.format('[MEDEVAC] Crew will include MANPADS (unit %d of %d)', manPadIndex, crewSize))
    end
    
    -- Get country ID from the destroyed unit instead of trying to map coalition to country
    -- This is the same approach used by the Medevac_KHASHURI.lua script
    local countryId = nil
    if eventData.initiator and eventData.initiator.getCountry then
      local success, result = pcall(function() return eventData.initiator:getCountry() end)
      if success and result then
        countryId = result
        _logVerbose(string.format('[MEDEVAC] Got country ID %d from destroyed unit', countryId))
      end
    end
    
    -- Fallback if we couldn't get it from the unit
    if not countryId then
      _logVerbose('[MEDEVAC] WARNING: Could not get country from dead unit, using fallback')
      if selfref.Side == coalition.side.BLUE then
        countryId = country.id.USA or 2
      else
        countryId = country.id.CJTF_RED or 18  -- Use CJTF RED as fallback
      end
    end
    
    _logVerbose(string.format('[MEDEVAC] Spawning crew now - coalition=%s, countryId=%d, crewUnitType=%s', 
      (selfref.Side == coalition.side.BLUE and 'BLUE' or 'RED'),
      countryId,
      crewUnitType))
    
    local groupData = {
      visible = false,
      lateActivation = false,
      tasks = {},
      task = 'Ground Nothing',
      route = {},
      units = {},
      name = crewGroupName
      -- Country ID passed directly to coalition.addGroup(), not in groupData
    }
    
    for i = 1, crewSize do
      -- Randomize position within a small radius (3-8 meters) for natural scattered appearance
      local angle = math.random() * 2 * math.pi
      local radius = 3 + math.random() * 5 -- 3-8 meters from center
      local offsetX = math.cos(angle) * radius
      local offsetZ = math.sin(angle) * radius
      
      -- Determine unit type (MANPADS or regular crew)
      local unitType = crewUnitType
      if i == manPadIndex then
        unitType = cfg.ManPadUnitTypes[selfref.Side] or crewUnitType
        _logVerbose(string.format('[MEDEVAC] Unit %d assigned MANPADS type: %s', i, unitType))
      end
      
      table.insert(groupData.units, {
        type = unitType,
        name = string.format('%s_U%d', crewGroupName, i),
        x = spawnPoint.x + offsetX,
        y = spawnPoint.z + offsetZ,
        heading = math.random() * 2 * math.pi -- Random heading for each unit
      })
    end
    
    _logVerbose(string.format('[MEDEVAC] About to call coalition.addGroup with country=%d (coalition=%s)', 
      countryId,
      (selfref.Side == coalition.side.BLUE and 'BLUE' or 'RED')))
    
    -- CRITICAL: First parameter is COUNTRY ID, not coalition ID!
    -- This matches Medevac_KHASHURI.lua line 500: coalition.addGroup(_deadUnit:getCountry(), ...)
    local crewGroup = coalition.addGroup(countryId, Group.Category.GROUND, groupData)
    
    if not crewGroup then
      _logVerbose('[MEDEVAC] Failed to spawn crew')
      return
    end
    
    -- Double-check what coalition the spawned group actually belongs to
    local spawnedCoalition = crewGroup:getCoalition()
    _logVerbose(string.format('[MEDEVAC] Crew group %s spawned successfully - actual coalition: %s (%d)', 
      crewGroupName,
      (spawnedCoalition == coalition.side.BLUE and 'BLUE' or spawnedCoalition == coalition.side.RED and 'RED' or 'NEUTRAL'),
      spawnedCoalition))
    
    -- Set crew to hold position and defend themselves
    local crewController = crewGroup:getController()
    if crewController then
      crewController:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.RETURN_FIRE)
      crewController:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
      
      -- Make crew immortal and/or invisible during announcement delay to prevent early death
      if cfg.CrewImmortalDuringDelay then
        local setImmortal = {
          id = 'SetImmortal',
          params = { value = true }
        }
        Controller.setCommand(crewController, setImmortal)
        _logVerbose('[MEDEVAC] Crew set to immortal during announcement delay')
      end
      
      if cfg.CrewInvisibleDuringDelay then
        local setInvisible = {
          id = 'SetInvisible',
          params = { value = true }
        }
        Controller.setCommand(crewController, setInvisible)
        _logVerbose('[MEDEVAC] Crew set to invisible to AI during announcement delay')
      end
    end
    
    -- Track crew immediately (but don't make mission available yet)
    -- Smoke will be popped AFTER the announcement delay when they actually call for help
    local crewData = {
      vehicleType = unitType,
      side = selfref.Side,
      countryId = countryId,  -- Store country ID for respawning
      spawnTime = timer.getTime(),
      position = spawnPoint,
      salvageValue = salvageValue,
      originalHeading = heading,
      requestTime = nil, -- Will be set after announcement delay
      warningsSent = {},
      invulnerable = false,
      invulnerableUntil = 0,
      greetingSent = false
    }
    CTLD._medevacCrews[crewGroupName] = crewData
    
    -- Wait before announcing mission (verify crew survival)
    local announceDelay = cfg.CrewAnnouncementDelay or 60
    _logVerbose(string.format('[MEDEVAC] Will announce mission in %d seconds if crew survives', announceDelay))
    
    local announceTimerId = timer.scheduleFunction(function()
      -- Check if crew still exists
      local g = Group.getByName(crewGroupName)
      if not g or not g:isExist() then
        _logVerbose(string.format('[MEDEVAC] Crew %s died before announcement, mission cancelled', crewGroupName))
        CTLD._medevacCrews[crewGroupName] = nil
        return
      end
      
      -- Crew survived! Now announce to players and make mission available
      _logVerbose(string.format('[MEDEVAC] Crew %s survived, announcing mission', crewGroupName))
      
      -- Optionally remove immortality after announcement; visibility is controlled by KeepCrewInvisibleForLifetime
      local crewController = g:getController()
      if crewController then
        -- Remove immortality unless config says to keep it
        if cfg.CrewImmortalDuringDelay and not cfg.CrewImmortalAfterAnnounce then
          local setMortal = {
            id = 'SetImmortal',
            params = { value = false }
          }
          Controller.setCommand(crewController, setMortal)
          _logVerbose('[MEDEVAC] Crew immortality removed, now vulnerable')
        elseif cfg.CrewImmortalAfterAnnounce then
          _logVerbose('[MEDEVAC] Crew remains immortal after announcement (per config)')
        end
      end
      
      -- Pop smoke now that they're calling for help
      if cfg.PopSmokeOnSpawn then
        local smokeColor = (cfg.SmokeColor and cfg.SmokeColor[selfref.Side]) or trigger.smokeColor.Red
        _spawnMEDEVACSmoke(spawnPoint, smokeColor, cfg)
        _logVerbose(string.format('[MEDEVAC] Crew popped smoke after announcement (color: %d)', smokeColor))
      end
      
      local grid = selfref:_GetMGRSString(spawnPoint)
      
      -- Pick random request message
      local requestMessages = cfg.RequestAirLiftMessages or {
        "Stranded Crew: This is {vehicle} crew at {grid}. Need pickup ASAP! We have {salvage} salvage to collect."
      }
      local messageTemplate = requestMessages[math.random(1, #requestMessages)]
      
      -- Replace placeholders
      local message = messageTemplate
      message = message:gsub("{vehicle}", unitType)
      message = message:gsub("{grid}", grid)
      message = message:gsub("{crew_size}", tostring(crewSize))
      message = message:gsub("{salvage}", tostring(salvageValue))
      
      _msgCoalition(selfref.Side, message, 25)
      
      -- Now crew is requesting pickup
      CTLD._medevacCrews[crewGroupName].requestTime = timer.getTime()
      
      -- Create map marker
      if cfg.MapMarkers and cfg.MapMarkers.Enabled then
        local markerID = selfref:_CreateMEDEVACMarker(spawnPoint, unitType, crewSize, salvageValue, crewGroupName)
        CTLD._medevacCrews[crewGroupName].markerID = markerID
      end
      
    end, nil, timer.getTime() + announceDelay)
    _trackOneShotTimer(announceTimerId)
    
  end, nil, timer.getTime() + spawnDelay)
  _trackOneShotTimer(spawnTimerId)
  
end

-- Create map marker for MEDEVAC crew
function CTLD:_CreateMEDEVACMarker(position, vehicleType, crewSize, salvageValue, crewGroupName)
  local cfg = CTLD.MEDEVAC.MapMarkers
  if not cfg or not cfg.Enabled then return nil end
  
  local grid = self:_GetMGRSString(position)
  local text = string.format('%s: %s Crew (%d) - Salvage: %d - %s', 
    cfg.IconText or '🔴 MEDEVAC',
    vehicleType,
    crewSize,
    salvageValue,
    grid
  )
  
  local markerID = _nextMarkupId()
  trigger.action.markToCoalition(markerID, text, {x = position.x, y = 0, z = position.z}, self.Side, true)
  
  return markerID
end

-- Get MGRS grid string for position
function CTLD:_GetMGRSString(position)
  if not position then
    return 'N/A'
  end
  local lat, lon = coord.LOtoLL({x = position.x, y = 0, z = position.z})
  local mgrs = coord.LLtoMGRS(lat, lon)
  if mgrs and mgrs.UTMZone and mgrs.MGRSDigraph then
    -- Ensure Easting and Northing are numbers
    local easting = tonumber(mgrs.Easting) or 0
    local northing = tonumber(mgrs.Northing) or 0
    return string.format('%s%s %05d %05d', mgrs.UTMZone, mgrs.MGRSDigraph, easting, northing)
  end
  return string.format('%.0f, %.0f', position.x, position.z)
end

-- Check for MEDEVAC crew timeouts and send warnings
function CTLD:_CheckMEDEVACTimeouts()
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end
  
  local now = timer.getTime()
  local toRemove = {}
  
  for crewGroupName, data in pairs(CTLD._medevacCrews) do
    if data.side == self.Side then
      local requestTime = data.requestTime
      if requestTime then -- Only check after crew has requested pickup
        local elapsed = now - requestTime
        if type(data.warningsSent) ~= 'table' then
          data.warningsSent = {}
        end
        local remaining = (cfg.CrewTimeout or 3600) - elapsed
        
        -- Check for approaching rescue helos (pop smoke and send greeting with cooldown)
        if cfg.PopSmokeOnApproach then
          local approachDist = cfg.PopSmokeOnApproachDistance or 5000
          local crewPos = data.position
          local smokeCooldown = cfg.SmokeCooldown or 900  -- Default 15 minutes (900 seconds)
          local lastSmoke = data.lastSmokeTime or 0
          local canPopSmoke = (now - lastSmoke) >= smokeCooldown
          
          if canPopSmoke then
            -- Check all units of this coalition for nearby transport helos
            local coalitionUnits = coalition.getGroups(self.Side, Group.Category.AIRPLANE)
            local heloGroups = coalition.getGroups(self.Side, Group.Category.HELICOPTER)
            
            if heloGroups then
              for _, grp in ipairs(heloGroups) do
                if grp and grp:isExist() then
                  local units = grp:getUnits()
                  if units then
                    for _, unit in ipairs(units) do
                      if unit and unit:isExist() and unit:isActive() then
                        -- Check if this is a transport helo (in AllowedAircraft list)
                        local unitType = unit:getTypeName()
                        local isTransport = false
                        if self.Config.AllowedAircraft then
                          for _, allowed in ipairs(self.Config.AllowedAircraft) do
                            if unitType == allowed then
                              isTransport = true
                              break
                            end
                          end
                        end
                        
                        if isTransport then
                          local unitPos = unit:getPoint()
                          if unitPos and crewPos then
                            local dx = unitPos.x - crewPos.x
                            local dz = unitPos.z - crewPos.z
                            local dist = math.sqrt(dx*dx + dz*dz)
                            
                            if dist <= approachDist then
                              -- Rescue helo detected! Pop smoke and send greeting
                              local smokeColor = (cfg.SmokeColor and cfg.SmokeColor[self.Side]) or trigger.smokeColor.Red
                              _spawnMEDEVACSmoke(crewPos, smokeColor, cfg)
                              
                              -- Pick random greeting message
                              local greetings = cfg.GreetingMessages or {"We see you! Over here!"}
                              local greeting = greetings[math.random(1, #greetings)]
                              
                              _msgCoalition(self.Side, string.format('[MEDEVAC] %s crew: "%s"', data.vehicleType, greeting), 10)
                              
                              -- Set cooldown timer instead of permanent flag
                              data.lastSmokeTime = now
                              local cooldownMins = smokeCooldown / 60
                              _logVerbose(string.format('[MEDEVAC] Crew %s detected helo at %.0fm, popped smoke (cooldown: %.0f mins)', 
                                crewGroupName, dist, cooldownMins))
                              break
                            end
                          end
                        end
                      end
                    end
                  end
                end
                if data.lastSmokeTime == now then break end  -- Just popped smoke, exit loop
              end
            end  -- if heloGroups then
          end  -- if canPopSmoke then
        end  -- if cfg.PopSmokeOnApproach then
        
        -- Send warnings
        if cfg.Warnings then
          for _, warning in ipairs(cfg.Warnings) do
            local warnTime = warning.time
            if remaining <= warnTime and not data.warningsSent[warnTime] then
              local grid = self:_GetMGRSString(data.position)
              _msgCoalition(self.Side, _fmtTemplate(warning.message, {
                crew = data.vehicleType..' crew',
                grid = grid
              }), 15)
              data.warningsSent[warnTime] = true
            end
          end
        end
        
        -- Check timeout
        if remaining <= 0 then
          table.insert(toRemove, crewGroupName)
        end
      end
    end
  end
  
  -- Remove timed-out crews
  for _, crewGroupName in ipairs(toRemove) do
    self:_RemoveMEDEVACCrew(crewGroupName, 'timeout')
  end
end

-- Remove MEDEVAC crew (timeout or death)
function CTLD:_RemoveMEDEVACCrew(crewGroupName, reason)
  local data = CTLD._medevacCrews[crewGroupName]
  if not data then return end
  
  -- Remove map marker
  if data.markerID then
    pcall(function() trigger.action.removeMark(data.markerID) end)
  end
  
  -- Destroy crew group
  local g = Group.getByName(crewGroupName)
  if g and g:isExist() then
    g:destroy()
  end
  
  -- Send message
  if reason == 'timeout' then
    local grid = self:_GetMGRSString(data.position)
    _msgCoalition(self.Side, _fmtTemplate(CTLD.Messages.medevac_crew_timeout, {
      vehicle = data.vehicleType,
      grid = grid
    }), 15)
    
    -- Track statistics
    if CTLD.MEDEVAC and CTLD.MEDEVAC.Statistics and CTLD.MEDEVAC.Statistics.Enabled then
      CTLD._medevacStats[self.Side].timedOut = (CTLD._medevacStats[self.Side].timedOut or 0) + 1
    end
  elseif reason == 'killed' then
    local grid = self:_GetMGRSString(data.position)
    local lines = CTLD.Messages.medevac_crew_killed_lines
    if lines and #lines > 0 then
      local line = lines[math.random(1, #lines)]
      _msgCoalition(self.Side, _fmtTemplate(line, {
        vehicle = data.vehicleType,
        grid = grid,
      }), 15)
    else
      _msgCoalition(self.Side, _fmtTemplate(CTLD.Messages.medevac_crew_killed, {
        vehicle = data.vehicleType,
        grid = grid,
      }), 15)
    end
    
    -- Track statistics
    if CTLD.MEDEVAC and CTLD.MEDEVAC.Statistics and CTLD.MEDEVAC.Statistics.Enabled then
      CTLD._medevacStats[self.Side].killed = (CTLD._medevacStats[self.Side].killed or 0) + 1
    end
  end
  
  -- Remove from tracking
  CTLD._medevacCrews[crewGroupName] = nil

  if data.rescueGroup and CTLD._medevacEnrouteStates then
    CTLD._medevacEnrouteStates[data.rescueGroup] = nil
  end
  
  _logVerbose(string.format('[MEDEVAC] Removed crew %s (reason: %s)', crewGroupName, reason or 'unknown'))
end

-- Check if crew was picked up (called from troop loading system)
function CTLD:CheckMEDEVACPickup(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end
  
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  local pos = unit:GetPointVec3()
  local searchRadius = 100 -- meters to search for nearby crew
  
  for crewGroupName, data in pairs(CTLD._medevacCrews) do
    if data.side == self.Side and data.requestTime then
      local crewPos = data.position
      local dx = pos.x - crewPos.x
      local dz = pos.z - crewPos.z
      local dist = math.sqrt(dx*dx + dz*dz)
      
      if dist <= searchRadius then
        -- Check if crew group still exists and is being loaded
        local crewGroup = Group.getByName(crewGroupName)
        if crewGroup and crewGroup:isExist() then
          -- Crew was picked up! Handle respawn
          self:_HandleMEDEVACPickup(group, crewGroupName, data)
          return true
        end
      end
    end
  end
  
  return false
end

-- Auto-pickup: Send MEDEVAC crews to landed helicopter within range
function CTLD:AutoPickupMEDEVACCrew(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end
  if not cfg.AutoPickup or not cfg.AutoPickup.Enabled then return end
  
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  -- Only work with landed helicopters
  if _isUnitInAir(unit) then return end

  local autoCfg = cfg.AutoPickup
  local requireGround = (autoCfg.RequireGroundContact ~= false)
  if requireGround then
    local agl = _getUnitAGL(unit)
    if agl > (autoCfg.GroundContactAGL or 3) then
      return -- still hovering/high skid - wait for full touchdown
    end
    local gs = _getGroundSpeed(unit)
    if gs > (autoCfg.MaxLandingSpeed or 2) then
      return -- helicopter is sliding/taxiing - hold crews until stable
    end
  end
  
  local pos = unit:GetPointVec3()
  if not pos then return end
  local maxDist = autoCfg.MaxDistance or 200
  local groupName = group:GetName()
  
  -- Skip if helicopter already has an active load hold
  if CTLD._medevacLoadStates and CTLD._medevacLoadStates[groupName] then
    return
  end
  
  -- Find nearby MEDEVAC crews within pickup range
  for crewGroupName, data in pairs(CTLD._medevacCrews) do
    if data.side == self.Side and data.requestTime and not data.pickedUp then
      local crewPos = data.position
      local dx = pos.x - crewPos.x
      local dz = pos.z - crewPos.z
      local dist = math.sqrt(dx*dx + dz*dz)
      
      if dist <= maxDist then
        local crewGroup = Group.getByName(crewGroupName)
        if crewGroup and crewGroup:isExist() then
          -- Crew is close enough - start load hold
          local loadCfg = cfg.AutoPickup or {}
          local delay = loadCfg.LoadDelay or 15
          local now = timer.getTime()
          
          -- Check if already in a load hold
          local existingState = CTLD._medevacLoadStates[groupName]
          if not existingState then
            -- Start new load hold
            CTLD._medevacLoadStates[groupName] = {
              startTime = now,
              delay = delay,
              crewGroupName = crewGroupName,
              crewData = data,
              holdAnnounced = true,
              nextReminder = now + math.max(1.5, delay / 3),
              lastQualified = now,
            }
            
            _msgGroup(group, string.format("MEDEVAC crew from %s is boarding. Hold position for %d seconds...", 
              data.vehicleType or 'unknown vehicle', delay), 10)
            _logVerbose(string.format('[MEDEVAC][AutoLoad] Hold started for %s (delay=%.1fs, crew=%s, dist=%.0fm)', 
              groupName, delay, crewGroupName, dist))
          end
        end
      end
    end
  end
end
-- Auto-unload: Send MEDEVAC crews to landed helicopter within MASH zone
-- Scan all active transport groups for auto-pickup and auto-unload opportunities
function CTLD:ScanMEDEVACAutoActions()
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end
  
  -- Progress any ongoing load and unload holds before new scans
  self:_UpdateMedevacLoadStates()
  self:_UpdateMedevacUnloadStates()
  
  -- Scan all active transport groups
  for gname, _ in pairs(self.MenusByGroup or {}) do
    local group = GROUP:FindByName(gname)
    if group and group:IsAlive() then
      local unit = group:GetUnit(1)
      if unit and unit:IsAlive() then
        local isAirborne = _isUnitInAir(unit)

        local autoUnloadCfg = cfg.AutoUnload or {}
        local aglLimit = autoUnloadCfg.GroundContactAGL or 2
        local agl = _getUnitAGL(unit)
        if agl == nil then agl = aglLimit end
        local hasGroundContact = (not isAirborne)
          or (agl <= aglLimit)

        if not isAirborne then
          -- Helicopter is landed according to DCS state
          if cfg.AutoPickup and cfg.AutoPickup.Enabled then
            self:AutoPickupMEDEVACCrew(group)
          end
        end

        if cfg.AutoUnload and cfg.AutoUnload.Enabled and hasGroundContact then
          -- Reduce log spam: only attempt auto-unload when there are rescued crews onboard
          local crews = self:_CollectRescuedCrewsForGroup(group:GetName())
          if crews and #crews > 0 then
            self:AutoUnloadMEDEVACCrew(group)
          end
        end

        self:_TickMedevacEnrouteMessage(group, unit, isAirborne)
      else
        CTLD._medevacEnrouteStates[gname] = nil
      end
    else
      CTLD._medevacEnrouteStates[gname] = nil
    end
  end

  -- Finalize unload checks after handling current landings
  self:_UpdateMedevacUnloadStates()

  local enrouteStates = CTLD._medevacEnrouteStates
  if enrouteStates then
    for gname, _ in pairs(enrouteStates) do
      if not (self.MenusByGroup and self.MenusByGroup[gname]) then
        local group = GROUP:FindByName(gname)
        if not group or not group:IsAlive() then
          enrouteStates[gname] = nil
        end
      end
    end
  end
end

-- Auto-unload: Automatically unload MEDEVAC crews when landed in MASH zone
function CTLD:AutoUnloadMEDEVACCrew(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end
  if not cfg.AutoUnload or not cfg.AutoUnload.Enabled then return end

  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  local gname = group:GetName() or 'UNKNOWN'

  -- Early silent exit (reduces log spam): only proceed if there are rescued crews onboard
  local earlyCrews = self:_CollectRescuedCrewsForGroup(gname)
  if not earlyCrews or #earlyCrews == 0 then return end
  
  local autoCfg = cfg.AutoUnload or {}
  local aglLimit = autoCfg.GroundContactAGL or 2.0
  local gsLimit = autoCfg.MaxLandingSpeed or 2.0
  local settleLimit = autoCfg.SettledAGL or (aglLimit + 2.0)

  local agl = _getUnitAGL(unit)
  if agl == nil then agl = 0 end
  local gs = _getGroundSpeed(unit)
  if gs == nil then gs = 0 end
  local inAir = _isUnitInAir(unit)

  -- Treat the helicopter as landed when weight-on-wheels flips or when the skid height is within tolerance.
  local hasGroundContact = (not inAir) or (agl <= aglLimit)
  if not hasGroundContact then
    _logDebug(string.format('[MEDEVAC][AutoUnload] %s skipped: no ground contact (agl=%.2f, limit=%.2f, inAir=%s)', gname, agl, aglLimit, tostring(inAir)))
    return
  end

  if inAir and agl > aglLimit then
    _logDebug(string.format('[MEDEVAC][AutoUnload] %s skipped: AGL %.2f above limit %.2f while still airborne', gname, agl, aglLimit))
    return
  end

  if gs > gsLimit then
    _logDebug(string.format('[MEDEVAC][AutoUnload] %s skipped: ground speed %.2f above limit %.2f', gname, gs, gsLimit))
    return
  end

  if settleLimit and settleLimit > 0 and agl > settleLimit then
    _logDebug(string.format('[MEDEVAC][AutoUnload] %s skipped: AGL %.2f above settled limit %.2f', gname, agl, settleLimit))
    return
  end
  
  local crews = self:_CollectRescuedCrewsForGroup(group:GetName())
  if #crews == 0 then return end

  -- Check if inside MASH zone
  local pos = unit:GetPointVec3()
  local inMASH, mashZone = self:_IsPositionInMASHZone({ x = pos.x, z = pos.z })
  if not inMASH then
    _logDebug(string.format('[MEDEVAC][AutoUnload] %s skipped: not inside MASH zone (crews=%d)', gname, #crews))
    return
  end

  _logVerbose(string.format('[MEDEVAC][AutoUnload] %s qualified for unload in MASH %s (crews=%d, agl=%.2f, gs=%.2f)',
    gname,
    tostring((mashZone and (mashZone.name or mashZone.unitName)) or 'UNKNOWN'),
    #crews,
    agl,
    gs))

  -- Begin or maintain the unload hold state
  self:_EnsureMedevacUnloadState(group, mashZone, crews, { trigger = 'auto' })
end

-- Gather all MEDEVAC crews currently onboard the specified rescue group
function CTLD:_CollectRescuedCrewsForGroup(groupName)
  local crews = {}
  if not groupName then return crews end

  for crewGroupName, data in pairs(CTLD._medevacCrews or {}) do
    if data.side == self.Side and data.pickedUp and data.rescueGroup == groupName then
      crews[#crews + 1] = { name = crewGroupName, data = data }
    end
  end

  return crews
end

-- Periodically deliver enroute status chatter while MEDEVAC patients are onboard
function CTLD:_TickMedevacEnrouteMessage(group, unit, isAirborne, forceSend)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end

  local enrouteCfg = cfg.EnrouteMessages or {}
  if enrouteCfg.Enabled == false then return end

  if not group or not unit or not unit:IsAlive() then
    if group then
      local gname = group:GetName()
      if gname and gname ~= '' then
        CTLD._medevacEnrouteStates[gname] = nil
      end
    end
    return
  end

  local gname = group:GetName()
  if not gname or gname == '' then return end

  local crews = self:_CollectRescuedCrewsForGroup(gname)
  if not crews or #crews == 0 then
    CTLD._medevacEnrouteStates[gname] = nil
    return
  end

  if not isAirborne and not forceSend then
    return
  end

  local interval = enrouteCfg.Interval or 180
  if interval <= 0 then interval = 180 end

  CTLD._medevacEnrouteStates = CTLD._medevacEnrouteStates or {}
  local now = timer.getTime()
  local state = CTLD._medevacEnrouteStates[gname]

  if not state then
    state = { nextSend = now + interval, lastIndex = nil }
    CTLD._medevacEnrouteStates[gname] = state
  end

  if not forceSend and now < (state.nextSend or 0) then
    return
  end

  local vector = self:_ComputeNearestMASHVector(unit)
  if not vector then return end

  local messages = cfg.EnrouteToMashMessages or {}
  if #messages == 0 then return end

  local idx = math.random(1, #messages)
  if state.lastIndex and #messages > 1 and idx == state.lastIndex then
    idx = (idx % #messages) + 1
  end
  state.lastIndex = idx
  state.nextSend = now + interval

  local text = _fmtTemplate(messages[idx], {
    mash = vector.name,
    brg = vector.bearing,
    rng = vector.rangeValue,
    rng_u = vector.rangeUnit
  })

  _msgGroup(group, text, math.min(self.Config.MessageDuration or 15, 18))
end

-- Ensure an unload hold state exists for the group and announce if newly started
function CTLD:_EnsureMedevacUnloadState(group, mashZone, crews, opts)
  CTLD._medevacUnloadStates = CTLD._medevacUnloadStates or {}

  if not group or not group:IsAlive() then return nil end

  local gname = group:GetName()
  local now = timer.getTime()
  local cfg = self.MEDEVAC or {}
  local cfgAuto = cfg.AutoUnload or {}
  local delay = cfgAuto.UnloadDelay or 2
  if delay < 0 then delay = 0 end

  local state = CTLD._medevacUnloadStates[gname]
  if not state then
    state = {
      groupName = gname,
      side = self.Side,
      startTime = now,
      delay = delay,
      holdAnnounced = false,
      mashZoneName = mashZone and (mashZone.name or mashZone.unitName) or nil,
      triggeredBy = opts and opts.trigger or 'auto',
    }
    CTLD._medevacUnloadStates[gname] = state
    self:_AnnounceMedevacUnloadHold(group, state)
    _logVerbose(string.format('[MEDEVAC][AutoUnload] Hold started for %s (delay=%0.1fs, trigger=%s, mash=%s, crews=%d)',
      gname,
      state.delay,
      tostring(state.triggeredBy),
      tostring(state.mashZoneName or 'UNKNOWN'),
      crews and #crews or 0))
  else
    state.delay = delay
    state.triggeredBy = opts and opts.trigger or state.triggeredBy
    if mashZone then
      state.mashZoneName = mashZone.name or mashZone.unitName or state.mashZoneName
    end
    _logDebug(string.format('[MEDEVAC][AutoUnload] Hold refreshed for %s (trigger=%s, crews=%d)',
      gname,
      tostring(state.triggeredBy),
      crews and #crews or 0))
  end

  state.lastQualified = now
  state.pendingCrewCount = crews and #crews or state.pendingCrewCount

  return state
end

-- Notify the pilot that unloading is in progress and set up reminder cadence
function CTLD:_AnnounceMedevacUnloadHold(group, state)
  if not group or not state or state.holdAnnounced then return end

  state.holdAnnounced = true
  local delay = math.ceil(state.delay or 0)
  if delay < 1 then delay = 1 end

  _msgGroup(group, _fmtTemplate(CTLD.Messages.medevac_unload_hold, {
    seconds = delay
  }), math.min(delay + 2, 12))

  local unloadMsgs = (self.MEDEVAC and self.MEDEVAC.UnloadingMessages) or {}
  if #unloadMsgs > 0 then
    local msg = unloadMsgs[math.random(1, #unloadMsgs)]
    _msgGroup(group, msg, math.min(delay, 10))
  end

  local now = timer.getTime()
  local spacing = state.delay or 2
  spacing = math.max(1.5, math.min(4, spacing / 2))
  state.nextReminder = now + spacing
end

-- Send a reminder from the unloading message pool while waiting out the hold
function CTLD:_SendMedevacUnloadReminder(group)
  if not group then return end
  local unloadMsgs = (self.MEDEVAC and self.MEDEVAC.UnloadingMessages) or {}
  if #unloadMsgs == 0 then return end

  local msg = unloadMsgs[math.random(1, #unloadMsgs)]
  _msgGroup(group, msg, 6)
end

-- Inform the pilot that the unload was cancelled and the hold must restart
function CTLD:_NotifyMedevacUnloadAbort(group, state, reasonKey)
  if not group or not state or state.abortNotified or not state.holdAnnounced then return end

  local reasonText
  if reasonKey == 'air' then
    reasonText = 'wheels up too soon'
  elseif reasonKey == 'zone' then
    reasonText = 'left the MASH zone'
  elseif reasonKey == 'agl' then
    reasonText = 'climbed above unload height'
  elseif reasonKey == 'crew' then
    reasonText = 'no MEDEVAC patients onboard'
  else
    reasonText = 'hold interrupted'
  end

  local delay = math.ceil(state.delay or 0)
  if delay < 1 then delay = 1 end

  _msgGroup(group, _fmtTemplate(CTLD.Messages.medevac_unload_aborted, {
    reason = reasonText,
    seconds = delay
  }), 10)

  state.abortNotified = true
end

-- Finalize the unload, deliver all crews, and celebrate success
function CTLD:_CompleteMedevacUnload(group, crews)
  if not group or not group:IsAlive() then return end
  if not crews or #crews == 0 then return end

  for _, crew in ipairs(crews) do
    self:_DeliverMEDEVACCrewToMASH(group, crew.name, crew.data)
  end

  local successMsgs = (self.MEDEVAC and self.MEDEVAC.UnloadCompleteMessages) or {}
  if #successMsgs > 0 then
    local msg = successMsgs[math.random(1, #successMsgs)]
    _msgGroup(group, msg, 10)
  end

  _logVerbose(string.format('[MEDEVAC] Auto unload complete for %s (%d crew group(s) delivered)', group:GetName(), #crews))
end

-- Send loading reminder message to pilot
function CTLD:_SendMedevacLoadReminder(group)
  if not group then return end
  local loadingMsgs = (self.MEDEVAC and self.MEDEVAC.LoadingMessages) or {}
  if #loadingMsgs == 0 then return end

  local msg = loadingMsgs[math.random(1, #loadingMsgs)]
  _msgGroup(group, msg, 6)
end

-- Inform the pilot that the loading was cancelled and the hold must restart
function CTLD:_NotifyMedevacLoadAbort(group, state, reasonKey)
  if not group or not state or state.abortNotified or not state.holdAnnounced then return end

  local reasonText
  if reasonKey == 'air' then
    reasonText = 'wheels up too soon'
  elseif reasonKey == 'agl' then
    reasonText = 'climbed above loading height'
  elseif reasonKey == 'crew' then
    reasonText = 'crew lost contact'
  else
    reasonText = 'hold interrupted'
  end

  local delay = math.ceil(state.delay or 0)
  if delay < 1 then delay = 1 end

  _msgGroup(group, string.format("MEDEVAC boarding aborted: %s. Land and hold for %d seconds to restart.", 
    reasonText, delay), 10)

  state.abortNotified = true
end

-- Complete the load, pick up crew, and show success message
function CTLD:_CompleteMedevacLoad(group, crewGroupName, crewData)
  if not group or not group:IsAlive() then return end
  if not crewGroupName or not crewData then return end

  -- Destroy the crew unit
  local crewGroup = Group.getByName(crewGroupName)
  if crewGroup and crewGroup:isExist() then
    crewGroup:destroy()
  end

  -- Handle the actual pickup (respawn vehicle, etc.)
  self:_HandleMEDEVACPickup(group, crewGroupName, crewData)

  -- Show completion message
  local successMsgs = (self.MEDEVAC and self.MEDEVAC.LoadMessages) or {}
  if #successMsgs > 0 then
    local msg = successMsgs[math.random(1, #successMsgs)]
    _msgGroup(group, msg, 10)
  end

  _logVerbose(string.format('[MEDEVAC] Auto load complete for %s (crew %s)', group:GetName(), crewGroupName))
end

-- Maintain load hold states, handling completion or interruption
function CTLD:_UpdateMedevacLoadStates()
  local states = CTLD._medevacLoadStates
  if not states or not next(states) then return end

  local now = timer.getTime()
  local cfg = self.MEDEVAC or {}
  local cfgAuto = cfg.AutoPickup or {}
  local aglLimit = cfgAuto.GroundContactAGL or 3
  local settleLimit = cfgAuto.SettledAGL or 6
  local gsLimit = cfgAuto.MaxLandingSpeed or 2
  local airGrace = cfgAuto.AirAbortGrace or 2

  for gname, state in pairs(states) do
    local group = GROUP:FindByName(gname)
    if not group or not group:IsAlive() then
      states[gname] = nil
      _logDebug(string.format('[MEDEVAC][AutoLoad] %s removed: group not alive', gname))
    else
      local unit = group:GetUnit(1)
      if not unit or not unit:IsAlive() then
        states[gname] = nil
        _logDebug(string.format('[MEDEVAC][AutoLoad] %s removed: unit not alive', gname))
      else
        local removeState = false
        local agl = _getUnitAGL(unit)
        local gs = _getGroundSpeed(unit)

        -- Check if crew still exists
        local crewGroup = Group.getByName(state.crewGroupName)
        if not crewGroup or not crewGroup:isExist() then
          _logVerbose(string.format('[MEDEVAC][AutoLoad] Hold abort for %s: crew %s no longer exists', gname, state.crewGroupName))
          removeState = true
        else
          -- Check distance to crew
          local crewUnit = crewGroup:getUnit(1)
          if crewUnit then
            local crewPos = crewUnit:getPoint()
            local heliPos = unit:GetPointVec3()
            local dx = heliPos.x - crewPos.x
            local dz = heliPos.z - crewPos.z
            local dist = math.sqrt(dx*dx + dz*dz)
            
            if dist > 40 then
              self:_NotifyMedevacLoadAbort(group, state, 'crew')
              _logVerbose(string.format('[MEDEVAC][AutoLoad] Hold abort for %s: moved too far from crew (%.1fm)', gname, dist))
              removeState = true
            end
          end

          if not removeState then
            -- Check landing status (similar to unload logic)
            local landed = not _isUnitInAir(unit)
            if landed then
              if settleLimit and settleLimit > 0 and agl > settleLimit then
                landed = false
                state.highAglSince = state.highAglSince or now
                _logDebug(string.format('[MEDEVAC][AutoLoad] %s hold paused: AGL %.2f above settled limit %.2f', gname, agl, settleLimit))
              else
                state.highAglSince = nil
              end
            else
              state.highAglSince = nil
              if agl <= aglLimit and gs <= gsLimit then
                landed = true
              end
            end

            if landed then
              state.airborneSince = nil
              state.lastQualified = now

              -- Send reminders while holding
              if state.nextReminder and now >= state.nextReminder then
                self:_SendMedevacLoadReminder(group)
                local spacing = state.delay or 2
                spacing = math.max(1.5, math.min(4, spacing / 2))
                state.nextReminder = now + spacing
              end

              -- Complete load after delay
              if (now - state.startTime) >= state.delay then
                self:_CompleteMedevacLoad(group, state.crewGroupName, state.crewData)
                _logVerbose(string.format('[MEDEVAC][AutoLoad] Hold complete for %s', gname))
                removeState = true
              end
            else
              state.airborneSince = state.airborneSince or now
              if (now - state.airborneSince) >= airGrace then
                self:_NotifyMedevacLoadAbort(group, state, 'air')
                _logVerbose(string.format('[MEDEVAC][AutoLoad] Hold abort for %s: airborne for %.1fs (grace=%.1f)',
                  gname,
                  now - state.airborneSince,
                  airGrace))
                removeState = true
              end
            end
          end
        end

        if removeState then
          states[gname] = nil
        end
      end
    end
  end
end

-- Maintain unload hold states, handling completion or interruption
function CTLD:_UpdateMedevacUnloadStates()
  local states = CTLD._medevacUnloadStates
  if not states or not next(states) then return end

  local now = timer.getTime()
  local cfg = self.MEDEVAC or {}
  local cfgAuto = cfg.AutoUnload or {}
  local aglLimit = cfgAuto.GroundContactAGL or 2
  local gsLimit = cfgAuto.MaxLandingSpeed or 2
  local airGrace = cfgAuto.AirAbortGrace or 2

  for gname, state in pairs(states) do
    -- Multiple CTLD instances share the global unload state table; skip entries owned by the other coalition.
    if not state.side or state.side == self.Side then
      local group = GROUP:FindByName(gname)
      local removeState = false

      if not group or not group:IsAlive() then
        removeState = true
      else
        local unit = group:GetUnit(1)
        if not unit or not unit:IsAlive() then
          removeState = true
        else
          local crews = self:_CollectRescuedCrewsForGroup(gname)
          if #crews == 0 then
            self:_NotifyMedevacUnloadAbort(group, state, 'crew')
            _logVerbose(string.format('[MEDEVAC][AutoUnload] Hold abort for %s: crew list empty', gname))
            removeState = true
          else
            local agl = _getUnitAGL(unit)
            if agl == nil then agl = 0 end
            local gs = _getGroundSpeed(unit)
            if gs == nil then gs = 0 end
            local settleLimit = cfgAuto.SettledAGL or (aglLimit + 2.0)

            local landed = not _isUnitInAir(unit)
            if landed then
              if settleLimit and settleLimit > 0 and agl > settleLimit then
                landed = false
                state.highAglSince = state.highAglSince or now
                _logDebug(string.format('[MEDEVAC][AutoUnload] %s hold paused: AGL %.2f above settled limit %.2f', gname, agl, settleLimit))
              else
                state.highAglSince = nil
              end
            else
              state.highAglSince = nil
              if agl <= aglLimit and gs <= gsLimit then
                landed = true
              end
            end

            if landed then
              state.airborneSince = nil
              state.lastQualified = now
              local pos = unit:GetPointVec3()
              local inMASH, mashZone = self:_IsPositionInMASHZone({ x = pos.x, z = pos.z })
              if not inMASH then
                self:_NotifyMedevacUnloadAbort(group, state, 'zone')
                _logVerbose(string.format('[MEDEVAC][AutoUnload] Hold abort for %s: left MASH zone', gname))
                removeState = true
              else
                state.mashZoneName = mashZone and (mashZone.name or mashZone.unitName or state.mashZoneName)
                
                -- Send reminders while holding
                if state.nextReminder and now >= state.nextReminder then
                  self:_SendMedevacUnloadReminder(group)
                  local spacing = state.delay or 2
                  spacing = math.max(1.5, math.min(4, spacing / 2))
                  state.nextReminder = now + spacing
                end

                -- Complete unload after delay
                if (now - state.startTime) >= state.delay then
                  self:_CompleteMedevacUnload(group, crews)
                  _logVerbose(string.format('[MEDEVAC][AutoUnload] Hold complete for %s (crews delivered=%d)', gname, #crews))
                  removeState = true
                end
              end
            else
              state.airborneSince = state.airborneSince or now
              if (now - state.airborneSince) >= airGrace then
                self:_NotifyMedevacUnloadAbort(group, state, 'air')
                _logVerbose(string.format('[MEDEVAC][AutoUnload] Hold abort for %s: airborne for %.1fs (grace=%.1f)',
                  gname,
                  now - state.airborneSince,
                  airGrace))
                removeState = true
              end
            end
          end
        end
      end

      if removeState then
        states[gname] = nil
      end
    end
  end
end

-- Handle MEDEVAC crew pickup - respawn vehicle
function CTLD:_HandleMEDEVACPickup(rescueGroup, crewGroupName, crewData)
  local cfg = CTLD.MEDEVAC
  
  -- Remove map marker
  if crewData.markerID then
    pcall(function() trigger.action.removeMark(crewData.markerID) end)
  end
  
  -- Show initial load message (random from LoadMessages)
  local loadMsgs = cfg.LoadMessages or {}
  if #loadMsgs > 0 then
    local randomLoadMsg = loadMsgs[math.random(1, #loadMsgs)]
    _msgGroup(rescueGroup, randomLoadMsg, 5)
  end
  
  -- Show loading progress messages during a brief delay (simulate boarding time)
  local loadingDuration = 8 -- seconds for crew to board
  local loadingMsgInterval = 2 -- show message every 2 seconds
  local loadingMsgs = cfg.LoadingMessages or {}
  local gname = rescueGroup:GetName()
  
  if #loadingMsgs > 0 then
    local messageCount = math.floor(loadingDuration / loadingMsgInterval)
    for i = 1, messageCount do
      local msgId = timer.scheduleFunction(function()
        local g = GROUP:FindByName(gname)
        if g and g:IsAlive() then
          local randomLoadingMsg = loadingMsgs[math.random(1, #loadingMsgs)]
          _msgGroup(g, randomLoadingMsg, loadingMsgInterval - 0.5)
        end
      end, nil, timer.getTime() + (i * loadingMsgInterval))
      _trackOneShotTimer(msgId)
    end
  end
  
  -- Schedule final completion after loading duration
  local completionId = timer.scheduleFunction(function()
    local g = GROUP:FindByName(gname)
    if g and g:IsAlive() then
      -- Show completion message
      _msgGroup(g, _fmtTemplate(CTLD.Messages.medevac_crew_loaded, {
        vehicle = crewData.vehicleType,
        crew_size = crewData.crewSize
      }), 10)

      local unit = g:GetUnit(1)
      if unit and unit:IsAlive() then
        self:_TickMedevacEnrouteMessage(g, unit, _isUnitInAir(unit), true)
      end
    end
    
    -- Track statistics
    if CTLD.MEDEVAC and CTLD.MEDEVAC.Statistics and CTLD.MEDEVAC.Statistics.Enabled then
      CTLD._medevacStats[self.Side].rescued = (CTLD._medevacStats[self.Side].rescued or 0) + 1
    end
    
    -- Respawn vehicle if enabled
    if cfg.RespawnOnPickup then
      local respawnId = timer.scheduleFunction(function()
        self:_RespawnMEDEVACVehicle(crewData)
      end, nil, timer.getTime() + 2) -- 2 second delay for realism
      _trackOneShotTimer(respawnId)
    end
    
    -- Mark crew as picked up (for MASH delivery tracking)
    crewData.pickedUp = true
    crewData.rescueGroup = gname
    
    _logVerbose(string.format('[MEDEVAC] Crew %s picked up by %s', crewGroupName, gname))
  end, nil, timer.getTime() + loadingDuration)
  _trackOneShotTimer(completionId)
end

-- Respawn the vehicle at original death location
function CTLD:_RespawnMEDEVACVehicle(crewData)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.RespawnOnPickup then return end
  
  -- Calculate respawn position (offset from original death)
  local offset = cfg.RespawnOffset or 15
  local angle = math.random() * 2 * math.pi
  local respawnPos = {
    x = crewData.position.x + math.cos(angle) * offset,
    z = crewData.position.z + math.sin(angle) * offset
  }
  
  local heading = cfg.RespawnSameHeading and (crewData.originalHeading or 0) or 0
  
  -- Find catalog entry to get build function
  local catalogEntry = nil
  local catalogKey = nil
  for key, def in pairs(self.Config.CrateCatalog or {}) do
    if def and def.MEDEVAC then
      local matches = false

      if def.unitType and def.unitType == crewData.vehicleType then
        matches = true
      end

      if (not matches) and type(def.unitTypes) == 'table' then
        for _, unitType in ipairs(def.unitTypes) do
          if unitType == crewData.vehicleType then
            matches = true
            break
          end
        end
      end

      if not matches then
        local ok, unitTypes = pcall(function()
          return self:_collectEntryUnitTypes(def)
        end)
        if ok and type(unitTypes) == 'table' then
          for _, unitType in ipairs(unitTypes) do
            if unitType == crewData.vehicleType then
              matches = true
              break
            end
          end
        end
      end

      if matches then
        catalogEntry = def
        catalogKey = key
        break
      end
    end
  end
  
  if not catalogEntry or not catalogEntry.build then
    _logVerbose('[MEDEVAC] No catalog entry found for respawn: '..crewData.vehicleType)
    return
  end
  
  -- Spawn vehicle using catalog build function
  local groupData = catalogEntry.build(respawnPos, math.deg(heading))
  if not groupData then
    _logVerbose('[MEDEVAC] Failed to generate group data for: '..crewData.vehicleType)
    return
  end

  if crewData.countryId then
    groupData.country = crewData.countryId
  end

  local category = catalogEntry.category or Group.Category.GROUND
  
  local newGroup = coalition.addGroup(self.Side, category, groupData)
  
  if newGroup then
    if catalogKey then
      _logVerbose(string.format('[MEDEVAC] Respawn using catalog entry %s for %s', tostring(catalogKey), crewData.vehicleType))
    end
    _msgCoalition(self.Side, _fmtTemplate(CTLD.Messages.medevac_vehicle_respawned, {
      vehicle = crewData.vehicleType
    }), 10)
    
    -- Track statistics
    if CTLD.MEDEVAC and CTLD.MEDEVAC.Statistics and CTLD.MEDEVAC.Statistics.Enabled then
      CTLD._medevacStats[self.Side].vehiclesRespawned = (CTLD._medevacStats[self.Side].vehiclesRespawned or 0) + 1
    end
    
    _logVerbose(string.format('[MEDEVAC] Respawned %s at %.0f, %.0f', crewData.vehicleType, respawnPos.x, respawnPos.z))
  else
    _logVerbose('[MEDEVAC] Failed to respawn vehicle: '..crewData.vehicleType)
  end
end

-- Check if troops being unloaded are MEDEVAC crew and if inside MASH zone
function CTLD:CheckMEDEVACDelivery(group, troopData)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return false end
  if not cfg.Salvage or not cfg.Salvage.Enabled then return false end
  if not group or not group:IsAlive() then return false end

  local gname = group:GetName()
  local crews = self:_CollectRescuedCrewsForGroup(gname)
  if #crews == 0 then return false end

  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return false end

  if _isUnitInAir(unit) then
    local delay = (cfg.AutoUnload and cfg.AutoUnload.UnloadDelay) or 2
    delay = math.max(1, math.ceil(delay or 0))
    _msgGroup(group, _fmtTemplate(CTLD.Messages.medevac_unload_hold, {
      seconds = delay
    }), 10)
    return 'pending'
  end

  local pos = unit:GetPointVec3()
  local inMASH, mashZone = self:_IsPositionInMASHZone({ x = pos.x, z = pos.z })
  if not inMASH then return false end

  self:_EnsureMedevacUnloadState(group, mashZone, crews, { trigger = 'manual' })
  self:_UpdateMedevacUnloadStates()

  local remaining = self:_CollectRescuedCrewsForGroup(gname)
  if #remaining == 0 then
    return 'delivered'
  end

  return 'pending'
end

-- Deliver MEDEVAC crew to MASH - award salvage points
function CTLD:_DeliverMEDEVACCrewToMASH(group, crewGroupName, crewData)
  local cfg = CTLD.MEDEVAC.Salvage
  if not cfg or not cfg.Enabled then return end
  
  -- Award salvage points
  CTLD._salvagePoints[self.Side] = (CTLD._salvagePoints[self.Side] or 0) + crewData.salvageValue
  
  -- Message to coalition (shown after brief delay to let unload message be seen)
  local msgId = timer.scheduleFunction(function()
    _msgCoalition(self.Side, _fmtTemplate(CTLD.Messages.medevac_crew_delivered_mash, {
      player = _playerNameFromGroup(group),
      vehicle = crewData.vehicleType,
      salvage = crewData.salvageValue,
      total = CTLD._salvagePoints[self.Side]
    }), 15)
  end, nil, timer.getTime() + 3)
  _trackOneShotTimer(msgId)
  
  -- Track statistics
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Statistics and CTLD.MEDEVAC.Statistics.Enabled then
    CTLD._medevacStats[self.Side].delivered = (CTLD._medevacStats[self.Side].delivered or 0) + 1
    CTLD._medevacStats[self.Side].salvageEarned = (CTLD._medevacStats[self.Side].salvageEarned or 0) + crewData.salvageValue
  end
  
  -- Remove map marker
  if crewData.markerID then
    pcall(function() trigger.action.removeMark(crewData.markerID) end)
  end
  
  -- Destroy crew group to prevent clutter
  local crewGroup = Group.getByName(crewGroupName)
  if crewGroup and crewGroup:isExist() then
    crewGroup:destroy()
  end
  
  -- Remove crew from tracking
  CTLD._medevacCrews[crewGroupName] = nil

  if group and group:IsAlive() then
    local gname = group:GetName()
    if gname and gname ~= '' then
      CTLD._medevacEnrouteStates = CTLD._medevacEnrouteStates or {}
      CTLD._medevacEnrouteStates[gname] = nil
    end
  end
  
  _logVerbose(string.format('[MEDEVAC] Delivered %s crew to MASH - awarded %d salvage (total: %d)', 
    crewData.vehicleType, crewData.salvageValue, CTLD._salvagePoints[self.Side]))
end

-- Try to use salvage to spawn a crate when out of stock
function CTLD:_TryUseSalvageForCrate(group, crateKey, catalogEntry)
  local cfg = CTLD.MEDEVAC and CTLD.MEDEVAC.Salvage
  if not cfg or not cfg.Enabled then return false end
  if not cfg.AutoApply then return false end
  
  -- Check if item has salvage value (use same fallback logic as MEDEVAC)
  local salvageCost = catalogEntry.salvageValue
  if not salvageCost then
    salvageCost = catalogEntry.required or cfg.DefaultValue or 1
  end
  if salvageCost <= 0 then return false end
  
  -- Check if we have enough salvage
  local available = CTLD._salvagePoints[self.Side] or 0
  if available < salvageCost then
    -- Send insufficient salvage message
    local deficit = salvageCost - available
    _msgGroup(group, _fmtTemplate(CTLD.Messages.medevac_salvage_insufficient, {
      need = salvageCost,
      deficit = deficit
    }))
    return false
  end
  
  -- Consume salvage
  CTLD._salvagePoints[self.Side] = available - salvageCost
  
  -- Track statistics
  if CTLD.MEDEVAC and CTLD.MEDEVAC.Statistics and CTLD.MEDEVAC.Statistics.Enabled then
    CTLD._medevacStats[self.Side].salvageUsed = (CTLD._medevacStats[self.Side].salvageUsed or 0) + salvageCost
  end
  
  -- Send success message
  _msgGroup(group, _fmtTemplate(CTLD.Messages.medevac_salvage_used, {
    item = self:_friendlyNameForKey(crateKey),
    salvage = salvageCost,
    remaining = CTLD._salvagePoints[self.Side]
  }))
  
  _logVerbose(string.format('[Salvage] Used %d salvage for %s (remaining: %d)', 
    salvageCost, crateKey, CTLD._salvagePoints[self.Side]))
  
  return true
end

-- Check if salvage can cover a crate request (for bundle pre-checks)
function CTLD:_CanUseSalvageForCrate(crateKey, catalogEntry, quantity)
  local cfg = CTLD.MEDEVAC and CTLD.MEDEVAC.Salvage
  if not cfg or not cfg.Enabled then return false end
  if not cfg.AutoApply then return false end
  
  quantity = quantity or 1
  -- Check if item has salvage value (use same fallback logic as MEDEVAC)
  local salvageCost = catalogEntry.salvageValue
  if not salvageCost then
    salvageCost = catalogEntry.required or cfg.DefaultValue or 1
  end
  salvageCost = salvageCost * quantity
  if salvageCost <= 0 then return false end
  
  local available = CTLD._salvagePoints[self.Side] or 0
  return available >= salvageCost
end

-- Resolve the 2D position of a MASH zone, handling fixed and mobile variants
function CTLD:_ResolveMASHPosition(mashData, mashKey)
  if not mashData then return nil end

  if mashData.position and mashData.position.x and mashData.position.z then
    return { x = mashData.position.x, z = mashData.position.z }
  end

  local zone = mashData.zone
  if zone then
    if zone.GetPointVec3 then
      local ok, vec3 = pcall(function() return zone:GetPointVec3() end)
      if ok and vec3 then
        return { x = vec3.x, z = vec3.z }
      end
    end
    if zone.GetPointVec2 then
      local ok, vec2 = pcall(function() return zone:GetPointVec2() end)
      if ok and vec2 then
        return { x = vec2.x, z = vec2.y }
      end
    end
    if zone.GetCoordinate then
      local ok, coord = pcall(function() return zone:GetCoordinate() end)
      if ok and coord then
        local vec3 = coord.GetVec3 and coord:GetVec3()
        if vec3 then
          return { x = vec3.x, z = vec3.z }
        end
      end
    end
  end

  if mashKey and trigger and trigger.misc and trigger.misc.getZone then
    local ok, zoneInfo = pcall(function() return trigger.misc.getZone(mashKey) end)
    if ok and zoneInfo and zoneInfo.point then
      return { x = zoneInfo.point.x, z = zoneInfo.point.z }
    end
  end

  return nil
end

-- Find the nearest friendly MASH zone to a given point (x/z expected)
function CTLD:_FindNearestMASHForPoint(point)
  if not point then return nil end

  local nearestName, nearestData, nearestPos
  local nearestDist = math.huge

  for name, data in pairs(CTLD._mashZones or {}) do
    if data.side == self.Side then
      local pos = self:_ResolveMASHPosition(data, name)
      if pos then
        local dx = pos.x - point.x
        local dz = pos.z - point.z
        local dist = math.sqrt(dx * dx + dz * dz)
        if dist < nearestDist then
          nearestDist = dist
          nearestName = name
          nearestData = data
          nearestPos = pos
        end
      end
    end
  end

  if not nearestData or not nearestPos then
    return nil
  end

  local displayName = nearestData.displayName or nearestData.catalogKey
  if not displayName then
    local zone = nearestData.zone
    if zone and zone.GetName then
      local ok, zname = pcall(function() return zone:GetName() end)
      if ok and zname then
        displayName = zname
      end
    end
  end
  displayName = displayName or nearestName or 'MASH'

  return {
    name = displayName,
    position = nearestPos,
    distance = nearestDist,
    data = nearestData,
  }
end

-- Build directional info toward the nearest MASH for a specific unit
function CTLD:_ComputeNearestMASHVector(unit)
  if not unit or not unit:IsAlive() then return nil end
  local pos = unit:GetPointVec3()
  if not pos then return nil end

  local info = self:_FindNearestMASHForPoint({ x = pos.x, z = pos.z })
  if not info or not info.position then return nil end

  local bearing = _bearingDeg({ x = pos.x, z = pos.z }, info.position)
  local isMetric = _getPlayerIsMetric(unit)
  local rangeValue, rangeUnit = _fmtRange(info.distance, isMetric)

  if rangeUnit == 'm' and rangeValue >= 1000 then
    rangeValue = _round(rangeValue / 1000, 1)
    rangeUnit = 'km'
  end

  local valueText
  if math.abs(rangeValue - math.floor(rangeValue)) < 0.05 then
    valueText = string.format('%d', math.floor(rangeValue + 0.5))
  else
    valueText = string.format('%.1f', rangeValue)
  end

  return {
    name = info.name,
    bearing = bearing,
    rangeValue = valueText,
    rangeUnit = rangeUnit,
  }
end

-- Check if position is inside any MASH zone
function CTLD:_IsPositionInMASHZone(position)
  for zoneName, mashData in pairs(CTLD._mashZones) do
    if mashData.side == self.Side then
      local zonePos = self:_ResolveMASHPosition(mashData, zoneName)
      if zonePos then
        local radius = mashData.radius or CTLD.MEDEVAC.MASHZoneRadius or 500
        local dx = position.x - zonePos.x
        local dz = position.z - zonePos.z
        local dist = math.sqrt(dx*dx + dz*dz)

        if dist <= radius then
          return true, mashData
        end
      end
    end
  end
  return false, nil
end

-- Initialize MASH zones from config
function CTLD:_InitMASHZones()
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then return end
  
  _logDebug('_InitMASHZones called for coalition '..tostring(self.Side))
  _logDebug('self.MASHZones count: '..tostring(#(self.MASHZones or {})))
  _logDebug('self.Config.Zones.MASHZones count: '..tostring(#(self.Config.Zones and self.Config.Zones.MASHZones or {})))
  
  -- Fixed MASH zones are now initialized via InitZones() in the standard Zones structure
  -- This function now focuses on setting up mobile MASH tracking and announcements
  
  if not CTLD._mashZones then CTLD._mashZones = {} end
  
  -- Register fixed MASH zones in the global _mashZones table for delivery detection
  -- (mobile MASH zones will be added dynamically when built)
  for _, mz in ipairs(self.MASHZones or {}) do
    local name = mz:GetName()
    local zdef = self._ZoneDefs.MASHZones[name]
    CTLD._mashZones[name] = {
      zone = mz,
      side = self.Side,
      isMobile = false,
      radius = (zdef and zdef.radius) or cfg.MASHZoneRadius or 500,
      freq = (zdef and zdef.freq) or nil
    }
    _logVerbose('[MEDEVAC] Registered fixed MASH zone: '..name)
  end
end

-- =========================
-- MEDEVAC Menu Functions
-- =========================

-- List all active MEDEVAC requests
function CTLD:ListActiveMEDEVACRequests(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  local count = 0
  local lines = {}
  table.insert(lines, '=== Active MEDEVAC Requests ===')
  table.insert(lines, '')
  
  for crewGroupName, data in pairs(CTLD._medevacCrews or {}) do
    if data.side == self.Side and data.requestTime then
      count = count + 1
      local grid = self:_GetMGRSString(data.position)
      local elapsed = timer.getTime() - data.requestTime
      local remaining = (cfg.CrewTimeout or 3600) - elapsed
      local remainMin = math.floor(remaining / 60)
      
      table.insert(lines, string.format('%d. %s crew', count, data.vehicleType))
      table.insert(lines, string.format('   Grid: %s', grid))
      table.insert(lines, string.format('   Crew Size: %d', data.crewSize or 2))
      table.insert(lines, string.format('   Salvage: %d points', data.salvageValue or 1))
      table.insert(lines, string.format('   Time Remaining: %d minutes', remainMin))
      table.insert(lines, '')
    end
  end
  
  if count == 0 then
    table.insert(lines, 'No active MEDEVAC requests.')
    table.insert(lines, '')
    table.insert(lines, 'MEDEVAC missions appear when friendly vehicles')
    table.insert(lines, 'are destroyed and crew survives to call for rescue.')
  end
  
  _msgGroup(group, table.concat(lines, '\n'), 30)
end

-- Show nearest MEDEVAC location
function CTLD:NearestMEDEVACLocation(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  local unit = group:GetUnit(1)
  if not unit then return end
  
  local pos = unit:GetCoordinate()
  if not pos then return end
  
  local nearest = nil
  local nearestDist = math.huge
  
  for crewGroupName, data in pairs(CTLD._medevacCrews or {}) do
    if data.side == self.Side and data.requestTime then
      local dist = math.sqrt((data.position.x - pos.x)^2 + (data.position.z - pos.z)^2)
      if dist < nearestDist then
        nearestDist = dist
        nearest = data
      end
    end
  end
  
  if not nearest then
    _msgGroup(group, 'No active MEDEVAC requests.')
    return
  end
  
  local grid = self:_GetMGRSString(nearest.position)
  local distKm = nearestDist / 1000
  local distNm = nearestDist / 1852
  local elapsed = timer.getTime() - nearest.requestTime
  local remaining = (cfg.CrewTimeout or 3600) - elapsed
  local remainMin = math.floor(remaining / 60)
  
  local lines = {}
  table.insert(lines, '=== Nearest MEDEVAC ===')
  table.insert(lines, '')
  table.insert(lines, string.format('%s crew at %s', nearest.vehicleType, grid))
  table.insert(lines, string.format('Distance: %.1f km / %.1f nm', distKm, distNm))
  table.insert(lines, string.format('Crew Size: %d', nearest.crewSize or 2))
  table.insert(lines, string.format('Salvage Value: %d points', nearest.salvageValue or 1))
  table.insert(lines, string.format('Time Remaining: %d minutes', remainMin))
  
  _msgGroup(group, table.concat(lines, '\n'), 20)
end

-- Show coalition salvage points
function CTLD:ShowSalvagePoints(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  local salvage = CTLD._salvagePoints[self.Side] or 0
  env.info('ShowSalvagePoints: self.Side = ' .. tostring(self.Side) .. ', CTLD._salvagePoints[self.Side] = ' .. tostring(CTLD._salvagePoints and CTLD._salvagePoints[self.Side] or 'nil') .. ', salvage = ' .. tostring(salvage))
  
  local lines = {}
  table.insert(lines, '=== Coalition Salvage Points ===')
  table.insert(lines, '')
  table.insert(lines, string.format('Current Balance: %d points', salvage))
  table.insert(lines, '')
  table.insert(lines, 'Earn salvage by:')
  table.insert(lines, '- Rescuing MEDEVAC crews and delivering them to a MASH zone')
  table.insert(lines, '')
  table.insert(lines, 'Use salvage to:')
  table.insert(lines, '- Build items that are out of stock (automatic)')
  table.insert(lines, '- Cost = item\'s required crate count')
  
  _msgGroup(group, table.concat(lines, '\n'), 20)
end

function CTLD:ShowOnboardManifest(group)
  if not group then return end

  local gname = group:GetName()
  if not gname or gname == '' then return end

  self:_refreshLoadedTroopSummaryForGroup(gname)

  local lines = { '=== Onboard Manifest ===', '' }
  local hasCargo = false

  local crateData = CTLD._loadedCrates[gname]
  if crateData and crateData.byKey then
    local keys = {}
    for crateKey, count in pairs(crateData.byKey) do
      if (count or 0) > 0 then
        table.insert(keys, crateKey)
      end
    end
    table.sort(keys, function(a, b)
      return self:_lookupCrateLabel(a) < self:_lookupCrateLabel(b)
    end)
    for _, crateKey in ipairs(keys) do
      local count = crateData.byKey[crateKey] or 0
      if count > 0 then
        table.insert(lines, string.format('Crate: %s x %d', self:_lookupCrateLabel(crateKey), count))
        hasCargo = true
      end
    end
  end

  local troopSummary = CTLD._loadedTroopTypes[gname]
  if troopSummary and troopSummary.total and troopSummary.total > 0 then
    local typeKeys = {}
    for typeKey, _ in pairs(troopSummary.byType) do
      if (troopSummary.byType[typeKey] or 0) > 0 then
        table.insert(typeKeys, typeKey)
      end
    end
    table.sort(typeKeys, function(a, b)
      local la = troopSummary.labels and troopSummary.labels[a] or self:_lookupTroopLabel(a)
      local lb = troopSummary.labels and troopSummary.labels[b] or self:_lookupTroopLabel(b)
      return la < lb
    end)
    for _, typeKey in ipairs(typeKeys) do
      local count = troopSummary.byType[typeKey] or 0
      if count > 0 then
        local label = troopSummary.labels and troopSummary.labels[typeKey] or self:_lookupTroopLabel(typeKey)
        table.insert(lines, string.format('Troop: %s x %d', label, count))
        hasCargo = true
      end
    end
  end

  local crews = self:_CollectRescuedCrewsForGroup(gname)
  if crews and #crews > 0 then
    local crewTotals = {}
    for _, crew in ipairs(crews) do
      local data = crew.data or {}
      local label = data.vehicleType or 'Wounded crew'
      local size = data.crewSize or 0
      if size <= 0 then size = 1 end
      crewTotals[label] = (crewTotals[label] or 0) + size
    end
    local labels = {}
    for label, _ in pairs(crewTotals) do
      table.insert(labels, label)
    end
    table.sort(labels)
    for _, label in ipairs(labels) do
      table.insert(lines, string.format('Wounded: %s x %d', label, crewTotals[label]))
    end
    hasCargo = true
  end

  if not hasCargo then
    table.insert(lines, 'Nothing onboard.')
  end

  local salvage = CTLD._salvagePoints and (CTLD._salvagePoints[self.Side] or 0) or 0
  table.insert(lines, '')
  table.insert(lines, string.format('Salvage: %d pts', salvage))

  _msgGroup(group, table.concat(lines, '\n'), math.min(self.Config.MessageDuration or 20, 25))
end

-- Vectors to nearest MEDEVAC (shows top 3 with time remaining)
function CTLD:VectorsToNearestMEDEVAC(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  local unit = group:GetUnit(1)
  if not unit then return end
  
  local pos = unit:GetCoordinate()
  if not pos then return end
  
  local heading = unit:GetHeading() or 0
  local isMetric = _getPlayerIsMetric(unit)
  
  -- Collect all active MEDEVAC requests with distance
  local requests = {}
  for crewGroupName, data in pairs(CTLD._medevacCrews or {}) do
    if data.side == self.Side and data.requestTime and not data.pickedUp then
      local dist = math.sqrt((data.position.x - pos.x)^2 + (data.position.z - pos.z)^2)
      table.insert(requests, {
        data = data,
        distance = dist
      })
    end
  end
  
  if #requests == 0 then
    _msgGroup(group, 'No active MEDEVAC requests.')
    return
  end
  
  -- Sort by distance (closest first)
  table.sort(requests, function(a, b) return a.distance < b.distance end)
  
  -- Show top 3 (or fewer if less than 3 exist)
  local lines = {}
  table.insert(lines, 'MEDEVAC VECTORS (nearest 3):')
  table.insert(lines, '')
  
  local maxShow = math.min(3, #requests)
  for i = 1, maxShow do
    local req = requests[i]
    local data = req.data
    local dist = req.distance
    
    local dx = data.position.x - pos.x
    local dz = data.position.z - pos.z
    -- DCS uses LuaJIT (Lua 5.1) which has math.atan2, not math.atan(y,x)
    local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
    local bearing = math.deg(atan2(dz, dx))
    if bearing < 0 then bearing = bearing + 360 end
    
    local relativeBrg = bearing - heading
    if relativeBrg < 0 then relativeBrg = relativeBrg + 360 end
    if relativeBrg > 180 then relativeBrg = relativeBrg - 360 end
    
    -- Calculate time remaining
    local timeoutAt = data.spawnTime + (cfg.CrewTimeout or 3600)
    local timeRemainSec = math.max(0, timeoutAt - timer.getTime())
    local timeRemainMin = math.floor(timeRemainSec / 60)
    
    -- Format distance
    local distV, distU = _fmtRange(dist, isMetric)
    
    -- Build message for this crew
    table.insert(lines, string.format('#%d: %s crew', i, data.vehicleType))
    table.insert(lines, string.format('    BRG %03d° (%+.0f° rel) | RNG %s %s', 
      math.floor(bearing + 0.5), relativeBrg, distV, distU))
    table.insert(lines, string.format('    Time left: %d min | Salvage: %d pts', 
      timeRemainMin, data.salvageValue or 1))
    
    if i < maxShow then
      table.insert(lines, '')
    end
  end
  
  _msgGroup(group, table.concat(lines, '\n'), 20)
end

-- List MASH locations
function CTLD:ListMASHLocations(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  local unit = group:GetUnit(1)
  local playerPos = unit and unit:GetCoordinate()
  local playerVec3 = nil
  if playerPos then
    if playerPos.GetVec3 then
      local ok, vec = pcall(function() return playerPos:GetVec3() end)
      if ok then playerVec3 = vec end
    elseif playerPos.x and playerPos.z then
      playerVec3 = playerPos
    end
  end
  
  local count = 0
  local lines = {}
  table.insert(lines, '=== MASH Locations ===')
  table.insert(lines, '')
  
  for name, data in pairs(CTLD._mashZones or {}) do
    if data.side == self.Side then
      count = count + 1
      
      -- Get position from zone object
      local position = nil
      if data.position then
        position = data.position
      elseif data.zone and data.zone.GetCoordinate then
        local coord = data.zone:GetCoordinate()
        if coord then
          position = {x = coord.x, z = coord.z}
        end
      end
      
  local grid = position and self:_GetMGRSString(position) or 'Unknown'
      local typeStr = data.isMobile and 'Mobile' or 'Fixed'
      local radius = tonumber(data.radius) or 500

      local label = data.displayName or name
      table.insert(lines, string.format('%d. MASH %s (%s)', count, label, typeStr))
      table.insert(lines, string.format('   Grid: %s', grid))
      table.insert(lines, string.format('   Radius: %d m', radius))
      
      if playerVec3 and position then
        local dist = math.sqrt((position.x - playerVec3.x)^2 + (position.z - playerVec3.z)^2)
        local distKm = dist / 1000
        table.insert(lines, string.format('   Distance: %.1f km', distKm))
      end
      
      if data.freq then
        local freq = tonumber(data.freq)
        if freq then
          table.insert(lines, string.format('   Beacon: %.2f MHz', freq))
        else
          table.insert(lines, string.format('   Beacon: %s', tostring(data.freq)))
        end
      end
      
      table.insert(lines, '')
    end
  end
  
  if count == 0 then
    table.insert(lines, 'No MASH zones configured.')
    table.insert(lines, '')
    table.insert(lines, 'MASH zones are where you deliver rescued')
    table.insert(lines, 'MEDEVAC crews to earn salvage points.')
  else
    table.insert(lines, 'Deliver rescued crews to any MASH to earn salvage.')
  end
  
  _msgGroup(group, table.concat(lines, '\n'), 30)
end

-- Pop smoke at all active MEDEVAC sites
function CTLD:PopSmokeAtMEDEVACSites(group)
  _logVerbose('[MEDEVAC] PopSmokeAtMEDEVACSites called')
  
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _logVerbose('[MEDEVAC] MEDEVAC system not enabled')
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  if not CTLD._medevacCrews then
    _logVerbose('[MEDEVAC] No _medevacCrews table')
    _msgGroup(group, 'No active MEDEVAC requests to mark with smoke.')
    return
  end
  
  local count = 0
  _logVerbose(string.format('[MEDEVAC] Checking %d crew entries', CTLD._medevacCrews and #CTLD._medevacCrews or 0))
  
  for crewGroupName, data in pairs(CTLD._medevacCrews) do
    if data and data.side == self.Side and data.requestTime and data.position then
      count = count + 1
      _logVerbose(string.format('[MEDEVAC] Popping smoke for crew %s', crewGroupName))
      
      local smokeColor = (cfg.SmokeColor and cfg.SmokeColor[self.Side]) or trigger.smokeColor.Red
      _spawnMEDEVACSmoke(data.position, smokeColor, cfg)
    end
  end
  
  _logVerbose(string.format('[MEDEVAC] Popped smoke at %d locations', count))
  
  if count == 0 then
    _msgGroup(group, 'No active MEDEVAC requests to mark with smoke.')
  else
    _msgGroup(group, string.format('Smoke popped at %d MEDEVAC location(s).', count), 10)
  end
end

-- Pop smoke at MASH zones (delivery locations)
function CTLD:PopSmokeAtMASHZones(group)
  _logVerbose('[MEDEVAC] PopSmokeAtMASHZones called')
  
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _logVerbose('[MEDEVAC] MEDEVAC system not enabled')
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  if not CTLD._mashZones then
    _msgGroup(group, 'No MASH zones configured.')
    return
  end
  
  local count = 0
  local smokeColor = trigger.smokeColor.Orange
  
  for name, data in pairs(CTLD._mashZones) do
    if data and data.side == self.Side then
      -- Get position from zone object
      local position = nil
      if data.position then
        position = data.position
      elseif data.zone and data.zone.GetCoordinate then
        local coord = data.zone:GetCoordinate()
        if coord then
          position = {x = coord.x, z = coord.z}
        end
      end
      
      if position then
        count = count + 1
        _spawnMEDEVACSmoke(position, smokeColor, cfg)
        _logVerbose(string.format('[MEDEVAC] Popped smoke at MASH zone: %s', name))
      end
    end
  end
  
  if count == 0 then
    _msgGroup(group, 'No MASH zones found for your coalition.')
  else
    _msgGroup(group, string.format('Smoke popped at %d MASH zone(s).', count), 10)
  end
end

-- Clear all MEDEVAC missions (admin function)
function CTLD:ClearAllMEDEVACMissions(group)
  local cfg = CTLD.MEDEVAC
  if not cfg or not cfg.Enabled then
    _msgGroup(group, 'MEDEVAC system is not enabled.')
    return
  end
  
  local count = 0
  
  for crewGroupName, data in pairs(CTLD._medevacCrews or {}) do
    if data.side == self.Side then
      count = count + 1
      self:_RemoveMEDEVACCrew(crewGroupName, 'admin_clear')
    end
  end
  
  _msgGroup(group, string.format('Cleared %d MEDEVAC mission(s).', count), 10)
  _logVerbose(string.format('[MEDEVAC] Admin cleared %d MEDEVAC missions for coalition %s', count, self.Side))
end

--#endregion MEDEVAC

--#region Mobile MASH

-- Create a Mobile MASH zone and start announcements
function CTLD:_CreateMobileMASH(group, position, catalogDef)
  _logInfo('[MobileMASH] _CreateMobileMASH called')
  local cfg = self.Config.MEDEVAC
  if not cfg or not cfg.Enabled then
    _logInfo('[MobileMASH] Config missing or MEDEVAC disabled; aborting mobile deployment')
    return
  end
  if not cfg.MobileMASH or not cfg.MobileMASH.Enabled then
    _logInfo('[MobileMASH] MobileMASH feature disabled in config; aborting')
    return
  end

  if not position or not position.x or not position.z then
    _logInfo('[MobileMASH] Missing build position; aborting Mobile MASH deployment')
    return
  end

  local groupNamePreview = 'unknown'
  if group then
    local okPreview, namePreview = pcall(function() return group:getName() end)
    if okPreview and namePreview and namePreview ~= '' then groupNamePreview = namePreview end
  end
  _logInfo(string.format('[MobileMASH] Build requested for group %s at (%.1f, %.1f)', groupNamePreview, position.x or 0, position.z or 0))

  local function safeGetName(g)
    if not g then return nil end
    if g.getName then
      local ok, name = pcall(function() return g:getName() end)
      if ok and name and name ~= '' then return name end
    end
    if g.GetName then
      local ok, name = pcall(function() return g:GetName() end)
      if ok and name and name ~= '' then return name end
    end
    return nil
  end

  local side = catalogDef.side or self.Side
  if not side then
    _logError('[MobileMASH] Unable to determine coalition side; aborting Mobile MASH deployment')
    return
  end
  _logInfo(string.format('[MobileMASH] Using coalition side %s (%s)', tostring(side), tostring(catalogDef.side or self.Side)))

  CTLD._mobileMASHCounter = CTLD._mobileMASHCounter or { [coalition.side.BLUE] = 0, [coalition.side.RED] = 0 }
  CTLD._mobileMASHCounter[side] = (CTLD._mobileMASHCounter[side] or 0) + 1
  local index = CTLD._mobileMASHCounter[side]
  _logInfo(string.format('[MobileMASH] Assigned deployment index %d for side %s', index, tostring(side)))

  local mashId = string.format('MOBILE_MASH_%d_%d', side, index)
  local displayName
  if cfg.MobileMASH.AutoIncrementName == false then
    displayName = catalogDef.description or mashId
  else
    displayName = string.format('Mobile MASH %d', index)
  end
  _logInfo(string.format('[MobileMASH] mashId=%s displayName=%s recipeDesc=%s', mashId, tostring(displayName), tostring(catalogDef.description)))

  local initialPos = { x = position.x, z = position.z }
  local radius = cfg.MobileMASH.ZoneRadius or 500
  local beaconFreq = cfg.MobileMASH.BeaconFrequency or '30.0 FM'
  local mashGroupName = safeGetName(group)
  _logInfo(string.format('[MobileMASH] Initial position (%.1f, %.1f) radius %.1f freq %s groupName=%s', initialPos.x or 0, initialPos.z or 0, radius, tostring(beaconFreq), tostring(mashGroupName)))

  local function buildZoneObject(name, r, pos)
    if ZONE_RADIUS and VECTOR2 and VECTOR2.New then
      local ok, zoneObj = pcall(function()
        local v2 = VECTOR2:New(pos.x, pos.z)
        return ZONE_RADIUS:New(name, v2, r)
      end)
      if ok and zoneObj then
        _logDebug('[MobileMASH] Created ZONE_RADIUS object for mobile MASH')
        return zoneObj
      end
      if not ok then
        _logDebug(string.format('[MobileMASH] ZONE_RADIUS creation failed: %s', tostring(zoneObj)))
      end
    end
    local posCopy = { x = pos.x, z = pos.z }
    _logDebug('[MobileMASH] Falling back to table-based zone representation')
    local zoneObj = {}
    function zoneObj:GetName()
      return name
    end
    function zoneObj:GetPointVec3()
      return { x = posCopy.x, y = 0, z = posCopy.z }
    end
    function zoneObj:GetRadius()
      return r
    end
    function zoneObj:SetPointVec3(vec3)
      if vec3 and vec3.x and vec3.z then
        posCopy.x = vec3.x
        posCopy.z = vec3.z
      end
    end
    function zoneObj:SetVec2(vec2)
      if vec2 and vec2.x and vec2.y then
        posCopy.x = vec2.x
        posCopy.z = vec2.y
      end
    end
    return zoneObj
  end

  local rawGroupHandle = group

  local function finalizeMobileMASH()
    _logVerbose(string.format('[MobileMASH] Finalizing Mobile MASH %s', mashId))
    local mashGroupMoose = nil
    if GROUP and GROUP.FindByName and not mashGroupName then
      local ok, found = pcall(function()
        -- coalition.addGroup sometimes renames groups; scan by coalition
        if rawGroupHandle and rawGroupHandle.getName then
          return GROUP:FindByName(rawGroupHandle:getName())
        end
        return nil
      end)
      if ok and found then
        mashGroupMoose = found
        mashGroupName = mashGroupName or safeGetName(found)
      end
    elseif GROUP and GROUP.FindByName and mashGroupName then
      local ok, found = pcall(function() return GROUP:FindByName(mashGroupName) end)
      if ok and found then mashGroupMoose = found end
    end

    local function resolveRawGroup()
      if rawGroupHandle and rawGroupHandle.isExist and rawGroupHandle:isExist() then
        return rawGroupHandle
      end
      if mashGroupName and Group and Group.getByName then
        local ok, g = pcall(function() return Group.getByName(mashGroupName) end)
        if ok and g then
          rawGroupHandle = g
          if g.isExist and g:isExist() then
            return rawGroupHandle
          end
        elseif not ok then
          _logDebug(string.format('[MobileMASH] resolveRawGroup Group.getByName error: %s', tostring(g)))
        end
      end
      return nil
    end

    local function groupIsAlive()
      if mashGroupMoose and mashGroupMoose.IsAlive then
        local ok, alive = pcall(function() return mashGroupMoose:IsAlive() end)
        if ok and alive then return true end
        if not ok then
          _logDebug(string.format('[MobileMASH] groupIsAlive Moose check error: %s', tostring(alive)))
        end
      end
      local g = resolveRawGroup()
      if not g then return false end
      local units = g:getUnits()
      if not units then return false end
      for _, u in ipairs(units) do
        if u and u.isExist and u:isExist() then
          return true
        end
      end
      return false
    end

    local function groupVec3()
      if mashGroupMoose and mashGroupMoose.GetCoordinate then
        local ok, coord = pcall(function() return mashGroupMoose:GetCoordinate() end)
        if ok and coord then
          local vec3 = coord.GetVec3 and coord:GetVec3()
          if vec3 then return vec3 end
        end
        if not ok then
          _logDebug(string.format('[MobileMASH] groupVec3 Moose coordinate error: %s', tostring(coord)))
        end
      end
      local g = resolveRawGroup()
      if g then
        local units = g:getUnits()
        if units and units[1] and units[1].getPoint then
          local ok, point = pcall(function() return units[1]:getPoint() end)
          if ok and point then return point end
        end
      end
      return nil
    end

    local zoneObj = buildZoneObject(displayName, radius, initialPos)
    CTLD._mashZones = CTLD._mashZones or {}

    local mashData = {
      id = mashId,
      displayName = displayName,
      position = { x = initialPos.x, z = initialPos.z },
      radius = radius,
      side = side,
      group = mashGroupMoose or rawGroupHandle,
      groupName = mashGroupName,
      isMobile = true,
      catalogKey = catalogDef.description or 'Mobile MASH',
      zone = zoneObj,
      freq = beaconFreq,
    }

    CTLD._mashZones[mashId] = mashData
    _logInfo(string.format('[MobileMASH] Registered mashId=%s displayName=%s zoneRadius=%.1f freq=%s', mashId, displayName, radius, tostring(beaconFreq)))

    self._ZoneDefs = self._ZoneDefs or { PickupZones = {}, DropZones = {}, FOBZones = {}, MASHZones = {} }
    self._ZoneDefs.MASHZones = self._ZoneDefs.MASHZones or {}
    self._ZoneDefs.MASHZones[displayName] = { name = displayName, radius = radius, active = true, freq = beaconFreq }

    self._ZoneActive = self._ZoneActive or { Pickup = {}, Drop = {}, FOB = {}, MASH = {} }
    self._ZoneActive.MASH = self._ZoneActive.MASH or {}
    self._ZoneActive.MASH[displayName] = true

    -- Add zone to MASHZones array so it's recognized by the system
    self.MASHZones = self.MASHZones or {}
    table.insert(self.MASHZones, zoneObj)
    _logInfo(string.format('[MobileMASH] Added zone to MASHZones array, total count: %d', #self.MASHZones))

    -- Add to MEDEVAC zones if MEDEVAC is active
    if self.MEDEVAC and self.MEDEVAC.AddZone then
      local ok, err = pcall(function()
        self.MEDEVAC:AddZone(displayName, zoneObj)
      end)
      if ok then
        _logInfo(string.format('[MobileMASH] Added zone to MEDEVAC system: %s', displayName))
        -- Refresh MEDEVAC menu to include the new zone
        pcall(function() self.MEDEVAC:__Start(1) end)
      else
        _logDebug(string.format('[MobileMASH] Could not add to MEDEVAC system: %s', tostring(err)))
      end
    end

    -- Auto-draw the new zone on the map using the update function
    -- This ensures the drawing is tracked properly and can be updated/removed later
    local md = self.Config and self.Config.MapDraw or {}
    if md.Enabled and md.DrawMASHZones then
      _logInfo('[MobileMASH] Drawing new Mobile MASH zone on map')
      local ok, err = pcall(function() self:_updateMobileMASHDrawing(mashId) end)
      if not ok then
        _logError(string.format('_updateMobileMASHDrawing failed after Mobile MASH creation: %s', tostring(err)))
      end
    end

    local gridStr = self:_GetMGRSString(initialPos)
    trigger.action.outTextForCoalition(side, _fmtTemplate(CTLD.Messages.medevac_mash_deployed, {
      mash_id = index,
      grid = gridStr,
      freq = beaconFreq,
    }), 30)
    _logInfo(string.format('[MobileMASH] Mobile MASH "%s" registered at %s', displayName, gridStr))

    if cfg.MobileMASH.AnnouncementInterval and cfg.MobileMASH.AnnouncementInterval > 0 then
      local ctldInstance = self
      local scheduler = SCHEDULER:New(nil, function()
        local ok, err = pcall(function()
          if not groupIsAlive() then
            ctldInstance:_RemoveMobileMASH(mashId)
            return
          end

          local vec3 = groupVec3()
          if vec3 then
            mashData.position = { x = vec3.x, z = vec3.z }
            if mashData.zone then
              if mashData.zone.SetPointVec3 then
                mashData.zone:SetPointVec3({ x = vec3.x, y = vec3.y or 0, z = vec3.z })
              elseif mashData.zone.SetVec2 then
                mashData.zone:SetVec2({ x = vec3.x, y = vec3.z })
              end
            end
            local currentGrid = ctldInstance:_GetMGRSString({ x = vec3.x, z = vec3.z })
            trigger.action.outTextForCoalition(side, _fmtTemplate(CTLD.Messages.medevac_mash_announcement, {
              mash_id = index,
              grid = currentGrid,
              freq = beaconFreq,
            }), 20)
            _logDebug(string.format('[MobileMASH] Announcement tick for %s at grid %s', displayName, tostring(currentGrid)))
          end
        end)
        if not ok then _logError('Mobile MASH announcement scheduler error: '..tostring(err)) end
      end, {}, cfg.MobileMASH.AnnouncementInterval, cfg.MobileMASH.AnnouncementInterval)

      mashData.scheduler = scheduler
      _logDebug(string.format('[MobileMASH] Announcement scheduler started every %.1fs', cfg.MobileMASH.AnnouncementInterval))
    end

    -- Create a separate frequent position update scheduler for mobile MASH tracking
    -- This ensures the zone follows the vehicle even if announcements are infrequent
    local ctldInstance = self
    local positionUpdateInterval = 15  -- Update position every 15 seconds
    local mapRedrawInterval = 15  -- Redraw map every 15 seconds
    local updatesSinceRedraw = 0
    local posScheduler = SCHEDULER:New(nil, function()
      local ok, err = pcall(function()
        if not groupIsAlive() then
          ctldInstance:_RemoveMobileMASH(mashId)
          return
        end

        local vec3 = groupVec3()
        if vec3 then
          mashData.position = { x = vec3.x, z = vec3.z }
          if mashData.zone then
            if mashData.zone.SetPointVec3 then
              mashData.zone:SetPointVec3({ x = vec3.x, y = vec3.y or 0, z = vec3.z })
            elseif mashData.zone.SetVec2 then
              mashData.zone:SetVec2({ x = vec3.x, y = vec3.z })
            end
          end
          _logDebug(string.format('[MobileMASH] Position updated for %s at (%.1f, %.1f)', displayName, vec3.x, vec3.z))
          
          -- Redraw map only every 120 seconds
          updatesSinceRedraw = updatesSinceRedraw + positionUpdateInterval
          if updatesSinceRedraw >= mapRedrawInterval then
            pcall(function() ctldInstance:_updateMobileMASHDrawing(mashId) end)
            updatesSinceRedraw = 0
          end
        end
      end)
      if not ok then _logError('Mobile MASH position update scheduler error: '..tostring(err)) end
    end, {}, positionUpdateInterval, positionUpdateInterval)

    mashData.positionScheduler = posScheduler
    _logDebug(string.format('[MobileMASH] Position update scheduler started every %ds (map redraw every %ds)', positionUpdateInterval, mapRedrawInterval))

    if EVENTHANDLER then
      local ctldInstance = self
      local eventHandler = EVENTHANDLER:New()
      eventHandler:HandleEvent(EVENTS.Dead)

      function eventHandler:OnEventDead(EventData)
        local killedName = EventData.IniGroupName or (EventData.IniGroup and EventData.IniGroup:GetName())
        if killedName and killedName == mashGroupName then
          ctldInstance:_RemoveMobileMASH(mashId)
        end
      end

      mashData.eventHandler = eventHandler
      _logDebug(string.format('[MobileMASH] Event handler registered for group %s', tostring(mashGroupName)))
    end
  end

  if timer and timer.scheduleFunction and timer.getTime then
    _logDebug('[MobileMASH] Scheduling finalizeMobileMASH via timer')
    timer.scheduleFunction(function(_args, _time)
      local ok, err = pcall(finalizeMobileMASH)
      if not ok then
        _logError(string.format('[MobileMASH] finalize failed: %s', tostring(err)))
      end
      return nil
    end, {}, timer.getTime() + 0.2)
  else
    _logDebug('[MobileMASH] timer.scheduleFunction unavailable, running finalizeMobileMASH inline')
    local ok, err = pcall(finalizeMobileMASH)
    if not ok then
      _logError(string.format('[MobileMASH] finalize failed: %s', tostring(err)))
    end
  end
end

-- Remove a Mobile MASH zone (on destruction or manual removal)
function CTLD:_RemoveMobileMASH(mashId)
  if not CTLD._mashZones then return end
  
  local mash = CTLD._mashZones[mashId]
  if mash then
    -- Stop schedulers
    if mash.scheduler then
      mash.scheduler:Stop()
    end
    if mash.positionScheduler then
      mash.positionScheduler:Stop()
    end
    
    -- Remove map drawings
    if mash.circleId then trigger.action.removeMark(mash.circleId) end
    if mash.textId then trigger.action.removeMark(mash.textId) end
    local name = mash.displayName or mashId
    if self._ZoneDefs and self._ZoneDefs.MASHZones then self._ZoneDefs.MASHZones[name] = nil end
    if self._ZoneActive and self._ZoneActive.MASH then self._ZoneActive.MASH[name] = nil end
    self:_removeZoneDrawing('MASH', name)
    
    -- Remove from MASHZones array
    if self.MASHZones and mash.zone then
      for i = #self.MASHZones, 1, -1 do
        if self.MASHZones[i] == mash.zone then
          table.remove(self.MASHZones, i)
          _logDebug(string.format('[MobileMASH] Removed zone from MASHZones array, remaining count: %d', #self.MASHZones))
          break
        end
      end
    end
    
    -- Remove from MEDEVAC system if possible
    if self.MEDEVAC and self.MEDEVAC.RemoveZone then
      pcall(function() self.MEDEVAC:RemoveZone(name) end)
      _logDebug(string.format('[MobileMASH] Attempted to remove zone from MEDEVAC system: %s', name))
    end
    
    -- Send destruction message
    local msg = _fmtTemplate(CTLD.Messages.medevac_mash_destroyed, {
      mash_id = string.match(mashId, 'MOBILE_MASH_%d+_(%d+)') or '?'
    })
    trigger.action.outTextForCoalition(mash.side, msg, 20)
    
    -- Remove from table
    CTLD._mashZones[mashId] = nil
    _logVerbose(string.format('[MobileMASH] Removed MASH %s', mashId))
    if self.Config and self.Config.MapDraw and self.Config.MapDraw.Enabled then
      pcall(function() self:DrawZonesOnMap() end)
    end
  end
end

--#endregion Mobile MASH

--#endregion Inventory helpers

-- Create a new Drop Zone (AO) at the player's current location and draw it on the map if enabled
function CTLD:CreateDropZoneAtGroup(group)
  if not group or not group:IsAlive() then return end
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  -- Prevent creating a Drop Zone inside or too close to a Pickup Zone
  -- 1) Block if inside a (potentially active-only) pickup zone
  local activeOnlyForInside = (self.Config and self.Config.ForbidChecksActivePickupOnly ~= false)
  local inside, pz, distInside, pr = self:_isUnitInsidePickupZone(unit, activeOnlyForInside)
  if inside then
    local isMetric = _getPlayerIsMetric(unit)
    local curV, curU = _fmtRange(distInside or 0, isMetric)
    local needV, needU = _fmtRange(self.Config.MinDropZoneDistanceFromPickup or 10000, isMetric)
    _eventSend(self, group, nil, 'drop_zone_too_close_to_pickup', {
      zone = (pz and pz.GetName and pz:GetName()) or '(pickup)',
      need = needV, need_u = needU,
      dist = curV, dist_u = curU,
    })
    return
  end
  -- 2) Enforce a minimum distance from the nearest pickup zone (configurable)
  local minD = tonumber(self.Config and self.Config.MinDropZoneDistanceFromPickup) or 0
  if minD > 0 then
    local considerActive = (self.Config and self.Config.MinDropDistanceActivePickupOnly ~= false)
    local nearestZone, nearestDist
    if considerActive then
      nearestZone, nearestDist = self:_nearestActivePickupZone(unit)
    else
      local list = (self.Config and self.Config.Zones and self.Config.Zones.PickupZones) or {}
      nearestZone, nearestDist = _nearestZonePoint(unit, list)
    end
    if nearestZone and nearestDist and nearestDist < minD then
      local isMetric = _getPlayerIsMetric(unit)
      local needV, needU = _fmtRange(minD, isMetric)
      local curV, curU = _fmtRange(nearestDist, isMetric)
      _eventSend(self, group, nil, 'drop_zone_too_close_to_pickup', {
        zone = (nearestZone and nearestZone.GetName and nearestZone:GetName()) or '(pickup)',
        need = needV, need_u = needU,
        dist = curV, dist_u = curU,
      })
      return
    end
  end
  local p = unit:GetPointVec3()
  local baseName = group:GetName() or 'GROUP'
  local safe = tostring(baseName):gsub('%W', '')
  local name = string.format('AO_%s_%d', safe, math.random(100000,999999))
  local r = tonumber(self.Config and self.Config.DropZoneRadius) or 250
  local v2 = (VECTOR2 and VECTOR2.New) and VECTOR2:New(p.x, p.z) or { x = p.x, y = p.z }
  local mz = ZONE_RADIUS:New(name, v2, r)
  -- Register in runtime and config so other features can find it
  self.DropZones = self.DropZones or {}
  table.insert(self.DropZones, mz)
  self._ZoneDefs = self._ZoneDefs or { PickupZones = {}, DropZones = {}, FOBZones = {} }
  self._ZoneDefs.DropZones[name] = { name = name, radius = r, active = true }
  self._ZoneActive = self._ZoneActive or { Pickup = {}, Drop = {}, FOB = {} }
  self._ZoneActive.Drop[name] = true
  self.Config.Zones = self.Config.Zones or { PickupZones = {}, DropZones = {}, FOBZones = {} }
  self.Config.Zones.DropZones = self.Config.Zones.DropZones or {}
  table.insert(self.Config.Zones.DropZones, { name = name, radius = r, active = true })
  -- Draw on map if configured
  local md = self.Config and self.Config.MapDraw or {}
  if md.Enabled and (md.DrawDropZones ~= false) then
    local ok, err = pcall(function() self:DrawZonesOnMap() end)
    if not ok then
      _logError(string.format('DrawZonesOnMap failed after creating drop zone %s: %s', name, tostring(err)))
    end
  end
  MESSAGE:New(string.format('Drop Zone created: %s (r≈%dm)', name, r), 10):ToGroup(group)
end

function CTLD:AddPickupZone(z)
  local mz = _findZone(z)
  if mz then table.insert(self.PickupZones, mz); table.insert(self.Config.Zones.PickupZones, z) end
end

function CTLD:AddDropZone(z)
  local mz = _findZone(z)
  if mz then table.insert(self.DropZones, mz); table.insert(self.Config.Zones.DropZones, z) end
end

function CTLD:SetAllowedAircraft(list)
  self.Config.AllowedAircraft = DeepCopy(list)
end

-- Explicit cleanup handler for mission end
-- Call this to properly shut down all CTLD schedulers and clear state
function CTLD:Cleanup()
  _logInfo('Cleanup initiated - stopping all schedulers and clearing state')
  
  -- Stop all smoke refresh schedulers
  if CTLD._smokeRefreshSchedules then
    for crateId, schedule in pairs(CTLD._smokeRefreshSchedules) do
      if schedule.funcId then
        pcall(function() timer.removeFunction(schedule.funcId) end)
      end
    end
    CTLD._smokeRefreshSchedules = {}
  end
  
  -- Stop all Mobile MASH schedulers
  if CTLD._mashZones then
    for mashId, mash in pairs(CTLD._mashZones) do
      if mash.scheduler then
        pcall(function() mash.scheduler:Stop() end)
      end
      if mash.eventHandler then
        -- Event handlers clean themselves up, but we can nil the reference
        mash.eventHandler = nil
      end
    end
  end
  
  -- Stop any MEDEVAC timeout checkers or other schedulers
  -- (If you add schedulers in the future, stop them here)
  if self.MEDEVACSched then
    pcall(function() self.MEDEVACSched:Stop() end)
    self.MEDEVACSched = nil
  end
  if self.SalvageSched then
    pcall(function() self.SalvageSched:Stop() end)
    self.SalvageSched = nil
  end
  
  -- Clear spatial grid
  CTLD._spatialGrid = {}
  
  -- Clear state tables (optional - helps with memory in long-running missions)
  CTLD._crates = {}
  CTLD._troopsLoaded = {}
  CTLD._loadedCrates = {}
  CTLD._loadedTroopTypes = {}
  CTLD._deployedTroops = {}
  CTLD._hoverState = {}
  CTLD._unitLast = {}
  CTLD._coachState = {}
  CTLD._msgState = {}
  CTLD._buildConfirm = {}
  CTLD._buildCooldown = {}
  CTLD._jtacReservedCodes = { [coalition.side.BLUE] = {}, [coalition.side.RED] = {}, [coalition.side.NEUTRAL] = {} }
  if self._loadedCrateMenus then
    for _,state in pairs(self._loadedCrateMenus) do
      if state and state.commands then
        for _,cmd in ipairs(state.commands) do
          if cmd and cmd.Remove then pcall(function() cmd:Remove() end) end
        end
      end
    end
    self._loadedCrateMenus = {}
  end
  
  -- Clear salvage state
  if CTLD._salvageCrates then
    for crateName, meta in pairs(CTLD._salvageCrates) do
      if meta.staticObject and meta.staticObject.destroy then
        pcall(function() meta.staticObject:destroy() end)
      end
    end
    CTLD._salvageCrates = {}
  end
  if self.JTACSched then
    pcall(function() self.JTACSched:Stop() end)
    self.JTACSched = nil
  end
  if self._jtacRegistry then
    for groupName in pairs(self._jtacRegistry) do
      self:_cleanupJTACEntry(groupName)
    end
    self._jtacRegistry = {}
  end
  
  _logInfo('Cleanup complete')
end

-- Register mission end event to auto-cleanup
-- This ensures resources are properly released
if not CTLD._cleanupHandlerRegistered then
  CTLD._cleanupHandlerRegistered = true
  
  local cleanupHandler = EVENTHANDLER:New()
  cleanupHandler:HandleEvent(EVENTS.MissionEnd)
  
  function cleanupHandler:OnEventMissionEnd(EventData)
    _logInfo('Mission end detected - initiating cleanup')
    -- Cleanup all instances
    for _, instance in pairs(CTLD._instances or {}) do
      if instance and instance.Cleanup then
        pcall(function() instance:Cleanup() end)
      end
    end
    -- Also call static cleanup
    if CTLD.Cleanup then
      pcall(function() CTLD:Cleanup() end)
    end
  end
end

--#endregion Public helpers

-- =========================
-- Sling-Load Salvage System
-- =========================
--#region SlingLoadSalvage

-- Spawn a salvage crate when an enemy ground unit dies
function CTLD:_SpawnSlingLoadSalvageCrate(unitPos, unitTypeName, enemySide, eventData)
  local cfg = self.Config.SlingLoadSalvage
  if not cfg or not cfg.Enabled then return end
  
  -- Check spawn chance for this coalition
  local spawnChance = cfg.SpawnChance[enemySide] or 0.15
  if math.random() > spawnChance then
    _logVerbose(string.format('[SlingLoadSalvage] Spawn roll failed (%.2f chance)', spawnChance))
    return
  end
  
  -- Check spawn restrictions
  if cfg.NoSpawnNearPickupZones then
    local minDist = cfg.NoSpawnNearPickupZoneDistance or 1000
    for _, zone in ipairs(self.PickupZones or {}) do
      local zoneName = zone:GetName()
      if zoneName and (self._ZoneActive.Pickup[zoneName] ~= false) then
        local zonePos = zone:GetPointVec3()
        local dist = math.sqrt((unitPos.x - zonePos.x)^2 + (unitPos.z - zonePos.z)^2)
        if dist < minDist then
          _logVerbose('[SlingLoadSalvage] Too close to pickup zone, aborting spawn')
          return
        end
      end
    end
  end
  
  if cfg.NoSpawnNearAirbasesKm and cfg.NoSpawnNearAirbasesKm > 0 then
    local airbases = coalition.getAirbases(enemySide)
    if airbases then
      local minDistKm = cfg.NoSpawnNearAirbasesKm * 1000
      for _, ab in ipairs(airbases) do
        local abPos = ab:getPoint()
        local dist = math.sqrt((unitPos.x - abPos.x)^2 + (unitPos.z - abPos.z)^2)
        if dist < minDistKm then
          _logVerbose('[SlingLoadSalvage] Too close to airbase, aborting spawn')
          return
        end
      end
    end
  end
  
  -- Select weight class
  local totalProb = 0
  for _, wc in ipairs(cfg.WeightClasses) do
    totalProb = totalProb + wc.probability
  end
  local roll = math.random() * totalProb
  local cumulative = 0
  local selectedClass = cfg.WeightClasses[1] -- fallback
  for _, wc in ipairs(cfg.WeightClasses) do
    cumulative = cumulative + wc.probability
    if roll <= cumulative then
      selectedClass = wc
      break
    end
  end
  
  local weight = math.random(selectedClass.min, selectedClass.max)
  local rewardValue = math.floor((weight / 500) * selectedClass.rewardPer500kg)
  
  -- Calculate spawn position
  local minDist = cfg.MinSpawnDistance or 10
  local maxDist = cfg.MaxSpawnDistance or 25
  local distance = minDist + math.random() * (maxDist - minDist)
  local angle = math.random() * 2 * math.pi
  local spawnPos = {
    x = unitPos.x + math.cos(angle) * distance,
    z = unitPos.z + math.sin(angle) * distance
  }
  
  -- Get land height
  local landHeight = land.getHeight({ x = spawnPos.x, y = spawnPos.z })
  
  -- Select cargo type based on weight
  local cargoType
  if weight < 1500 then
    -- Light: barrels or ammo pallets
    local lightTypes = { 'barrels_cargo', 'ammo_cargo' }
    cargoType = lightTypes[math.random(1, #lightTypes)]
  elseif weight < 2500 then
    -- Medium: fuel tanks or containers
    local mediumTypes = { 'fueltank_cargo', 'container_cargo', 'ammo_cargo' }
    cargoType = mediumTypes[math.random(1, #mediumTypes)]
  else
    -- Heavy: large containers only
    cargoType = 'container_cargo'
  end
  
  -- Create unique crate name
  -- Use prefix that matches the coalition allowed to collect this crate
  local sidePrefix = (enemySide == coalition.side.BLUE) and 'B' or 'R'
  local crateName = string.format('SALVAGE-%s-%04dKG-%06d', sidePrefix, weight, math.random(100000, 999999))
  
  -- Enforce active salvage crate cap before spawning
  if cfg.MaxActiveCrates then
    local activeCount = 0
    for cname, meta in pairs(CTLD._salvageCrates or {}) do
      if meta and meta.side == enemySide then
        activeCount = activeCount + 1
      end
    end
    if activeCount >= cfg.MaxActiveCrates then
      _logVerbose(string.format('[SlingLoadSalvage] Max active crates (%d) reached for side %d; skipping spawn', cfg.MaxActiveCrates, enemySide))
      return
    end
  end

  -- Spawn the static cargo
  -- Spawn the crate for the coalition that can recover it (enemySide)
  local countryId = nil
  if CTLD._instances then
    for _, inst in ipairs(CTLD._instances) do
      if inst and inst.Side == enemySide and inst.CountryId then
        countryId = inst.CountryId
        break
      end
    end
  end
  if not countryId then
    countryId = _defaultCountryForSide(enemySide)
  end
  
  local staticData = {
    ['type'] = cargoType,
    ['name'] = crateName,
    ['x'] = spawnPos.x,
    ['y'] = spawnPos.z,
    ['heading'] = math.random() * 2 * math.pi,
    ['canCargo'] = true,
    ['mass'] = weight,
  }
  
  local success, staticObj = pcall(function()
    return coalition.addStaticObject(countryId, staticData)
  end)
  
  if not success or not staticObj then
    _logError('[SlingLoadSalvage] Failed to spawn salvage crate: ' .. tostring(staticObj))
    return
  end
  
  -- Store crate metadata
  CTLD._salvageCrates[crateName] = {
    side = enemySide,
    weight = weight,
    spawnTime = timer.getTime(),
    position = spawnPos,
    initialHealth = 1.0,
    rewardValue = rewardValue,
    warningsSent = {},
    staticObject = staticObj,
    crateClass = selectedClass.name,
  }
  
  -- Update stats
  if not CTLD._salvageStats[enemySide] then
    CTLD._salvageStats[enemySide] = { spawned = 0, delivered = 0, expired = 0, totalWeight = 0, totalReward = 0 }
  end
  CTLD._salvageStats[enemySide].spawned = CTLD._salvageStats[enemySide].spawned + 1
  
  -- Spawn smoke if enabled (use unified crate smoke offset logic)
  if cfg.SpawnSmoke then
    local smokeColor = cfg.SmokeColor or trigger.smokeColor.Orange
    -- Reuse crate smoke offset parameters but force Enabled for salvage spawn event
    local baseCfg = self.Config.CrateSmoke or {}
    local smokeConfig = {
      Enabled = true,                         -- always allow initial salvage smoke when SlingLoadSalvage.SpawnSmoke = true
      AutoRefresh = false,                    -- do not auto-refresh salvage smoke unless we explicitly add support later
      RefreshInterval = baseCfg.RefreshInterval,
      MaxRefreshDuration = baseCfg.MaxRefreshDuration,
      OffsetMeters = baseCfg.OffsetMeters,
      OffsetRandom = (baseCfg.OffsetRandom ~= false),
      OffsetVertical = baseCfg.OffsetVertical,
    }
    -- Provide a position table compatible with _spawnCrateSmoke (y = ground height)
    _spawnCrateSmoke({ x = spawnPos.x, y = landHeight, z = spawnPos.z }, smokeColor, smokeConfig, crateName)
  end
  
  -- Calculate expiration time
  local lifetime = cfg.CrateLifetime or 10800
  local timeRemainMin = math.floor(lifetime / 60)
  local timeRemainHrs = math.floor(timeRemainMin / 60)
  local timeRemainStr
  if timeRemainHrs >= 1 then
    timeRemainStr = string.format("%d hr%s", timeRemainHrs, timeRemainHrs > 1 and "s" or "")
  else
    timeRemainStr = string.format("%d min%s", timeRemainMin, timeRemainMin > 1 and "s" or "")
  end
  local grid = self:_GetMGRSString(spawnPos)
  
  -- Announce to coalition
  local msg = _fmtTemplate(self.Messages.slingload_salvage_spawned, {
    grid = grid,
    weight = weight,
    reward = rewardValue,
    time_remain = timeRemainStr,
  })
  _msgCoalition(enemySide, msg)
  
  _logInfo(string.format('[SlingLoadSalvage] Spawned %s: weight=%dkg, reward=%dpts at %s', 
    crateName, weight, rewardValue, grid))
end

-- Check salvage crates for delivery and cleanup
function CTLD:_CheckSlingLoadSalvageCrates()
  local cfg = self.Config.SlingLoadSalvage
  if not cfg or not cfg.Enabled then return end
  
  local now = timer.getTime()
  local cratesToRemove = {}
  
  for crateName, meta in pairs(CTLD._salvageCrates) do
    if meta.side == self.Side then
      local elapsed = now - meta.spawnTime
      local lifetime = cfg.CrateLifetime or 10800
      
      -- Check for expiration (skip for manual crates)
      if elapsed >= lifetime and not meta.isManual then
        table.insert(cratesToRemove, crateName)
        
        -- Update stats
        CTLD._salvageStats[meta.side].expired = CTLD._salvageStats[meta.side].expired + 1
        
        -- Announce expiration
        local grid = self:_GetMGRSString(meta.position)
        local msg = _fmtTemplate(self.Messages.slingload_salvage_expired, {
          id = crateName,
          grid = grid,
        })
        _msgCoalition(meta.side, msg)
        
        -- Remove the static object
        if meta.staticObject and meta.staticObject.destroy then
          pcall(function() meta.staticObject:destroy() end)
        end
        
        _logVerbose(string.format('[SlingLoadSalvage] Crate %s expired', crateName))
        
      else
        -- Check for warnings (skip for manual crates)
        if not meta.isManual then
          local remaining = lifetime - elapsed
          for _, warnTime in ipairs(cfg.WarningTimes or { 1800, 300 }) do
            if remaining <= warnTime and not meta.warningsSent[warnTime] then
            meta.warningsSent[warnTime] = true
            local grid = self:_GetMGRSString(meta.position)
            local msgKey = (warnTime >= 1800) and 'slingload_salvage_warn_30min' or 'slingload_salvage_warn_5min'
            local msg = _fmtTemplate(self.Messages[msgKey], {
              id = crateName,
              grid = grid,
              weight = meta.weight,
            })
            _msgCoalition(meta.side, msg)
            end
          end
        end
        
        -- Check if crate is in a salvage zone
        if meta.staticObject and meta.staticObject:isExist() then
          local cratePos = meta.staticObject:getPoint()
          if cratePos then
            -- Check all salvage zones for this coalition
            for _, zone in ipairs(self.SalvageDropZones or {}) do
              local zoneName = zone:GetName()
              local zoneDef = self._ZoneDefs.SalvageDropZones[zoneName]
              
              if zoneDef and zoneDef.side == meta.side and (self._ZoneActive.SalvageDrop[zoneName] ~= false) then
                -- cratePos is a DCS Vec3 table, so use the direct Vec3 helper to avoid GetVec2 calls
                if zone:IsVec3InZone(cratePos) then
                  -- Simple CTLD.lua style: just check if crate is in air
                  local crateHooked = _isCrateHooked(meta.staticObject)
                  
                  if not crateHooked then
                    -- Crate is on the ground in the zone - deliver it!
                    _logInfo(string.format('[SlingLoadSalvage] Delivering %s', crateName))
                    self:_DeliverSlingLoadSalvageCrate(crateName, meta, zoneName)
                    table.insert(cratesToRemove, crateName)
                    break
                  else
                    -- Crate is still hooked - send hint and wait for release
                    self:_SendSalvageHint(meta, 'slingload_salvage_hooked_in_zone', {
                      id = crateName,
                      zone = zoneName,
                    }, cratePos, 8)
                    _logDebug(string.format('[SlingLoadSalvage] Crate %s still hooked, waiting for release', crateName))
                  end
                end
              end
            end
            -- Provide guidance if crate is lingering inside other zone types
            self:_CheckCrateZoneHints(crateName, meta, cratePos)
          end
        else
          -- Crate no longer exists (destroyed or removed)
          table.insert(cratesToRemove, crateName)
          _logVerbose(string.format('[SlingLoadSalvage] Crate %s no longer exists', crateName))
        end
      end
    end
  end
  
  -- Remove processed crates
  for _, crateName in ipairs(cratesToRemove) do
    CTLD._salvageCrates[crateName] = nil
  end
end

-- Deliver a salvage crate and award points
function CTLD:_DeliverSlingLoadSalvageCrate(crateName, meta, zoneName)
  local cfg = self.Config.SlingLoadSalvage
  
  -- Check crate health for condition multiplier
  local healthRatio = 1.0
  if meta.staticObject and meta.staticObject.getLife then
    local success, currentLife = pcall(function() return meta.staticObject:getLife() end)
    if success and currentLife then
      local success2, maxLife = pcall(function() return meta.staticObject:getLife0() end)
      if success2 and maxLife and maxLife > 0 then
        healthRatio = currentLife / maxLife
      end
    end
  end
  
  -- Determine condition multiplier
  local conditionMult = cfg.ConditionMultipliers.Damaged or 1.0
  local conditionLabel = "Damaged"
  if healthRatio >= 0.9 then
    conditionMult = cfg.ConditionMultipliers.Undamaged or 1.5
    conditionLabel = "Undamaged"
  elseif healthRatio < 0.5 then
    conditionMult = cfg.ConditionMultipliers.HeavyDamage or 0.5
    conditionLabel = "Heavy Damage"
  end
  
  -- Calculate final reward
  local finalReward = math.floor(meta.rewardValue * conditionMult)
  
  -- Award salvage points
  CTLD._salvagePoints[meta.side] = (CTLD._salvagePoints[meta.side] or 0) + finalReward
  
  -- Update stats
  CTLD._salvageStats[meta.side].delivered = CTLD._salvageStats[meta.side].delivered + 1
  CTLD._salvageStats[meta.side].totalWeight = CTLD._salvageStats[meta.side].totalWeight + meta.weight
  CTLD._salvageStats[meta.side].totalReward = CTLD._salvageStats[meta.side].totalReward + finalReward
  
  -- Find the player who delivered (nearest transport helo in zone)
  local playerName = "Unknown Pilot"
  local deliveryUnit = nil
  for _, zone in ipairs(self.SalvageDropZones or {}) do
    if zone:GetName() == zoneName then
      -- Find nearby friendly helicopters
      local zonePos = zone:GetPointVec3()
      local radius = self:_getZoneRadius(zone) or 300
      local nearbyUnits = {}
      
      -- Search for units in the zone
      local sphere = _buildSphereVolume(zonePos, radius)
      
      local foundUnits = {}
      world.searchObjects(Object.Category.UNIT, sphere, function(obj)
        if obj and obj:isExist() and obj.getCoalition then
          local objCoal = obj:getCoalition()
          if objCoal == meta.side and obj.getGroup then
            local grp = obj:getGroup()
            if grp then
              local grpName = grp:getName()
              table.insert(foundUnits, { unit = obj, group = grp, groupName = grpName })
            end
          end
        end
        return true
      end)
      
      -- Find player name from group
      if #foundUnits > 0 then
        deliveryUnit = foundUnits[1].unit
        local grpName = foundUnits[1].groupName
        if grpName then
          -- Try to extract player name from group
          local mooseGrp = GROUP:FindByName(grpName)
          if mooseGrp then
            local unit1 = mooseGrp:GetUnit(1)
            if unit1 then
              local pName = unit1:GetPlayerName()
              if pName and pName ~= '' then
                playerName = pName
              else
                playerName = grpName
              end
            end
          end
        end
      end
      break
    end
  end
  
  -- Announce delivery
  local msg = _fmtTemplate(self.Messages.slingload_salvage_delivered, {
    player = playerName,
    weight = meta.weight,
    reward = finalReward,
    condition = conditionLabel,
    total = CTLD._salvagePoints[meta.side],
  })
  local quip
  local quipPool = self.Messages.slingload_salvage_received_quips
  if quipPool and #quipPool > 0 then
    local template = quipPool[math.random(#quipPool)]
    if template and template ~= '' then
      quip = _fmtTemplate(template, {
        player = playerName,
        zone = zoneName,
        reward = finalReward,
        weight = meta.weight,
        condition = conditionLabel,
        total = CTLD._salvagePoints[meta.side],
        coalition = (self.Side == coalition.side.BLUE) and 'BLUE' or 'RED',
      })
    end
  end
  if quip and quip ~= '' then
    msg = msg .. '\n' .. quip
  end
  _msgCoalition(meta.side, msg)
  
  -- Remove the crate
  if meta.staticObject and meta.staticObject.destroy then
    pcall(function() meta.staticObject:destroy() end)
  end
  
  _logInfo(string.format('[SlingLoadSalvage] %s delivered %s: %dkg, %dpts (%s), total=%d', 
    playerName, crateName, meta.weight, finalReward, conditionLabel, CTLD._salvagePoints[meta.side]))
end

-- Menu: Create Salvage Zone at group position
function CTLD:CreateSalvageZoneAtGroup(group)
  local cfg = self.Config.SlingLoadSalvage
  if not cfg or not cfg.Enabled then
    _msgGroup(group, 'Sling-Load Salvage system is disabled.')
    return
  end
  
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  local pos = unit:GetPointVec3()
  local coord = COORDINATE:NewFromVec3(pos)
  local radius = cfg.DefaultZoneRadius or 300
  
  -- Check for nearby salvage cargo (prevent zone placement within 1km of cargo)
  local minDistance = 1000 -- 1km
  for crateName, meta in pairs(CTLD._salvageCrates or {}) do
    if meta and meta.position then
      local cratePos = meta.position
      local distance = math.sqrt((pos.x - cratePos.x)^2 + (pos.z - cratePos.z)^2)
      if distance < minDistance then
        _msgGroup(group, string.format('Cannot create salvage zone within %.0fm of existing salvage cargo. Nearest cargo is %.0fm away.', minDistance, distance))
        return
      end
    end
  end
  
  self._DynamicSalvageZones = self._DynamicSalvageZones or {}
  self._DynamicSalvageQueue = self._DynamicSalvageQueue or {}

  -- Pre-clean existing dynamics so limit checks are up to date
  self:_enforceDynamicSalvageZoneLimit()

  -- Generate unique zone name
  local zoneName = string.format('SalvageZone-%s-%d', (self.Side == coalition.side.BLUE and 'BLUE' or 'RED'), 
    math.random(1000, 9999))
  
  -- Create MOOSE zone
  local zone = ZONE_RADIUS:New(zoneName, coord:GetVec2(), radius)
  
  -- Add to instance zones
  table.insert(self.SalvageDropZones, zone)
  local now = timer and timer.getTime and timer.getTime() or 0
  local lifetime = tonumber(cfg.DynamicZoneLifetime or 0) or 0
  local expiresAt = (lifetime > 0) and (now + lifetime) or nil

  self._ZoneDefs.SalvageDropZones[zoneName] = {
    name = zoneName,
    side = self.Side,
    active = true,
    radius = radius,
    dynamic = true,
    createdAt = now,
    expiresAt = expiresAt,
  }
  self._ZoneActive.SalvageDrop[zoneName] = true

  -- Track dynamic zone metadata for cleanup enforcement
  self._DynamicSalvageZones[zoneName] = {
    zone = zone,
    createdAt = now,
    expiresAt = expiresAt,
    radius = radius,
  }
  table.insert(self._DynamicSalvageQueue, zoneName)

  -- Enforce limits after registering the new zone
  self:_enforceDynamicSalvageZoneLimit()
  if not self._DynamicSalvageZones[zoneName] then
    _msgGroup(group, 'Unable to create salvage zone (limit reached). Older zones were not cleared in time.')
    return
  end
  
  -- Announce
  local msg = _fmtTemplate(self.Messages.slingload_salvage_zone_created, {
    zone = zoneName,
    radius = radius,
  })
  if lifetime > 0 then
    msg = msg .. string.format(' Expires in %s.', _ctldFormatSeconds(lifetime))
  end
  local maxZones = tonumber(cfg.MaxDynamicZones or 0) or 0
  if maxZones > 0 then
    msg = msg .. string.format(' Active zone cap: %d.', maxZones)
  end
  _msgGroup(group, msg)
  
  _logInfo(string.format('[SlingLoadSalvage] Created zone %s at %s', zoneName, coord:ToStringLLDMS()))

  local ok, err = pcall(function() self:DrawZonesOnMap() end)
  if not ok then
    _logError(string.format('[SlingLoadSalvage] DrawZonesOnMap failed after creating %s: %s', zoneName, tostring(err)))
  end
end

function CTLD:RetireOldestDynamicSalvageZone(group)
  local cfg = self.Config.SlingLoadSalvage
  if not cfg or not cfg.Enabled then return end

  self._DynamicSalvageQueue = self._DynamicSalvageQueue or {}
  if #self._DynamicSalvageQueue == 0 then
    if group then _msgGroup(group, 'No dynamic salvage zones to retire.') end
    return
  end

  local oldest = self._DynamicSalvageQueue[1]
  if not oldest then
    if group then _msgGroup(group, 'No dynamic salvage zones to retire.') end
    return
  end

  local exists = self._DynamicSalvageZones and self._DynamicSalvageZones[oldest]
  if exists then
    self:_removeDynamicSalvageZone(oldest, 'manual-retire')
    if group then
      _msgGroup(group, string.format('Retired salvage zone: %s', oldest))
    end
  else
    -- Remove stale entry from queue and notify user
    table.remove(self._DynamicSalvageQueue, 1)
    if group then _msgGroup(group, 'Oldest salvage zone already retired.') end
  end
end

-- Menu: Show active salvage zones
function CTLD:ShowActiveSalvageZones(group)
  local cfg = self.Config.SlingLoadSalvage
  if not cfg or not cfg.Enabled then return end
  
  local activeZones = {}
  for _, zone in ipairs(self.SalvageDropZones or {}) do
    local zoneName = zone:GetName()
    if self._ZoneActive.SalvageDrop[zoneName] ~= false then
      local zoneDef = self._ZoneDefs.SalvageDropZones[zoneName]
      if zoneDef and zoneDef.side == self.Side then
        table.insert(activeZones, zoneName)
      end
    end
  end
  
  if #activeZones == 0 then
    _msgGroup(group, 'No active Salvage Collection Zones configured.')
  else
    local msg = 'Active Salvage Collection Zones:\n' .. table.concat(activeZones, '\n')
    _msgGroup(group, msg)
  end
end

-- Menu: Show nearest salvage crate vectors
function CTLD:ShowNearestSalvageCrate(group)
  local cfg = self.Config.SlingLoadSalvage
  if not cfg or not cfg.Enabled then return end
  
  local unit = group:GetUnit(1)
  if not unit or not unit:IsAlive() then return end
  
  local pos = unit:GetPointVec3()
  local here = { x = pos.x, z = pos.z }
  
  local nearestName, nearestMeta, nearestDist = nil, nil, math.huge
  for crateName, meta in pairs(CTLD._salvageCrates) do
    if meta.side == self.Side then
      local dx = meta.position.x - here.x
      local dz = meta.position.z - here.z
      local dist = math.sqrt(dx*dx + dz*dz)
      if dist < nearestDist then
        nearestDist = dist
        nearestName = crateName
        nearestMeta = meta
      end
    end
  end
  
  if not nearestName or not nearestMeta or not nearestMeta.position then
    local msg = self.Messages.slingload_salvage_no_crates or 'No active salvage crates available.'
    _msgGroup(group, msg)
    return
  end
  
  local brg = _bearingDeg(here, nearestMeta.position)
  local isMetric = _getPlayerIsMetric(unit)
  local rng, rngU = _fmtRange(nearestDist, isMetric)
  
  local msg = _fmtTemplate(self.Messages.slingload_salvage_vectors, {
    id = nearestName,
    brg = brg,
    rng = rng,
    rng_u = rngU,
    weight = nearestMeta.weight,
    reward = nearestMeta.rewardValue,
  })
  _msgGroup(group, msg)
end

--#endregion SlingLoadSalvage

--#endregion Public helpers

-- =========================
-- Return factory
-- =========================
--#region Export
_MOOSE_CTLD = CTLD
return CTLD
--#endregion Export



