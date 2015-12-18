CREATE OR REPLACE FUNCTION nats(NUMERIC)
  RETURNS SETOF NUMERIC AS
$BODY$
DECLARE
  i NUMERIC;
BEGIN
  FOR i IN 1..$1 LOOP
  RETURN NEXT i;
END loop;
RETURN;
END;
$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT
COST 100
ROWS 100000;
ALTER FUNCTION nats( NUMERIC )
OWNER TO postgres;

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
           (VALUES ('FN', 'LN', BirthDate, 'AD', '?', wkid, election, election, NULL :: INTEGER)) AS R, nats(haveVoted))
        UNION ALL
        (SELECT R.*
         FROM (VALUES ('FN', 'LN', BirthDate, 'AD', '?', wkid, election, NULL :: INTEGER, NULL :: INTEGER)) AS R,
           nats(count - haveVoted))
      );
  ELSE
    INSERT INTO voter (FirstName, LastName, BirthDate, Address, Gender, Wahlkreis, FirstValidElection, LastVotedOn, LastValidElection)
      (SELECT R.*
       FROM (VALUES ('FN', 'LN', BirthDate, 'AD', '?', wkid, election, NULL :: INTEGER, NULL :: INTEGER)) AS R,
         nats(count));

    UPDATE voter
    SET LastVotedOn = election
    WHERE id IN (
      SELECT id
      FROM (
             SELECT id
             FROM voter
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
     FROM (VALUES (isInvalid,cID, wkID, eID)) AS R, nats(count));
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
     FROM (VALUES (isInvalid, COALESCE(pID,'0'), wkID, eID)) AS R, nats(count));

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
         FROM (VALUES (FALSE, COALESCE(cIDs [i],'0'), wkID, eID)) AS R, nats(count / candidates));
    END LOOP;

    INSERT INTO erststimme (isInvalid, Candidate, Wahlkreis, Election)
      (SELECT R.*
       FROM (VALUES (FALSE, cIDs [0], wkID, eID)) AS R, nats(count % candidates));
  END IF;

END;$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;
ALTER FUNCTION generate_erststimmen( BOOLEAN, CHARACTER VARYING, INTEGER, INTEGER, INTEGER )
OWNER TO postgres;

