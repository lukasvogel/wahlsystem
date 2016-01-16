
CREATE TABLE erststimme_results AS
  (
    SELECT
      candidate,
      wahlkreis,
      election,
      COUNT(*)
    FROM erststimme
    WHERE isInvalid = FALSE
    GROUP BY candidate, wahlkreis, election
  );

CREATE INDEX erststimme_results_id ON erststimme_results (candidate, election, wahlkreis);


CREATE TABLE zweitstimme_results AS
  (
    SELECT
      Party,
      wahlkreis,
      election,
      COUNT(*)
    FROM Zweitstimme
    WHERE isInvalid = FALSE
    GROUP BY Party, wahlkreis, election
  );

CREATE INDEX zweitstimme_results_id ON zweitstimme_results (Party, election, wahlkreis);


CREATE TABLE erststimme_invalid AS
  SELECT
    wahlkreis,
    election,
    count(*)
  FROM erststimme
  WHERE isInvalid = TRUE
  GROUP BY election, wahlkreis;

CREATE TABLE zweitstimme_invalid AS
  SELECT
    wahlkreis,
    election,
    count(*)
  FROM zweitstimme
  WHERE isInvalid = TRUE
  GROUP BY election, wahlkreis;

CREATE TABLE wahlberechtigte AS
  SELECT
    e.id AS election,
    v.wahlkreis,
    count(v.id)
  FROM election e, voter v
  WHERE e.id >= v.firstvalidelection
        AND e.id <= coalesce(v.lastvalidelection, e.id)
  GROUP BY e.id, v.wahlkreis;
