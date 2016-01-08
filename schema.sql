DROP TABLE IF EXISTS DirectMandate CASCADE;
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

DROP INDEX IF EXISTS zw_index CASCADE;
DROP INDEX IF EXISTS er_index CASCADE;

CREATE TABLE Election
(
  ID   SERIAL PRIMARY KEY,
  Date DATE NOT NULL
);

CREATE TABLE Bundesland
(
  ID   SERIAL PRIMARY KEY,
  Name VARCHAR(30) NOT NULL
);

CREATE TABLE Wahlkreis
(
  ID         SERIAL PRIMARY KEY,
  Name       VARCHAR(150) NOT NULL,
  Bundesland INTEGER      NOT NULL REFERENCES Bundesland
);

CREATE TABLE Voter
(
  ID                 SERIAL PRIMARY KEY,
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
  ID              SERIAL PRIMARY KEY,
  Name            VARCHAR(30) NOT NULL,
  isMinorityParty BOOLEAN
);
INSERT INTO Party VALUES (0, 'dummy', FALSE);


CREATE TABLE Candidate
(
  ID        SERIAL PRIMARY KEY,
  FirstName VARCHAR(60) NOT NULL,
  LastName  VARCHAR(60) NOT NULL,
  BirthYear SMALLINT    NOT NULL
);

INSERT INTO Candidate VALUES (0, 'dummy', 'dummy', '1900');

CREATE TABLE Erststimme
(
  ID        SERIAL,
  isInvalid BOOLEAN NOT NULL,
  Candidate INTEGER REFERENCES Candidate,
  Wahlkreis INTEGER REFERENCES Wahlkreis,
  Election  INTEGER REFERENCES Election
);

CREATE TABLE Zweitstimme
(
  ID        SERIAL,
  isInvalid BOOLEAN NOT NULL,
  Party     INTEGER REFERENCES Party,
  Wahlkreis INTEGER REFERENCES Wahlkreis,
  Election  INTEGER REFERENCES Election
);

CREATE TABLE Landesliste
(
  ID         SERIAL PRIMARY KEY,
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

CREATE MATERIALIZED VIEW erststimme_results AS
  (
    SELECT
      candidate,
      wahlkreis,
      election,
      COUNT(*)
    FROM erststimme
    WHERE isInvalid = FALSE
    GROUP BY candidate, wahlkreis, election
  );

CREATE UNIQUE INDEX erststimme_results_id ON erststimme_results (candidate, election, wahlkreis);


CREATE MATERIALIZED VIEW zweitstimme_results AS
  (
    SELECT
      Party,
      wahlkreis,
      election,
      COUNT(*)
    FROM Zweitstimme
    WHERE isInvalid = FALSE
    GROUP BY Party, wahlkreis, election
  );

CREATE UNIQUE INDEX zweitstimme_results_id ON zweitstimme_results (Party, election, wahlkreis);


CREATE MATERIALIZED VIEW erststimme_invalid AS
  SELECT
    wahlkreis,
    election,
    count(*)
  FROM erststimme
  WHERE isInvalid = TRUE
  GROUP BY election, wahlkreis;

CREATE MATERIALIZED VIEW zweitstimme_invalid AS
  SELECT
    wahlkreis,
    election,
    count(*)
  FROM zweitstimme
  WHERE isInvalid = TRUE
  GROUP BY election, wahlkreis;

CREATE MATERIALIZED VIEW wahlberechtigte AS
  SELECT
    e.id AS election,
    v.wahlkreis,
    count(v.id)
  FROM election e, voter v
  WHERE e.id >= v.firstvalidelection
        AND e.id <= coalesce(v.lastvalidelection, e.id)
  GROUP BY e.id, v.wahlkreis;


CREATE ROLE "analyse" WITH LOGIN;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO "analyse";
