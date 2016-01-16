import uuid

import psycopg2

conn = psycopg2.connect("host=localhost dbname=wahlsystem user=analyse password=Password01")
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
    def check(token, candidate_id, party_id, er_invalid, zw_invalid):

        cur = conn.cursor()

        print(token)

        # get the election and wahlkreis for the token (if valid)
        cur.execute(
                'select election,wahlkreis from token where token=%s', (token,)
        )

        result = cur.fetchone()

        if result is None:
            print('token falsch')
            # the token was not found
            # IGNORE THE IMPOSTOR!!
            return False
        else:
            print('token stimmt')
            e_id = result[0]
            wk_id = result[1]

            if not er_invalid:
                # we check if the candidate and party is actually running in the wahlkreis
                cur.execute(
                        'select * from directmandate where election = %s and  wahlkreis = %s and candidate = %s',
                        (e_id, wk_id, candidate_id)
                )
                candidate = cur.fetchone()
                if candidate is None:
                    return False

            if not zw_invalid:
                cur.execute(
                        '''select * from landesliste l join wahlkreis w on w.bundesland = l.bundesland
                        where l.election = %s and  w.id = %s and party = %s''',
                        (e_id, wk_id, party_id)
                )
                party = cur.fetchone()

                if party is None:
                    return False

        # only return true if all gültige Votes are for
        # a party and candidate running in the current election and wahlkreis
        return True

    @staticmethod
    def vote(token, candidate_id, party_id, er_invalid, zw_invalid):
        cur = votingconn.cursor()

        # get the election and wahlkreis for the token

        cur.execute(
                'select election,wahlkreis from token where token=%s', (token,)
        )

        result = cur.fetchone()

        # we are allowed to cast unspecified candidates to null values
        # the check()-function guarantees that the corresponding vote has been set to invalid,
        # if the candidate or party is not set

        if candidate_id == '':
            candidate_id = None

        if party_id == '':
            party_id = None

        if result is None:
            # the token was not found
            # IGNORE THE IMPOSTOR!!
            return False
        else:
            e_id = result[0]
            wk_id = result[1]

            # Erststimme
            cur.execute(
                    'INSERT INTO erststimme(isInvalid,Candidate,Wahlkreis,Election) VALUES (%s , %s, %s, %s)',
                    (er_invalid, candidate_id, wk_id, e_id)
            )

            # Zweitstimme
            cur.execute(
                    'INSERT INTO zweitstimme(isInvalid,Party,Wahlkreis,Election) VALUES (%s , %s, %s, %s)',
                    (zw_invalid, party_id, wk_id, e_id)
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


class TokenGenerator(object):
    @staticmethod
    def generatetokens(no, wkid, elid):
        #voting cursor is neede to insert in table
        cur = votingconn.cursor()

        # generate no votes for wahlkreis wkid and election eid
        tokens = []
        for i in range(no):
            token = str(uuid.uuid4())
            tokens.append(token)
            cur.execute(
                    'INSERT INTO token VALUES ( %s, %s, %s ) ', (elid, wkid, token)
            )

        votingconn.commit()
        return tokens

class VoterVerifier(object):
    @staticmethod
    def verifyVoter(currentElection, voterId):

        #assume cannot vote
        canVote = False
        cur = votingconn.cursor()

        #no current election, BAIL!
        if currentElection is None:
            return False

        #get voting data for voter
        cur.execute(
                        'select FirstValidElection, LastValidElection, LastVotedOn from voter where id = %s ',
                        (voterId, )
                )
        elections = cur.fetchone()

        #invalid voter, BAIL!
        if elections is None:
            return False

        firstVe = elections[0]
        lastVe = elections[1]
        lastVo = elections[2]

        #interval checks
        if int(firstVe) <= int(currentElection) and (lastVe is None or int(lastVe) > int(currentElection) ) and (lastVo is None or int(lastVo) < int (currentElection)):
                canVote = True
                lastVo = currentElection

        if canVote:
            #update voting info:
            cur.execute(
                        'update voter set LastVotedOn = %s WHERE id = %s ',
                        ( lastVo, voterId )
                )
            votingconn.commit()

        return canVote