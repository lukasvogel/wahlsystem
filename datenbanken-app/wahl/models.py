import psycopg2

conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
conn.autocommit = True

votingconn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
votingconn.autocommit = False


class Ballot(object):
    @staticmethod
    def get_ballot(election, wk_id):
        cur = conn.cursor()

        # get the name of the wahlkreis
        cur.execute(
            'select id,name from wahlkreis where id=%s', (wk_id,)
        )

        wahlkreis = cur.fetchone()

        # get the date of the election
        cur.execute(
            'select date from election where id=%s', (election,)
        )

        date = cur.fetchone()

        return {
            'wk_id': wahlkreis[0],
            'wk_name': wahlkreis[1],
            'e_date': date[0]
        }


class VoteHandler(object):
    @staticmethod
    # Checks whether the vote is valid, i.e. the candidate and party voted for is actually running in the wahlkreis
    # and the token exists
    def check(token, candidate_id, party_id):

        cur = conn.cursor()

        # get the election and wahlkreis for the token (if valid)
        cur.execute(
            'select election,wahlkreis from token where token=%s', (token,)
        )

        result = cur.fetchone()
        # Do we have to check whether multiple tokens with the same key exist?
        # my guess: no. If our system generates colliding tokens we have other problems to worry about
        # ... really encouraging to have comments like this in an application like this, isn't it?

        if result is None:
            # the token was not found
            # IGNORE THE IMPOSTOR!!
            return False
        else:
            e_id = result[0]
            wk_id = result[1]

            # we check if the candidate and party is actually running in the wahlkreis
            cur.execute(
                'select * from directmandate where election = %s and  wahlkreis = %s and candidate = %s',
                (e_id, wk_id, candidate_id)
            )
            candidate = cur.fetchone()

            cur.execute(
                '''select * from landesliste l join wahlkreis w on w.bundesland = l.bundesland
                where l.election = %s and  w.id = %s and party = %s''',
                (e_id, wk_id, party_id)
            )

            party = cur.fetchone()

            # only return true if party and candidate are running in this wahlkreis and election
            return party is not None and candidate is not None

    @staticmethod
    def vote(token, candidate_id, party_id):

        cur = votingconn.cursor()

        # get the election and wahlkreis for the token
        cur.execute(
            'select election,wahlkreis from token where token=%s', (token,)
        )

        result = cur.fetchone()

        if result is None:
            # the token was not found
            # IGNORE THE IMPOSTOR!!
            return False
        else:
            e_id = result[0]
            wk_id = result[1]

            # Erststimme
            cur.execute(
                'INSERT INTO erststimme(isInvalid,Candidate,Wahlkreis,Election) VALUES (FALSE , %s, %s, %s)',
                (candidate_id, wk_id, e_id)
            )

            # Zweitstimme
            cur.execute(
                'INSERT INTO zweitstimme(isInvalid,Party,Wahlkreis,Election) VALUES (FALSE , %s, %s, %s)',
                (party_id, wk_id, e_id)
            )

            # Delete Token
            cur.execute(
                'DELETE FROM token WHERE token = %s returning *', (token,)
            )

            if cur.fetchone is None:
                # the token was not in the database
                votingconn.rollback()
                return False

            cur.close()

            try:
                votingconn.commit()
            except:
                return False

            return True