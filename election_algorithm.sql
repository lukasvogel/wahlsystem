CREATE OR REPLACE FUNCTION lague_coeff(NUMERIC)
  RETURNS SETOF NUMERIC AS
$BODY$
DECLARE
  i NUMERIC;
BEGIN
  FOR i IN 1..$1 LOOP
  RETURN NEXT i - .5;
END loop;
RETURN;
END;
$BODY$
LANGUAGE plpgsql IMMUTABLE STRICT
COST 100
ROWS 1000;
ALTER FUNCTION nats( NUMERIC )
OWNER TO postgres;

CREATE OR REPLACE VIEW votesbyparty AS
  SELECT
    zr_1.election,
    zr_1.party,
    sum(zr_1.count) AS votes
  FROM zweitstimme_results zr_1
  GROUP BY zr_1.election, zr_1.party;

ALTER TABLE votesbyparty
OWNER TO postgres;

CREATE OR REPLACE VIEW totalvotes AS (
  SELECT
    zr2.election,
    sum(zr2.count) AS total
  FROM zweitstimme_results zr2
  GROUP BY zr2.election
);

ALTER TABLE totalvotes
OWNER TO postgres;


/* The winners of a direct mandate */

CREATE OR REPLACE VIEW directmandate_winners AS
  SELECT
    er.election,
    w.bundesland,
    w.id AS wahlkreis,
    d.candidate,
    d.party
  FROM erststimme_results er,
    directmandate d,
    wahlkreis w
  WHERE er.candidate = d.candidate
        AND d.election = er.election
        AND er.wahlkreis = w.id
        AND NOT (EXISTS
  (SELECT
     er2.candidate,
     er2.wahlkreis,
     er2.election,
     er2.count
   FROM erststimme_results er2
   WHERE er2.wahlkreis = er.wahlkreis
         AND er2.election = er.election
         AND er2.count > er.count));

ALTER TABLE directmandate_winners
OWNER TO postgres;


/* The following two VIEWs are needed for the party divisor calculation function */

CREATE OR REPLACE VIEW mandates_party_bland AS
  SELECT
    dw.election,
    dw.bundesland,
    dw.party,
    count(*) AS mandates
  FROM directmandate_winners dw
  GROUP BY dw.election, dw.bundesland, dw.party;

ALTER TABLE mandates_party_bland
OWNER TO postgres;

CREATE OR REPLACE VIEW votes_bundesland AS
  WITH im_bundestag AS (
    SELECT
      v.election,
      v.party
    FROM votesbyparty v,
      totalvotes t
    WHERE v.election = t.election
          AND v.votes >= (t.total * 1.00 / 100 :: NUMERIC * 5 :: NUMERIC)
    UNION
    SELECT
      dw.election,
      dw.party
    FROM directmandate_winners dw
    GROUP BY dw.election, dw.party
    HAVING count(*) >= 3
  )
  SELECT
    zr.election,
    wk.bundesland,
    zr.party,
    sum(zr.count) AS votes
  FROM zweitstimme_results zr,
    wahlkreis wk,
    im_bundestag ib
  WHERE zr.wahlkreis = wk.id
        AND zr.party = ib.party
        AND zr.election = ib.election
  GROUP BY zr.election, wk.bundesland, zr.party;

ALTER TABLE votes_bundesland
OWNER TO postgres;


DROP TYPE IF EXISTS divisorspec CASCADE;
CREATE TYPE divisorspec AS (election INT, party INT, divisor NUMERIC);

CREATE OR REPLACE FUNCTION find_partydivisor()
  RETURNS SETOF divisorspec AS
$BODY$

DECLARE
  lower_bound     NUMERIC := 1;
  /* AT LEAST ONE VOTE PER SEAT */
  upper_bound     NUMERIC := 80000000;
  /* NOT MORE VOTES PER SEAT THAN PEOPLE VOTING */
  row             RECORD;
  cur_divisor     NUMERIC := lower_bound;
  /* INITIAL VALUE */
  cur_total_seats NUMERIC := 0;
  /* INITIAL VALUE */
