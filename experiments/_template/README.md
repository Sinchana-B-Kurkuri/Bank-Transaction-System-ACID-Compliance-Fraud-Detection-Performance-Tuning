# Experiment template

HYPOTHESIS — not yet measured. Record purpose, prerequisites and expected result before execution.

Manual: (1) t+0 SELECT VERSION(),NOW(6),CONNECTION_ID() in both windows; (2) source setup.sql in both; (3) A t+0, B t+1; (4) save raw output/screenshots with visible version/time; (5) rollback and source teardown.sql.

Automated: adapt the independent Start-MySqlSession/Wait-Sessions driver in lib/Run-Experiment.ps1; never mark a sequential simulation as a concurrent run.
