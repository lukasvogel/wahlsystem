DROP TABLE DirectMandates CASCADE;
DROP TABLE VotedOn CASCADE;
DROP TABLE Listenplatz CASCADE;
DROP TABLE Landesliste;
DROP TABLE Zweitstimme;
DROP TABLE Erststimme;
DROP TABLE Candidate;
DROP TABLE Party;
DROP TABLE Voter;
DROP TABLE Wahlkreis;
DROP TABLE Bundesland;
DROP TABLE Election;


CREATE TABLE Election
      (
        ID          SERIAL PRIMARY KEY,
        Date        DATE NOT NULL
      );

CREATE TABLE Bundesland
      (
        ID          SERIAL PRIMARY KEY,
        Name        VARCHAR(30) NOT NULL
      );

CREATE TABLE Wahlkreis
      (
        ID          SERIAL PRIMARY KEY,
        Name        VARCHAR(150) NOT NULL,
        Bundesland  INTEGER NOT NULL REFERENCES Bundesland
      );

CREATE TABLE Voter
      (
        ID          SERIAL PRIMARY KEY,
        FirstName   VARCHAR(60) NOT NULL,
        LastName    VARCHAR(60) NOT NULL,
        BirthYear    SMALLINT NOT NULL,
        Address      VARCHAR(100) NOT NULL,
        Gender      CHAR(1) NOT NULL,
        Wahlkreis   INTEGER NOT NULL REFERENCES Wahlkreis
      );

CREATE TABLE Party
      (
        ID          SERIAL PRIMARY KEY,
        Name        VARCHAR(30) NOT NULL
      );

CREATE TABLE Candidate
      (
        ID          SERIAL PRIMARY KEY REFERENCES Voter,
        Profession  VARCHAR(30) NOT NULL,
        Party       INTEGER REFERENCES Party
      );

CREATE TABLE Erststimme
      (
        ID          INTEGER PRIMARY KEY,
        isInvalid   BOOLEAN NOT NULL,
        Candidate   INTEGER REFERENCES Candidate,
        Wahlkreis   INTEGER REFERENCES Wahlkreis
      );

CREATE TABLE Zweitstimme
      (
        ID          INTEGER PRIMARY KEY,
        isInvalid   BOOLEAN NOT NULL,
        Party       INTEGER REFERENCES Party,
        Wahlkreis   INTEGER REFERENCES Wahlkreis
      );

CREATE TABLE Landesliste
      (
        ID          SERIAL PRIMARY KEY,
        Party       INTEGER NOT NULL REFERENCES Party,
        Election    INTEGER NOT NULL REFERENCES Election,
        Bundesland  INTEGER NOT NULL REFERENCES Bundesland
      );

CREATE TABLE Listenplatz
      (
        Landesliste INTEGER NOT NULL REFERENCES  Landesliste,
        Candidate   INTEGER NOT NULL REFERENCES Candidate,
        Platz       INTEGER NOT NULL,
        PRIMARY KEY (Landesliste,Candidate)
      );

CREATE TABLE VotedOn
      (
        Election    INTEGER NOT NULL REFERENCES Election,
        Voter       INTEGER NOT NULL REFERENCES Voter,
        PRIMARY KEY (Election,Voter)
      );

CREATE TABLE DirectMandates
      (
        Election    INTEGER NOT NULL REFERENCES Election,
        Candidate   INTEGER NOT NULL REFERENCES Candidate,
        Wahlkreis   INTEGER NOT NULL REFERENCES Wahlkreis,
        PRIMARY KEY (Election,Candidate,Wahlkreis)
      );
