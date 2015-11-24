CREATE VIEW wahlbeteiligung AS (
  WITH valid_zr_votes AS (
    SELECT zr.election, zr.wahlkreis, sum(count) as votes
    FROM zweitstimme_results zr
    GROUP BY zr.election, zr.wahlkreis
  ),
  valid_er_votes AS (
    SELECT er.election, er.wahlkreis, sum(count) as votes
    FROM erststimme_results er
    GROUP BY er.election, er.wahlkreis)

SELECT ev.election, w.wahlkreis, round(greatest(zv.votes+zi.count,ev.votes+vi.count) / w.count * 100,1) as wahlbeteiligung
FROM wahlberechtigte w, valid_zr_votes zv, valid_er_votes ev, erststimme_invalid vi, zweitstimme_invalid zi
WHERE w.wahlkreis = ev.wahlkreis
AND zv.election = ev.election
AND zv.wahlkreis = ev.wahlkreis
AND w.election = ev.election
AND vi.election = ev.election
AND zi.election = ev.election
AND vi.wahlkreis = w.wahlkreis
AND zi.wahlkreis = w.wahlkreis
order by wahlbeteiligung desc
);

CREATE OR REPLACE VIEW closest_winners AS (
  WITH ranking AS (
	SELECT r.election, r.wahlkreis, r.count
	FROM (
	          SELECT er.election, er.wahlkreis, count, rank() over (partition by election, wahlkreis order by count DESC)
	          FROM erststimme_results er
            ) as r
	WHERE rank = 2)

  SELECT
    c.firstname,
    c.lastname,
    dw.party,
    w.id               AS wahlkreis,
    w.name             AS wname,
    er.count - r.count AS difference
  FROM ranking r, directmandate_winners dw, erststimme_results er, candidate c, wahlkreis w
            WHERE dw.wahlkreis = r.wahlkreis
            AND r.election = 2
            AND er.election = r.election
            AND er.wahlkreis = r.wahlkreis
            AND er.candidate = dw.candidate
            AND c.id = dw.candidate
            AND w.id = dw.wahlkreis
            order by difference asc
);

CREATE OR REPLACE VIEW closest_losers AS (
  SELECT
    c.firstname,
    c.lastname,
    d.party,
    w.id                             AS wahlkreis,
    w.name                           AS wname,
    er_loser.count - er_winner.count AS difference
  FROM directmandate_winners dw, erststimme_results er_winner,
    directmandate d, erststimme_results er_loser,
    candidate c, wahlkreis w
  WHERE d.election = 2
        AND er_winner.candidate = dw.candidate
        AND er_winner.election = 2
        AND er_loser.candidate = d.candidate
        AND er_loser.election = d.election
        AND dw.wahlkreis = d.wahlkreis
        AND dw.candidate <> d.candidate
        AND c.id = d.candidate
        AND w.id = d.wahlkreis
  ORDER BY difference DESC
);

GRANT SELECT ON ALL TABLES IN SCHEMA public TO "analyse";
