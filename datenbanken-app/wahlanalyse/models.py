import psycopg2
from decimal import Decimal
import json


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
                ON mb.id = dw.candidate
               ORDER BY mb.lastname""")

        members = []

        for member in self.cur.fetchall():
            members.append({
                'firstname': member[0],
                'lastname': member[1],
                'party': member[2],
                'bundesland': member[3],
                'wk_id': member[4],
                'wk_name': member[5]
            })

        return members


class Wahlkreise(object):
    def __init__(self):
        self.conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
        self.cur = self.conn.cursor()
        self.conn.autocommit = True

    def get_info(self, wk_id):

        # Get infos on wahlkreis and direct mandate winner
        self.cur.execute(
            """SELECT w.id, w.name, c.firstname, c.lastname
                FROM wahlkreis w, directmandate_winners dw, candidate c
                WHERE dw.wahlkreis = w.id
                AND c.id = dw.candidate
                AND w.id = %s""",
            (wk_id,)
        )

        # TODO: Was wenn party = None?
        wahlkreis = self.cur.fetchone()

        # Get the candidates trying to get a direct mandate
        wk_candidates = []

        self.cur.execute(
            """
            SELECT c.firstname, c.lastname, p.name, er.count,
                    round(er.count / (select sum(count)
                                      from erststimme_results er2
                                      where er2.election = 2
                                      and er2.wahlkreis = %s) * 100,1) as percentage
            FROM directmandate d left join party p on p.id = d.party, candidate c, erststimme_results er
            WHERE d.candidate = c.id
            AND er.candidate = c.id
            AND d.election = 2
            AND er.election = d.election
            AND d.wahlkreis = %s
            order by er.count desc
            """,
            (wk_id,wk_id)
        )
        for candidate in self.cur.fetchall():
            wk_candidates.append({
                'c_name': candidate[0] + ' ' + candidate[1],
                'c_pname': candidate[2],
                'c_votes': candidate[3],
                'c_percentage' : candidate[4]
            })

        # Get the results of the parties
        wk_parties = []
        self.cur.execute(
            """
            SELECT p.name, zr.count, round(zr.count / (select sum(count) from zweitstimme_results zr2 where zr2.election = 2 and zr2.wahlkreis = %s) * 100,1) as percentage
            FROM zweitstimme_results zr, party p
            WHERE zr.election = 2
            AND zr.party = p.id
            AND zr.wahlkreis = %s
            order by zr.count desc
            """,
            (wk_id,wk_id)
        )
        for party in self.cur.fetchall():
            wk_parties.append({
                'p_name': party[0],
                'p_votes': party[1],
                'p_percentage' : party[2]
            })

        # Get wahlbeteiligung
        self.cur.execute(
            """
            SELECT w.wahlbeteiligung
            FROM wahlbeteiligung w
            WHERE w.wahlkreis = %s
            AND w.election = 2
            """,
            (wk_id,)
        )
        wahlbeteiligung = self.cur.fetchone()

        return {'wk_id': wahlkreis[0],
                'wk_name': wahlkreis[1],
                'winner_fn': wahlkreis[2],
                'winner_ln': wahlkreis[3],
                'wahlbeteiligung': wahlbeteiligung[0],
                'candidates': wk_candidates,
                'parties': wk_parties}


class Overview(object):
    def __init__(self):
        self.conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
        self.cur = self.conn.cursor()
        self.conn.autocommit = True
        self.color_mapping = {
            'CDU': 'black',
            'SPD': 'red',
            'FDP': 'yellow',
            'CSU': 'black',
            'GRÜNE': 'green',
            'DIE LINKE': 'purple'
        }
        self.interesting_parties = [
            'CDU', 'FDP', 'CSU', 'SPD','GRÜNE','DIE LINKE', 'AfD', 'PIRATEN'
        ]

    def get_composition(self, election):

        self.cur.execute(
            """SELECT p.name, cast(seats as int)
               FROM seats_by_party_2013 sp, party p
               WHERE p.id = sp.party
            """
        )

        data = []
        for datapoint in self.cur.fetchall():
            data.append({'name': datapoint[0],
                         'y': datapoint[1],
                         'color': self.color_mapping[datapoint[0]]})
        return data

    def get_percentages(self, election):

        self.cur.execute(
            """
            SELECT p.name, round((v.votes / t.total * 100),1) as percentage
            FROM votesbyparty v, party p, totalvotes t
            WHERE v.party = p.id
            ORDER BY percentage DESC
            """
        )
        # TODO: WELCHE ELECTION???!!!


        results = self.cur.fetchall()

        graphDef = []
        for year in [2009, 2013]:
            graphDef.append({
                "index": (year - 2009) // 4, #0,1,... HACK
                "colorbyPoint": True,
                "name": year,
                "data": [[mapping[0], mapping[1]] for mapping in results if mapping[0] in self.interesting_parties]
            })
        return json.dumps(graphDef, cls=DecimalEncoder)


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return json.JSONEncoder.default(self, obj)
