DROP FUNCTION IF EXISTS get_transferred_points();
CREATE OR REPLACE FUNCTION get_transferred_points()
    RETURNS TABLE("Peer1" VARCHAR(30), "Peer2" VARCHAR(30), "PointsAmount" INTEGER)
    LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH aggregated_points AS (
        -- Calculate the transferred points between peers
        SELECT
            tp1.id AS id1,
            tp2.id AS id2,
            tp1.checkingpeer AS peer1,
            tp1.checkedpeer AS peer2,
            tp1.pointsamount - COALESCE(tp2.pointsamount, 0) AS points_amount
        FROM transferredpoints AS tp1
        LEFT JOIN transferredpoints AS tp2
            ON tp1.checkingpeer = tp2.checkedpeer AND tp1.checkedpeer = tp2.checkingpeer
    ),
    aggregated_pairs AS (
        SELECT MAX(peer1) AS peer1,
               MIN(peer2) AS peer2
        FROM aggregated_points
        WHERE id2 IS NOT NULL
        --  Identify pairs of checking and checked peers that have interacted with each other
        GROUP BY id1 * id2
    )
    SELECT peer1, peer2, points_amount
    FROM aggregated_points
    WHERE id2 IS NULL
    UNION
    -- Calculate aggregated points
    SELECT a.peer1, a.peer2, ap.points_amount
    FROM aggregated_pairs as a
    JOIN aggregated_points AS ap ON a.peer1 = ap.peer1 AND a.peer2 = ap.peer2
    ORDER BY peer1, peer2;
END;
$$;

-- Tests --
SELECT * FROM get_transferred_points();

CALL add_p2p_check('Elizabeth', 'Charlie', 'C2_SimpleBashUtils', 'Start', '14:00:00');
CALL add_p2p_check('Elizabeth', 'Charlie', 'C2_SimpleBashUtils', 'Failure', '15:30:00');

CALL add_p2p_check('Katherine', 'Charlie', 'C2_SimpleBashUtils', 'Start', '15:00:00');
CALL add_p2p_check('Katherine', 'Charlie', 'C2_SimpleBashUtils', 'Success', '15:30:00');

-- 2 --

CREATE OR REPLACE FUNCTION get_successful_task_xp()
    RETURNS TABLE("Peer" VARCHAR(30), "Task" VARCHAR(30), "XPReceived" INTEGER)
    LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT c.Peer AS "Peer",
           c.Task AS "Task",
           xp.XPAmount AS "XPReceived"
    FROM Checks AS c
    JOIN XP AS xp ON c.ID = xp.CheckID
    WHERE xp.XPAmount > 0
    ORDER BY c.Peer, c.Task, xp.XPAmount DESC;
END;
$$;

-- Tests --
SELECT * FROM get_successful_task_xp();

INSERT INTO XP (CheckID, XPAmount)
VALUES (5, 200);

INSERT INTO XP (CheckID, XPAmount)
VALUES (3, 250);

INSERT INTO XP (CheckID, XPAmount)
VALUES (7, 0);

-- 3 --

CREATE OR REPLACE FUNCTION find_peers_not_left_campus(day DATE)
    RETURNS SETOF VARCHAR(30)
    LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT tt.Peer
    FROM TimeTracking tt
    WHERE tt.Date = day
        AND NOT EXISTS (
            SELECT 1
            FROM TimeTracking tt2
            WHERE tt.Peer = tt2.Peer
                AND tt2.Date = day
                AND tt2.State = 2
        );
END;
$$;

-- Tests --
SELECT * FROM find_peers_not_left_campus('2023-06-01');

INSERT INTO TimeTracking (Peer, Date, Time, State)
VALUES ('Margaret', '2023-08-03', '08:00', 1),
       ('Margaret', '2023-08-04', '17:00', 2);
SELECT * FROM find_peers_not_left_campus('2023-08-03');

