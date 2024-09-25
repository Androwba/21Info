DROP TABLE IF EXISTS P2P CASCADE;
DROP TABLE IF EXISTS Verter CASCADE;
DROP TABLE IF EXISTS TransferredPoints CASCADE;
DROP TABLE IF EXISTS Friends CASCADE;
DROP TABLE IF EXISTS Recommendations CASCADE;
DROP TABLE IF EXISTS XP CASCADE;
DROP TABLE IF EXISTS TimeTracking CASCADE;
DROP TABLE IF EXISTS Peers CASCADE;
DROP TABLE IF EXISTS Tasks CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TYPE IF EXISTS CheckStatus CASCADE;

CREATE TABLE Peers (
    Nickname VARCHAR(30) PRIMARY KEY,
    Birthday DATE NOT NULL,
    CONSTRAINT unique_nickname UNIQUE (Nickname)
);

INSERT INTO Peers (Nickname, Birthday)
VALUES 
    ('William', '2000-01-01'),
    ('Margaret', '1999-02-02'),
    ('Charlie', '1998-03-03'),
    ('Elizabeth', '1997-04-04'),
    ('Katherine', '1996-05-05');

CREATE TABLE Tasks (
    Title VARCHAR(30) PRIMARY KEY,
    ParentTask VARCHAR(30) DEFAULT NULL,
    MaximumNumberOfXP INTEGER,
    FOREIGN KEY (ParentTask) REFERENCES Tasks(Title)
);

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

CREATE TABLE Checks (
    ID SERIAL PRIMARY KEY,
    Peer VARCHAR(30) NOT NULL,
    Task VARCHAR(30) NOT NULL,
    CheckDate DATE NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
    FOREIGN KEY (Task) REFERENCES Tasks(Title)
);

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

CREATE TYPE CheckStatus AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE P2P (
    ID SERIAL PRIMARY KEY,
    CheckID INTEGER NOT NULL,
    CheckingPeer VARCHAR(30) NOT NULL,
    P2PCheckStatus CheckStatus NOT NULL,
    Time TIME NOT NULL,
    FOREIGN KEY (CheckID) REFERENCES Checks(ID),
    FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname)
);

INSERT INTO P2P (CheckID, CheckingPeer, P2PCheckStatus, Time)
VALUES 
    (1, 'Katherine', 'Start', '2023-04-27 09:00:00'),
    (1, 'Katherine', 'Success', '2023-04-27 10:00:00'),
    (2, 'Charlie', 'Start', '2023-04-30 08:00:00'),
    (2, 'Charlie', 'Failure', '2023-04-30 08:30:00'),
    (3, 'Margaret', 'Start', '2023-05-03 14:00:00'),
    (3, 'Margaret', 'Success', '2023-05-03 15:00:00'),
    (4, 'Charlie', 'Start', '2023-05-04 12:00:00'),
    (4, 'Charlie', 'Success', '2023-05-04 12:45:00'),
    (5, 'Elizabeth', 'Start', '2023-05-08 10:00:00'),
    (5, 'Elizabeth', 'Success', '2023-05-08 11:00:00'),
    (6, 'Elizabeth', 'Start', '2023-05-09 09:00:00'),
    (6, 'Elizabeth', 'Success', '2023-05-09 09:30:00'),
    (7, 'Charlie', 'Start', '2023-05-11 13:00:00'),
    (7, 'Charlie', 'Success', '2023-05-11 13:45:00'),
    (8, 'William', 'Start', '2023-05-20 09:00:00'),
    (8, 'William', 'Success', '2023-05-20 10:00:00'),
    (9, 'William', 'Start', '2023-05-23 08:00:00'),
    (9, 'William', 'Success', '2023-05-23 08:30:00');

CREATE TABLE Verter (
    ID SERIAL PRIMARY KEY,
    CheckID INT NOT NULL,
    VerterCheckStatus CheckStatus NOT NULL,
    Time TIME NOT NULL,
    FOREIGN KEY (CheckID) REFERENCES Checks(ID)
);

INSERT INTO Verter (CheckID, VerterCheckStatus, Time)
VALUES
    (1, 'Start', '2023-04-27 10:00:00'),
    (1, 'Success', '2023-04-27 10:02:00'),
    (3, 'Start', '2023-05-03 15:00:00'),
    (3, 'Success', '2023-05-03 15:03:00'),
    (4, 'Start', '2023-05-04 12:45:00'),
    (4, 'Failure', '2023-05-04 12:49:00'),
    (5, 'Start', '2023-05-08 11:00:00'),
    (5, 'Success', '2023-05-08 11:03:00'),
    (6, 'Start', '2023-05-09 09:30:00'),
    (6, 'Success', '2023-05-09 09:35:00'),
    (7, 'Start', '2023-05-11 13:45:00'),
    (7, 'Failure', '2023-05-11 13:47:00'),
    (8, 'Start', '2023-05-20 10:00:00'),
    (8, 'Success', '2023-05-20 10:04:00'),
    (9, 'Start', '2023-05-23 08:30:00'),
    (9, 'Success', '2023-05-23 08:35:00');

