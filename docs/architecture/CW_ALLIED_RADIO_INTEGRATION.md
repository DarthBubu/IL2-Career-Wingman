# Career Wingman ↔ IL-2 Radio Control Integration

Date: 2026-09-18
Status: Architecture decision; Allied Radio v6.2 is a reference release candidate, not a fixed dependency

## Objective

Reuse proven mechanisms from the IL-2 Allied Radio project without freezing Career Wingman to version 6.2. Later Allied Radio releases may revise their API, states and implementation.

When Career Wingman's enhanced combat-radio session is active, Career Wingman owns the combat-radio channel. Every managed IL-2 native AI voice group must remain suppressed for the complete enhanced session so generated conversation takes precedence without routine native-voice collisions.

## Proven reference capabilities

The inspected Allied Radio v6.2 candidate demonstrates:

- a Windows bridge and local status/control API;
- passive global hotkey observation;
- forwarded IL-2 UDP telemetry handling;
- `_gen.Mission` parsing;
- single-player/Career player selection using a unique `AILevel=0` aircraft;
- correlation between mission aircraft and telemetry identity;
- player lifecycle handling;
- mission, nation and voice-group policy;
- `COMBAT`, `BROADCAST`, `NO_TOUCH` and forced-silence decisions;
- safe audio-folder transitions, conflict checks and recovery;
- heartbeat and abnormal-exit recovery.

These capabilities are evidence and reusable building blocks, not a requirement to preserve the exact v6.2 design.

## Required operating contract

| Combined state | Native IL-2 AI voices | Historical broadcast | Career Wingman dialogue |
|---|---|---|---|
| Enhanced `COMBAT`, player active and radio allowed | **All managed voice groups suppressed** | Off | **Allowed; Career Wingman owns channel** |
| `BROADCAST` | All managed voice groups suppressed | On | **Muted** |
| Player dead/absent during enhanced session | Keep suppression stable until orderly release or revalidation | Stopped | **Stop current line and clear/suspend queue** |
| Forced radio silence | Suppressed | Off | **Muted** |
| `NO_TOUCH` before session start | No new manipulation | Off | **Do not start** |
| Unknown/stale state before session start | Preserve safe existing condition | Off | **Do not start** |
| New/restarted verified aircraft | Revalidate before continuing suppression | Off | Resume only after validation |
| Enhanced mode disabled or orderly exit | Restore appropriate ordinary Radio/native policy | Follow selected mode | Off |

> Career Wingman speech is audible only in verified enhanced COMBAT mode. During that mode, all managed IL-2 native AI voices are suppressed and Career Wingman exclusively supplies radio conversation.

## Responsibility boundary

The shared Radio Control service owns:

- mode selection;
- native voice suppression and restoration;
- historical broadcast playback;
- aircraft radio availability;
- mission/player/nation validation;
- global radio hotkeys;
- lifecycle interlocks;
- crash and stale-session recovery.

Career Wingman owns:

- event normalization;
- participant and formation state;
- conversation planning;
- radio priorities and channel arbitration;
- AI prompt construction and validation;
- generated/recorded speech;
- optional text transcript/overlay;
- squadron and historical memory.

Career Wingman must never rename IL-2 voice folders directly. It requests channel ownership; the Radio Control service performs suppression and restoration atomically.

## Version-independent adapter

Career Wingman should depend on capabilities, not on an Allied Radio version number. The adapter should expose operations equivalent to:

```text
GetRadioCapabilities()
GetRadioState()
AcquireEnhancedCombatChannel(owner, leaseDuration)
RenewEnhancedCombatChannel(lease)
ReleaseEnhancedCombatChannel(lease)
SetBroadcastMode(on)
SubscribeToStateChanges()
```

The exact transport can initially use the v6.2 local HTTP API. Exact v6.2 field names must remain inside the adapter.

## Leased channel ownership

Enhanced channel ownership must use a renewable lease:

1. Career Wingman requests ownership.
2. Radio Control verifies player, mission, aircraft policy and mode.
3. Radio Control suppresses all managed native voice groups.
4. Only after suppression succeeds does it grant the lease.
5. Career Wingman renews the lease through a heartbeat.
6. On orderly exit it releases the lease.
7. On crash or stale heartbeat, Radio Control restores the appropriate ordinary radio policy automatically.