INSERT INTO TimeTracking (Peer, Date, Time, State)
VALUES ('William', '2023-08-03', '10:45', 1),
       ('William', '2023-08-04', '02:10', 2);
SELECT * FROM find_peers_not_left_campus('2023-08-03');

-- 4 --

CREATE OR REPLACE PROCEDURE calculate_pp_change(ref REFCURSOR)
    LANGUAGE plpgsql
AS $$
BEGIN
    OPEN ref FOR
    WITH points_count AS (
        SELECT checkingpeer AS "Peer", pointsamount
        FROM transferredpoints
        UNION ALL
        SELECT checkedpeer, pointsamount * (-1)
        FROM transferredpoints
    )
    SELECT "Peer", SUM(pointsamount) AS "PointsChange"
    FROM points_count
    GROUP BY "Peer"
    ORDER BY "PointsChange" DESC; 
END;
$$;

-- Tests --
BEGIN;
CALL calculate_pp_change('ref');
FETCH ALL IN "ref";
COMMIT;

CALL add_p2p_check('William', 'Margaret', 'C2_SimpleBashUtils', 'Start', '14:30:00');
CALL add_p2p_check('William', 'Margaret', 'C2_SimpleBashUtils', 'Failure', '15:15:00');

CALL add_p2p_check('Margaret', 'William', 'C2_SimpleBashUtils', 'Start', '16:00:00');
CALL add_p2p_check('Margaret', 'William', 'C2_SimpleBashUtils', 'Failure', '16:30:00');

-- 5 --

CREATE OR REPLACE PROCEDURE calculate_pp_from_table(IN ref REFCURSOR)
    LANGUAGE plpgsql
AS $$ BEGIN
    OPEN ref FOR
        SELECT points."Peer", SUM(points."PointsChange") AS "PointsChange" FROM
            (SELECT "Peer1" AS "Peer", "PointsAmount" AS "PointsChange" FROM get_transferred_points()
             UNION ALL
             SELECT "Peer2" AS "Peer", "PointsAmount" * (-1) AS "PointsChange" FROM get_transferred_points()) AS points
        GROUP BY points."Peer"
        ORDER BY "PointsChange" DESC, points."Peer";
END;$$;

-- Tests are the same as in previous task --
BEGIN;
CALL calculate_pp_from_table('ref');
FETCH ALL IN "ref";
COMMIT;

-- 6 --

CREATE OR REPLACE PROCEDURE most_checked_task(IN ref REFCURSOR)
AS $$
BEGIN
	OPEN ref FOR
	WITH task_count AS (
		SELECT
			TO_CHAR(checks.CheckDate, 'dd.mm.yyyy') AS "Day",
			SPLIT_PART(checks.task, '_', 1) AS "Task",
			COUNT(*) AS Count
		FROM p2p 
		LEFT JOIN checks ON p2p.checkID = checks.id
		GROUP BY checks.CheckDate, "Task"
		ORDER BY "Day" DESC
	),
	max_task_count AS (
		SELECT "Day", "Task", MAX(Count) OVER (PARTITION BY "Day") AS MaxCount
		FROM task_count
	)
	SELECT task_count."Day", task_count."Task" 
	FROM task_count
	RIGHT JOIN max_task_count 
	ON task_count."Day" = max_task_count."Day" AND task_count."Task" = max_task_count."Task" AND task_count.Count = max_task_count.MaxCount 
	WHERE task_count."Day" IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Tests --
BEGIN;
CALL most_checked_task('ref');
FETCH ALL IN "ref";
COMMIT;

CALL add_p2p_check('Elizabeth', 'Charlie', 'D01_Linux', 'Start', '14:30:00');
CALL add_p2p_check('Elizabeth', 'Charlie', 'D01_Linux', 'Success', '15:00:00');

CALL add_p2p_check('William', 'Margaret', 'CPP1_s21_matrix+', 'Start', '14:00:00');
CALL add_p2p_check('William', 'Margaret', 'CPP1_s21_matrix+', 'Success', '14:00:00');

