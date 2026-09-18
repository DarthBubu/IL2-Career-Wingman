# Career Wingman End-to-End Technical Architecture

Date: 2026-09-18
Status: Recommended architecture after code inspection and source review

## Executive conclusion

The system is feasible as an external Windows companion, but not through one IL-2 interface. It requires a fused architecture that combines pre-mission files, forwarded telemetry, optional live mission-report logs, post-flight reconciliation and a separate exclusive radio-output service.

Do not place an AI model directly between raw telemetry and the speakers. Build a deterministic event/state layer first. The AI receives validated facts and returns constrained dialogue plans. Critical tactical calls use templates and cached speech; AI is reserved for controlled variation, character continuity and narrative conversation.

## Confirmed constraints

1. IL-2 mission-authored Subtitle and Media MCUs can display prepared text and play prepared audio.
2. No documented single-player interface was found for injecting arbitrary new text/audio into an already-loaded Career mission.
3. DServer Remote Console and chat facilities are multiplayer-server features, not ordinary single-player Career interfaces.
4. The existing Allied Radio candidate demonstrates external telemetry reception, player lifecycle classification, mission parsing, passive hotkeys and voice-folder management.
5. The public mlg2txt project states that binary `.mlg` data is normally finalized after mission completion, while text mission reports are written in chunks as the mission progresses. Our CW 0.1 probe must resolve whether current IL-2 builds expose any useful partial `.mlg` growth earlier.
6. An external Windows process can play speech alongside IL-2, but it is not audio injected into IL-2's internal radio engine.
7. Full native AI voice suppression is therefore required when Career Wingman owns the enhanced combat channel.

## Recommended runtime topology

```text
                         PRE-MISSION
  _gen.Mission ----+
  Career data -----+--> Mission Context Builder --> Entity/Formation Registry
  History dataset -+                                  |
  Squadron memory -+                                  v
                                               Authoritative World State
                                                        ^
                                                        |
                          IN-FLIGHT                     |
  Forwarded UDP ------> Telemetry Adapter --------------+
  text missionReport -> Log Tail Adapter ---------------+
  file lifecycle -----> Mission Lifecycle Adapter ------+
  user marks ---------> Test/Correction Adapter --------+
                                                        |
                                                        v
                                                Event Fusion Engine
                                                        |
                                                        v
                                             Conversation Director
                                          /             |              \
                              Tactical rules       AI planner      Memory selector
                                     \                |                /
                                      +------- Output Validator ------+
                                                        |
                                                        v
                                                Speech Scheduler
                                                        |
                                       +----------------+----------------+
                                       |                                 |
                                TTS/voice cache                   Text transcript
                                       |
                                       v
                              Radio Control + Audio Mixer
                                       |
                                       v
                               Windows/Quest audio output
```

## 1. Process boundaries

### Recommended first implementation

Use three cooperating local components:

1. **Radio Control Service**
   - evolves from proven Allied Radio mechanisms;
   - owns native voice suppression/restoration, broadcast playback, hotkeys, player lifecycle interlocks and channel leases;
   - runs independently so it can recover folders if another component crashes.

2. **Career Wingman Core**
   - owns mission ingestion, world state, event fusion, conversation, memory, validation and scheduling;
   - never manipulates IL-2 files except permitted read-only access;
   - communicates with Radio Control over localhost.

3. **Speech Worker**
   - isolates TTS model/runtime failures and heavy memory usage;
   - accepts structured synthesis jobs;
   - returns PCM/WAV data plus duration metadata;
   - can be restarted without losing the mission state.

The launcher starts and supervises all three. Later they may be combined only if testing shows no recovery or performance disadvantage.

### Inter-process transport

Use localhost HTTP for commands and WebSocket or Server-Sent Events for state changes in the first build. It matches the existing Radio approach and is easy to inspect.

Every message should include:

- schema version;
- session ID;
- monotonic sequence;
- UTC and monotonic timestamps;
- producer;
- correlation/event ID.

Bind only to `127.0.0.1`. Do not expose these services to the LAN.

## 2. Data acquisition

### A. Pre-mission `_gen.Mission` — primary identity source

Parse before cockpit entry and whenever the file is replaced.

Extract:

