CREATE TABLE lague_coeff
(
    VAL    NUMERIC PRIMARY KEY
);

create function generateLagueCoeff(num integer not null)
as $$
   DELETE FROM lague_coeff;
   select index from sequence(1,num) {
       INSERT INTO lague_coeff VALUES (index - 0.5);
   }
   Return;
$$ language 'hyperscript' strict;


hyper> DELETE from candidate;
STATEMENT 1
hyper> DELETE from party
raul-# ;
STATEMENT 1
hyper> COPY election FROM '/home/raul/db-dump/cvs-processed/election.tsv';
STATEMENT 2
hyper> COPY bundesland FROM '/home/raul/db-dump/cvs-processed/bundesland.tsv';
STATEMENT 16
hyper> COPY wahlkreis FROM ^Csv';
hyper> COPY wahlkreis FROM '/home/raul/db-dump/cvs-processed/wahlkreis.tsv';
STATEMENT 299
hyper> COPY party FROM '/home/raul/db-dump/cvs-processed/party.tsv';
STATEMENT 41
hyper> COPY candidate FROM '/home/raul/db-dump/cvs-processed/candidates.tsv';
STATEMENT 6945
hyper> COPY directmandate FROM '/home/raul/db-dump/cvs-processed/directmandate.tsv';
STATEMENT 4900
hyper> COPY landesliste FROM '/home/raul/db-dump/cvs-processed/landesliste.tsv';
STATEMENT 433
hyper> COPY listenplatz FROM '/home/raul/db-dump/cvs-processed/listenplatz.tsv';
STATEMENT 6151
hyper> COPY erststimme FROM '/home/raul/db-dump/cvs-processed/erststimme.tsv';
STATEMENT 88449680
hyper> COPY zweitstimme FROM '/home/raul/db-dump/cvs-processed/zweitstimme.tsv';
STATEMENT 88315500
hyper> COPY voter FROM '/home/raul/db-dump/cvs-processed/voter.tsv';
STATEMENT 62591573


SELECT c.firstname, c.lastname, p.name, er.count,
                        round(er.count / votes.votes * 100,1) as percentage,
                        (CASE WHEN d.election > 1
                                THEN round((er.count / votes.votes - er_prev.count / votes_prev.votes) * 100,1)
                             ELSE
                                NULL
                         END)as change
                FROM directmandate d
                    join candidate c
                        on c.id = d.candidate
                    left join party p
                        on p.id = d.party
                    join erststimme_results er
                        on er.candidate = d.candidate
                        and er.election = d.election
                        and er.wahlkreis = d.wahlkreis
                    join (select sum(count) as votes, er2.election, er2.wahlkreis
                                          from erststimme_results er2
                                          group by er2.election, er2.wahlkreis) as votes
                        on votes.election = d.election
                        and votes.wahlkreis = d.wahlkreis
                      left join directmandate d_prev
                        on d_prev.party = d.party
                        and d_prev.wahlkreis = d.wahlkreis
                        and d_prev.election = 1
                    left join erststimme_results er_prev
                        on er_prev.election = d_prev.election
                        and er_prev.wahlkreis = d.wahlkreis
                        and er_prev.candidate = d_prev.candidate
                    left join (select sum(count) as votes, er3.election, er3.wahlkreis
                                        from erststimme_results er3
                                        group by er3.election, er3.wahlkreis) as votes_prev
                        on votes_prev.election = d_prev.election
                        and votes_prev.wahlkreis = d.wahlkreis
                WHERE d.election = $1
                AND d.wahlkreis = $2
                order by er.count desc;

