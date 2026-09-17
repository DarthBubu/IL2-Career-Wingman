CW 0.1 CONTROLLED TEST
======================

Use one normal single-player Career mission. Start the probe before loading the
mission and make these marks as close as practical to the actual event:

  01 MISSION LOADING STARTED
  02 COCKPIT SPAWNED
  03 ENGINE STARTED
  04 TAKEOFF
  05 COMBAT STARTED
  06 PLAYER FIRED
  07 AIRCRAFT DESTROYED (if observed)
  08 PLAYER AIRCRAFT DAMAGED (if applicable)
  09 COMBAT ENDED
  10 LANDED
  11 MISSION FINISHED
  12 DEBRIEF OPENED
  13 DEBRIEF ACCEPTED

Do not alter normal gameplay merely to complete every optional mark. One clean
timeline is more useful than an artificially complicated sortie.

Pass criteria for CW 0.1A
-------------------------
[ ] .mlg creation time is captured.
[ ] Every .mlg size/write change is timestamped.
[ ] Active .mlg read-open status is captured.
[ ] _gen.Mission timing is captured if it exists under the selected root.
[ ] cp.db timing is captured if it exists under the selected root.
[ ] User marks can be correlated against changes with sub-second timestamps.
[ ] IL-2 completes the mission normally with the probe running.

