CREATE OR REPLACE FUNCTION lague_coeff(numeric)
  RETURNS SETOF numeric AS
$BODY$
DECLARE
    i NUMERIC;
BEGIN
    FOR i IN 1..$1 loop
        RETURN NEXT i - .5;
    END loop;
    RETURN;
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT
  COST 100
  ROWS 100000;
ALTER FUNCTION nats(numeric)
  OWNER TO postgres;


/* The following two VIEWs are needed for the party divisor calculation function */

CREATE OR REPLACE VIEW mandates_party_bland AS
 WITH directmandate_winners AS (
         SELECT w.bundesland,
            w.id AS wahlkreis,
            d.candidate,
            d.party
           FROM erststimme_results er,
            directmandate d,
            wahlkreis w
          WHERE er.candidate = d.candidate AND d.election = 2 AND er.wahlkreis = w.id AND er.election = 2 AND NOT (EXISTS ( SELECT er2.candidate,
                    er2.wahlkreis,
                    er2.election,
                    er2.count
                   FROM erststimme_results er2
                  WHERE er2.wahlkreis = er.wahlkreis AND er2.election = 2 AND er2.count > er.count))
        )
 SELECT dw.bundesland,
    dw.party,
    count(*) AS mandates
   FROM directmandate_winners dw
  GROUP BY dw.bundesland, dw.party;

ALTER TABLE mandates_party_bland
  OWNER TO postgres;

CREATE OR REPLACE VIEW votes_bundesland AS
 WITH votesbyparty AS (
         SELECT zr_1.party,
            sum(zr_1.count) AS votes
           FROM zweitstimme_results zr_1
          WHERE zr_1.election = 2
          GROUP BY zr_1.party
        ), totalvotes AS (
         SELECT sum(zr2.count) AS total
           FROM zweitstimme_results zr2
          WHERE zr2.election = 2
        ), directmandate_winners AS (
         SELECT w.bundesland,
            w.id AS wahlkreis,
            d.candidate,
            d.party
           FROM erststimme_results er,
            directmandate d,
            wahlkreis w
          WHERE er.candidate = d.candidate AND d.election = 2 AND er.wahlkreis = w.id AND er.election = 2 AND NOT (EXISTS ( SELECT er2.candidate,
                    er2.wahlkreis,
                    er2.election,
                    er2.count
                   FROM erststimme_results er2
                  WHERE er2.wahlkreis = er.wahlkreis AND er2.election = 2 AND er2.count > er.count))
        ), im_bundestag AS (
         SELECT v.party
           FROM votesbyparty v,
            totalvotes t
          WHERE v.votes >= (t.total * 1.00 / 100::numeric * 5::numeric)
        UNION
         SELECT directmandate_winners.party
           FROM directmandate_winners
          GROUP BY directmandate_winners.party
         HAVING count(*) >= 3
        )
 SELECT wk.bundesland,
    zr.party,
    sum(zr.count) AS votes
   FROM zweitstimme_results zr,
    wahlkreis wk,
    im_bundestag ib
  WHERE zr.wahlkreis = wk.id AND zr.party = ib.party AND zr.election = 2
  GROUP BY wk.bundesland, zr.party;

ALTER TABLE votes_bundesland
  OWNER TO postgres;




/* A function that finds a valid party divisor for a given party and number of seats
    using the views votes_bundesland and mandates_party_bland */
CREATE OR REPLACE FUNCTION find_partydivisor(
    partyID integer,
    seats_to_distribute numeric)
  RETURNS numeric AS
$BODY$

DECLARE
	total_votes INTEGER := (select sum(votes) from votes_bundesland vb where vb.party = partyID);
	lower_bound NUMERIC := total_votes / seats_to_distribute;
	upper_bound NUMERIC := 1 + (select max(votes) from votes_bundesland vb where vb.party = partyID);

	cur_divisor NUMERIC := lower_bound; /* INITIAL VALUE */
	cur_total_seats NUMERIC := 0; /* INITIAL VALUE */
BEGIN
	CREATE TEMP TABLE mandates_votes AS (
		select votes, mandates
		from votes_bundesland vb left join mandates_party_bland mb
						on vb.bundesland = mb.bundesland and mb.party = vb.party
						where vb.party = partyID
	);

	WHILE not cur_total_seats = seats_to_distribute LOOP


		cur_total_seats = (select sum(greatest(round( votes / cur_divisor, 0), coalesce(mandates,0)))
						from mandates_votes);

		/* binary search */
		IF cur_total_seats > seats_to_distribute THEN
			lower_bound := cur_divisor;
			cur_divisor := (cur_divisor + upper_bound) / 2;
		ELSIF cur_total_seats < seats_to_distribute THEN
			upper_bound := cur_divisor;
			cur_divisor := (cur_divisor + lower_bound) / 2;

		END IF;

	END LOOP;

	DROP TABLE mandates_votes;
	RETURN cur_divisor;

END

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  ALTER FUNCTION find_partydivisor(integer, numeric)
    OWNER TO postgres;