- mission date, time, map/theatre and weather when available;
- every aircraft block;
- object `Index` and `LinkTrId`;
- name, script/model, country and `AILevel`;
- `NumberInFormation`, callsign/code and formation links;
- player candidate;
- flight membership;
- escort/cover relationships when represented;
- mission objectives, routes and cooperating formations where parseable.

Do not identify the player by generated pilot name. Retain the current hardened rule: exactly one appropriate player candidate with `AILevel=0`, then correlate aircraft identity with telemetry.

Generate a mission fingerprint from stable mission fields. All live events must reference that fingerprint so events from an old sortie cannot leak into a new one.

### B. Career/squadron data — pre/post-flight memory source

Use a read-only snapshot or an export produced by the existing Career Tracker rather than allowing two projects to write directly to `cp.db`.

Preferred boundary:

```json
{
  "schema": "career-context/v1",
  "career_id": "...",
  "as_of": "...",
  "pilot": {},
  "squadron": {},
  "roster": [],
  "sorties": [],
  "confirmed_events": []
}
```

Career Tracker remains authoritative for confirmed career history. Career Wingman stores narrative memories separately and reconciles them after the official result is known.

### C. Forwarded UDP telemetry — continuous live state

Use the existing bridge work as a starting point, but treat every decoded field as empirical until documented or validated through controlled captures.

Suitable roles:

- detect telemetry health;
- player aircraft presence/activity;
- aircraft-session restart;
- continuous state changes exposed by the stream;
- correlate telemetry aircraft identity with the mission player;
- derive candidate phase transitions after debouncing.

Do not assume the stream identifies every AI aircraft or combat event. Maintain `UNKNOWN` rather than guessing.

### D. Text mission-report logs — preferred discrete live-event candidate

When IL-2 text mission logging is enabled, tail only complete appended records. These logs are described by community tooling as chunked during mission progress.

Requirements:

- remember byte offset and file identity;
- handle rotation/new chunks;
- parse only newline-complete records;
- tolerate partial writes;
- deduplicate by stable event fingerprint;
- map log object IDs to the mission entity registry;
- record raw provenance for replay.

This route must be validated with controlled missions before being promoted to a required source.

### E. Binary `.mlg` — fallback and experiment

The public mlg2txt documentation states that `.mlg` is generally written/finalized when the mission ends. Therefore:

- do not make live conversation depend on `.mlg`;
- continue CW 0.1 read/open/growth testing against the current game;
- if partial growth is proven, copy consistent snapshots before parsing;
- never parse the game's actively written file in a way that blocks IL-2;
- use post-flight conversion for reconciliation if live parsing is unreliable.

### F. User/test marks

Keep manual event marks in development builds. They provide ground-truth timestamps for comparing telemetry and log detection.

## 3. Entity and formation registry

Every participant receives a stable internal ID independent of displayed pilot name.

```json
{
  "entity_id": "missionFingerprint:planeIndex",
  "link_tr_id": 30027,
  "pilot_id": "career-pilot-id-or-null",
  "display_name": "Gary Fleming",
  "radio_callsign": "Red Two",
  "country": "GB",
  "aircraft_type": "Spitfire Mk IX",
  "flight_id": "red-flight",
  "formation_position": 2,
  "role": "wingman",
  "source_confidence": 1.0
}
```

Model flight, section and cooperating-flight relationships explicitly. Do not give eight pilots eight independent AI agents. They are characters governed by one conversation director and one radio channel.

## 4. Authoritative world state

Maintain current facts with provenance:

- mission phase;
- player state;
- participant state: active, uncertain, missing, landed or unavailable;
- last known position/state when exposed;
- flight membership and task;
- current commands and acknowledgements;
- detected threats/events;
- radio mode and channel ownership;
- recent transcript;
- uncertainty and data-source health.

A fact contains:

```text
value + source + confidence + observedAt + validUntil + confirmationClass
```

Confirmation classes:

- **CONFIRMED**: direct reliable source;
- **CORROBORATED**: multiple independent observations;
- **INFERRED**: rule-derived with stated confidence;
- **UNKNOWN**: insufficient evidence;
- **CONTRADICTED**: sources disagree.

Only CONFIRMED/CORROBORATED facts can drive high-consequence tactical statements. INFERRED facts may produce cautious wording such as a query, not a declaration.

