# CW Dynamic In-Flight Messages and Audio — Feasibility Study

Date: 2026-09-18

## Objective

Determine whether Career Wingman can react to events detected during an IL-2 Great Battles single-player Career sortie by displaying text or playing audio while the flight is still running.

## Evidence-backed findings

### 1. IL-2 has native mission-authored subtitles

The Mission Editor provides a `Translator: Subtitle` MCU. Mission logic can trigger it during a sortie, and its authored properties include message text, coalition visibility, duration, font size, alignment, and colour. The Mission Editor manual also confirms that subtitle messages are localized mission content.

This proves that IL-2 can display timed in-flight text when the text and trigger graph are already part of the loaded mission.

It does **not** prove that an external program can create or rewrite a subtitle after the mission has loaded.

### 2. IL-2 has native mission-authored media/audio

The Mission Editor provides `Translator: Media` functionality for mission media, including sound. This proves that a scripted mission can trigger pre-authored audio.

As with subtitles, no reliable public interface was found that lets an external companion inject a new sound file or change a Media MCU in an already-running single-player Career mission.

### 3. Runtime edits to `_gen.Mission` are unproven and probably too late

Career generates mission files before flight. IL-2 uses mission data loaded for the active sortie, including compiled mission data and localization indexes. Editing `_gen.Mission` or localization text after the sortie begins should therefore be treated as an experiment, not as a supported control interface.

Even if the text file changes on disk, the running mission may continue using its already-loaded representation. The current CW 0.1 probe should record timing, but must not modify IL-2 files.

### 4. Remote Console is a multiplayer-server facility

The Mission Editor and Multiplayer Server Manual describes Remote Console as a way to control a DServer multiplayer mission server. This is not evidence of an RCon channel for the normal single-player Career process.

RCon/chat injection is therefore not a valid primary design for Career Wingman. It may be revisited only for a separate cooperative/DServer mode.

### 5. External audio is the strongest near-term output route

A Windows companion can play WAV/MP3/OGG dialogue independently while IL-2 is running. The audio will reach the same Windows output device used by IL-2 unless the user routes applications differently.

Advantages:

- no modification of IL-2 mission files;
- generated or selected dialogue can be played immediately;
- works with single-player Career;
- can be synchronized to detected events;
- easy to prototype and disable;
- volume, queuing, interruption and radio effects remain under companion control.

This audio is heard alongside the game rather than being inserted into IL-2's internal radio engine. Spatialization, cockpit occlusion and native radio mixing must be simulated externally if desired.

### 6. External visual overlay is the strongest near-term text route

For desktop play, a transparent always-on-top overlay can show short wingman messages without touching the game. For VR, a supported OpenXR/VR overlay or kneeboard surface is a more realistic route than trying to rewrite the active mission.

OpenKneeboard documents third-party integration and OpenXR overlay use, making it a candidate display bridge. Compatibility and visibility in the user's exact Quest 3 runtime must be tested.

This would be Career Wingman text layered over the game, not native IL-2 chat or native Subtitle MCU output.

## Feasibility ranking

| Route | Single-player Career | Dynamic during flight | Risk | Current verdict |
|---|---:|---:|---:|---|
| External companion audio | Yes | Yes | Low | Recommended first output channel |
| Desktop transparent overlay | Yes | Yes | Low–medium | Recommended for 2D testing |
| OpenXR/OpenKneeboard text surface | Likely | Yes | Medium | Best VR text candidate; requires Quest 3 test |
| Pre-authored Subtitle MCU | Only if mission can be prepared before load | Triggerable, but text is pre-authored | Medium | Proven mission feature, poor fit for unmodified Career |
| Pre-authored Media MCU | Only if mission can be prepared before load | Triggerable, but media is pre-authored | Medium | Proven mission feature, poor fit for unmodified Career |
| Edit `_gen.Mission` after mission load | Unknown | Unproven | High | Research experiment only; do not rely on it |
| DServer RCon/chat | No for ordinary Career | Yes on applicable multiplayer server | Medium | Out of scope for core Career Wingman |
| DLL injection/process-memory modification | Technically uncertain | Potentially | Very high | Rejected from project scope |

## Recommended architecture

```text
IL-2 files/logs/telemetry
          |
          v
Event detector -> Event confidence gate -> Story/rules engine
                                          |              |
                                          v              v
                                  Audio queue       Text overlay
                                  (primary)         (optional)
```

The extraction probe and output prototype should remain separate processes/modules initially. That prevents an output experiment from corrupting evidence about when IL-2 writes its files.

## Controlled test plan

### CW 0.1A — extraction timing (current)

1. Run the read-only FlightLog probe.
2. Mark cockpit spawn, engine start, takeoff, combat start, weapon use, damage, landing, mission finish and debrief.
3. Establish which files change during flight and which change only at mission/debrief completion.
4. Do not inject messages or alter mission files during this baseline test.

### CW 0.1B — independent audio proof

1. Add a test button/event simulator to the companion.
2. Play a short local voice sample while IL-2 Career is in flight.
3. Verify 2D and Quest 3 audio routing, latency, volume balance and whether IL-2 remains focused.
4. Record timestamp from trigger to audible playback.

Pass target: reliable playback without changing focus or interrupting controls.

### CW 0.1C — desktop text proof

1. Show a borderless, click-through message overlay.
2. Confirm visibility in fullscreen/windowed modes used by the player.
3. Test queueing, expiry and suppression during menus/debrief.

### CW 0.1D — Quest 3 text proof

1. Test OpenKneeboard or another supported OpenXR overlay route.
2. Display a changing local text page/panel controlled by the companion.
3. Measure update delay, readability and frame-time impact.
4. Keep audio as the fallback if VR overlay integration is unreliable.

### CW 0.1E — event-to-output loop

Only after an event source is proven during CW 0.1A:

1. Convert one high-confidence event into an internal normalized event.
2. Trigger one audio line and one optional text line.
3. Add cooldown and duplicate suppression.
4. Log detected event, confidence, selected response, playback start and completion.

## Decision

Proceed with **external audio first**, followed by **external text overlay**. Continue extraction testing at the same time, but keep the two paths isolated until event timing is proven.

Do not build the core design around live rewriting of Career mission files, native chat injection, or DServer RCon. These are unsupported or mismatched to single-player Career based on currently available evidence.

## Sources

- IL-2 Sturmovik Mission Editor and Multiplayer Server Manual: https://www.scribd.com/document/372123635/IL-2-Sturmovik-Mission-Editor-and-Multiplayer-Server-Manual
- IL-2 forum discussion demonstrating Subtitle Translator behavior: https://forum.il2sturmovik.com/topic/53595-the-mystery-of-the-disappearing-subtitle-translator/
- OpenKneeboard documentation and third-party developer FAQ: https://openkneeboard.com/

## Evidence limits

No official single-player runtime API for inserting arbitrary new text/audio into an already-running Career mission was found. Absence from public documentation is not proof that no internal mechanism exists; it means the project must treat such a route as unverified until a controlled test proves it.
