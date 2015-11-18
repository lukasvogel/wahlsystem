import psycopg2


class Bundestag_Members(object):

    def __init__(self):
        self.conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres")
        self.cur = self.conn.cursor()
        self.conn.autocommit = True

    def getMembers(self, election):
        self.cur.execute(
            """SELECT mb.firstname, mb.lastname, mb.party, mb.bundesland, dw.wahlkreis, w.name
               FROM members_of_bundestag_2013 mb
               LEFT JOIN (directmandate_winners dw   JOIN wahlkreis w ON w.id = dw.wahlkreis) ON mb.id = dw.candidate AND dw.election = 2
               ORDER BY mb.lastname""")

        members = self.cur.fetchall();

        return members