-- 7 --

CREATE OR REPLACE PROCEDURE completed_the_whole_block(IN ref REFCURSOR, given_block VARCHAR(30))
    LANGUAGE plpgsql
AS $$
BEGIN
    OPEN ref FOR
        SELECT
             c.peer AS "Peer",
            TO_CHAR(MAX(c.CheckDate), 'DD.MM.YYYY') AS "Day"
        FROM
            Checks c
        JOIN
            p2p ON c.id = p2p.checkID
                AND p2p.P2PCheckStatus = 'Success'
                AND c.task IN (
                    SELECT title
                    FROM Tasks
                    WHERE title SIMILAR TO format('%s[0-9]+_%%', given_block)
                )
        LEFT JOIN
            Verter v ON c.id = v.checkID
        WHERE
            v.VerterCheckStatus = 'Success'
            OR v.VerterCheckStatus IS NULL
        GROUP BY
            c.peer
        HAVING
            count(DISTINCT c.task) = (
                SELECT count(*)
                FROM Tasks
                WHERE title SIMILAR TO format('%s[0-9]+_%%', given_block)
            );
END;
$$;

-- Tests --
BEGIN;
CALL completed_the_whole_block('ref', 'D');
FETCH ALL IN "ref";
COMMIT;

CALL add_p2p_check('William', 'Charlie', 'CPP3_SmartCalc_v2.0', 'Start', '17:30:00');
CALL add_p2p_check('William', 'Charlie', 'CPP3_SmartCalc_v2.0', 'Success', '18:15:00');
CALL add_p2p_check('William', 'Charlie', 'CPP2_s21_containers', 'Start', '20:30:00');
CALL add_p2p_check('William', 'Charlie', 'CPP2_s21_containers', 'Success', '21:00:00');
CALL add_p2p_check('William', 'Charlie', 'CPP4_s21_3DViewer_v2.0', 'Start', '20:30:00');
CALL add_p2p_check('William', 'Charlie', 'CPP4_s21_3DViewer_v2.0', 'Success', '21:00:00');

BEGIN;
CALL completed_the_whole_block('ref', 'CPP');
FETCH ALL IN "ref";
COMMIT;

CALL add_p2p_check('Charlie', 'William', 'CPP1_s21_matrix+', 'Start', '11:30:00');
CALL add_p2p_check('Charlie', 'William', 'CPP1_s21_matrix+', 'Success', '12:00:00');
CALL add_p2p_check('Charlie', 'William', 'CPP3_SmartCalc_v2.0', 'Start', '17:30:00');
CALL add_p2p_check('Charlie', 'William', 'CPP3_SmartCalc_v2.0', 'Success', '18:15:00');
CALL add_p2p_check('Charlie', 'William', 'CPP2_s21_containers', 'Start', '20:30:00');
CALL add_p2p_check('Charlie', 'William', 'CPP2_s21_containers', 'Success', '21:00:00');
CALL add_p2p_check('Charlie', 'William', 'CPP4_s21_3DViewer_v2.0', 'Start', '20:30:00');
CALL add_p2p_check('Charlie', 'William', 'CPP4_s21_3DViewer_v2.0', 'Success', '21:00:00');

-- 8 --

