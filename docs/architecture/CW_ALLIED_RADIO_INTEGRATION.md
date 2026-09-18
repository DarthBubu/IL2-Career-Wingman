# Career Wingman ↔ IL-2 Allied Radio Integration

Date: 2026-09-18
Status: Architecture decision based on Allied Radio v6.2 acceptance candidate

## Objective

Reuse the working IL-2 Allied Radio bridge as Career Wingman's radio-mode and player-lifecycle authority. Career Wingman dialogue must only enter the audio channel when the selected mode and verified aircraft policy permit it.

## Existing reusable capabilities

The inspected v6.2 build already provides:

- a Windows bridge executable;
- a local HTTP control/status API on `127.0.0.1:49152`;
- passive global hotkey observation;
- forwarded IL-2 UDP telemetry handling;
- `_gen.Mission` parsing;
- unique single-player/Career player selection using `AILevel=0`;
- correlation between mission aircraft and live telemetry identity;
- player `ACTIVE`, `DEAD` and restarted-aircraft lifecycle handling;
- nation-aware voice-group policy;
- `COMBAT` and `BROADCAST` state;
- `NO_TOUCH` handling for uncertain classifications;
- aircraft radio-equipment policy and forced radio silence;
- recovery logic for renamed IL-2 audio folders;
- browser heartbeat and abnormal-exit recovery.

Career Wingman should consume these decisions rather than duplicating them.

## Required mode contract

| Allied Radio state | Native IL-2 voice policy | Historical broadcast | Career Wingman conversation |
|---|---|---|---|
| `COMBAT`, player `ACTIVE`, radio allowed | Nation-appropriate friendly group enabled; managed enemy groups suppressed | Off | **Allowed** |
| `BROADCAST` | GBR, USA and GER managed groups suppressed | On | **Muted/blocked** |
| Player `DEAD` | Allied Radio performs no new folder transition; IL-2 remains responsible | Stopped | **Stop current line and clear/suspend queue** |
| Forced radio silence | Managed voice groups silenced | Off | **Muted/blocked** |
| `NO_TOUCH` | No new folder manipulation | Off | **Muted by default** because identity/policy is uncertain |
| Telemetry/player state unknown | Preserve existing Radio safety behavior | Do not start | **Muted by default** |
| New/restarted verified aircraft | Reset to nation-appropriate `COMBAT` | Off | Resume only after fresh validation |

The user-facing rule is therefore:

> Career Wingman conversation is audible only in verified COMBAT mode. BROADCAST, forced silence, DEAD, NO_TOUCH or uncertain state suppresses it.

## Integration boundary

Allied Radio remains the owner of:

- radio mode selection;
- native voice-folder policy;
- historical broadcast playback;
- aircraft radio availability;
- mission/player/nation validation;
- global radio hotkeys;
- player lifecycle interlocks.

Career Wingman owns:

- event normalization;
- participant and formation state;
- conversation planning;
- radio priority and channel arbitration;
- AI prompt construction and validation;
- synthetic/recorded wingman speech;
- optional text transcript/overlay;
- squadron and historical memory.

## Proposed local interface

Career Wingman should initially read the existing bridge `State` response and use at least:

- `playerAlive`;
- `aircraftData`;
- `aircraftName`;
- `broadcastMode`;
- `radioPolicy`;
- `forcedRadioSilence`;
- `deadInterlock`;
- `missionTheater`;
- `missionPolicy`;
- `playerNation`;
- `voiceGroup`;
- telemetry-active and packet-count health signals.

Career Wingman should calculate a single gate:

```text
conversationAllowed =
    bridge healthy
    AND telemetry/player validation healthy
    AND player ACTIVE
    AND mission policy permits managed radio
    AND aircraft policy is not SILENCE
    AND forcedRadioSilence is false
    AND broadcastMode is false
```

When this expression changes from true to false:

1. stop or rapidly fade any Career Wingman line;
2. clear expired tactical messages;
3. suspend narrative messages;
4. preserve only messages explicitly eligible for later replay;
5. log the gate transition and reason.

## Channel arbitration

