CREATE VIEW wahlbeteiligung AS (
  WITH valid_zr_votes AS (
      SELECT
        zr.election,
        zr.wahlkreis,
        sum(count) AS votes
      FROM zweitstimme_results zr
      GROUP BY zr.election, zr.wahlkreis
  ),
      valid_er_votes AS (
        SELECT
          er.election,
          er.wahlkreis,
          sum(count) AS votes
        FROM erststimme_results er
        GROUP BY er.election, er.wahlkreis)

  SELECT
    ev.election,
    w.wahlkreis,
    round(greatest(zv.votes + zi.count, ev.votes + vi.count) / w.count * 100, 1) AS wahlbeteiligung
  FROM wahlberechtigte w, valid_zr_votes zv, valid_er_votes ev, erststimme_invalid vi, zweitstimme_invalid zi
  WHERE w.wahlkreis = ev.wahlkreis
        AND zv.election = ev.election
        AND zv.wahlkreis = ev.wahlkreis
        AND w.election = ev.election
        AND vi.election = ev.election
        AND zi.election = ev.election
        AND vi.wahlkreis = w.wahlkreis
        AND zi.wahlkreis = w.wahlkreis
  ORDER BY wahlbeteiligung DESC
);

CREATE OR REPLACE VIEW closest_winners AS (
  WITH ranking AS (
      SELECT
        r.election,
        r.wahlkreis,
        r.count
      FROM (
             SELECT
               er.election,
               er.wahlkreis,
               count,
               rank()
               OVER (PARTITION BY election, wahlkreis
                 ORDER BY count DESC)
             FROM erststimme_results er
           ) AS r
      WHERE rank = 2)

  SELECT
    dw.election,
    c.firstname,
    c.lastname,
    dw.party,
    w.id               AS wahlkreis,
    w.name             AS wname,
    er.count - r.count AS difference
  FROM ranking r, directmandate_winners dw, erststimme_results er, candidate c, wahlkreis w
  WHERE dw.wahlkreis = r.wahlkreis
        AND er.election = r.election
        AND dw.election = r.election
        AND er.wahlkreis = r.wahlkreis
        AND er.candidate = dw.candidate
        AND c.id = dw.candidate
        AND w.id = dw.wahlkreis
  ORDER BY difference ASC
);

CREATE OR REPLACE VIEW closest_losers AS (
  SELECT
    d.election,
    c.firstname,
    c.lastname,
    d.party,
    w.id                             AS wahlkreis,
    w.name                           AS wname,
    er_loser.count - er_winner.count AS difference
  FROM directmandate_winners dw, erststimme_results er_winner,
    directmandate d, erststimme_results er_loser,
    candidate c, wahlkreis w
  WHERE er_winner.candidate = dw.candidate
        AND er_winner.election = dw.election
        AND er_loser.election = dw.election
        AND er_loser.election = d.election
        AND dw.wahlkreis = d.wahlkreis
        AND er_loser.candidate = d.candidate
        AND dw.candidate <> d.candidate
        AND c.id = d.candidate
        AND w.id = d.wahlkreis
  ORDER BY difference DESC
);


CREATE OR REPLACE VIEW overhang_mandates AS (
  WITH lague_ranking AS ( /* parties ranked after the sainte-lague procedure by bundesland*/
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
    )

  SELECT
    mpb.*,
    mpb.mandates - pd.seats AS overhang
  FROM
    mandates_party_bland mpb,
    pseudodistribution_zw pd
  WHERE mpb.bundesland = pd.bundesland
        AND pd.party = mpb.party
        AND pd.election = mpb.election
        AND mpb.mandates > pd.seats
);
/*
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "analyse";
*/