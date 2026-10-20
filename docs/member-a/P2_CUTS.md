# P2 / cut items

Part B is NOT IMPLEMENTED in Prompt 6 because P1 cannot pass whole-system integration while B runtime/security and the required Quick entry point are unavailable. No Berka data, PaySim or synthetic fraud behavior generator is added.

To finish Berka dimensions after P1 passes: verify source/licensing with the team; obtain files privately; add the five staging tables, explicit client/server local_infile checks, delimiter/date/birth-number validation, OWNER-only disposition mapping, synthetic names/emails/proofs, idempotent natural keys, correct loan owner/disbursement links and positive opening Deposit rows. Restrict run_load to scratch unless explicitly forced; preserve guards and restore A audits/watermark in finally; do not remove a B dependent fraud trigger without B handling its lifecycle. First test empty staging and malformed rows, then real data plus all six invariants. No loader syntax or data run is claimed today.

Binary Review 1 updates are deferred: originals are missing, so exact slide/page numbers cannot be supplied. Obtain the final DOCX/PPTX, apply CORRECTIONS_A.md, render/review copies under docs/review1/updated and retain originals. Workbench GUI execution is also pending manual verification.

Real crash/restart and elevated local-binlog PITR remain explicit manual demonstrations under the Prompt 5 runbooks. A process crash is not an OS/power-loss experiment. No administrative action was executed in Prompt 6.

Quick integration needs an owner-authorized change to experiments/run_all_auto.ps1 (outside this Prompt 6 path scope): declare a real Quick parameter, use bounded driver parameters, select Integrated when real B components exist, retain new evidence without overwriting historical reports and assert invariants afterward. Do not silently pass unsupported switches or replace this requirement with a full benchmark grid.
