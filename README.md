# WWII Pilot Intuition System

[![Lua](https://img.shields.io/badge/Lua-5.1-blue.svg)](https://www.lua.org/)
[![DCS World](https://img.shields.io/badge/DCS%20World-Compatible-green.svg)](https://www.digitalcombatsimulator.com/)

A Moose Framework-based script for DCS World that simulates WWII-era pilot intuition and reconnaissance, enhancing immersion in historical aviation scenarios by providing realistic target spotting without modern aids.

## Description

The WWII Pilot Intuition System bridges the gap between modern DCS gameplay and historical WWII aviation. In an era without radar or advanced avionics, pilots relied on visual scanning, formation flying, and intuition to maintain situational awareness. This script recreates that experience by alerting players to nearby air and ground threats through voice-like messages and optional visual markers.

Whether flying solo or in formation, players receive timely warnings about bandits, ground units, and tactical situations, promoting better tactics and deeper immersion in WWII-themed missions.

## Features

- **Dynamic Detection Ranges**: Base ranges adjusted by formation bonuses and environmental factors (night, bad weather).
- **Realistic Messaging**: Simulates pilot radio calls for spotting bandits, ground threats, and formation feedback.
- **Formation Integrity Monitoring**: Alerts for wingmen presence and formation status.
- **Dogfight Assistance**: Warnings for merging bandits, tail threats, head-on encounters, and more.
- **Visual Markers**: Optional smoke or flare markers for spotted targets.
- **Independent Scanning Toggles**: Separate controls for air and ground target detection, available globally (mission-wide) and per-player.
- **Player Customization**: Configurable settings via in-game F10 menu, including per-player overrides for scanning preferences and alert frequency modes.
- **Environmental Awareness**: Reduced detection ranges at night or in bad weather.
- **Multiplayer Support**: Works in both single-player and multiplayer environments.

## Installation

### Prerequisites
- **DCS World**: Ensure you have DCS World installed and updated.
- **Moose Framework**: Download and install the Moose framework from [FlightControl's MOOSE Documentation](https://flightcontrol-master.github.io/MOOSE_DOCS/).

### Steps
1. **Download the Script**:
   - Clone or download this repository.
   - Copy `Moose_WWII_PilotIntuition.lua` to your DCS mission folder.

2. **Include Moose Framework**:
   - Ensure `Moose_.lua` is also in your mission folder (included in this repo).

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
  - **Global Settings**: Mission-wide toggles for active messaging, markers, and scanning (air/ground).
  - **Per-Player Settings**: Individual controls under "Pilot Intuition" for dogfight assist, markers, scanning preferences, and alert frequency (Normal/Quiet/Verbose).
- **Automatic Alerts**: Receive voice-like messages for detected threats, formation changes, and compliments (based on your enabled scans).
- **On-Demand Summaries**: Request situation summaries via menu options.

### Gameplay Tips
- **Formation Flying**: Fly close to wingmen to increase detection ranges.
- **Environmental Factors**: Be aware that night and bad weather reduce spotting distances.
- **Dogfights**: Use the system for merge warnings and tactical advice.
- **Ground Attacks**: Get alerts for nearby enemy units and vehicles.
- **Custom Scanning**: Toggle air or ground scanning on/off via F10 menu to focus on specific threats (e.g., disable ground alerts during air battles).
- **Alert Frequency**: Adjust alert frequency to "Quiet" for fewer messages in busy situations or "Verbose" for more detailed feedback.

## Configuration

The script uses a global configuration table `PILOT_INTUITION_CONFIG` for easy customization. Edit the values in `Moose_WWII_PilotIntuition.lua` before loading the mission. Players can override global settings via the F10 menu for personalized experience.

### Key Settings
- **Detection Ranges**: Adjust base ranges for air and ground targets.
- **Multipliers**: Set environmental factors like night and weather penalties.
- **Messaging**: Control cooldowns and enable/disable features.
- **Markers**: Choose marker type and duration.
- **Scanning Toggles**: Enable/disable air and ground scanning globally (players can override individually).
- **Dogfight Assist**: Toggle assistance and set thresholds.

For detailed parameter descriptions, refer to the comments in the script.

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