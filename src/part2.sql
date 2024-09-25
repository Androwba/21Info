CREATE OR REPLACE PROCEDURE add_p2p_check(
    IN p_checked_peer VARCHAR(30),
    IN p_checker_peer VARCHAR(30),
    IN p_task_name VARCHAR(30),
    IN p_p2p_check_status CheckStatus,
    IN p_p2p_time TIME
) AS $$
DECLARE
    p_check_id INT;
BEGIN
    IF p_p2p_check_status = 'Start' THEN
        INSERT INTO Checks (ID, Peer, Task, CheckDate)
        VALUES ((SELECT COALESCE(MAX(ID), 0) + 1 FROM Checks), p_checked_peer, p_task_name, CURRENT_DATE)
        RETURNING ID INTO p_check_id;
    ELSE
        -- Get the check ID for the unfinished P2P step
        SELECT CheckID INTO p_check_id
        FROM P2P
        WHERE CheckingPeer = p_checker_peer
            AND P2PCheckStatus = 'Start'
            AND NOT EXISTS (
                SELECT 1
                FROM P2P p2
                WHERE p2.CheckID = P2P.CheckID
                    AND p2.CheckingPeer = p_checker_peer
                    AND p2.P2PCheckStatus IN ('Success', 'Failure')
            );
        IF p_check_id IS NULL THEN
            RAISE EXCEPTION 'No check with status "Start" found for % and %', p_checker_peer, p_task_name;
            RETURN;
        END IF;
    END IF;
    INSERT INTO P2P (ID, CheckID, CheckingPeer, P2PCheckStatus, Time)
    VALUES ((SELECT COALESCE(MAX(ID), 0) + 1 FROM P2P), p_check_id, p_checker_peer, p_p2p_check_status, p_p2p_time);
END;
$$ LANGUAGE plpgsql;

-- ---------------------Tests-----------------------------

-- P2P check with start status
CALL add_p2p_check('Margaret', 'Katherine', 'C3_s21_string+', 'Start', '10:00:00');

-- Success or Failure P2P step
CALL add_p2p_check('Margaret', 'Katherine', 'C3_s21_string+', 'Success', '10:30:00');
CALL add_p2p_check('Margaret', 'Katherine', 'C3_s21_string+', 'Failure', '11:00:00');

-- Start status
CALL add_p2p_check('Elizabeth', 'Charlie', 'C2_SimpleBashUtils', 'Start', '14:00:00');

CALL add_p2p_check('Elizabeth', 'Charlie', 'C2_SimpleBashUtils', 'Success', '15:00:00');
CALL add_p2p_check('Elizabeth', 'Charlie', 'C2_SimpleBashUtils', 'Failure', '15:30:00');

-- Start a check
CALL add_p2p_check('William', 'Katherine', 'C8_3DViewer_v1.0', 'Start', '09:00:00');
CALL add_p2p_check('William', 'Katherine', 'C8_3DViewer_v1.0', 'Success', '09:00:00');

-- Finish the check without a Start status and get an EXCEPTION
CALL add_p2p_check('William', 'Katherine', 'C8_3DViewer_v1.0', 'Success', '09:00:00');

SELECT * FROM Checks;
SELECT * FROM P2P;

-- 2 --

CREATE OR REPLACE PROCEDURE add_verter_check(
    IN checking_p VARCHAR(30),
    IN task_name TEXT,
    IN verter_state CheckStatus,
    IN verter_time TIME
) AS $$
DECLARE
    check_ID INT;
BEGIN
    SELECT Checks.id
    INTO check_ID
    FROM P2P
    JOIN Checks ON P2P.checkid = Checks.id
    WHERE P2P.p2pcheckstatus = 'Success'
        AND Checks.peer = checking_p
        AND Checks.task = task_name
    ORDER BY time DESC
    LIMIT 1;
    IF check_ID IS NULL THEN
        RAISE EXCEPTION 'No successful check found for peer % and task %', checking_p, task_name;
    END IF;

    INSERT INTO Verter (CheckID, VerterCheckStatus, Time)
    VALUES (check_id, verter_state, verter_time);
END;
$$ LANGUAGE plpgsql;

 -----Tests-----------------------------

