-- Basic contract smoke tests for required B fraud function interfaces.
SET @failures=0;
SELECT CASE WHEN fn_distance_km(0,0,0,1) BETWEEN 111 AND 112 THEN 'PASS' ELSE 'FAIL' END AS distance_km;
SELECT CASE WHEN fn_amount_zscore(150,100,25)=2 THEN 'PASS' ELSE 'FAIL' END AS amount_zscore;
SELECT CASE WHEN fn_is_odd_hour('2026-01-01 23:00:00')=1
                  AND fn_is_odd_hour('2026-01-01 12:00:00')=0 THEN 'PASS' ELSE 'FAIL' END AS odd_hour;
SELECT CASE WHEN fn_risk_level(20)='Low' AND fn_risk_level(40)='Medium'
                  AND fn_risk_level(70)='High' AND fn_risk_level(90)='Critical'
             THEN 'PASS' ELSE 'FAIL' END AS risk_level;