CREATE OR REPLACE PROCEDURE determine_peer_for_check(IN ref refcursor)
AS $$
BEGIN
    OPEN ref FOR
    WITH PeerFriendPairs AS (
         -- List of pairs where each row represents a main peer and their friend
        SELECT 
            p.Nickname AS peer,
            CASE WHEN p.Nickname = f.Peer1 THEN f.Peer2 ELSE f.Peer1 END AS friend
        FROM Peers p
        JOIN Friends f ON p.Nickname = f.Peer1 OR p.Nickname = f.Peer2
        ORDER BY 1
    ), RecommendedPeerPairs AS (
        SELECT 
            pfp.peer,
            r.RecommendedPeer
        FROM PeerFriendPairs pfp
        LEFT JOIN Recommendations r ON pfp.friend = r.Peer
        WHERE r.RecommendedPeer IS NOT NULL
        ORDER BY 1
    ), RecommendedCounts AS (
        SELECT 
            peer,
            RecommendedPeer,
            COUNT (RecommendedPeer) AS recommendation_count
        FROM RecommendedPeerPairs
        GROUP BY peer, RecommendedPeer
        ORDER BY 1
    ), MaxRecommendedCounts AS (
        SELECT 
            peer,
            RecommendedPeer,
            recommendation_count,
            MAX(recommendation_count) OVER (PARTITION BY peer) AS max_recommendation_count 
        FROM RecommendedCounts
        ORDER BY 1
    )
    SELECT 
        peer AS "Peer",
        RecommendedPeer AS "RecommendedPeer"
    FROM MaxRecommendedCounts
    WHERE max_recommendation_count = recommendation_count AND peer <> RecommendedPeer;
END;
$$ LANGUAGE plpgsql;

-- Tests --
BEGIN;
CALL determine_peer_for_check('ref');
FETCH ALL IN "ref";
COMMIT;

BEGIN;
    -- William recommend Margaret
    INSERT INTO Recommendations (Peer, RecommendedPeer)
    VALUES
        ('William', 'Charlie'),
        ('Charlie', 'Margaret');
END;

--  Multiple Recommendations from Different Friends
BEGIN;
    DELETE FROM Recommendations;
    INSERT INTO Recommendations (Peer, RecommendedPeer)
    VALUES 
        ('William', 'Katherine'),
        ('Margaret', 'Charlie'),
        ('Katherine', 'William'),
        ('Katherine', 'Elizabeth'),
        ('Elizabeth', 'Margaret'),
        ('Charlie', 'Elizabeth');
END;

-- Recommendations with No Friendship Connection
-- Expected output: No data
BEGIN;
    DELETE FROM Friends;
    DELETE FROM Recommendations;
    INSERT INTO Recommendations (Peer, RecommendedPeer)
    VALUES 
        ('William', 'Katherine'),
        ('Charlie', 'Margaret'),
        ('Elizabeth', 'William');
END;

-- 9 --

CREATE OR REPLACE PROCEDURE started_block_percentage(
    IN Block1 varchar(30), 
    IN Block2 varchar(30), 
    OUT StartedBlock1 real, 
    OUT StartedBlock2 real, 
    OUT StartedBothBlocks real, 
    OUT DidntStartAnyBlock real
) AS $$
DECLARE
    TotalPeersCount int;
BEGIN
    SELECT COUNT(*) INTO TotalPeersCount FROM peers;

    WITH BlockTable1 AS ( 
        SELECT DISTINCT peer 
        FROM Checks 
        WHERE Checks.task LIKE (Block1 || '%')
    ),
    BlockTable2 AS (
        SELECT DISTINCT peer 
        FROM Checks 
        WHERE Checks.task LIKE (Block2 || '%')
    ),
    BothBlocks AS (
        SELECT DISTINCT BlockTable1.peer
        FROM BlockTable1
        INNER JOIN BlockTable2 ON BlockTable1.peer = BlockTable2.peer
    ),
   DidNotStarted AS (
        SELECT DISTINCT peer
        FROM (SELECT * FROM BlockTable1 UNION SELECT * FROM BlockTable2) AS tmp
    )
    SELECT 
        CAST((SELECT COUNT(*) FROM BlockTable1) AS real) / TotalPeersCount * 100,
        CAST((SELECT COUNT(*) FROM BlockTable2) AS real) / TotalPeersCount * 100,
        CAST((SELECT COUNT(*) FROM BothBlocks) AS real) / TotalPeersCount * 100,
        CAST(TotalPeersCount - (SELECT COUNT(*) FROM DidNotStarted) AS real) / TotalPeersCount * 100
    INTO StartedBlock1, StartedBlock2, StartedBothBlocks, DidntStartAnyBlock;
