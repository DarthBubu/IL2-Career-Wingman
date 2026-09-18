# CW 0.1 Controlled Test Results

Last updated: 2026-09-19 (Malaysia, UTC+08:00)

## Environment

- IL-2 data root: `Z:\SteamLibrary\steamapps\common\IL-2 Sturmovik Battle of Stalingrad\data`
- Probe polling interval: 500 ms
- Probe mode: read-only
- Capture timestamps include UTC, local time and monotonic elapsed milliseconds.

## Test 1 — Launcher and folder selection

Result: PASS

- PowerShell/WinForms probe launched through `Start_CW_0.1.cmd`.
- IL-2 data folder was selected successfully.

## Test 2 — Original closed-game baseline

Result: PASS WITH OPTIMIZATION REQUIRED

- 1,072 records captured.
- 1,069 existing historical `.mlg` files were classified as discovered/created baseline files.
- `_gen.Mission` detected at `data\Missions\_gen.Mission`.
- `_gen.Mission` size: 29,201,905 bytes.
- All sampled file opens returned `read-open=OK`.
- No ERROR or BLOCKED records.
- No file changes while IL-2 was closed.
- `cp.db` was not found at the monitored candidate paths.

Finding: baseline enumeration and UI logging of the complete historical FlightLogs archive took approximately 8.7 seconds and produced excessive output.

Corrections:

- limit the active historical baseline to the five newest `.mlg` candidates;
- classify already-existing files as `BASELINE`;
- do not classify an older candidate leaving the newest-five set as file removal.

Commits:

- `22b00f1ce265ec640f8b9a05e76b8578741fcf96`
- `2fcebdf4940aac219120ee9a851b497f946a263c`

## Test 3 — Optimized closed-game baseline

Result: PASS

- Nine total records:
  - one SESSION;
  - six BASELINE;
  - one USER_MARK;
  - one SESSION_END.
- Baseline consisted of the five newest `.mlg` files plus `_gen.Mission`.
- All six returned `read-open=OK`.
- No ERROR, BLOCKED, CHANGED, CREATED or false REMOVED events.
- Manual mark `OPTIMIZED BASELINE - IL2 CLOSED` recorded successfully.

## Test 4 — IL-2 launch to main menu

Result: PASS

Timeline:

- session began: 2026-09-19 02:29:12.931 +08:00;
- `BEFORE IL2 LAUNCH`: elapsed 13,142 ms;
- `IL2 MAIN MENU VISIBLE`: elapsed 150,897 ms;
- session ended: elapsed 159,082 ms.

Observed result:

- ten total records;
- six BASELINE records;
- two USER_MARK records;
- no CREATED, CHANGED or REMOVED records;
- no ERROR or BLOCKED records.

Conclusion: in this run, launching IL-2 and reaching the main menu did not modify `_gen.Mission` or create/change a monitored `.mlg`. Later activity can therefore be compared against Career mission selection and mission loading rather than ordinary application startup.

## Test 5 — Career mission generation/briefing

Result: PASS — PRE-MISSION CONTEXT AVAILABLE

Timeline:

- `IL2 MAIN MENU - BEFORE CAREER`: elapsed 2,826 ms;
- `_gen.Mission` changed: elapsed 70,068 ms;
- `CAREER MISSION BRIEFING VISIBLE`: elapsed 110,030 ms.

Observed file change:

- path: `data\Missions\_gen.Mission`;
- baseline size: 29,201,905 bytes;
- new size: 29,163,996 bytes;
- delta: -37,909 bytes;
- read access: `read-open=OK`.

No `.mlg` file was created or changed, and no ERROR or BLOCKED record occurred.

Conclusion: in this run, selecting/opening the Career mission caused `_gen.Mission` to be rewritten approximately 39.962 seconds before the user marked the briefing as fully visible. Mission context is therefore available for read-only preflight parsing before Start Mission is clicked.

