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

CREATE TABLE Tasks (
    Title VARCHAR(30) PRIMARY KEY,
    ParentTask VARCHAR(30) DEFAULT NULL,
    MaximumNumberOfXP INTEGER NOT NULL CHECK (MaximumNumberOfXP > 0),
    FOREIGN KEY (ParentTask) REFERENCES Tasks(Title)
);

CREATE TABLE Checks (
    ID SERIAL PRIMARY KEY,
    Peer VARCHAR(30) NOT NULL,
    Task VARCHAR(30) NOT NULL,
    CheckDate DATE NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
    FOREIGN KEY (Task) REFERENCES Tasks(Title)
);

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

CREATE TABLE Verter (
    ID SERIAL PRIMARY KEY,
    CheckID INT NOT NULL,
    VerterCheckStatus CheckStatus NOT NULL,
    Time TIME NOT NULL,
    FOREIGN KEY (CheckID) REFERENCES Checks(ID)
);

CREATE TABLE TransferredPoints (
    ID SERIAL PRIMARY KEY,
    CheckingPeer VARCHAR(30) NOT NULL,
    CheckedPeer VARCHAR(30) NOT NULL,
    PointsAmount INTEGER DEFAULT 0,
    FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
    FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname),
    CHECK (CheckingPeer <> CheckedPeer)
);

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

CREATE TABLE Recommendations (
    ID SERIAL PRIMARY KEY,
    Peer VARCHAR(30),
    RecommendedPeer VARCHAR(30),
    FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
    FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname),
    CONSTRAINT different_peers CHECK (Peer <> RecommendedPeer),
    CONSTRAINT unique_recommends UNIQUE (Peer, RecommendedPeer)
);

CREATE TABLE XP (
    ID SERIAL PRIMARY KEY,
    CheckID INTEGER NOT NULL,
    XPAmount INTEGER NOT NULL DEFAULT 0 CHECK (XPAmount >= 0),
    FOREIGN KEY (CheckID) REFERENCES Checks(ID)
);

CREATE TABLE TimeTracking (
    ID SERIAL PRIMARY KEY,
    Peer VARCHAR(30) NOT NULL,
    Date DATE NOT NULL DEFAULT CURRENT_DATE,
    Time TIME NOT NULL DEFAULT CURRENT_TIME,
    State SMALLINT NOT NULL CHECK (State IN (1, 2)),
    FOREIGN KEY (Peer) REFERENCES Peers(Nickname)
);

