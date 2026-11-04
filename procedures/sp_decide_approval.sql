DELIMITER $$
CREATE PROCEDURE sp_decide_approval(IN p_approval_id INT, IN p_decision VARCHAR(10), IN p_manager_employee_id INT, OUT p_transfer_group_id CHAR(36)) SQL SECURITY DEFINER
BEGIN
 DECLARE v_from INT; DECLARE v_to INT; DECLARE v_amount DECIMAL(14,2); DECLARE v_requester INT; DECLARE v_status VARCHAR(12); DECLARE v_debit BIGINT; DECLARE v_credit BIGINT;
 DECLARE v_errno INT;
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
  GET DIAGNOSTICS CONDITION 1 v_errno=MYSQL_ERRNO;
  ROLLBACK; SET p_transfer_group_id=NULL;
  IF v_errno IN (5003,5004,5005,5006,5010) THEN BEGIN
   DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; END;
   START TRANSACTION; CALL sp_internal_record_failed(v_from,v_amount,'TransferOut','Branch'); COMMIT;
  END; END IF;
  RESIGNAL;
 END;
 SET p_transfer_group_id=NULL;
 IF p_decision IS NULL OR p_decision NOT IN ('Approved','Rejected') THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5018,MESSAGE_TEXT='E_INVALID_ARGUMENT: invalid approval decision'; END IF;
 START TRANSACTION;
 IF p_approval_id IS NULL OR NOT EXISTS(SELECT 1 FROM Transaction_Approvals WHERE approval_id=p_approval_id) THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5007,MESSAGE_TEXT='E_INVALID_REFERENCE: approval does not exist'; END IF;
 SELECT from_account_id,to_account_id,amount,requested_by_employee_id,status INTO v_from,v_to,v_amount,v_requester,v_status FROM Transaction_Approvals WHERE approval_id=p_approval_id FOR UPDATE;
 IF v_status<>'Requested' THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5009,MESSAGE_TEXT='E_APPROVAL_STATE: request is already decided'; END IF;
 CALL sp_internal_assert_staff(p_manager_employee_id,v_from,'Manager');
 IF v_requester=p_manager_employee_id THEN SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO=5010,MESSAGE_TEXT='E_NOT_AUTHORIZED: requester cannot decide own request'; END IF;
 IF p_decision='Approved' THEN
  CALL sp_internal_post_transfer(v_from,v_to,v_amount,'Branch',p_manager_employee_id,NULL,NULL,0,1,p_transfer_group_id,v_debit,v_credit);
 END IF;
 UPDATE Transaction_Approvals SET status=p_decision,decided_by=p_manager_employee_id,decided_at=NOW(),resulting_transfer_group_id=p_transfer_group_id WHERE approval_id=p_approval_id;
 COMMIT;
END$$
DELIMITER ;