## 5. Event fusion

Normalize raw inputs into versioned events:

```json
{
  "schema": "cw-event/v1",
  "event_id": "...",
  "mission_id": "...",
  "type": "FORMATION_MEMBER_MISSING",
  "occurred_monotonic_ms": 123456,
  "observed_utc": "...",
  "actors": ["red-3"],
  "confidence": 0.82,
  "confirmation": "INFERRED",
  "sources": ["udp", "mission-context"],
  "expires_ms": 8000,
  "dedupe_key": "missing:red-3"
}
```

Processing stages:

1. decode;
2. validate schema/range;
3. correlate entity;
4. debounce;
5. fuse corroborating observations;
6. assign confidence;
7. generate normalized event;
8. deduplicate/cool down;
9. persist for replay;
10. submit to conversation director.

## 6. Conversation architecture

### A. Tactical path — deterministic and low latency

Use doctrine-approved intents and short templates for:

- immediate warnings;
- break/turn/regroup commands;
- acknowledgement;
- position/status requests;
- formation changes;
- essential ground-control calls.

Do not wait for a remote AI model. Select a validated template, fill verified slots and play cached or pre-generated audio.

Target event-to-audio-start budget:

- urgent warning: under 300 ms after event confirmation;
- tactical command: under 700 ms;
- acknowledgement: under 1 second.

These are engineering targets, not claims about current performance.

### B. AI path — constrained and asynchronous

Use AI for:

- variation within an approved intent;
- character-specific phrasing;
- low-workload squadron conversation;
- references to confirmed previous sorties;
- historically scoped discussion;
- multi-turn narrative planning.

The model receives structured context, not raw files or unlimited memory. It must return JSON matching a strict schema.

Example:

```json
{
  "speak": true,
  "speaker_id": "red_leader",
  "recipient_scope": "flight",
  "intent": "regroup",
  "priority": 2,
  "text": "Red Section, reform on me.",
  "facts_used": ["evt-123", "mission-red-flight"],
  "requires_ack": true,
  "expires_ms": 5000
}
```

Reject and fall back to a template if:

- speaker or recipient does not exist;
- facts are unsupported;
- the line exceeds length;
- terminology violates selected doctrine/period;
- priority or authority is invalid;
- the output misses schema;
- response arrives after expiry.

### C. Historical knowledge gate

Historical records require:

- event date;
- earliest plausible awareness date;
- theatre and service;
- knowledge scope: public, command, unit or restricted;
- confidence/source;
- relevance tags.

A mission dated earlier than awareness must never retrieve that event. Historical retrieval happens before prompting; the model cannot browse freely during flight.

## 7. Radio doctrine engine

Create data packs by nationality, service, theatre and period rather than one universal WWII style.

Each pack defines:

- callsign patterns;
- brevity/phraseology;
- chain of command;
- acknowledgement expectations;
- allowable message intents;
- maximum length by urgency;
- ground-control vocabulary;
- prohibited anachronisms;
- uncertainty wording;
- language/accent/voice assignment.

The doctrine engine produces allowed intent + slots. The AI may phrase within those boundaries.

## 8. Native voice suppression and radio ownership

Career Wingman requests a renewable enhanced-channel lease from Radio Control.

Radio Control must:

1. validate the mission/player/radio policy;
2. atomically suppress every managed native AI voice group;
3. confirm resulting folder state;
4. grant the lease;
5. keep BROADCAST mutually exclusive with Career Wingman speech;
6. restore ordinary policy when the lease is released or expires;
7. recover on crash/reboot.

Career Wingman does not speak unless the lease and suppression confirmation are valid.

Test whether IL-2 caches a voice clip before suppression. One clip already loaded may be able to finish; ongoing native chatter after lease grant is a failure.

## 9. Speech synthesis

Use a provider-neutral Speech Worker API:

```json
{
  "job_id": "...",
  "speaker_voice_id": "raf_red_leader_01",
  "text": "...",
  "urgency": "tactical",
  "radio_profile": "raf_vhf_1944",
  "deadline_monotonic_ms": 123900
}
```

### Two-tier strategy

**Tier 1: pre-generated/cache**

