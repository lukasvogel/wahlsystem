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

        return {
            'wk_id': wahlkreis[0],
            'wk_name': wahlkreis[1],
            'e_date': date[0]
        }
