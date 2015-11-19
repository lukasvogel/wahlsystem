import psycopg2


class BundestagMembers(object):

    def __init__(self):
        self.conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
        self.cur = self.conn.cursor()
        self.conn.autocommit = True

    def get_members(self, election):
        self.cur.execute(
            """SELECT mb.firstname, mb.lastname, mb.party, mb.bundesland, dw.wahlkreis, w.name
               FROM members_of_bundestag_2013 mb
               LEFT JOIN (directmandate_winners dw
                          JOIN wahlkreis w
                          ON w.id = dw.wahlkreis)
                ON mb.id = dw.candidate AND dw.election = 2
               ORDER BY mb.lastname""")

        members = []

        for member in self.cur.fetchall():
            members.append({
                'firstname' : member[0],
                'lastname' : member[1],
                'party' : member[2],
                'bundesland' : member[3],
                'wk_id' : member[4],
                'wk_name' : member[5]
            })

        return members


class Wahlkreise(object):

    def __init__(self):
        self.conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
        self.cur = self.conn.cursor()
        self.conn.autocommit = True

    def get_info(self,wk_id):
        self.cur.execute(
            """SELECT *
                FROM wahlkreis w
                WHERE w.id = %s""",
            (wk_id,)
        )

        wahlkreis = self.cur.fetchone()

        return {'wk_id': wahlkreis[0], 'wk_name': wahlkreis[1]}


class Overview(object):

    def __init__(self):
        self.conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
        self.cur = self.conn.cursor()
        self.conn.autocommit = True
        self.color_mapping = {
            'CDU' : 'black',
            'SPD' : 'red',
            'FDP' : 'yellow',
            'CSU' : 'black',
            'GRÜNE' : 'green',
            'DIE LINKE' : 'purple'
        }

    def get_composition(self,election):

        self.cur.execute(
            """SELECT p.name, cast(seats as int)
               FROM seats_by_party_2013 sp, party p
               WHERE p.id = sp.party
            """
        )

        data = []
        for datapoint in self.cur.fetchall():
            data.append({'name' : datapoint[0],
                         'y' : datapoint[1],
                         'color' : self.color_mapping[datapoint[0]]})
        return data