- all urgent and common tactical lines;
- acknowledgements;
- player/formation callsign variants;
- common numbers/headings where safe;
- guaranteed low latency.

**Tier 2: runtime synthesis**

- narrative and uncommon contextual lines;
- generated asynchronously;
- discarded if its event expires;
- cached by hash of normalized text + voice + radio profile + synthesis version.

### Voice safety and consistency

- use licensed/synthetic voices;
- do not clone a real person's voice without permission;
- one stable voice per recurring character;
- normalize loudness;
- apply radio filtering after synthesis;
- return duration before scheduling when possible.

## 10. Audio engine

Use one Career Wingman output bus with:

- priority queue;
- one active transmission;
- preemption for urgent warnings;
- short start/end radio cues;
- band-limit/EQ/noise profile;
- loudness normalization;
- fade/cancel support;
- broadcast mutual exclusion;
- device selection and reconnect;
- per-transmission start/end logging.

Use Windows shared audio output so it follows the user's normal Quest/headset route. The engine cannot independently lower IL-2 native voices through Windows because IL-2 audio is one process/session; full native folder suppression solves that at the source.

## 11. Optional text/VR output

Text is a secondary synchronized transcript.

First options:

- desktop click-through overlay;
- local web status/transcript;
- OpenXR/OpenKneeboard integration after compatibility testing.

Text must obey the same visibility, recipient, radio-mode and expiry rules as audio.

## 12. Persistence

Use local SQLite with migrations.

Suggested tables:

- missions;
- entities;
- normalized_events;
- transmissions;
- official_career_facts;
- narrative_memories;
- relationships;
- historical_records;
- source_health;
- test_marks;
- configuration_versions.

Keep official facts and generated narrative memories separate. Every narrative memory stores originating transmission/event IDs.

## 13. Packaging and technology recommendation

### Core and Radio Control

Continue with Go for the Windows services because the existing bridge is Go, produces standalone executables and already handles Win32 hotkeys, HTTP, UDP and filesystem operations.

### Speech Worker

Keep it behind a process boundary. This permits:

- an embedded/offline engine packaged with its model;
- a cloud provider when configured;
- later engine replacement without changing the conversation core.

### Distribution

Provide one ZIP containing:

- launcher executable;
- Radio Control executable;
- Career Wingman Core executable;
- Speech Worker and licensed model assets;
- configuration/data directory;
- documentation;
- uninstall/restore function.

No administrator requirement unless a later feature proves it necessary. No DLL injection, process-memory access or modification of IL-2 executables.

## 14. Performance and reliability targets

Engineering targets:

| Function | Target |
|---|---:|
| UDP ingest and state update | <50 ms internal processing |
| Event fusion after input | <100 ms |
| Cached urgent speech start | <300 ms after confirmation |
| Tactical generated/template speech | <700 ms |
| Runtime narrative speech | 1–4 s acceptable |
| Radio state change enforcement | <500 ms, verified |
| Crash lease recovery | 3–8 s |
| Added steady CPU excluding synthesis | <2% of one modern desktop CPU average |
| Added RAM excluding TTS model | <250 MB |

Validate rather than promise these numbers.

## 15. Security and privacy

- localhost-only services;
- random per-install session token;
- reject non-local requests;
- no opening inbound firewall ports;
- read IL-2 inputs with shared read access;
- atomic and reversible folder transitions;
- store external API credentials in Windows credential storage, not config files;
- explicit opt-in before sending mission/pilot text to cloud AI/TTS;
- redact local Windows paths from exported diagnostics;
- never transmit raw telemetry unless required and disclosed.

## 16. Replay-first testing

Every live adapter writes a timestamped raw/normalized capture. The complete conversation engine must run offline against recorded sorties.

Benefits:

- repeatable development without launching IL-2;
- deterministic regression tests;
- comparison of detector versions;
- latency simulation;
- no risk to Career data;
- doctrine and conversation evaluation at scale.

Test layers:

1. parser fixtures;
2. event-fusion unit tests;
3. recorded-sortie replay;
4. synthetic eight-aircraft load;
5. radio lease/crash tests;
6. TTS deadline/cancellation tests;
7. controlled live sortie;
8. post-flight reconciliation.

## 17. Phased delivery plan

### CW 0.1A — current evidence capture