END;
$$ LANGUAGE plpgsql;

-- Tests --
CALL started_block_percentage('D', 'A', NULL, NULL, NULL, NULL);
CALL started_block_percentage('C', 'CPP', NULL, NULL, NULL, NULL);
CALL started_block_percentage('C', 'D', NULL, NULL, NULL, NULL);
CALL started_block_percentage('D', 'CPP', NULL, NULL, NULL, NULL);

-- 10 --
CREATE OR REPLACE PROCEDURE calculate_birthday_check_percentages(ref REFCURSOR)
    LANGUAGE plpgsql AS $$
BEGIN
    OPEN ref FOR
        WITH birthday_checks AS (
            -- Select peers with birthday checks
            SELECT p.nickname, p.birthday, p2p.p2pcheckstatus AS p2p_check_status, verter.vertercheckstatus AS verter_check_status
            FROM peers p
            JOIN checks c ON p.nickname = c.peer
            JOIN p2p ON c.id = p2p.CheckID
            LEFT JOIN verter ON c.id = verter.checkID AND (verter.vertercheckstatus = 'Success' OR verter.vertercheckstatus = 'Failure')
            WHERE date_part('day', c.checkdate) = date_part('day', p.birthday)
              AND date_part('month', c.checkdate) = date_part('month', p.birthday)
              AND (p2p.p2pcheckstatus = 'Success' OR p2p.p2pcheckstatus = 'Failure')
        ), aggregated_checks AS (
            -- Calculate final state for each peer
            SELECT b.nickname, b.birthday, (
                CASE WHEN b.p2p_check_status = 'Success' AND b.verter_check_status <> 'Failure'
                     THEN 1
                     ELSE 0
                END
            ) AS final_state
            FROM birthday_checks b
        )
        SELECT
            TRUNC(COALESCE((SELECT SUM(final_state)
                            FROM aggregated_checks) * 100.0 / NULLIF((SELECT COUNT(*) FROM aggregated_checks), 0), 0)) AS "SuccessfulChecks",
            TRUNC(COALESCE(100.0 - (SELECT SUM(final_state)
                            FROM aggregated_checks) * 100.0 / NULLIF((SELECT COUNT(*) FROM aggregated_checks), 0), 0)) AS "UnsuccessfulChecks";
END;
$$;

-- Tests --
BEGIN;
CALL calculate_birthday_check_percentages('ref');
FETCH ALL IN "ref";
COMMIT;

-- Insert new peers with birthday checks
DO $$ 
DECLARE 
    nextCheckID INT;
BEGIN
    -- Get the next available CheckID value
    SELECT COALESCE(MAX(id) + 1, 1) INTO nextCheckID FROM Checks;

    INSERT INTO Peers (Nickname, Birthday)
    VALUES 
        ('John', '1995-06-06'),
        ('Alice', '1994-07-07');
    INSERT INTO Checks (ID, Peer, Task, CheckDate)
    VALUES 
        (nextCheckID, 'John', 'C2_SimpleBashUtils', '2023-06-06'),
        (nextCheckID + 1, 'Alice', 'C2_SimpleBashUtils', '2023-07-07');
    INSERT INTO P2P (CheckID, CheckingPeer, P2PCheckStatus, Time)
    VALUES 
        (nextCheckID, 'John', 'Start', '2023-06-06 09:00:00'),
        (nextCheckID, 'John', 'Success', '2023-06-06 10:00:00'),
        (nextCheckID + 1, 'Alice', 'Start', '2023-07-07 08:00:00'),
        (nextCheckID + 1, 'Alice', 'Failure', '2023-07-07 08:30:00');
    INSERT INTO Verter (CheckID, VerterCheckStatus, Time)
    VALUES 
        (nextCheckID, 'Start', '2023-06-06 10:00:00'),
        (nextCheckID, 'Success', '2023-06-06 10:02:00'),
        (nextCheckID + 1, 'Start', '2023-07-07 08:30:00'),
        (nextCheckID + 1, 'Success', '2023-07-07 08:33:00');
