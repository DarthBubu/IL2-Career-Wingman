IL-2 CAREER WINGMAN — CW 0.1 FLIGHTLOG PROBE
================================================

Purpose
-------
This instrumentation build measures exactly when IL-2 creates or changes:

  * FlightLogs\*.mlg
  * _gen.Mission
  * cp.db

It does not interpret combat events yet. It establishes whether useful mission
data reaches disk during flight, after landing, or only after debrief.

Requirements
------------
Windows 10 or Windows 11. No installation or extra runtime is required.
The launcher uses Windows PowerShell and WinForms already included with Windows.

How to use
----------
1. Extract the complete ZIP to a normal folder.
2. Double-click Start_CW_0.1.cmd.
3. Choose the IL-2 data folder containing FlightLogs. Common installations use
   a path ending in IL-2 Sturmovik Battle of Stalingrad\data.
4. Click Start capture before starting/loading a Career mission.
5. While flying, type a short note and click Mark event immediately after each
   controlled test action (mission loaded, takeoff, combat begins, aircraft
   damaged/destroyed, landing, mission ends, debrief opened).
6. Click Stop capture after the debrief screen.
7. Send back the newest folder inside Captures. Its events.jsonl file contains
   timestamps, file sizes, byte deltas and read-open results.

What the results mean
---------------------
Repeated CHANGED rows for an .mlg during flight prove that IL-2 is flushing data
before mission completion. "read-open=OK" proves the active file can be opened
read-only with file sharing enabled; it does not yet prove incomplete data can
be converted by mlg2txt.

Safety and privacy
------------------
The probe opens watched files read-only and never changes IL-2 files. It does
not use the internet, administrator rights, a Windows service, DLL injection,
process memory access, registry writes, or telemetry ports. It writes only to
its own Captures folder. Paths in the log can reveal the Windows account/folder
name, so review the log before sharing it publicly.

Known CW 0.1 limitation
-----------------------
This build intentionally does not bundle or run mlg2txt. First we must prove
when .mlg files grow and whether Windows permits read access while IL-2 writes.
Conversion of safe snapshots belongs in CW 0.1B after this timing test.

