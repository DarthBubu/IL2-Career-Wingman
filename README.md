# IL-2 Career Wingman

Career Wingman is an external Windows companion for IL-2 Great Battles single-player Career. Its goal is to add persistent, historically disciplined radio conversation among the player, a flight of up to eight aircraft, ground control, and escorting or escorted formations.

It complements Career Tracker: confirmed career facts remain with the tracker, while Career Wingman uses verified mission context and history to create tactical radio traffic, character continuity and squadron narrative.

## Current status

The project is in **CW 0.1 — evidence gathering**. The current probe measures when IL-2 creates or changes:

- `FlightLogs\*.mlg`
- `_gen.Mission`
- `cp.db`

It does not yet interpret combat events. Its purpose is to establish which information is available before flight, during flight and after debrief.

## Architecture

Read the [authoritative project blueprint](docs/architecture/CW_PROJECT_BLUEPRINT.md) first.

The supported design is an external companion consisting of:

- Career Wingman Core for mission state, events, doctrine and conversation;
- Radio Control Service for native-voice suppression, channel ownership and recovery;
- Speech Worker for local clips, streaming TTS and offline fallback;
- Audio engine for priority, interruption and WWII radio processing.

Urgent tactical calls remain deterministic and locally available. Online TTS is an optional rendering layer for dynamic speech, not a source of game facts and not a dependency for critical warnings.

## CW 0.1 probe

### Requirements

Windows 10 or Windows 11. No additional runtime is required. The launcher uses Windows PowerShell and WinForms included with Windows.

### How to use

1. Extract the complete ZIP to a normal folder.
2. Double-click `Start_CW_0.1.cmd`.
3. Choose the IL-2 data folder containing `FlightLogs`.
4. Start capture before loading a Career mission.
5. Mark controlled events such as mission load, takeoff, combat, damage, landing, mission end and debrief.
6. Stop capture after debrief.
7. Retain the newest folder inside `Captures` for analysis.

The probe opens watched files read-only and writes only to its own `Captures` folder. It does not inject code, read process memory or modify IL-2 files.

## Documentation

- [Authoritative project blueprint](docs/architecture/CW_PROJECT_BLUEPRINT.md)
- [End-to-end technical architecture](docs/architecture/CW_END_TO_END_TECHNICAL_ARCHITECTURE.md)
- [Dynamic conversation architecture](docs/architecture/CW_DYNAMIC_CONVERSATION_ARCHITECTURE.md)
- [Allied Radio integration](docs/architecture/CW_ALLIED_RADIO_INTEGRATION.md)
- [TTS provider and low-latency speech architecture](docs/architecture/CW_TTS_PROVIDER_ARCHITECTURE.md)
- [Dynamic in-flight output feasibility](docs/research/CW_DYNAMIC_OUTPUT_FEASIBILITY.md)

## Development order

1. Prove the available input feeds.
2. Prove external audio and crash-safe native-voice suppression.
3. Build provider-neutral speech with local tactical clips and Gemini streaming.
4. Complete one replayable event-to-radio vertical slice.
5. Expand to formation, ground-control and escort radio.
6. Add Career Tracker continuity and historical doctrine packs.