Prove timing and accessibility of `.mlg`, text logs, `_gen.Mission` and Career data. Preserve manual marks.

### CW 0.2 — context and replay foundation

- mission parser;
- mission fingerprint;
- entity/formation registry;
- normalized event schema;
- raw capture/replay format;
- no AI and no speech.

### CW 0.3 — Radio Control adapter

- capability negotiation;
- exclusive enhanced-channel lease;
- all-native-voice suppression;
- crash restoration;
- state-change subscription.

### CW 0.4 — deterministic speech proof

- one synthetic event;
- one cached voice;
- priority queue;
- COMBAT/BROADCAST/dead gating;
- timing and recovery logs.

### CW 0.5 — first real live event

- select one event proven by CW 0.1;
- map to one validated intent;
- replay test then live sortie test;
- no general AI generation.

### CW 0.6 — participant registry and exchanges

- player flight up to eight aircraft;
- speaker selection;
- acknowledgements;
- ground-control logical participant;
- synthetic escort/escorted fixtures before relying on live extraction.

### CW 0.7 — constrained AI narrative

- strict JSON output;
- fact citations;
- expiry and fallback;
- asynchronous narrative only;
- official-vs-narrative memory split.

### CW 0.8 — historical/doctrine packs

- researched RAF/USAAF/Luftwaffe packs by period/theatre;
- knowledge-scope gating;
- regression corpus for anachronism and command discipline.

### CW 0.9 — VR/text and hardening

- optional overlay;
- Quest 3 test;
- installer-free ZIP;
- resource/latency soak test;
- recovery and upgrade paths.

### CW 1.0 acceptance

- verified live events;
- exclusive generated combat channel;
- deterministic tactical calls;
- constrained narrative AI;
- persistent squadron continuity;
- post-flight reconciliation;
- reproducible test evidence.

## 18. Main risks and mitigations

| Risk | Mitigation |
|---|---|
| Live discrete events unavailable | Start with phase/state events; use text logs if proven; reconcile post-flight |
| UDP fields insufficient for AI entities | Use mission registry plus conservative UNKNOWN state; never invent |
| `.mlg` only finalizes after mission | Do not use it for live critical path |
| Native voices cached | Suppress before mission/aircraft activation where safe; test startup boundary |
| AI latency | templates/cached speech for tactical path |
| AI hallucination | strict schema, fact IDs, validator and fallback |
| Too much radio traffic | one director, priority queue, silence policy and cooldowns |
| Wrong historical knowledge | offline curated dataset with awareness dates/scopes |
| Project crash leaves voices disabled | leased ownership with independent watchdog restoration |
| Future Allied Radio changes | capability negotiation and version-independent adapter |

## 19. Go/no-go gates

1. **Event gate:** at least one useful in-flight event is detected reproducibly.
2. **Identity gate:** player and relevant flight entities are mapped without name guessing.
3. **Radio gate:** native voices remain suppressed and recover safely after crash.
4. **Latency gate:** cached tactical audio starts within the tested budget.
5. **Truth gate:** dialogue validator prevents unsupported facts.
6. **Replay gate:** the same capture produces deterministic normalized events.
7. **Resource gate:** no material impact on IL-2/VR frame timing.
8. **Usability gate:** user can run the packaged build without installing a development runtime.

If a gate fails, the project remains at that phase rather than adding AI complexity.

## Sources reviewed

- IL-2 Sturmovik Mission Editor and Multiplayer Server Manual: https://www.scribd.com/document/372123635/IL-2-Sturmovik-Mission-Editor-and-Multiplayer-Server-Manual
- mlg2txt source and documentation: https://github.com/Murleen/mlg2txt
- mlg2txt IL-2 forum announcement: https://forum.il2sturmovik.com/topic/37093-mlg2txt-a-mlg-log-to-text-converter/
- OpenKneeboard documentation: https://openkneeboard.com/
- Existing IL-2 Allied Radio v6.2 source and documentation inspected from the project build.

## Evidence limits

The exact semantic content of the forwarded UDP packets remains empirically decoded rather than fully documented in the reviewed sources. The availability and timing of current text mission logs and partial `.mlg` data must be established by CW 0.1 tests. Escort relationships, individual AI status and native voice caching must not be claimed until controlled captures prove them.

