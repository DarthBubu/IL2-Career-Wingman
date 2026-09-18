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

## Remaining CW 0.1A gates

- Career mission briefing/generation timing;
- cockpit spawn timing;
- active mission `.mlg` creation and growth behavior;
- in-flight changes correlated with controlled event marks;
- mission finish/debrief timing;
- post-flight reconciliation timing;
- actual `cp.db` location and change timing.