END; 
$$;

BEGIN;
CALL calculate_birthday_check_percentages('ref');
FETCH ALL IN "ref";
COMMIT;

-- Add 1 more successful birthday check
DO $$ 
DECLARE 
    nextCheckID INT;
BEGIN
    SELECT COALESCE(MAX(id) + 1, 1) INTO nextCheckID FROM Checks;
    INSERT INTO Peers (Nickname, Birthday)
    VALUES 
        ('Carl', '1990-08-01');
    INSERT INTO Checks (ID, Peer, Task, CheckDate)
    VALUES 
        (nextCheckID, 'Carl', 'C2_SimpleBashUtils', '2023-08-01');
    INSERT INTO P2P (CheckID, CheckingPeer, P2PCheckStatus, Time)
    VALUES 
        (nextCheckID, 'Carl', 'Start', '2023-08-01 09:00:00'),
        (nextCheckID, 'Carl', 'Success', '2023-08-01 10:00:00');
    INSERT INTO Verter (CheckID, VerterCheckStatus, Time)
    VALUES 
        (nextCheckID, 'Start', '2023-08-01 10:00:00'),
        (nextCheckID, 'Success', '2023-08-01 10:02:00');
END; 
$$;

-- 11 --

CREATE OR REPLACE PROCEDURE peers_who_did_the_given_tasks(
    INOUT ref REFCURSOR,
    IN task1 VARCHAR(30),
    IN task2 VARCHAR(30),
    IN task3 VARCHAR(30)
)
LANGUAGE plpgsql AS $$
BEGIN
    OPEN ref FOR
    WITH aggregated_checks AS (
        SELECT
            c.id,
            c.peer AS checked_peer,
            p.checkingpeer AS checking_peer,
            c.task,
            p.p2pcheckstatus AS p2p_check_status,
            v.vertercheckstatus AS verter_check_status
        FROM
            checks c
            JOIN p2p p ON c.id = p.checkid AND c.task IN (task1, task2, task3) AND p.p2pcheckstatus = 'Success'
            LEFT JOIN verter v ON c.id = v.checkid
        WHERE
            v.vertercheckstatus = 'Success' OR v.vertercheckstatus IS NULL
    )
    SELECT
        checked_peer AS "list of peers"
    FROM
        aggregated_checks
    WHERE
        task = task1
        AND checked_peer IN (
            SELECT checked_peer FROM aggregated_checks WHERE task = task2
        )
        AND checked_peer NOT IN (
            SELECT checked_peer FROM aggregated_checks WHERE task = task3
        );
END;
$$;

BEGIN;
CALL peers_who_did_the_given_tasks('ref', 'C2_SimpleBashUtils', 'C3_s21_string+', 'A1_Maze');
FETCH ALL IN "ref";
COMMIT;

BEGIN;
CALL peers_who_did_the_given_tasks('ref', 'C2_SimpleBashUtils', 'C8_3DViewer_v1.0', 'A1_Maze');
FETCH ALL IN "ref";
COMMIT;

BEGIN;
CALL peers_who_did_the_given_tasks('ref', 'CPP1_s21_matrix+', 'D01_Linux', 'A1_Maze');
FETCH ALL IN "ref";
COMMIT;

-- 12 --

CREATE OR REPLACE PROCEDURE number_of_preceding_tasks(INOUT ref REFCURSOR)
LANGUAGE plpgsql AS $$
BEGIN
    OPEN ref FOR
    WITH RECURSIVE task_hierarchy AS (
        -- Select tasks with no parent task
        SELECT
            title AS task,
            parenttask,
            0 AS PrevCount
        FROM
            tasks
        WHERE
            parenttask IS NULL
        UNION ALL
        -- Recursive case: Join with previous level and count preceding tasks
        SELECT
            t.title AS task,
            t.parenttask,
            th.PrevCount + 1 AS PrevCount
        FROM
            tasks AS t
        JOIN
            task_hierarchy AS th ON t.parenttask = th.task
    )
    SELECT
        task,
        MAX(PrevCount) AS PrevCount
    FROM
        task_hierarchy
    GROUP BY
        task;
