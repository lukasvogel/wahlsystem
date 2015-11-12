CREATE OR REPLACE FUNCTION nats(numeric)
  RETURNS SETOF numeric AS
$BODY$
DECLARE
    i NUMERIC;
BEGIN
    FOR i IN 1..$1 loop
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