BEGIN
  CREATE TEMP TABLE mandates_votes AS (
    SELECT
      vb.election,
      votes,
      mandates,
      vb.party
    FROM votes_bundesland vb LEFT JOIN mandates_party_bland mb
        ON vb.bundesland = mb.bundesland
           AND mb.party = vb.party
           AND vb.election = mb.election
  );

  FOR row IN
  SELECT
    sp.election,
    sp.party,
    sp.seats
  FROM seats_by_party sp
  LOOP

    lower_bound := 1;
    upper_bound := 80000000;
    cur_divisor := lower_bound;
    cur_total_seats := 0;

    CREATE TEMP TABLE mandates_votes_instance AS (
      SELECT *
      FROM mandates_votes mv
      WHERE mv.party = row.party
            AND mv.election = row.election
    );

    WHILE NOT cur_total_seats = row.seats LOOP

      cur_total_seats = (SELECT sum(greatest(round(votes / cur_divisor, 0), coalesce(mandates, 0)))
                         FROM mandates_votes_instance);

      /* binary search */
      IF cur_total_seats > row.seats
      THEN
        lower_bound := cur_divisor;
        cur_divisor := (cur_divisor + upper_bound) / 2;
      ELSIF cur_total_seats < row.seats
        THEN
          upper_bound := cur_divisor;
          cur_divisor := (cur_divisor + lower_bound) / 2;

      END IF;

    END LOOP;

    DROP TABLE mandates_votes_instance;

    RETURN NEXT (row.election, row.party, cur_divisor);


  END LOOP;

  DROP TABLE mandates_votes;
  RETURN;
END

$BODY$
LANGUAGE plpgsql VOLATILE
COST 10000
ROWS 1000;
ALTER FUNCTION public.find_partydivisor()
OWNER TO postgres;



CREATE OR REPLACE VIEW seats_by_party AS
  WITH parties_in_bundestag AS /* Parties that may get seats in the bundestag */
  (SELECT
     v.election,
     v.party
   FROM votesbyparty v, totalvotes t
   WHERE v.votes >= (t.total * 1.00 / 100 * 5) /* all parties with more than 5% of total zweitstimmen */
         AND v.election = t.election
   UNION
   SELECT
     election,
     party
   FROM directmandate_winners dw
   GROUP BY election, party
   HAVING count(*) >= 3 /* all parties with 3 or more direct mandates */
   UNION
   SELECT
     election,
     party
   FROM votesbyparty v, party p
   WHERE v.party = p.id
         AND p.isMinorityParty /* all minority parties are exempt from the 5% clause */
  ),

      lague_ranking AS ( /* parties ranked after the sainte-lague procedure by bundesland*/
        SELECT
          election,
          bundesland,
          party,
          rank()
          OVER (PARTITION BY election, bundesland
            ORDER BY votes / c.lague_coeff * 1.00 DESC) AS rank
        FROM votes_bundesland vb,
          (SELECT lague_coeff(300)) AS c /* up to about 128 seats per bundesland, no party will get more than 150*/
    ),

      initial_seats AS ( /* The seats each bundesland should get if voters/seat is the metric*/
        SELECT *
        FROM (VALUES
          (1, 76), /* Baden-Württemberg */
          (2, 92), /* Bayern */
          (3, 24), /* Berlin */
          (4, 19), /* Brandenburg */
          (5, 5), /* Bremen */
          (6, 13), /* Hamburg */
          (7, 43), /* Hessen */
          (8, 13), /* Mecklenburg-Vorpommern */
          (9, 59), /* Niedersachsen */
          (10, 128), /* Nordrhein-Westfalen */
          (11, 30), /* Rheinland-Pfalz */
          (12, 7), /* Saarland */
          (13, 32), /* Sachsen */
          (14, 18), /* Sacshen-Anhalt */
          (15, 22), /* Schleswig-Holstein */
          (16, 17) /* Thüringen */
             ) AS zuteilung(Bundesland, Sitze) /* Sum: 598 Sitze, minimum amount of seats in the Bundestag */
    ),
      pseudodistribution_zw AS ( /* distribution of seats taking no direct mandates into consideration*/
        SELECT
          election,
          r.bundesland,
          party,
          count(*) AS seats
        FROM lague_ranking r, initial_seats a
        WHERE r.bundesland = a.bundesland
              AND rank <= a.sitze
        GROUP BY election, r.bundesland, party
    ),

      pseudodistribution AS ( /* per party and bundesland, the greater number of seats by zweitstimmen and direct mandates */
        SELECT
          pv.election,
          pv.bundesland,
          pv.party,
          greatest(seats, mandates) AS seats
        FROM pseudodistribution_zw pv LEFT JOIN mandates_party_bland m
            ON m.party = pv.party
               AND m.bundesland = pv.bundesland
               AND m.election = pv.election
    ),

      least_num_seats AS ( /* the number of seats each party has to get at least to satisfy all direct mandates */
        SELECT
          election,
          party,
          sum(seats) AS minsitze
        FROM pseudodistribution
        GROUP BY party, election
    ),

      bundesdivisor AS ( /* the amount of votes needed to get one seat */
        SELECT
          vp.election,
          round(min(vp.votes / (m.minsitze - 0.5)),
                2) AS bundesdivisor /* truncate because of possible floating point errors TODO: reason about this carefully! :) */
        FROM least_num_seats m, votesbyparty vp
        WHERE m.party = vp.party
              AND vp.election = m.election
        GROUP BY vp.election
    )
  SELECT
    vp.election,
    vp.party,
    CASE
    WHEN (vp.votes * 1.00 / 2) > totalvotes.votes
      THEN round(totalvotes.votes / (d.bundesdivisor * 2), 0) + 1
    ELSE round(vp.votes / d.bundesdivisor, 0)
    END AS seats,
    bundesdivisor
  FROM votesbyparty vp,
    parties_in_bundestag ib,
    bundesdivisor d,
    (SELECT
       vb.election,
       sum(vb.votes) AS votes
     FROM votes_bundesland vb
     GROUP BY vb.election) totalvotes
  WHERE vp.party = ib.party
        AND totalvotes.election = vp.election
        AND vp.election = ib.election
        AND ib.election = d.election;