CREATE TABLE TransferredPoints (
    ID SERIAL PRIMARY KEY,
    CheckingPeer VARCHAR(30) NOT NULL,
    CheckedPeer VARCHAR(30) NOT NULL,
    PointsAmount INTEGER,
    FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
    FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname),
    CHECK (CheckingPeer <> CheckedPeer)
);

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

CREATE TABLE Friends (
    ID SERIAL PRIMARY KEY,
    Peer1 VARCHAR(30) NOT NULL,
    Peer2 VARCHAR(30) NOT NULL,
    FOREIGN KEY (Peer1) REFERENCES Peers(Nickname),
    FOREIGN KEY (Peer2) REFERENCES Peers(Nickname),
    CHECK (Peer1 <> Peer2),
    CONSTRAINT unique_friends UNIQUE (Peer1, Peer2)
);

CREATE OR REPLACE FUNCTION prevent_reverse_pairs()
    RETURNS TRIGGER AS $$
BEGIN
    -- Check if the pair already exists
    IF EXISTS (
        SELECT TRUE
        FROM Friends
        WHERE (
            (Peer1 = NEW.Peer1 AND Peer2 = NEW.Peer2)
            OR
            (Peer1 = NEW.Peer2 AND Peer2 = NEW.Peer1)
        )
    ) THEN
        RAISE EXCEPTION 'This pair of peers are friends already: (%, %)', NEW.Peer1, NEW.Peer2;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_reverse_pairs
BEFORE INSERT ON Friends
FOR EACH ROW
EXECUTE FUNCTION prevent_reverse_pairs();

INSERT INTO Friends (Peer1, Peer2)
VALUES ('William', 'Charlie'),
       ('Margaret', 'Katherine'),
       ('Katherine', 'Elizabeth'),
       ('Elizabeth', 'Margaret'),
       ('Elizabeth', 'William'),
       ('Charlie', 'Margaret');

CREATE TABLE Recommendations (
    ID SERIAL PRIMARY KEY,
    Peer VARCHAR(30),
    RecommendedPeer VARCHAR(30),
    FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
    FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname),
    CONSTRAINT different_peers CHECK (Peer <> RecommendedPeer),
    CONSTRAINT unique_recommends UNIQUE (Peer, RecommendedPeer)
);

INSERT INTO Recommendations (Peer, RecommendedPeer)
VALUES ('William', 'Katherine'),
       ('Margaret', 'Katherine'),
       ('Katherine', 'William'),
       ('Katherine', 'Elizabeth'),
       ('Katherine', 'Margaret'),
       ('Elizabeth', 'Margaret'),
       ('Elizabeth', 'William'),
       ('Charlie', 'William');

CREATE TABLE XP (
    ID SERIAL PRIMARY KEY,
    CheckID INTEGER NOT NULL,
    XPAmount INTEGER NOT NULL DEFAULT 0 CHECK (XPAmount >= 0),
    FOREIGN KEY (CheckID) REFERENCES Checks(ID)
);

INSERT INTO XP (CheckID, XPAmount)
VALUES 
    (1, 250),
    (3, 250),
    (5, 250),
    (6, 500),
    (8, 500),
    (9, 750);

CREATE TABLE TimeTracking (
    ID SERIAL PRIMARY KEY,
    Peer VARCHAR(30) NOT NULL,
    Date DATE NOT NULL DEFAULT CURRENT_DATE,
    Time TIME NOT NULL DEFAULT CURRENT_TIME,
    State SMALLINT NOT NULL CHECK (State IN (1, 2)),
    FOREIGN KEY (Peer) REFERENCES Peers(Nickname)
);

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

create or replace procedure import_from_csv (table_name text, path text, delim char(1) default ',')
as $$
begin
execute 'COPY '||$1||' FROM ''/Users/evgeny/SQL2_Info21_v1.0-2/src/data/'||$2||''' DELIMITER '''||$3||''' CSV header';
end;
$$ language plpgsql;

create or replace procedure export_to_csv (table_name text, path text, delim char(1) default ',')
as $$
begin
	execute 'COPY '||$1||' TO ''/Users/evgeny/SQL2_Info21_v1.0-2/src/data/'||$2||''' DELIMITER '''||$3||''' CSV HEADER';
end;
$$ language plpgsql;

call import_from_csv('peers', 'users.csv');
call import_from_csv('friends', 'friends.csv');
call import_from_csv('tasks', 'task.csv');
call import_from_csv('checks', 'checks.csv');
call import_from_csv('p2p', 'p2p.csv');
call import_from_csv('recommendations', 'recoms.csv');
call import_from_csv('verter', 'verter.csv');
call import_from_csv('timetracking', 't_track.csv');
call import_from_csv('transferredpoints', 't_points.csv');
call import_from_csv('xp', 'xp.csv');
-- SELECT * FROM Peers;
-- SELECT * FROM Tasks;
-- SELECT * FROM Checks;
-- SELECT * FROM P2P;
-- SELECT * FROM Verter;
-- SELECT * FROM TransferredPoints;
-- SELECT * FROM Friends;
-- SELECT * FROM Recommendations;
-- SELECT * FROM XP;
-- SELECT * FROM TimeTracking;
   
   


