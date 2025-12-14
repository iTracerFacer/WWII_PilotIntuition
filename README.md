# WWII Pilot Intuition System

[![Lua](https://img.shields.io/badge/Lua-5.1-blue.svg)](https://www.lua.org/)
[![DCS World](https://img.shields.io/badge/DCS%20World-Compatible-green.svg)](https://www.digitalcombatsimulator.com/)

A Moose Framework-based script for DCS World that simulates WWII-era pilot intuition and reconnaissance, enhancing immersion in historical aviation scenarios by providing realistic target spotting without modern aids.

## Description

The WWII Pilot Intuition System bridges the gap between modern DCS gameplay and historical WWII aviation. In an era without radar or advanced avionics, pilots relied on visual scanning, formation flying, and intuition to maintain situational awareness. This script recreates that experience by alerting players to nearby air and ground threats through voice-like messages and optional visual markers.

Whether flying solo or in formation, players receive timely warnings about bandits, ground units, and tactical situations, promoting better tactics and deeper immersion in WWII-themed missions.

## Features

- **Dynamic Detection Ranges**: This core feature simulates historical WWII reconnaissance by dynamically adjusting spotting distances based on formation flying and environmental conditions. Detection ranges for air and ground targets are boosted when flying in close formation with wingmen, reflecting how pilots in WWII relied on mutual support for better situational awareness. For instance, a solo pilot has base detection ranges (e.g., 5km for air targets, 3km for ground). In a 2-ship formation (two pilots flying within 1km of each other), ranges double to 10km air and 6km ground. A 4-ship formation triples them to 15km air and 9km ground, up to a maximum multiplier of 6x. Environmental factors further modify this: at night (22:00-06:00), ranges are reduced by 50%; bad weather can apply an additional 30% penalty. This encourages tactical formation flying and adapts to real-world conditions, making solo flights more challenging and formations more rewarding.
- **Realistic Messaging**: Simulates pilot radio calls for spotting bandits, ground threats, and formation feedback.
- **Formation Integrity Monitoring**: Alerts for wingmen presence and formation status.
- **Intelligent Threat Assessment**: Advanced aspect angle and clock position calculations accurately determine bandit orientation and position relative to your aircraft, providing precise tactical information about whether threats are nose-on, tail-chase, or flanking.
- **Combat Focus Filtering**: Realistic tunnel-vision behavior during close combat—when engaged with an immediate threat (HOT bandit within 1km), distant or non-threatening bandits are automatically suppressed to reduce message clutter and simulate pilot focus under stress.
- **Dogfight Assistance**: Warnings for merging bandits, tail threats, head-on encounters, and more.
- **Visual Markers**: Optional smoke or flare markers for spotted targets. The illumination system provides a limited number of illumination flares (default 3 per sortie) that can be dropped manually via the F10 menu to mark positions or targets. Flares have a cooldown between drops (30 seconds) and are reloaded to full capacity upon landing at a friendly airbase.
- **Independent Scanning Toggles**: Separate controls for air and ground target detection per-player.
- **Player Customization**: Configurable settings via in-game F10 menu, including per-player overrides for scanning preferences and alert frequency modes.
- **Environmental Awareness**: Reduced detection ranges at night or in bad weather.
- **Multiplayer Support**: Works in both single-player and multiplayer environments.

## Installation

### Prerequisites
- **DCS World**: Ensure you have DCS World installed and updated.
- **Moose Framework**: Download and install the Moose framework from [FlightControl's MOOSE](https://github.com/FlightControl-Master/MOOSE_INCLUDE/tree/develop/Moose_Include_Static).

### Steps
1. **Download the Script**:
   - Clone or download this repository.
   - Copy `Moose_WWII_PilotIntuition.lua` to your DCS mission folder.

2. **Include Moose Framework**:
   - Download `Moose_Include_Static.lua` from [FlightControl's MOOSE](https://github.com/FlightControl-Master/MOOSE_INCLUDE/tree/develop/Moose_Include_Static) and include it in your mission folder.

3. **Add to Mission**:
   - Open your DCS mission in the Mission Editor.
   - Go to **Triggers** > **Mission Start** > **Do Script File**.
   - Select `Moose_WWII_PilotIntuition.lua`.
   - Save and export the mission.

4. **Test the Mission**:
   - Load the mission in DCS.
   - The system initializes automatically on mission start.
   - Players will see a welcome message and can access settings via the F10 menu.

## Usage

### In-Game Controls
- **F10 Menu**:
  - **Global Settings**: Mission-wide toggles for active messaging, markers, and air scanning.
  - **Per-Player Settings**: Individual controls under "Pilot Intuition" for dogfight assist, markers, air scanning preferences, alert frequency (Normal/Quiet/Verbose), and ground targeting (scan and select targets to mark).
- **Automatic Alerts**: Receive voice-like messages for detected threats, formation changes, and compliments (based on your enabled scans).
- **On-Demand Summaries**: Request situation summaries via menu options.

### Gameplay Tips
- **Formation Flying**: Fly close to wingmen to increase detection ranges. This is a key tactical element inspired by WWII aviation, where formations provided mutual spotting support. For example, maintaining a tight 2-ship formation boosts your air detection range from 5km to 10km, allowing you to spot bandits twice as far. In larger formations like a 4-ship flight, ranges can reach 15km, giving you a significant advantage in reconnaissance and defense. Stay within 1km of your wingmen to qualify for these bonuses—formations enhance capabilities but require discipline to maintain.
- **Environmental Factors**: Be aware that night and bad weather reduce spotting distances. At night, detection ranges are halved, simulating reduced visibility without modern aids. Bad weather applies additional penalties, making formation flying even more critical for maintaining awareness.
- **Dogfights**: Use the system for merge warnings and tactical advice.
- **Ground Attacks**: Use on-demand ground scanning to detect and mark specific targets. Scan lists up to 5 nearby targets, then select which one to mark with smoke/flares.
- **Custom Scanning**: Toggle air scanning on/off via F10 menu. Use "Ground Targeting" submenu to scan for nearby ground targets and select specific ones to mark.
- **Alert Frequency**: Adjust alert frequency to "Quiet" for fewer messages in busy situations or "Verbose" for more detailed feedback.

## Configuration

The script uses a global configuration table `PILOT_INTUITION_CONFIG` for easy customization. Edit the values in `Moose_WWII_PilotIntuition.lua` before loading the mission. Players can override global settings via the F10 menu for personalized experience.

### Key Settings
- **Detection Ranges**: Adjust base ranges for air and ground targets.
- **Multipliers**: Set environmental factors like night and weather penalties.
- **Messaging**: Control cooldowns and enable/disable features.
- **Markers**: Choose marker type and duration.
- **Scanning Toggles**: Enable/disable air scanning globally (players can override individually). Ground scanning is on-demand.
- **Dogfight Assist**: Toggle assistance and set thresholds.

For detailed parameter descriptions, refer to the comments in the script.

## Threat Detection System

### Design Philosophy

The threat detection system is designed to simulate realistic WWII pilot situational awareness, balancing comprehensive threat reporting with combat-focused tunnel vision. When pilots engage in close-quarters dogfighting, they naturally focus on immediate threats while peripheral awareness diminishes—this is reflected in our combat focus filtering.

### Aspect Angle Calculation

**Aspect angle** measures the angular difference between where the bandit's nose is pointing and where it would need to point to aim directly at you, ranging from 0° to 180°:

- **0°-45° = HOT (Nose-On)**: Bandit's nose is pointed at you or nearly at you—an immediate offensive threat
- **46°-134° = FLANKING**: Bandit has a side aspect—may be maneuvering, crossing, or setting up for attack
- **135°-180° = COLD (Tail Aspect)**: Bandit's nose is pointed away from you—likely fleeing, unaware, or you have the advantage

**How It Works:**
1. Calculate the bearing from bandit to you (the heading the bandit would need to point at you)
2. Get the bandit's actual nose heading
3. The difference is the aspect angle

**Examples:**
- **Aspect 0°**: Bandit heading 090° (east), you're at bearing 090° from him = pointing right at you (HOT)
- **Aspect 180°**: Bandit heading 090° (east), you're at bearing 270° (west) from him = pointing directly away (COLD)
- **Aspect 90°**: Bandit heading 090° (east), you're at bearing 180° (south) from him = crossing perpendicular (FLANKING)

### Clock Position Reporting

**Clock position** tells you where the bandit is in your field of view, using a 12-hour clock face:

- **12 o'clock**: Dead ahead, in front of your nose (345° to 15°)
- **1 o'clock**: Right-front (15° to 45°)
- **2 o'clock**: Right-front quarter (45° to 75°)
- **3 o'clock**: Off your right wing (75° to 105°)
- **6 o'clock**: Behind you, on your tail (165° to 195°)
- **9 o'clock**: Off your left wing (255° to 285°)

Each clock position covers a **30-degree sector** with **±15 degrees of tolerance** from the nominal angle. This means a bandit needs to be within 15 degrees of dead-ahead (0°) to be called as "12 o'clock." If the relative bearing is 16° or more, it will be called as "1 o'clock."

Clock positions are calculated from your heading to the bandit's position, independent of which way the bandit is facing. A bandit at your 12 o'clock might be flying HOT toward you, or COLD away from you—the clock position only tells you WHERE they are, not which way they're going.

**Note**: If you're seeing unexpected clock positions (e.g., "1 o'clock" or "3 o'clock" when you expect "12 o'clock"), the bandit may be slightly off-axis due to wind drift, maneuvering, or navigation errors. Enable debug mode to see the exact relative bearing values.

### Combat Focus Filtering

When you enter close combat (any HOT bandit within 1km), the system simulates realistic tunnel vision by filtering threat messages:

**During Close Combat (HOT engagement < 1km):**
- **Always Report**: Bandits within 2km (immediate threats)
- **Always Report**: HOT or FLANKING bandits at any distance (active threats)
- **Suppress**: COLD or DISTANT bandits beyond 2km (non-threatening)

**After Combat (no HOT bandits within 1km):**
- **Full Awareness Returns**: All detected bandits are reported normally

This prevents message spam during knife fights while ensuring you're aware of immediate dangers. Once you've defeated the close threat or separated, peripheral awareness returns and you'll be updated on the tactical situation.

### Example Scenarios

#### Scenario 1: Head-On Merge
**Situation**: You're flying north (heading 000°). A bandit appears 10 miles (16km) ahead, flying south (heading 180°) directly toward you—pure head-on engagement.

**Initial Detection:**
```
BANDIT! 12 o'clock, 16 kilometers, LEVEL
HOT! Nose aspect - closing fast!
```

**Analysis:**
- Your Heading: 000° (north)
- Bandit Heading: 180° (south, flying toward you)
- Bearing to Bandit: 000° (dead ahead)
- Relative Bearing: (000° - 000° + 360) % 360 = 0°
- **Clock Position**: floor((0° + 15) / 30) + 1 = 1 = **12 o'clock** ✓
- Bearing from Bandit to You: 000° + 180° = 180° (you are directly behind/south of bandit from his perspective)
- Aspect Angle: |180° - 180°| = 0° = **HOT** ✓

**Clock Position Tolerance:**
- If relative bearing is **0° to 14°**: Reports as **12 o'clock**
- If relative bearing is **15° to 44°**: Reports as **1 o'clock**
- If you're seeing **1 o'clock or 3 o'clock calls** when it should be 12 o'clock, check:
  - Is the bandit's actual position drifting due to wind?
  - Is the bandit maneuvering slightly left/right?
  - Enable debug mode to see exact bearing values

**As You Close (< 5km):**
```
BANDIT! 12 o'clock, 3 kilometers, LEVEL
HOT! Nose aspect - closing fast!
```

**As You Merge (< 1km):**
```
MERGE! Break now!
```

**After Merge**: You pass each other. Now the bandit is behind you (at your 6 o'clock), and from the bandit's perspective, you're at their 6 o'clock. If both continue straight, aspect becomes 180° = **COLD** for both.

#### Scenario 2: Tail Chase Opportunity
**Situation**: You're flying east (heading 090°). You spot a bandit at your 2 o'clock position, 4km away, also flying east (heading 090°)—same direction as you.

**Detection:**
```
BANDIT! 2 o'clock, 4 kilometers, LEVEL
COLD aspect - good chase opportunity
```

**Analysis:**
- Clock Position: 2 o'clock (60° right of your nose)
- Bearing to Bandit: ~060° from you
- Bandit Heading: 090° (east)
- Bearing from Bandit to You: 060° + 180° = 240° (you're southwest of the bandit)
- Aspect Angle: |240° - 090°| = 150° = **COLD** ✓
- Threat Level: COLD (bandit flying away/parallel, tail aspect)

**Your Response**: You turn to pursue. Since the bandit is COLD and beyond 2km, if another HOT bandit appears close by, this tail chase target will be temporarily suppressed in your callouts until you deal with the immediate threat.

#### Scenario 3: Multi-Bandit Combat Focus
**Situation**: You're flying west (heading 270°) at 1000m altitude. You're chasing Bandit-1 who is 3km ahead, flying away (COLD, 12 o'clock). Suddenly, Bandit-2 appears coming from the opposite direction, 2km away at your 12 o'clock, flying east (heading 090°)—toward you.

**Phase 1 - Initial State:**
```
BANDIT! 12 o'clock, 3 kilometers, LEVEL
COLD aspect - tail chase

BANDIT! 12 o'clock, 2 kilometers, LEVEL  
HOT! Nose aspect - closing fast!
```

**Phase 2 - Combat Focus Engages (Bandit-2 now < 1km):**
```
MULTIPLE BANDITS - 2 contacts
Nearest: 12 o'clock, 800 meters, HOT!
[Note: Bandit-1 at 3km COLD is suppressed from display]
```

**Analysis:**
- Combat Focus Active: Bandit-2 is HOT and within 1km (engaged in close combat)
- Filtered: Bandit-1 (3km away, COLD aspect) is temporarily removed from callouts
- Why: You need to focus on the immediate nose-on threat without distraction
- Debug Log: "COMBAT FOCUS - Filtered 1 distant threat, showing 1 immediate threat"

**Phase 3 - After Defeating Bandit-2 (separation > 1km):**
```
BANDIT! 12 o'clock, 4 kilometers, LEVEL
COLD aspect - target of opportunity
```

**Analysis:**
- Combat Focus Deactivated: No HOT bandits within 1km anymore
- Full Awareness Restored: Bandit-1 now visible again in your callouts
- Tactical Update: You can reassess whether to continue the pursuit

#### Scenario 4: Defensive Scissors
**Situation**: You're turning hard in a dogfight. Enemy is at your 4 o'clock, 500m, turning with you. Aspect angle fluctuates between FLANKING (90°) and HOT (30°) as you both maneuver.

**During Engagement:**
```
BANDIT! 4 o'clock, 500 meters, HOT!
Threat on your quarter!

[3 seconds later]
BANDIT! 5 o'clock, 600 meters, FLANKING
Watch your six!
```

**Analysis:**
- Clock Position Changes: 4 o'clock → 5 o'clock as relative bearing shifts
- Aspect Changes: HOT → FLANKING as the bandit's nose angle changes during turns
- Combat Focus: No suppression (bandit always within 2km = always reported)
- Cooldown System: Messages respect 3-5 second cooldowns to avoid spam

**Tactical Value**: Clock position tells you where to look; aspect tells you the threat level. If aspect goes COLD while they're still at your 6 o'clock, they've turned away—opportunity to reverse!

#### Scenario 5: Bounce from Above
**Situation**: You're flying straight and level, heading north (000°). An enemy bounces from above-behind, diving on you from 1.5km at your 7 o'clock, nose pointed at you.

**Detection:**
```
BANDIT! 7 o'clock, 1500 meters, HIGH
HOT! Check your six!
```

**Analysis:**
- Clock Position: 7 o'clock (behind and to the left)
- Altitude: HIGH (above you)
- Aspect: HOT (nose pointed at you = attacking)
- Immediate Threat: Within 2km and HOT aspect = priority alert

**Your Response**: Break hard into the attack. As you turn, clock position will shift (7 o'clock → 9 o'clock → 12 o'clock if you complete the turn), but aspect remains HOT as long as the bandit tracks you.

### Configuration Parameters

Key threat detection settings in `PILOT_INTUITION_CONFIG`:

- `threatHotRange = 1000` (meters): Distance threshold for HOT threat classification and combat focus activation
- `threatColdRange = 5000` (meters): Maximum range for COLD/FLANKING bandit reporting
- `combatFocusRange = 2000` (meters): During close combat, suppress bandits beyond this range unless they're HOT/FLANKING
- `messageCooldown = 5` (seconds): Minimum time between general threat updates
- `hotThreatCooldown = 3` (seconds): Minimum time between HOT threat warnings (more frequent)

### Debug Mode

Enable debug logging to see detailed calculations:
```lua
PILOT_INTUITION_CONFIG.debugMode = true
```

Debug output shows:
- Player heading and bandit bearing
- Relative bearing (clock position in degrees)
- Bandit heading and aspect angle
- Threat classification (HOT/COLD/FLANKING/DISTANT)
- Combat focus filtering counts

## Examples

### Basic Mission Setup
1. Create a new DCS mission with WWII aircraft.
2. Add enemy AI units or multiplayer slots.
3. Include the script as described in Installation.
4. Fly and observe alerts for spotted targets.

### Custom Configuration
```lua
PILOT_INTUITION_CONFIG = {
    airDetectionRange = 6000,  -- Increase air detection range
    dogfightAssistEnabled = false,  -- Disable dogfight help
    markerType = "flare",  -- Use flares instead of smoke
}
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/your-feature`.
3. Commit your changes: `git commit -m 'Add your feature'`.
4. Push to the branch: `git push origin feature/your-feature`.
5. Open a Pull Request.

### Development Notes
- Ensure compatibility with Moose Framework updates.
- Test changes in various DCS mission scenarios.
- Update documentation for new features.

## Credits

- **Script by**: F99th-TracerFacer
- **Built on the MOOSE framework**
- **Special thanks to the DCS and MOOSE communities**
- **Discord**: https://discord.gg/NdZ2JuSU (The Fighting 99th Discord Server where I spend most of my time.)

## License

Copyright 2025 F99th-TracerFacer

This project is open source under the MIT License. See LICENSE for details.

## Support

For issues, questions, or suggestions:
- Open an issue on [GitHub](https://github.com/iTracerFacer/WWII_PilotIntuition/issues).
- Check the [DCS Forums](https://forum.dcs.world/) for community support.

Enjoy immersive WWII flying with enhanced situational awareness!</content>
<parameter name="filePath">c:\DCS_ScriptingDev\WWII_PilotIntuition\README.md