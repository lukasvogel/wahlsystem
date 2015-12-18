DROP TABLE IF EXISTS erststimme_with_trigger;

CREATE TABLE erststimme_with_trigger
(
  Candidate INTEGER REFERENCES Candidate,
  Wahlkreis INTEGER REFERENCES Wahlkreis,
  Election  INTEGER REFERENCES Election,
  isInvalid BOOLEAN,
  Count     INTEGER DEFAULT 0,
  CONSTRAINT has_votes CHECK (count > 0),
  PRIMARY KEY (Candidate, Wahlkreis, Election, isInvalid)
);


CREATE FUNCTION count_increment()
  RETURNS TRIGGER AS $_$
BEGIN
  INSERT INTO erststimme_with_trigger AS ewt (candidate, wahlkreis, election, isInvalid, count)
  VALUES (NEW.candidate, NEW.wahlkreis, NEW.election, NEW.isinvalid, 1)
  ON CONFLICT ON CONSTRAINT erststimme_with_trigger_pkey DO UPDATE SET count = ewt.count + 1
WHERE ewt.candidate = NEW.candidate
AND ewt.wahlkreis = NEW.wahlkreis
AND ewt.election = NEW.election;
  RETURN NEW;
END $_$ LANGUAGE 'plpgsql';

/*
CREATE FUNCTION count_decrement()
  RETURNS TRIGGER AS $_$
BEGIN
  UPDATE erststimme_with_trigger AS ewt
  SET count = ewt.count - 1
  WHERE ewt.candidate = OLD.candidate
        AND ewt.wahlkreis = OLD.wahlkreis
        AND ewt.election = OLD.election
  ON CONFLICT ON CONSTRAINT has_votes
  DO DELETE FROM ewt
WHERE ewt.candidate = OLD.candidate
      AND ewt.wahlkreis = OLD.wahlkreis
      AND ewt.election = OLD.election;
RETURN OLD;
END $_$ LANGUAGE 'plpgsql';
CREATE TRIGGER erststimme_remove_trig AFTER DELETE ON erststimme FOR EACH ROW EXECUTE PROCEDURE count_decrement();
*/

CREATE TRIGGER erststimme_add_trig AFTER INSERT ON erststimme FOR EACH ROW EXECUTE PROCEDURE count_increment();
