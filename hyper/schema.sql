DROP TABLE IF EXISTS DirectMandate CASCADE;
DROP TABLE IF EXISTS VotedOn CASCADE;
DROP TABLE IF EXISTS Listenplatz CASCADE;
DROP TABLE IF EXISTS Landesliste CASCADE;
DROP TABLE IF EXISTS Zweitstimme CASCADE;
DROP TABLE IF EXISTS Erststimme CASCADE;
DROP TABLE IF EXISTS Candidate CASCADE;
DROP TABLE IF EXISTS Party CASCADE;
DROP TABLE IF EXISTS Voter CASCADE;
DROP TABLE IF EXISTS Wahlkreis CASCADE;
DROP TABLE IF EXISTS Bundesland CASCADE;
DROP TABLE IF EXISTS Election CASCADE;
DROP TABLE IF EXISTS Token CASCADE;

CREATE TABLE Election
(
  ID   INTEGER PRIMARY KEY,
  Date DATE NOT NULL
);

CREATE TABLE Bundesland
(
  ID   INTEGER PRIMARY KEY,
  Name VARCHAR(30) NOT NULL
);

CREATE TABLE Wahlkreis
(
  ID         INTEGER PRIMARY KEY,
  Name       VARCHAR(150) NOT NULL,
  Bundesland INTEGER      NOT NULL REFERENCES Bundesland
);

CREATE TABLE Voter
(
  ID                 INTEGER PRIMARY KEY,
  FirstName          VARCHAR(60)  NOT NULL,
  LastName           VARCHAR(60)  NOT NULL,
  BirthDate          DATE         NOT NULL,
  Address            VARCHAR(100) NOT NULL,
  Gender             CHAR(1)      NOT NULL,
  Wahlkreis          INTEGER      NOT NULL REFERENCES Wahlkreis,
  FirstValidElection INTEGER      NOT NULL REFERENCES Election,
  LastValidElection  INTEGER REFERENCES Election,
  LastVotedOn        INTEGER REFERENCES Election
);

CREATE TABLE Party
(
  ID              INTEGER PRIMARY KEY,
  Name            VARCHAR(30) NOT NULL,
  isMinorityParty BOOLEAN
);
INSERT INTO Party VALUES (0, 'dummy', FALSE);


CREATE TABLE Candidate
(
  ID        INTEGER PRIMARY KEY,
  FirstName VARCHAR(60) NOT NULL,
  LastName  VARCHAR(60) NOT NULL,
  BirthYear SMALLINT    NOT NULL
);

INSERT INTO Candidate VALUES (0, 'dummy', 'dummy', '1900');

CREATE TABLE Erststimme
(
  ID        INTEGER,
  isInvalid BOOLEAN NOT NULL,
  Candidate INTEGER REFERENCES Candidate,
  Wahlkreis INTEGER REFERENCES Wahlkreis,
  Election  INTEGER REFERENCES Election
);

CREATE TABLE Zweitstimme
(
  ID        INTEGER,
  isInvalid BOOLEAN NOT NULL,
  Party     INTEGER REFERENCES Party,
  Wahlkreis INTEGER REFERENCES Wahlkreis,
  Election  INTEGER REFERENCES Election
);

CREATE TABLE Landesliste
(
  ID         INTEGER PRIMARY KEY,
  Party      INTEGER NOT NULL REFERENCES Party,
  Election   INTEGER NOT NULL REFERENCES Election,
  Bundesland INTEGER NOT NULL REFERENCES Bundesland
);

CREATE TABLE Listenplatz
(
  Landesliste INTEGER NOT NULL REFERENCES Landesliste,
  Candidate   INTEGER NOT NULL REFERENCES Candidate,
  Platz       INTEGER NOT NULL,
  PRIMARY KEY (Landesliste, Candidate)
);

CREATE TABLE VotedOn
(
  Election INTEGER NOT NULL REFERENCES Election,
  Voter    INTEGER NOT NULL REFERENCES Voter,
  PRIMARY KEY (Election, Voter)
);

CREATE TABLE DirectMandate
(
  Election  INTEGER NOT NULL REFERENCES Election,
  Candidate INTEGER NOT NULL REFERENCES Candidate,
  Wahlkreis INTEGER NOT NULL REFERENCES Wahlkreis,
  Party     INTEGER REFERENCES Party,
  PRIMARY KEY (Election, Candidate, Wahlkreis)
);

CREATE TABLE Token
(
  Election  INTEGER   NOT NULL REFERENCES Election,
  Wahlkreis INTEGER   NOT NULL REFERENCES Wahlkreis,
  Token     CHAR(128) NOT NULL,
  PRIMARY KEY (Election, Wahlkreis, Token)
);

