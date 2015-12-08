import psycopg2

conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
conn.autocommit = True


class Ballot(object):
    @staticmethod
    def get_ballot(election, wk_id):

        cur = conn.cursor()

        # get the name of the wahlkreis
        cur.execute(
            'select id,name from wahlkreis where id=%s', (wk_id,)
        )

        wahlkreis = cur.fetchone();

        # get the date of the election
        cur.execute(
            'select date from election where id=%s', (election,)
        )

        date = cur.fetchone();

        # get candidats for first vote
        cur.execute(
            """
              select c.firstname, c.lastname, p.name
              from directmandate d
	            join candidate c on c.id = d.candidate
	            left join party p on d.party = p.id
              where election = %s
              and wahlkreis = %s
            """, (election, wk_id)
        )

        first_vote = []

        for candidate in cur.fetchall():
            first_vote.append({
                'c_fname': candidate[0],
                'c_lname': candidate[1],
                'c_pname': candidate[2]
            })

        # get parties for second vote
        cur.execute(
            """
              select p.name
              from wahlkreis w
	            join landesliste l on w.bundesland = l.bundesland
	            join bundesland b on w.bundesland = b.id
	            join party p on l.party = p.id
              where w.id = %s
              and l.election = %s
            """, (wk_id, election)
        )

        second_vote = []

        for party in cur.fetchall():
            second_vote.append(party[0])

        return {
            'first_vote': first_vote,
            'second_vote': second_vote,
            'wk_id': wahlkreis[0],
            'wk_name': wahlkreis[1],
            'e_date': date[0]
        }