END;
$$;

-- Test --
BEGIN;
CALL number_of_preceding_tasks('ref');
FETCH ALL IN "ref";
COMMIT;

-- 13 --

CREATE OR REPLACE PROCEDURE find_lucky_days (IN Number_of_Checks integer, IN lucky_days_cursor REFCURSOR) 
AS $$
BEGIN
    OPEN lucky_days_cursor FOR 
    WITH check_status AS (
        SELECT
            checkdate,
            time,
            CASE WHEN 100 * xp.xpamount / tasks.maximumnumberofxp >= 80 THEN 1 ELSE 0 END AS status
        FROM checks
        JOIN tasks ON checks.task = tasks.title
        JOIN xp ON checks.id = xp.checkID
        JOIN p2p ON checks.id = p2p.checkID AND p2p.p2pcheckstatus IN ('Success', 'Failure')
    ), 
    check_status_with_next AS (
        SELECT
            current.checkdate,
            current.time,
            current.status,
            next.status AS next_status
        FROM check_status AS current
        JOIN check_status AS next
        ON (current.checkdate = next.checkdate AND current.time < next.time)
        OR (current.checkdate < next.checkdate)
    ),
    consecutive_successful_checks AS (
        SELECT
            current.checkdate,
            current.time,
            current.status,
            current.next_status,
            COUNT(previous.checkdate)
        FROM check_status_with_next current
        JOIN check_status_with_next previous ON current.checkdate = previous.checkdate AND current.time <= previous.time AND current.status = previous.next_status
        GROUP BY current.checkdate, current.time, current.status, current.next_status
    )
    -- Select the lucky days with consecutive successful checks
    SELECT checkdate AS "list of dates"
    FROM (
        SELECT checkdate, MAX(successful_checks) AS max_successful_checks
        FROM (
            SELECT checkdate, COUNT(*) AS successful_checks
            FROM consecutive_successful_checks
            WHERE status = 1
            GROUP BY checkdate
        ) successful_checks
        GROUP BY checkdate
    ) lucky_day_counts
    WHERE max_successful_checks >= Number_of_Checks;
END;
$$ LANGUAGE plpgsql;

-- Test --
BEGIN;
CALL find_lucky_days(1, 'lucky_days_cursor');
FETCH ALL FROM "lucky_days_cursor";
COMMIT;

-- 14 --

create or replace function get_peer_with_max_xp()
returns table (peer varchar, xp int)
as $$
select c.peer, sum(x.xpamount)
from checks c
join xp x on c.id = x.checkid
group by peer
$$
language sql;

select * from get_peer_with_max_xp();

-- 15 --

create or replace function get_peers_come_earlier(p_time time)
returns table(peers varchar) as
$$
select peer from timetracking t
where t."time" < $1
$$
language sql;

select * from get_peers_come_earlier('10:00:00');

-- 16 --

CREATE OR REPLACE PROCEDURE peers_with_multiple_campus_exits(
    IN days_period int,
    IN exit_threshold integer,
    IN ref REFCURSOR
)
AS $$
BEGIN
    OPEN ref FOR
    WITH exit_counts AS (
        SELECT
            peer,
            date,
            COUNT(state) - 1 AS exit_count
        FROM timetracking
        WHERE state = 2 AND date >= current_date - days_period
        GROUP BY peer, date
    )
    SELECT peer AS "list of peers"
    FROM exit_counts
    WHERE exit_count > exit_threshold;
END;
$$ LANGUAGE plpgsql;

-- Tests --
BEGIN;
CALL peers_with_multiple_campus_exits(15, 1, 'ref');
FETCH ALL IN "ref";
COMMIT;

