CREATE OR REPLACE FUNCTION generate_voters(
  wkid      INTEGER,
  election  INTEGER,
  count     INTEGER,
  haveVoted INTEGER
)
  RETURNS VOID AS
$BODY$
DECLARE
  BirthDate DATE;
BEGIN
  BirthDate := to_date('1900-01-01', 'YYYY-MM-DD');
  IF count > haveVoted
  THEN
    INSERT INTO voter (FirstName, LastName, BirthDate, Address, Gender, Wahlkreis, FirstValidElection, LastVotedOn, LastValidElection)
      (
        (SELECT R.*
         FROM
           (VALUES ('FN', 'LN', BirthDate, 'AD', '?', wkid, election, election, NULL :: INTEGER)) AS R, generate_series(1,haveVoted))
        UNION ALL
        (SELECT R.*
         FROM (VALUES ('FN', 'LN', BirthDate, 'AD', '?', wkid, election, NULL :: INTEGER, NULL :: INTEGER)) AS R,
           generate_series(1,count - haveVoted))
      );
  ELSE
    INSERT INTO voter (FirstName, LastName, BirthDate, Address, Gender, Wahlkreis, FirstValidElection, LastVotedOn, LastValidElection)
      (SELECT R.*
       FROM (VALUES ('FN', 'LN', BirthDate, 'AD', '?', wkid, election, NULL :: INTEGER, NULL :: INTEGER)) AS R,
         generate_series(1,count));

    UPDATE voter
    SET LastVotedOn = election
    WHERE id IN (
      SELECT id
      FROM (
             SELECT id
             FROM voter
             WHERE LastVotedOn < election
             AND wahlkreis = wkid
             LIMIT haveVoted
           ) tmp
    );

  END IF;
END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
ALTER FUNCTION generate_voters( INTEGER, INTEGER, INTEGER, INTEGER )
OWNER TO postgres;
;


CREATE OR REPLACE FUNCTION kill_voters(
  wkid      INTEGER,
  lastElectionAlive  INTEGER,
  count     INTEGER
  )
  RETURNS VOID AS
$BODY$
DECLARE
BEGIN
    UPDATE voter
    SET LastValidElection = lastElectionAlive
    WHERE id IN (
      SELECT id
      FROM (
             SELECT id
             FROM voter
             WHERE LastVotedOn <= lastElectionAlive
             AND FirstValidElection <= lastElectionAlive
             AND wahlkreis = wkid
             LIMIT count
           ) tmp
    );
END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
ALTER FUNCTION kill_voters( INTEGER, INTEGER, INTEGER )
OWNER TO postgres;
;


CREATE OR REPLACE FUNCTION generate_erststimmen(
  isinvalid BOOLEAN,
  pname     CHARACTER VARYING,
  wkid      INTEGER,
  eid       INTEGER,
  count     INTEGER)
  RETURNS VOID AS
$BODY$
DECLARE
  cID INTEGER;
BEGIN
  SELECT d.Candidate,'0'
  INTO cID
  FROM directmandate d, party p
  WHERE d.party = p.id
        AND d.wahlkreis = wkID
        AND d.election = eID
        AND p.name = pName;

  INSERT INTO erststimme (isInvalid, Candidate, Wahlkreis, Election)
    (SELECT isinvalid, COALESCE(cID,'0'), wkID, eID
     FROM (VALUES (isInvalid,cID, wkID, eID)) AS R, generate_series(1,count));
END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
ALTER FUNCTION generate_erststimmen( BOOLEAN, CHARACTER VARYING, INTEGER, INTEGER, INTEGER )
OWNER TO postgres;


CREATE OR REPLACE FUNCTION generate_zweitstimmen(
  isinvalid BOOLEAN,
  pname     CHARACTER VARYING,
  wkid      INTEGER,
  eid       INTEGER,
  count     INTEGER)
  RETURNS VOID AS
$BODY$
DECLARE
  pID INTEGER;
BEGIN
  SELECT  p.id
  INTO pID
  FROM party p
  WHERE p.Name = pName;

  INSERT INTO zweitstimme (isInvalid, Party, Wahlkreis, Election)
    (SELECT R.*
     FROM (VALUES (isInvalid, COALESCE(pID,'0'), wkID, eID)) AS R, generate_series(1,count));

END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
ALTER FUNCTION generate_zweitstimmen( BOOLEAN, CHARACTER VARYING, INTEGER, INTEGER, INTEGER )
OWNER TO postgres;

-- Function: generate_erststimmen(boolean, character varying, integer, integer, integer)

-- DROP FUNCTION generate_erststimmen(boolean, character varying, integer, integer, integer);

CREATE OR REPLACE FUNCTION generate_uebrige(
  wkid  INTEGER,
  eid   INTEGER,
  count INTEGER)
  RETURNS VOID AS
$BODY$
DECLARE
  cIDs       INTEGER [];
  cID        INTEGER;
  candidates INTEGER;
BEGIN
  SELECT array_agg(d.Candidate)
  INTO cIDs
  FROM directmandate d
  WHERE d.party IS NULL
        AND d.wahlkreis = wkID
        AND d.election = eID;

  candidates = array_length(cIDs, 1);

  IF candidates > 0
  THEN
    FOR i IN 0..candidates LOOP
      INSERT INTO erststimme (isInvalid, Candidate, Wahlkreis, Election)
        (SELECT R.*
         FROM (VALUES (FALSE, COALESCE(cIDs [i],'0'), wkID, eID)) AS R, generate_series(1,count / candidates));
    END LOOP;

    INSERT INTO erststimme (isInvalid, Candidate, Wahlkreis, Election)
      (SELECT R.*
       FROM (VALUES (FALSE, cIDs [0], wkID, eID)) AS R, generate_series(1,count % candidates));
  END IF;

END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
ALTER FUNCTION generate_erststimmen( BOOLEAN, CHARACTER VARYING, INTEGER, INTEGER, INTEGER )
OWNER TO postgres;

