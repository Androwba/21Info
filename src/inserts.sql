INSERT INTO Peers (Nickname, Birthday)
VALUES 
    ('William', '2000-01-01'),
    ('Margaret', '1999-02-02'),
    ('Charlie', '1998-03-03'),
    ('Elizabeth', '1997-04-04'),
    ('Katherine', '1996-05-05');

INSERT INTO Tasks (Title, ParentTask, MaximumNumberOfXP)
VALUES 
    ('C2_SimpleBashUtils', NULL, 250),
    ('C3_s21_string+', 'C2_SimpleBashUtils', 500),
    ('D01_Linux', 'C2_SimpleBashUtils', 300),
    ('C8_3DViewer_v1.0', 'C2_SimpleBashUtils', 750),
    ('CPP1_s21_matrix+', 'C8_3DViewer_v1.0', 300),
    ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350),
    ('CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 600),
    ('CPP4_s21_3DViewer_v2.0', 'CPP3_SmartCalc_v2.0', 500),
    ('A1_Maze', 'CPP4_s21_3DViewer_v2.0', 300),
    ('A2_SimpleNavigator_v1.0', 'A1_Maze', 400);

INSERT INTO Checks (Peer, Task, CheckDate)
VALUES 
    ('William', 'C2_SimpleBashUtils', '2023-04-27'),
    ('Margaret', 'C2_SimpleBashUtils', '2023-04-30'),
    ('Charlie', 'C2_SimpleBashUtils', '2023-05-03'),
    ('Elizabeth', 'C2_SimpleBashUtils', '2023-05-04'),
    ('William', 'C3_s21_string+', '2023-05-08'),
    ('Margaret', 'C3_s21_string+', '2023-05-09'),
    ('Katherine', 'C2_SimpleBashUtils', '2023-05-11'),
    ('William', 'C8_3DViewer_v1.0', '2023-05-20'),
    ('Elizabeth', 'C3_s21_string+', '2023-05-23');

INSERT INTO P2P (CheckID, CheckingPeer, P2PCheckStatus, Time)
VALUES 
    (1, 'Katherine', 'Start', '09:00:00'),
    (1, 'Katherine', 'Success', '10:00:00'),
    (2, 'Charlie', 'Start', '08:00:00'),
    (2, 'Charlie', 'Failure', '08:30:00'),
    (3, 'Margaret', 'Start', '14:00:00'),
    (3, 'Margaret', 'Success', '15:00:00'),
    (4, 'Charlie', 'Start', '12:00:00'),
    (4, 'Charlie', 'Success', '12:45:00'),
    (5, 'Elizabeth', 'Start', '10:00:00'),
    (5, 'Elizabeth', 'Success', '11:00:00'),
    (6, 'Elizabeth', 'Start', '09:00:00'),
    (6, 'Elizabeth', 'Success', '09:30:00'),
    (7, 'Charlie', 'Start', '13:00:00'),
    (7, 'Charlie', 'Success', '13:45:00'),
    (8, 'William', 'Start', '09:00:00'),
    (8, 'William', 'Success', '10:00:00'),
    (9, 'William', 'Start', '08:00:00'),
    (9, 'William', 'Success', '08:30:00');

INSERT INTO Verter (CheckID, VerterCheckStatus, Time)
VALUES
    (1, 'Start', '10:00:00'),
    (1, 'Success', '10:02:00'),
    (3, 'Start', '15:00:00'),
    (3, 'Success', '15:03:00'),
    (4, 'Start', '12:45:00'),
    (4, 'Failure', '12:49:00'),
    (5, 'Start', '11:00:00'),
    (5, 'Success', '11:03:00'),
    (6, 'Start', '09:30:00'),
    (6, 'Success', '09:35:00'),
    (7, 'Start', '13:45:00'),
    (7, 'Failure', '13:47:00'),
    (8, 'Start', '10:00:00'),
    (8, 'Success', '10:04:00'),
    (9, 'Start', '08:30:00'),
    (9, 'Success', '08:35:00');

INSERT INTO TransferredPoints (CheckingPeer, CheckedPeer, PointsAmount)
VALUES ('Charlie', 'Katherine', 1),
       ('William', 'Charlie', 1),
       ('Elizabeth', 'Margaret', 1),
       ('Katherine', 'Charlie', 1),
       ('Charlie', 'Elizabeth', 1),
       ('William', 'Elizabeth', 1),
       ('Elizabeth', 'Charlie', 1),
       ('Margaret', 'William', 1),
       ('Katherine', 'William', 1);

INSERT INTO Friends (Peer1, Peer2)
VALUES ('William', 'Charlie'),
       ('Margaret', 'Katherine'),
       ('Katherine', 'Elizabeth'),
       ('Elizabeth', 'Margaret'),
       ('Elizabeth', 'William'),
       ('Charlie', 'Margaret');

INSERT INTO Recommendations (Peer, RecommendedPeer)
VALUES ('William', 'Katherine'),
       ('Margaret', 'Katherine'),
       ('Katherine', 'William'),
       ('Katherine', 'Elizabeth'),
       ('Katherine', 'Margaret'),
       ('Elizabeth', 'Margaret'),
       ('Elizabeth', 'William'),
       ('Charlie', 'William');

INSERT INTO XP (CheckID, XPAmount)
VALUES 
    (1, 250),
    (3, 250),
    (5, 250),
    (6, 500),
    (8, 500),
    (9, 750);

INSERT INTO TimeTracking (Peer, Date, Time, State)
VALUES
    ('William', '2023-05-16', '13:37', 1),
    ('William', '2023-05-16', '15:48', 2),
    ('William', '2023-05-17', '16:02', 1),
    ('William', '2023-05-17', '20:00', 2),
    ('Margaret', '2023-05-19', '09:12', 1),
    ('Margaret', '2023-05-19', '17:43', 2),
    ('Katherine', '2023-05-22', '10:09', 1),
    ('Katherine', '2023-05-22', '17:17', 2),
    ('Katherine', '2023-05-23', '08:11', 1),
    ('Katherine', '2023-05-23', '16:33', 2),
    ('Elizabeth', '2023-05-25', '14:12', 1),
    ('Elizabeth', '2023-05-25', '23:59', 2),
    ('Charlie', '2023-06-01', '12:01', 1),
    ('Charlie', '2023-06-01', '21:43', 2),
    ('Elizabeth', '2023-06-01', '15:07', 1),
    ('Elizabeth', '2023-06-02', '01:10', 2);

SELECT * FROM Peers;
SELECT * FROM Tasks;
SELECT * FROM Checks;
SELECT * FROM P2P;
SELECT * FROM Verter;
SELECT * FROM TransferredPoints;
SELECT * FROM Friends;
SELECT * FROM Recommendations;
SELECT * FROM XP;
SELECT * FROM TimeTracking;