This prevents voice folders remaining disabled after Career Wingman terminates unexpectedly.

## Conversation gate

```text
conversationAllowed =
    radio service healthy
    AND telemetry/player validation healthy
    AND player ACTIVE
    AND mission policy permits radio
    AND aircraft policy is not SILENCE
    AND forcedRadioSilence is false
    AND broadcastMode is false
    AND enhanced-channel lease is valid
    AND native-suppression confirmation is true
```

When this becomes false:

1. stop or rapidly fade the current Career Wingman line;
2. discard expired tactical traffic;
3. suspend narrative traffic;
4. prevent backlog dumping when service resumes;
5. release ownership when appropriate;
6. log the transition and reason.

## Channel arbitration

Career Wingman maintains one logical radio queue:

1. immediate warning;
2. tactical command;
3. required acknowledgement;
4. mission/formation coordination;
5. ground-control report;
6. squadron/historical narrative.

`BROADCAST` blocks every Career Wingman priority. Switching to BROADCAST retains native-voice suppression, stops generated speech and starts historical playback.

## What IL-2 currently allows or exposes

### Confirmed or demonstrated externally

- External companion audio can play while IL-2 runs.
- A passive observer can see the configured radio hotkey without consuming it.
- Mission and forwarded telemetry data can support player and policy classification.
- Known nationality voice folders can be managed with conflict and recovery safeguards.
- Mission-authored Subtitle and Media MCUs can display prepared text and play prepared audio.

### Not exposed through a documented single-player runtime interface

- injection of a generated line into IL-2's internal radio engine;
- reliable notification of native voice playback start/end;
- dynamic native-radio recipient selection;
- rewriting active Career Subtitle/Media content after load;
- Career control through multiplayer DServer RCon;
- independent volume control for only IL-2 native voices while preserving other game sounds.

## Native suppression requirement and limitation

Full native suppression is the required Career Wingman model, not an optional future feature.

Suppression is applied once for the enhanced session, not around individual messages. This avoids repeated folder operations and gives the generated conversation clear precedence.

A controlled test must still determine whether IL-2 preloads or caches any native voice clips before suppression. If one preloaded clip can complete, document it as a startup-transition limitation. There should be no continuing native AI chatter after ownership is granted.

## Failure behaviour

Career Wingman fails silent if:

- the Radio Control service is unavailable;
- state is stale;
- player or mission identity is uncertain;
- the aircraft is verified as lacking usable radio equipment;
- BROADCAST is active;
- the player is dead/absent;
- policy returns `NO_TOUCH`;
- native suppression cannot be confirmed;
- the ownership lease is lost.

The flight must remain unaffected. Lease expiry restores the appropriate native folder policy.

## Test sequence

### AR-CW-01: adapter observation

Read current state through the version-independent adapter without modifying it.

### AR-CW-02: acquire enhanced combat channel

With a verified active player in COMBAT, request ownership. Confirm all managed native groups are suppressed before the lease is granted.

### AR-CW-03: conversation output

Play one test Career Wingman line only after suppression confirmation.

### AR-CW-04: broadcast takeover

Switch to BROADCAST during a queued/generated message. Confirm Career Wingman stops, native voices remain suppressed and only historical audio plays.

### AR-CW-05: return to enhanced combat

Confirm ownership is reacquired and no delayed narrative backlog is dumped.

### AR-CW-06: player lifecycle

Confirm dead/absent stops speech while suppression remains stable until orderly release or new-aircraft revalidation.

### AR-CW-07: uncertain mission

Reproduce `NO_TOUCH`; confirm ownership is not granted and Career Wingman remains silent.

### AR-CW-08: native-cache test

Acquire ownership at several mission phases and determine whether any already cached native clip can finish. Confirm no continuing native chatter.

### AR-CW-09: lease failure recovery

Terminate Career Wingman without releasing ownership. Confirm Radio Control detects lease expiry and restores the correct ordinary policy.

### AR-CW-10: future Radio compatibility

Run the same contract tests against later Allied Radio candidates without changing the conversation engine.

## Decision

Treat Allied Radio v6.2 as a valuable release candidate and evidence source, not the final dependency. Build a version-independent Radio Control adapter. During enhanced COMBAT, suppress every managed IL-2 native AI voice group and give Career Wingman exclusive ownership of radio conversation.