/* The view specifying the elected bundestag-candidates for 2013 */
CREATE OR REPLACE VIEW members_of_bundestag AS (


  WITH seats_bland AS ( /* the final amount of seats each party gets in each bundesland */
      SELECT
        vb.election,
        vb.bundesland,
        vb.party,
        greatest(round(votes / divisor, 0), coalesce(mandates, 0)) AS seats
      FROM find_partydivisor() d, votes_bundesland vb LEFT JOIN mandates_party_bland mpb
          ON mpb.bundesland = vb.bundesland
             AND mpb.party = vb.party
             AND mpb.election = vb.election
      WHERE vb.party = d.party
            AND vb.election = d.election
  ),

      rem_cands AS (
      SELECT
        election,
        candidate
      FROM landesliste l, listenplatz lp
      WHERE lp.landesliste = l.id
      EXCEPT
      SELECT
        election,
        candidate
      FROM directmandate_winners dw),

      remaining_cand_on_ll AS ( /* all the candidates on landeslisten that weren't elected by direct mandate */
        SELECT
          l.*,
          lp.candidate,
          rank()
          OVER (PARTITION BY l.id
            ORDER BY platz) platz
        FROM landesliste l, listenplatz lp, rem_cands rc
        WHERE lp.landesliste = l.id
              AND l.election = rc.election
              AND lp.candidate = rc.candidate
    ),

      rem_seats AS (
        SELECT
          sb.election,
          sb.bundesland,
          sb.party,
          sb.seats - coalesce(mpb.mandates, 0) AS seats
        FROM seats_bland sb LEFT JOIN mandates_party_bland mpb
            ON mpb.bundesland = sb.bundesland
               AND mpb.party = sb.party
               AND mpb.election = sb.election
    ),

      members_of_bundestag AS (
      SELECT
        election,
        bundesland,
        candidate,
        party
      FROM directmandate_winners dw
      UNION
      SELECT
        election,
        rc.bundesland,
        rc.candidate,
        rc.party
      FROM remaining_cand_on_ll rc
      WHERE rc.platz <= (SELECT seats
                         FROM rem_seats rm
                         WHERE rm.bundesland = rc.bundesland
                               AND rm.party = rc.party
                               AND rm.election = rc.election)
    )
  SELECT
    bm.election,
    c.id,
    c.firstname,
    c.lastname,
    p.name AS party,
    b.name AS bundesland
  FROM members_of_bundestag bm, party p, candidate c, bundesland b
  WHERE bm.bundesland = b.id
        AND bm.candidate = c.id
        AND bm.party = p.id
  ORDER BY lastname
);

GRANT SELECT ON ALL TABLES IN SCHEMA public TO "analyse";