## Test 6 — Start Mission to cockpit spawn

Result: PASS — NO ACTIVE MLG AT COCKPIT SPAWN

Timeline:

- `CAREER BRIEFING - BEFORE START MISSION`: elapsed 6,684 ms;
- `COCKPIT SPAWNED`: elapsed 41,353 ms;
- observed loading interval between marks: 34.669 seconds.

Observed result:

- no new `.mlg` appeared;
- none of the five existing `.mlg` candidates changed;
- `_gen.Mission` remained at 29,163,996 bytes;
- no ERROR or BLOCKED records occurred.

Conclusion: in this run, loading the mission and reaching the controllable cockpit did not create or modify a monitored `.mlg`. The Career-generated `_gen.Mission` was already stable from the briefing stage. This is evidence against treating `.mlg` as a mission-start live source, while supporting preflight parsing of `_gen.Mission`.

## Test 7 — Engine start, crash and debrief

Result: PASS — MLG CREATED BETWEEN CRASH AND DEBRIEF

Timeline:

- `COCKPIT - BEFORE ENGINE START`: elapsed 7,846 ms;
- `ENGINE STARTED`: elapsed 26,330 ms;
- `PLAYER AIRCRAFT CRASHED`: elapsed 111,510 ms;
- new `.mlg` detected: elapsed 119,049 ms;
- `DEBRIEF VISIBLE AFTER CRASH`: elapsed 139,482 ms.

New file:

- path: `data\FlightLogs\missionReport(2026-09-19_02-37-46).mlg`;
- initial observed size: 16,931 bytes;
- read access: `read-open=OK`.

No ERROR or BLOCKED record occurred.

Measured boundaries:

- the `.mlg` was detected 7.539 seconds after the crash mark;
- it was detected 20.433 seconds before the debrief-visible mark;
- no `.mlg` existed through cockpit spawn or engine start in the preceding captures.

Evidence limit: the exact moment the user clicked Finish Mission was not separately marked. This run proves only that the file was created between the crash mark and the debrief-visible mark. It does not by itself distinguish impact handling from mission finalization as the trigger.

## Test 8 — Active mission idle interval and normal Finish Mission

Result: PASS — MLG CREATED AFTER FINISH-MISSION BOUNDARY

Timeline:

- `MISSION ACTIVE - PARKED`: elapsed 3,315 ms;
- `MISSION ACTIVE 60 SECONDS`: elapsed 112,454 ms;
- `PAUSE MENU - BEFORE FINISH MISSION`: elapsed 146,474 ms;
- new `.mlg` detected: elapsed 155,561 ms;
- `DEBRIEF VISIBLE - NORMAL FINISH`: elapsed 169,565 ms.

New file:

- path: `data\FlightLogs\missionReport(2026-09-19_02-45-32).mlg`;
- initial observed size: 16,083 bytes;
- read access: `read-open=OK`.

Observed result:

- no monitored file creation or change occurred during the active parked interval;
- the first and only activity record was creation of the new `.mlg`;
- the `.mlg` was detected 9.087 seconds after the pause-menu/before-Finish-Mission mark;
- it was detected 13.478 seconds before the debrief-visible mark;
- no ERROR or BLOCKED record occurred.

Conclusion: this controlled normal-exit run resolves the ambiguity remaining after Test 7. The monitored `.mlg` was absent throughout the active mission interval and appeared only after the explicit pre-Finish-Mission boundary. For this Career mission, `.mlg` behaves as a mission-finalization/post-flight artifact, not as a continuously available in-flight event stream. It remains suitable for post-flight reconciliation but cannot be the sole source for live dynamic radio reactions.

Evidence limit: the mark was placed immediately before the user clicked Finish Mission, rather than being generated by interception of the UI click. Therefore the measurement establishes the user-controlled before/after boundary, with human interaction latency included.

## Test 9 — Decoded MLG content inspection

Result: PASS — POST-FLIGHT IDENTITY AND EVENT RECONCILIATION IS VIABLE

