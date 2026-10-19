-- Runs after audit capture; only completed transactions are scored.
DELIMITER $$
CREATE TRIGGER trg_transactions_ai_fraud_evaluate
AFTER INSERT ON Transactions
FOR EACH ROW FOLLOWS trg_transactions_ai_audit
BEGIN
  IF NEW.status='Completed' THEN
    CALL sp_evaluate_fraud(NEW.transaction_id);
  END IF;
END$$
DELIMITER ;