INSERT INTO peers (nickname, birthday) VALUES
    ('Michael', '1991-01-15'),
    ('Emma', '1994-03-25'),
    ('Olivia', '1992-04-05');

INSERT INTO TimeTracking (Peer, Date, Time, State)
VALUES
    ('Michael', '2023-08-01', '08:30:00', 2),
    ('Emma', '2023-08-01', '10:45:00', 2),
    ('Olivia', '2023-08-01', '09:15:00', 2),
    ('William', '2023-08-01', '11:00:00', 2),
    ('Michael', '2023-08-02', '09:30:00', 2),
    ('Emma', '2023-08-02', '08:45:00', 2),
    ('Olivia', '2023-08-02', '09:00:00', 2),
    ('William', '2023-08-02', '11:30:00', 2),
    ('Michael', '2023-08-03', '09:00:00', 2),
    ('Emma', '2023-08-03', '11:45:00', 2),
    ('Olivia', '2023-08-03', '09:15:00', 2),
    ('William', '2023-08-03', '10:30:00', 2),
    ('Michael', '2023-08-04', '08:45:00', 2),
    ('Emma', '2023-08-04', '10:30:00', 2),
    ('Olivia', '2023-08-04', '09:00:00', 2),
    ('William', '2023-08-04', '11:15:00', 2),
    ('Michael', '2023-08-05', '10:00:00', 2),
    ('Emma', '2023-08-05', '09:45:00', 2),
    ('Olivia', '2023-08-05', '09:30:00', 2),
    ('William', '2023-08-05', '10:45:00', 2),
    ('Michael', '2023-08-06', '09:15:00', 2),
    ('Emma', '2023-08-06', '08:30:00', 2),
    ('Olivia', '2023-08-06', '10:00:00', 2),
    ('William', '2023-08-06', '10:15:00', 2);

-- 17 --

CREATE OR REPLACE PROCEDURE percentage_of_early_entries(IN ref REFCURSOR)
AS $$
BEGIN
    OPEN ref FOR
    WITH entry_stats AS (
        SELECT
            to_char(peers.birthday, 'Month') AS "Month",
            peer,
            date,
            COUNT(*) FILTER (WHERE time < '12:00:00') AS early_entries,
            COUNT(*) AS total_entries
        FROM TimeTracking
        JOIN peers ON nickname = peer
        WHERE state = 1
        GROUP BY "Month", peer, date
    )
    SELECT
        "Month",
        ROUND(AVG(early_entries::real / total_entries) * 100) AS "EarlyEntries"
    FROM entry_stats
    GROUP BY "Month"
    HAVING AVG(early_entries::real / total_entries) > 0 -- Exclude months with zero early entries
    ORDER BY to_date("Month", 'Month');
END;
$$ LANGUAGE plpgsql;

-- Tests --
BEGIN;
CALL percentage_of_early_entries('ref');
FETCH ALL IN "ref";
COMMIT;

-- Add some Early Entries
INSERT INTO peers (nickname, birthday) VALUES
    ('Alice', '1990-01-15'),
    ('Bob', '1995-03-25'),
    ('David', '1991-04-05');

INSERT INTO TimeTracking (peer, date, state, time) VALUES
    ('Alice', '2023-08-01', 1, '09:30:00'),
    ('Alice', '2023-08-01', 1, '11:30:00'),
    ('Alice', '2023-08-01', 1, '14:30:00'),
    ('Bob', '2023-08-01', 1, '10:45:00'),
    ('Bob', '2023-08-01', 1, '13:00:00'),
    ('Bob', '2023-08-01', 1, '15:30:00'),
    ('David', '2023-08-01', 1, '09:00:00'),
    ('David', '2023-08-01', 1, '10:00:00'),
    ('David', '2023-08-01', 1, '12:30:00');

BEGIN;
CALL percentage_of_early_entries('ref');
FETCH ALL IN "ref";
COMMIT;

