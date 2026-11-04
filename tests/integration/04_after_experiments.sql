CALL sp_reconcile_balances(NULL);
SELECT CONCAT('TEST|',status,'|after experiments ',invariant,'|violations=',violations)
FROM JSON_TABLE(@reconcile_results,'$[*]' COLUMNS(invariant VARCHAR(4) PATH '$.invariant',violations BIGINT PATH '$.violations',status VARCHAR(4) PATH '$.status')) j ORDER BY invariant;
