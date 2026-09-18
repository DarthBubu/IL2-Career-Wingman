# Career Wingman — Limited or Missing Live Data Strategy

Date: 2026-09-18  
Status: Approved contingency architecture

## Conclusion

Career Wingman does not have to be cancelled if IL-2 exposes insufficient live data. It can degrade through explicit capability modes while retaining preflight mission awareness, historical continuity, radio discipline and external speech.

The system must never present an inferred or scripted event as directly observed. Every line is governed by the current capability mode and evidence class.

## Capability modes

### Mode A — Event-reactive

Inputs:

- mission context;
- reliable live telemetry;
- reliable discrete live events;
- post-flight reconciliation.

Features:

- verified event-triggered tactical calls;
- dynamic formation status;
- context-aware ground control;
- narrative dialogue;
- Career continuity.

This remains the ideal mode.

### Mode B — State-reactive

Inputs:

- mission context;
- limited continuous player state;
- mission lifecycle;
- no reliable per-aircraft combat event stream.

Features:

- mission-phase radio;
- player-state-sensitive dialogue;
- timed check-ins;
- formation doctrine and acknowledgements;
- cautious contact/status prompts;
- narrative conversation.

Restrictions:

- no declaration that a specific AI aircraft was damaged, destroyed or missing unless confirmed;
- no exact enemy count or position without evidence;
- no claim that an escort has completed an action unless confirmed.

### Mode C — Mission-scripted procedural radio

Inputs:

- preflight `_gen.Mission`;
- Career Tracker history;
- elapsed mission time;
- player hotkeys/manual reports;
- mission start/end detection.

At mission load, Career Wingman creates a radio plan from:

- flight composition;
- mission type;
- route and objectives when parseable;
- expected mission phases;
- historical doctrine;
- recurring squadron characters.

The runtime director uses phase windows, probability, cooldowns and player acknowledgements to schedule plausible traffic. Lines describe orders, intentions, checks and uncertainty rather than claiming unseen outcomes.

Examples of safe intents:

- radio check;
- formation check;
- fuel/status request;
- leader instruction;
- acknowledgment;
- controller handoff;
- lookout reminder;
- weather/navigation observation derived from mission context;
- low-workload historical/squadron conversation;
- player-requested report.

Unsafe without evidence:

- “I shot him down”;
- “Red Three is dead”;
- “Six fighters at two o'clock”;
- exact damage or kill claims;
- exact escort success/failure.

### Mode D — Player-mediated radio RPG

Inputs:

- mission context;
- player hotkeys, buttons or optional voice commands;
- Career history;
- mission clock.

The player reports the meaningful event, and Career Wingman responds within that declared context.

Example controls:

- Contact spotted
- Engaging
- Under attack
- Wingman check
- Reform
- Return to base
- Target destroyed/claim victory
- Damaged
- Abort
- Landing

The event is stored as `PLAYER_REPORTED`, not game-confirmed. Post-flight data may later confirm, reject or leave it unresolved.

This mode can provide the strongest interaction when automatic extraction is weak.

### Mode E — Briefing/debriefing companion

Inputs:

- preflight mission context;
- post-flight logs/results;
- Career Tracker history.

Features:

- spoken mission briefing;
- pilot introductions;
- historical context available on the mission date;
- expected radio plan;
- post-flight reconstruction;
- squadron reactions;
- persistent relationships and character development;
- next-mission continuity.

There is little or no event-reactive speech during flight, but the project still adds a substantial Career RPG layer.

## Recommended hybrid fallback

If testing shows weak live data, adopt a combination of Modes C, D and E:

1. generate a mission-aware procedural radio plan before takeoff;
2. use mission lifecycle and any safe player-state signals to advance broad phases;
3. accept simple player reports through existing global-hotkey infrastructure;
4. produce dynamic conversation from mission context and player-reported events;
5. reconcile factual outcomes after landing;
6. update Career memories only from confirmed post-flight results.