/* The view specifying the elected bundestag-candidates for 2013 */
CREATE OR REPLACE VIEW members_of_bundestag_2013 AS (

with votesbyparty as
	(select zr.party, sum(count) as votes
	from zweitstimme_results zr
	where zr.election = 2
	group by zr.party),

    totalvotes AS (
         select sum(zr2.count) AS total
         from zweitstimme_results zr2
         where zr2.election = 2
        ),


     directmandate_winners as ( /* The winners of a direct mandate in each wahlkreis and his party (if he has one) */
	select w.bundesland, w.id as wahlkreis, d.candidate, d.party
	from erststimme_results er, directmandate d, wahlkreis w
	where er.candidate = d.candidate
	and d.election = 2
	and er.wahlkreis = w.id
	and er.election = 2
	and not exists (
		select *
		from erststimme_results er2
		where er2.wahlkreis = er.wahlkreis
		and er2.election = 2
		and er2.count > er.count)
     ),

    parties_in_bundestag as /* Parties that may get seats in the bundestag */
	(select v.party
	from votesbyparty v, totalvotes t
	where v.votes >= (t.total * 1.00 / 100 * 5) /* all parties with more than 5% of total zweitstimmen */
	UNION
	select party
	from directmandate_winners
	group by party
	having count(*) >= 3 /* all parties with 3 or more direct mandates */
	/* TODO: get minderheitsparteien */
	),

    votes_bundesland as ( /* votes per bundesland and party */
	select wk.bundesland,zr.party, sum(count) as votes
	from zweitstimme_results zr, wahlkreis wk, parties_in_bundestag ib
	where zr.wahlkreis = wk.id
	and zr.party = ib.party
	and zr.election = 2
	group by wk.bundesland,zr.party),

     lague_ranking as ( /* parties ranked after the sainte-lague procedure by bundesland*/
	select bundesland, party, rank() over (partition by bundesland order by votes / c.lague_coeff * 1.00 desc) as rank
	from votes_bundesland, (select lague_coeff(150)) as c /* up to about 128 seats per bundesland, no party will get more than 150*/
     ),

     initial_seats as ( /* The seats each bundesland should get if voters/seat is the metric*/
	select *
	from (values
	(1,76), /* Baden-Württemberg */
	(2,92), /* Bayern */
	(3,24), /* Berlin */
	(4,19), /* Brandenburg */
	(5,5), /* Bremen */
	(6,13), /* Hamburg */
	(7,43), /* Hessen */
	(8,13), /* Mecklenburg-Vorpommern */
	(9,59), /* Niedersachsen */
	(10,128), /* Nordrhein-Westfalen */
	(11,30), /* Rheinland-Pfalz */
	(12,7), /* Saarland */
	(13,32), /* Sachsen */
	(14,18), /* Sacshen-Anhalt */
	(15,22), /* Schleswig-Holstein */
	(16,17) /* Thüringen */
	) as zuteilung(Bundesland,Sitze) /* Sum: 598 Sitze, minimum amount of seats in the Bundestag */
     ),

     mandates_party_bland as ( /* amount of direct mandates per party and bundesland */
	select bundesland, party, count(*) as mandates
	from directmandate_winners dw
	group by bundesland, party
     ),

     pseudodistribution_zw as ( /* distribution of seats taking no direct mandates into consideration*/
	select r.bundesland, party, count(*) as seats
	from lague_ranking r, initial_seats a
	where r.bundesland = a.bundesland
	and rank <= a.sitze
	group by r.bundesland,party
     ),

     pseudodistribution as ( /* per party and bundesland, the greater number of seats by zweitstimmen and direct mandates */
	select pv.bundesland, pv.party, greatest(seats, mandates) as seats
	from pseudodistribution_zw pv left join mandates_party_bland m on m.party = pv.party and m.bundesland = pv.bundesland
     ),

     least_num_seats as ( /* the number of seats each party has to get at least to satisfy all direct mandates */
	select party, sum(seats) as minsitze
	from pseudodistribution
	group by party
    ),

    bundesdivisor as ( /* the amount of votes needed to get one seat */
	select min(vp.votes / (m.minsitze - 0.5)) as bundesdivisor
	from least_num_seats m, votesbyparty vp
	where m.party = vp.party
    ),

    total_num_seats as ( /* the corrected number of seats per party*/
	select vp.party, round(vp.votes/d.bundesdivisor,0) seats
	from votesbyparty vp, parties_in_bundestag ib, bundesdivisor d
	where vp.party = ib.party
    ),

    partydivisor as ( /* the amount of votes needed to get one seat for each party */
	select * from total_num_seats total, find_partydivisor(total.party , total.seats) as divisor
    ),

    seats_bland as ( /* the final amount of seats each party gets in each bundesland */
	select vb.bundesland, vb.party, greatest(round(votes / divisor , 0), coalesce(mandates,0)) as seats
	from partydivisor d, votes_bundesland vb left join mandates_party_bland mpb on mpb.bundesland = vb.bundesland and mpb.party = vb.party
	where vb.party = d.party
    ),

    remaining_cand_on_ll as ( /* all the candidates on landeslisten that weren't elected by direct mandate */
	select l.*, candidate, rank() over (partition by l.id order by platz) platz
	from landesliste l, listenplatz lp
	where lp.landesliste = l.id
	and l.election = 2
	and lp.candidate not in (select candidate from directmandate_winners)
    ),

    members_of_bundestag as (
	select bundesland, candidate, party
	from directmandate_winners dw
	UNION
	select sb.bundesland, rc.candidate, rc.party
	from remaining_cand_on_ll rc, seats_bland sb left join mandates_party_bland mpb on mpb.bundesland = sb.bundesland and mpb.party = sb.party
	where rc.bundesland = sb.bundesland
	and rc.party = sb.party
	and rc.platz <= sb.seats - coalesce(mpb.mandates,0)
    )

select c.firstname, c.lastname, p.name as party, b.name as bundesland
from members_of_bundestag bm, party p, candidate c, bundesland b
where bm.bundesland = b.id
and bm.candidate = c.id
and bm.party = p.id
order by lastname
)