Career Wingman should use one internal channel queue:

1. immediate warning;
2. tactical command;
3. required acknowledgement;
4. mission/formation coordination;
5. ground-control report;
6. squadron/historical narrative.

`BROADCAST` overrides and blocks every Career Wingman priority. Narrative traffic must never interrupt or leak into historical broadcast mode.

## What IL-2 currently allows or exposes

### Confirmed/implemented externally

- An external companion can play audio while IL-2 runs.
- The existing project can observe the configured physical hotkey without preventing IL-2 from receiving it.
- The existing project can use forwarded UDP telemetry and mission data to classify the player and lifecycle state.
- The existing project can manage known nationality voice folders to implement broad COMBAT/BROADCAST availability policy, with safety and recovery logic.
- Mission-authored Subtitle and Media MCUs can display text and play sound when prepared in the mission before it runs.

### Not currently exposed by a documented single-player interface

- inject a newly generated line into IL-2's native radio system;
- identify exactly when an internal IL-2 voice line starts or ends;
- target an arbitrary native radio line to a dynamically selected recipient;
- change native Subtitle/Media content after the active Career mission has loaded;
- control Career-mode radio through DServer RCon;
- independently duck only IL-2's native voice channel while preserving every other IL-2 sound.

## Native-voice collision limitation

In COMBAT mode, IL-2's permitted friendly voice folder remains available. Career Wingman's external speech may therefore overlap a native IL-2 voice line.

The current project has no proven native-radio playback-state signal. Renaming a voice folder determines broad availability but does not prove that already loaded/cached audio will stop, and repeatedly renaming folders around every generated line would introduce race and recovery risks.

Initial policy:

- do not perform per-line folder renames;
- do not claim collision-free native integration;
- keep generated messages short;
- use conservative cooldowns after major detected events;
- log overlap observations during testing;
- investigate whether game logs, telemetry or repeatable file access reveal native voice playback timing.

If collisions remain unacceptable, evaluate an optional future **Career Wingman-owned combat channel** in which native friendly chatter is suppressed for the whole enhanced-radio session and Career Wingman supplies the conversation. This must be a separate, explicitly tested mode and must not alter the locked v6.2 behavior silently.

## Failure behavior

Career Wingman must fail silent when:

- Allied Radio bridge cannot be reached;
- state is stale;
- player or mission identity is uncertain;
- the aircraft is verified as lacking usable radio equipment;
- mode is BROADCAST;
- the player lifecycle is DEAD/ABSENT;
- an unsupported theatre or policy produces `NO_TOUCH`.

The flight must remain unaffected if Career Wingman stops or crashes.

## Test sequence

### AR-CW-01: state observation

Read bridge state without modifying it. Confirm all gate inputs for a verified Career flight.

### AR-CW-02: COMBAT permission

With player ACTIVE and mode COMBAT, play one test Career Wingman line. Confirm historical broadcast is off.

### AR-CW-03: BROADCAST suppression

While a Career Wingman line is queued, switch to BROADCAST. Confirm the line stops/fades, queue is blocked and only historical audio remains.

### AR-CW-04: return to COMBAT

Switch back to COMBAT. Confirm narrative backlog does not dump immediately and new validated traffic can play.

### AR-CW-05: DEAD interlock

During a controlled test, verify that DEAD stops Career Wingman audio and prevents new lines. Do not modify IL-2 voice folders as a consequence of DEAD.

### AR-CW-06: restart/new aircraft

Confirm fresh aircraft validation and default COMBAT reset before Career Wingman resumes.

### AR-CW-07: uncertain mission

Force or reproduce `NO_TOUCH`; verify Career Wingman remains silent.

### AR-CW-08: native voice collision logging

Run multiple sorties in COMBAT mode and manually mark any overlap between IL-2 native speech and Career Wingman speech. Use results to decide whether a future channel-ownership mode is needed.

## Decision

Use IL-2 Allied Radio v6.2 as the shared radio-state authority. Do not merge its code into Career Wingman yet. Integrate through the local bridge API so both projects remain independently testable and failures remain isolated.