This avoids dependence on an unavailable IL-2 interface while retaining most of the intended experience.

## Phase director

Use broad phases rather than pretending to track precise tactical state:

- PRESTART;
- STARTUP;
- TAXI/DEPARTURE;
- CLIMB;
- EN_ROUTE;
- APPROACH_OBJECTIVE;
- EXPECTED_COMBAT_WINDOW;
- EGRESS;
- RETURN;
- LANDING;
- POSTFLIGHT.

Transitions use available evidence in order:

1. direct live observation;
2. correlated limited state;
3. mission timer/route estimate;
4. player declaration;
5. manual phase selection.

The selected basis is recorded in diagnostics.

## Procedural radio planning

At mission load, produce a graph of allowed radio beats rather than a fixed audio script.

A beat contains:

```json
{
  "intent": "formation_check",
  "allowed_phases": ["CLIMB", "EN_ROUTE"],
  "speaker_roles": ["leader"],
  "recipient_scope": "flight",
  "earliest_seconds": 120,
  "cooldown_seconds": 600,
  "requires_fact": null,
  "claims_observation": false,
  "priority": 1
}
```

The director selects beats using:

- mission phase;
- recent channel usage;
- workload estimate;
- character relationships;
- doctrine;
- repetition history;
- random seed stored for replay.

The language model may phrase an approved beat but may not invent observations.

## Player interaction options

### Minimum viable: global hotkeys

Reuse the companion/global-hotkey capability. Provide a small number of configurable commands and optional two-step menus.

Advantages:

- lowest technical risk;
- works in VR;
- no microphone or speech-recognition dependency;
- deterministic intent.

### Optional voice commands

A push-to-talk speech-to-text adapter can translate the player's own radio call into one of a constrained set of intents. It must not accept arbitrary speech as confirmed game truth.

Recommended processing:

1. push-to-talk;
2. speech recognition;
3. constrained intent classification;
4. confirmation for high-impact claims;
5. emit `PLAYER_REPORTED` event;
6. generate acknowledgement/response.

This is optional and later than hotkeys.

## TTS in fallback modes

TTS remains valuable even with no live game data:

- preflight briefing and pilot introductions;
- mission-phase calls;
- responses to player commands;
- recurring character dialogue;
- historical and squadron conversation;
- post-flight narrative.

Urgent calls still use local clips. Dynamic responses may use streaming TTS. The lack of telemetry affects what may be said, not the speech-rendering architecture.

## Post-flight reconciliation

After the mission:

1. parse finalized logs/results;
2. match them against player-reported and inferred events;
3. mark each event CONFIRMED, CONTRADICTED or UNRESOLVED;
4. create factual Career memories only from confirmed results;
5. retain contradicted/unresolved reports only as claims or character perspective;
6. generate the debrief narrative from the reconciled record.

This protects long-term continuity from accumulating invented facts.

## Product viability by data level

| Available data | Viable product | Relative fidelity |
|---|---|---:|
| Rich live events | Full event-reactive wingman | Highest |
| Limited player state | Phase/state-reactive radio | High |
| Preflight plus lifecycle | Procedural mission-aware radio | Moderate–high |
| Preflight plus player input | Interactive radio RPG | High player agency |
| Pre/postflight only | Briefing/debriefing Career companion | Moderate |
| No mission files or results | Generic radio player only | Below Career Wingman scope |

## Revised go/no-go rule

The project only loses its core identity if neither mission context nor post-flight Career results can be accessed.

Missing live events is not a stop condition. It triggers a product-mode change:

- automatic event detection becomes optional;
- player-mediated and phase-directed interaction becomes primary;
- factual language becomes more conservative;
- post-flight reconciliation becomes mandatory.

## Recommended decision

Continue CW 0.1 testing because richer data improves the product. In parallel, design the first vertical slice so it can run from either:

- a verified automatic event; or
- the equivalent player-reported hotkey event.

This dual-input approach prevents the entire project from depending on an unproven IL-2 live-event feed.
