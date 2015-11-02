CREATE TABLE Election
      (
        ID          INTEGER PRIMARY KEY,
        Date        DATE NOT NULL
      );

CREATE TABLE Bundesland
      (
        ID          INTEGER PRIMARY KEY,
        Name        VARCHAR(30) NOT NULL
      );

CREATE TABLE Wahlkreis
      (
        ID          INTEGER PRIMARY KEY,
        Name        VARCHAR(60) NOT NULL,
        Bundesland  INTEGER NOT NULL REFERENCES Bundesland
      );

CREATE TABLE Voter
      (
        ID          INTEGER PRIMARY KEY,
        FirstName   VARCHAR(60) NOT NULL,
        LastName    VARCHAR(60) NOT NULL,
        Birthday    DATE NOT NULL,
        Adress      VARCHAR(100) NOT NULL,
        Gender      CHAR(1) NOT NULL,
        Wahlkreis   INTEGER NOT NULL REFERENCES Wahlkreis
      );

CREATE TABLE Party
      (
        ID          INTEGER PRIMARY KEY,
        Name        VARCHAR(30) NOT NULL
      );

CREATE TABLE Candidate
      (
        ID          INTEGER PRIMARY KEY REFERENCES Voter,
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
        ID          INTEGER PRIMARY KEY,
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
