# Career Wingman Dynamic Air-Combat Conversation System

Date: 2026-09-18
Status: Core product vision

## Product definition

Career Wingman is a real-time narrative and radio-conversation layer for IL-2 Great Battles single-player Career mode.

It is not a collection of fixed event-to-audio responses. The system interprets mission context, real-time flight events, squadron history and selected historical context, then conducts a disciplined multi-participant air-combat conversation appropriate to the situation.

The normal cast may include:

- player pilot;
- flight leader and deputy;
- up to eight aircraft in the player's flight or formation;
- ground controller or sector operations;
- escorted bomber or attack formations;
- escorting fighter formations;
- nearby friendly flights when operationally relevant.

## Core design principle

The language model must not freely improvise the battle. It receives a controlled, validated world state and may only speak for participants who are permitted to transmit about facts they could reasonably know.

## Information pipeline

```text
Pre-mission sources                         Live sources
-------------------                         ------------
Mission file and briefing                   Flight logs / telemetry
Player and flight roster                    Aircraft state changes
Career and squadron history                 Position and formation events
Historical date and theatre                 Combat and mission events
Previous sorties and relationships          Player commands / acknowledgements
              |                                      |
              +------------------+-------------------+
                                 v
                       Normalized world state
                                 |
                                 v
                     Radio conversation director
                                 |
              +------------------+------------------+
              |                  |                  |
         Doctrine/rules      Dialogue planner   Safety/validation
              |                  |                  |
              +------------------+------------------+
                                 v
                       Text and speech output
```

## Pre-mission context assembly

Before flight, the companion should build a mission context package containing only verified facts:

- mission date, time, theatre and weather;
- mission type and objective;
- player identity, rank, aircraft and formation position;
- flight members, aircraft types, callsigns and formation relationships;
- escort, escorted and cooperating formations;
- known enemy briefing information;
- previous sortie outcomes;
- squadron losses, victories, promotions and replacements;
- unresolved interpersonal or operational story threads;
- historically relevant events available to the squadron at that date.

Historical information must be tagged by knowledge scope. A pilot must not discuss events that occurred later, remained secret, or would not reasonably be known to the unit.

## Live event processing

Raw observations must be converted into normalized events before they reach the dialogue system. Example categories:

- mission phase changed;
- engine start, taxi, takeoff and formation join;
- formation member separated or rejoined;
- enemy sighting or threat warning;
- engagement started or ended;
- attack, defensive break or regroup instruction;
- aircraft damaged, missing, returning or forced to withdraw;
- escort formation endangered or objective reached;
- ammunition/fuel concern when actually observable;
- landing sequence and post-action acknowledgement.

Each event requires:

- timestamp;
- source;
- confidence level;
- involved entities;
- location/mission phase when available;
- whether it is confirmed, inferred or unknown;
- expiry time;
- duplicate/cooldown key.

## Conversation director

The conversation director decides whether anyone should speak. Silence is a valid and often preferable outcome.

For every potential transmission it determines:

1. Is the event sufficiently reliable?
2. Who observed it?
3. Who is authorized or expected to speak?
4. Who needs the information?
5. What is the appropriate priority?
6. Does another transmission already occupy the channel?
7. Is acknowledgement required?
8. Should the response be procedural, tactical, informational or personal?
9. Can the line be expressed briefly enough for combat conditions?

## Radio priorities

Suggested internal priorities:

1. immediate threat or collision warning;
2. direct tactical command;
3. essential acknowledgement;
4. formation and mission coordination;
5. status report;
6. ground-control information;
7. historical or squadron-context dialogue;
8. low-priority character conversation.

Higher-priority traffic may suppress or interrupt lower-priority dialogue. Personal and historical conversation should normally occur during low-workload mission phases.

## Dialogue generation contract

The language model should receive a compact structured prompt containing:

- immutable mission facts;
- current world state;
- recent radio transcript;
- permitted speakers and recipients;
- speaker rank, role and personality traits;
- relevant doctrine and phraseology rules;
- known squadron memories;
- event requiring consideration;
- maximum word count and urgency;
- facts that must not be invented.

The model should return structured output rather than unconstrained prose:

```json
{
  "speak": true,
  "speaker_id": "flight_leader",
  "recipient_scope": "flight",
  "priority": "tactical_command",
  "intent": "regroup",
  "text": "Red Section, reform on me.",
  "requires_acknowledgement": true,
  "expires_ms": 5000
}
```

A validator must reject output that:

- names nonexistent aircraft or pilots;
- contradicts confirmed mission state;
- uses knowledge unavailable to the speaker;
- violates chain of command or recipient scope;
- contains anachronistic terminology;
- is too long for the situation;
- duplicates recent traffic;
- reports an inferred event as certain.

## Multi-participant state

Each participant needs a persistent runtime record:

- stable pilot/formation identifier;
- callsign and radio label;
- rank and operational role;
- parent flight and formation position;
- aircraft type and current known status;
- who can hear the transmission;
- current task;
- last confirmed location/state;
- last transmission time;
- outstanding command or acknowledgement;
- relationship and squadron-memory references.

The system should simulate one shared radio network with channel arbitration, not eight independent chatbots speaking at once.

## Historical and squadron memory

Memory should be divided into:

- **official record:** missions, results, losses, promotions and roster changes;
- **operational memory:** repeated tactical situations and previous orders;
- **relationship memory:** trust, rivalry, mentorship and shared experiences;
- **historical context:** verified period events constrained by date, theatre and knowledge scope.

Generated dialogue must never rewrite the official record. New narrative memory should be stored as a separate attributed layer with provenance.

## Output strategy

Initial implementation:

- external audio as the primary channel;
- optional text transcript/overlay;
- deterministic voice assignment per participant;
- radio filter and channel sounds applied externally;
- transmission queue with priority, interruption and cooldown control.

Native IL-2 chat/subtitle injection is not required for the first functional version.

## Phased implementation

### Phase CW 0.x — observation and proof

- establish which events can be detected before and during a Career mission;
- prove independent audio and overlay output;
- measure event-to-output latency;
- build replayable event fixtures for development.

### Phase CW 1.0 — deterministic radio director

- fixed doctrine-compliant message templates;
- participant registry and radio queue;
- high-confidence mission-phase and combat events;
- no free AI generation in safety-critical tactical calls.

### Phase CW 1.5 — constrained AI dialogue

- AI paraphrasing inside validated intents;
- squadron relationships and recent mission memory;
- historical context during suitable mission phases;
- structured output validation and automatic fallback templates.

### Phase CW 2.0 — continuing squadron narrative

- persistent character development;
- multi-sortie story threads;
- coordinated conversations involving flight, control, escort and escorted units;
- post-mission memory reconciliation against confirmed game results.

## Immediate research requirements

1. Document nationality-, service-, theatre- and period-specific radio procedures.
2. Identify which participants and formation relationships can be extracted from `_gen.Mission` before launch.
3. Determine which live events can be confirmed during flight.
4. Establish a knowledge-scope model for historically accurate dialogue.
5. Define latency limits for threat, tactical, acknowledgement and narrative messages.
6. Test overlapping transmissions and priority interruption with up to eight aircraft plus control and cooperating flights.

## Current decision

Build a central conversation director around a validated event/state model. Use AI only after participant identity, event confidence, radio priority and historical knowledge scope have been established. The AI is a constrained dialogue renderer and narrative planner, not the source of truth about the sortie.