-- Start Verter check
CALL add_verter_check('William', 'C3_s21_string+', 'Start', '10:30:00');
CALL add_verter_check('William', 'C3_s21_string+', 'Success', '10:32:00');
-- Success or Failure
CALL add_verter_check('William', 'C3_s21_string+', 'Failure', '10:33:00');

CALL add_verter_check('Katherine', 'C2_SimpleBashUtils', 'Start', CURRENT_TIME::TIME(0));

CALL add_verter_check('Katherine', 'C2_SimpleBashUtils', 'Success', CURRENT_TIME::TIME(0));
CALL add_verter_check('Katherine', 'C2_SimpleBashUtils', 'Failure', CURRENT_TIME::TIME(0));

-- Failed p2p record
CALL add_verter_check('Margaret', 'C2_SimpleBashUtils', 'Start', '10:30:00');

-- Fail to add a Verter check since task does not have any successful P2P checks
CALL add_verter_check('William', 'A1_Maze', 'Success', '10:00:00');

SELECT * FROM Verter;

-- 3 --

CREATE OR REPLACE FUNCTION update_transferred_points()
RETURNS TRIGGER AS $$
DECLARE
    p_checked_peer VARCHAR(30);
BEGIN
    p_checked_peer = (
        SELECT Peer
        FROM Checks
        WHERE ID = NEW.CheckID
    );
    UPDATE TransferredPoints
    SET PointsAmount = PointsAmount + 1
    WHERE CheckingPeer = NEW.CheckingPeer
        AND CheckedPeer = p_checked_peer;
    IF NOT FOUND THEN
        INSERT INTO TransferredPoints (CheckingPeer, CheckedPeer, PointsAmount)
        VALUES (NEW.CheckingPeer, p_checked_peer, 1);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_transferred_points_trigger ON P2P;

CREATE OR REPLACE TRIGGER update_transferred_points_trigger
AFTER INSERT ON P2P
FOR EACH ROW
    WHEN (NEW.P2PCheckStatus = 'Start')
    EXECUTE FUNCTION update_transferred_points();

-- ---------------------Tests-----------------------------

CALL add_p2p_check('Elizabeth', 'Charlie', 'C2_SimpleBashUtils', 'Start', '14:00:00');
CALL add_p2p_check('Elizabeth', 'Charlie', 'C2_SimpleBashUtils', 'Failure', '15:30:00');

CALL add_p2p_check('William', 'Katherine', 'C8_3DViewer_v1.0', 'Start', '09:00:00');
CALL add_p2p_check('William', 'Katherine', 'C8_3DViewer_v1.0', 'Success', '09:00:00');

-- Non existing couple
CALL add_p2p_check('Charlie', 'Margaret', 'C8_3DViewer_v1.0', 'Start', '09:00:00');

SELECT * FROM TransferredPoints;

-- 4 --

CREATE OR REPLACE FUNCTION check_and_insert_xp() RETURNS TRIGGER AS $$
DECLARE
    last_check_status VARCHAR(30);
    task_max_xp INT;
BEGIN
    SELECT t.MaximumNumberOfXP INTO task_max_xp
    FROM Checks c
    JOIN tasks t ON t.title = c.task
    WHERE NEW.CheckID = c.id;  
    IF NEW.XPAmount > task_max_xp THEN
        RAISE EXCEPTION 'XP amount is greater than the maximum allowed';
    END IF;

    SELECT p.P2PCheckStatus INTO last_check_status
    FROM p2p p
    JOIN checks c ON p.CheckID = c.id
    WHERE NEW.CheckID = c.id
    ORDER BY p.P2PCheckStatus DESC
    LIMIT 1;
    IF last_check_status <> 'Success' THEN
        RAISE EXCEPTION 'No successful check found for the last task';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_and_insert_xp ON XP;

CREATE TRIGGER trg_check_and_insert_xp
BEFORE INSERT ON xp
FOR EACH ROW
EXECUTE FUNCTION check_and_insert_xp();

-- ---------------------Tests-----------------------------

-- Valid XP amount
INSERT INTO XP (CheckID, XPAmount)
VALUES (5, 200);

-- Failed status
INSERT INTO XP (CheckID, XPAmount)
VALUES (2, 250);

-- Invalid XP amount (exceeds maximum)
INSERT INTO XP (CheckID, XPAmount)
VALUES (11, 3300);

INSERT INTO XP (CheckID, XPAmount)
VALUES (5, -1);

SELECT * FROM XP;