Input:

- five decoded text segments from `missionReport(2026-09-19_02-45-32).mlg`;
- 222 records in total;
- segment record counts: 60, 10, 4, 15 and 133.

Observed record types:

- mission metadata (`AType:0`), including mission date/time and `Missions\_gen.msnbin`;
- user identity (`AType:20`);
- group membership and leader relationships (`AType:11`);
- object/pilot identity records (`AType:12`);
- player/aircraft records (`AType:10`);
- takeoff events (`AType:5`);
- end-state aircraft records (`AType:4`);
- player bot disposal/end record (`AType:16`);
- mission-end marker (`AType:7`);
- coalition/battle-state and spatial records (`AType:9`, `AType:13`, `AType:14`).

Confirmed player mapping:

- career pilot: `Jack Freeman`;
- account name: `AcesDarthBubu`;
- aircraft: `Spitfire Mk.IXc`;
- aircraft ID: `1374207`;
- pilot/bot ID: `1375231`;
- country: `102`;
- formation position: `7`;
- player flag: `ISPL:1`;
- starting bullets: `1680`;
- final recorded bullets: `1680`.

Confirmed flight structure:

- the player belonged to group `1390591`;
- the group contained eight Spitfire aircraft IDs;
- leader ID: `1254399`, mapped to Darwin Lenz;
- named flight members and formation positions were recoverable for all eight aircraft.

Event observations:

- takeoff records were present for six friendly Spitfire aircraft before mission termination;
- the player had no takeoff record and the final player position remained essentially at the starting location;
- no shot, hit, damage, kill or landing record types appeared;
- unchanged player ammunition corroborates that no player weapon fire occurred;
- the mission-end sequence contains the player's end-state record, bot disposal, and `AType:7`.

Conclusion: decoded `.mlg` content can support authoritative post-flight reconciliation of player identity, aircraft, flight membership, leader/wingman relationships, selected event history and final state. The absence of combat records in this file is consistent with the controlled parked mission and is not evidence that such record types are unavailable. Combined with Test 8, this source is valuable after mission finalization but cannot drive live radio during the same sortie.

Engineering consequence: CW should join preflight `_gen.Mission` identities with post-flight decoded `.mlg` identities using aircraft/pilot/group relationships, while obtaining live triggers from a separate source.

## Test 10 — startup.cfg capability inspection

Result: PASS — TEXT REPORT AND LOCAL UDP OUTPUTS ALREADY ENABLED

Confirmed settings:

- `[system] mission_text_log = 1`;
- `text_log_folder = ""` and `bin_log_folder = ""`, so no custom output folder is configured;
- `keep_binary_log = 0`;
- `chatlog = 0` and `gamelog = 0`;
- `[telemetrydevice] enable = true`, address `127.0.0.1`, port `24321`, decimation `1`;
- `[motiondevice] enable = true`, address `127.0.0.1`, port `24321`, decimation `1`;
- `[track_record] tacviewrecord = 1`.

Conclusion: the game's text mission-report output is already enabled, and the five numbered text files inspected in Test 9 are candidate live segments that the previous probe did not monitor. Local telemetry and motion output are also configured, but packet content and suitability for gameplay-event inference remain unproven.

Action:

- extended the probe to monitor the ten newest `missionReport*.txt` files alongside `.mlg`;
- retained read-only operation and 500 ms polling;
- updated historical-candidate handling to avoid false removals for text reports.

Implementation commit: `745b6129fed7e8285970d0443864a4854dd02977`.

## Remaining CW 0.1A gates

- Career mission briefing/generation timing;
- cockpit spawn timing;
- live in-flight event-source alternatives to finalized `.mlg`;
- in-flight changes correlated with controlled event marks from a live-capable source;
- post-finish `.mlg` content extraction and reconciliation;
- post-flight reconciliation timing;
- actual `cp.db` location and change timing.
