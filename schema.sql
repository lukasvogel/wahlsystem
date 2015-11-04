DROP TABLE IF EXISTS DirectMandate CASCADE;
DROP TABLE IF EXISTS VotedOn CASCADE;
DROP TABLE IF EXISTS Listenplatz CASCADE;
DROP TABLE IF EXISTS Landesliste;
DROP TABLE IF EXISTS Zweitstimme;
DROP TABLE IF EXISTS Erststimme;
DROP TABLE IF EXISTS Candidate;
DROP TABLE IF EXISTS Party;
DROP TABLE IF EXISTS Voter;
DROP TABLE IF EXISTS Wahlkreis;
DROP TABLE IF EXISTS Bundesland;
DROP TABLE IF EXISTS Election;


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

CREATE TABLE DirectMandate
      (
        Election    INTEGER NOT NULL REFERENCES Election,
        Candidate   INTEGER NOT NULL REFERENCES Candidate,
        Wahlkreis   INTEGER NOT NULL REFERENCES Wahlkreis,
        Party       INTEGER REFERENCES Party,
        PRIMARY KEY (Election,Candidate,Wahlkreis)
      );
