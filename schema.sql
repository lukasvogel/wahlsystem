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
        BirthDate    DATE NOT NULL,
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
        ID          SERIAL PRIMARY KEY,
        FirstName   VARCHAR(60) NOT NULL,
        LastName    VARCHAR(60) NOT NULL,
        BirthYear   SMALLINT NOT NULL
      );

CREATE TABLE Erststimme
      (
        ID          SERIAL PRIMARY KEY,
        isInvalid   BOOLEAN NOT NULL,
        Candidate   INTEGER REFERENCES Candidate,
        Wahlkreis   INTEGER REFERENCES Wahlkreis,
	Election    INTEGER REFERENCES Election
      );

CREATE TABLE Zweitstimme
      (
        ID          SERIAL PRIMARY KEY,
        isInvalid   BOOLEAN NOT NULL,
        Party       INTEGER REFERENCES Party,
        Wahlkreis   INTEGER REFERENCES Wahlkreis,
        Election    INTEGER REFERENCES Election
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

CREATE MATERIALIZED VIEW erststimme_results AS
	(
	SELECT candidate, wahlkreis,election, COUNT(*) FROM erststimme
	GROUP BY candidate,wahlkreis,election
	ORDER BY election, wahlkreis ASC
	);

CREATE UNIQUE INDEX  erststimme_results_id on erststimme_results (candidate,election);


CREATE MATERIALIZED VIEW zweitstimme_results AS
        (
        SELECT Party,wahlkreis,election, COUNT(*) FROM Zweitstimme
        GROUP BY Party,wahlkreis,election
        ORDER BY election, wahlkreis ASC
        );

CREATE UNIQUE INDEX  zweitstimme_results_id on zweitstimme_results (Party,election);

GRANT SELECT ON ALL TABLES IN SCHEMA public TO "analyse";

CREATE OR REPLACE FUNCTION nats(numeric)
  RETURNS SETOF numeric AS
$BODY$
DECLARE
    i NUMERIC;
BEGIN
    FOR i IN 0..$1 loop
        RETURN NEXT i;
    END loop;
    RETURN;
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100
  ROWS 100000;
ALTER FUNCTION nats(numeric)
  OWNER TO postgres;



CREATE OR REPLACE FUNCTION generate_voters(
   wkid integer,
   count integer)
 RETURNS void AS
$BODY$
DECLARE
 BirthDate Date;
BEGIN
   BirthDate := to_date('1900-01-01','YYYY-MM-DD');
   INSERT INTO voter(FirstName,LastName,BirthDate,Address,Gender,Wahlkreis)
  (SELECT R.* FROM (VALUES('FN','LN',BirthDate,'AD','?',wkid)) as R, nats(count));
END;$BODY$
 LANGUAGE plpgsql VOLATILE
 COST 100;
ALTER FUNCTION generate_voters(integer, integer)
 OWNER TO postgres;

CREATE OR REPLACE FUNCTION generate_erststimmen(
    isinvalid boolean,
    pname character varying,
    wkid integer,
    eid integer,
    count integer)
  RETURNS void AS
$BODY$
DECLARE
cID	integer;
BEGIN
  SELECT d.Candidate INTO cID
  FROM directmandate d, party p
  WHERE d.party = p.id
    AND d.wahlkreis = wkID
    AND d.election = eID
    AND p.name = pName;

  INSERT INTO erststimme(isInvalid,Candidate,Wahlkreis,Election)
	(SELECT R.* FROM (VALUES(isInvalid,cID,wkID,eID)) as R, nats(count));
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION generate_erststimmen(boolean, character varying, integer, integer, integer)
  OWNER TO postgres;



CREATE OR REPLACE FUNCTION generate_zweitstimmen(
       isinvalid boolean,
       pname character varying,
       wkid integer,
       eid integer,
       count integer)
     RETURNS void AS
   $BODY$
   DECLARE
   pID	integer;
   BEGIN
     SELECT p.id INTO pID
       FROM party p
     WHERE p.Name = pName;

INSERT INTO zweitstimme(isInvalid,Party,Wahlkreis,Election)
     	(SELECT R.* FROM (VALUES(isInvalid,pID,wkID,eID)) as R, nats(count));

END;$BODY$
     LANGUAGE plpgsql VOLATILE
     COST 100;
   ALTER FUNCTION generate_zweitstimmen(boolean, character varying, integer, integer, integer)
     OWNER TO postgres;
