import psycopg2
import csv
import datetime
from faker import Factory

### CONNECT TO POSTGRESQL ###
conn = psycopg2.connect("dbname=wahlsystem user=postgres")
cur = conn.cursor()

cur.execute("DELETE FROM Erststimme")
cur.execute("DELETE FROM Zweitstimme")
cur.execute("DELETE FROM Voter")
cur.execute("DELETE FROM VotedOn")
conn.commit()
faker = Factory.create('de_DE')

def main():
    addVotes('data/kerg_modified_unicode.csv',2)


def addVotes(fileName, electionID):

    with open(fileName) as file:
        file.seek(0)
        freader = csv.DictReader(file,delimiter=",")

        curWkID = 0

        for row in freader:
            curWkID = row['WahlkreisNr']
            for party, amount in row.items():

                if party.endswith('Prev'):
                    continue

                if party == 'Voters':

                    print("Generating " + amount + " voters for wahlkreis: " + curWkID)

                    voter = []
                    for i in range(1,int(amount)):
                        #voter.append((faker.first_name(),faker.last_name(),faker.date_time_between(start_date="-100y", end_date="-26y"),faker.address(),'?',curWkID))
                        voter.append(("fn","ln","1991-01-01","addr","?",curWkID))
                    records_list_template = ','.join(['%s'] * len(voter))
                    insert_query = 'INSERT INTO Voter(FirstName,LastName,BirthDate,Address,Gender,Wahlkreis) VALUES {0}'.format(records_list_template)
                    cur.execute(insert_query, voter)

                    conn.commit()


                elif party.startswith('Invalid_S1'):

                    print("Generating " + amount + " invalid erststimmen for wahlkreis: " + curWkID)

                    invalid = []

                    for i in range(1,int(amount)):
                        invalid.append((True,None,curWkID))

                    records_list_template = ','.join(['%s'] * len(invalid))
                    insert_query = 'INSERT INTO ERSTSTIMME(isInvalid,Candidate,Wahlkreis) VALUES {0}'.format(records_list_template)
                    cur.execute(insert_query, invalid)

                    conn.commit()
                elif party.startswith('Invalid_S2'):


                    print("Generating " + amount + " invalid zweitstimmen for wahlkreis: " + curWkID)

                    invalid = []

                    for i in range(1,int(amount)):
                        invalid.append((True,None,curWkID))

                    records_list_template = ','.join(['%s'] * len(invalid))
                    insert_query = 'INSERT INTO Zweitstimme(isInvalid,Party,Wahlkreis) VALUES {0}'.format(records_list_template)
                    cur.execute(insert_query, invalid)

                    conn.commit()
                elif party.startswith('Valid_S2'):
                    # we don't need to handle valid votes because: valid = total - invalid
                    # we only handle the invalid votes
                    continue

                elif party.startswith('Valid_S1'):
                    continue

                elif party.endswith('_S1') and not party.startswith('Übrige'):
                    if amount != "":
                        cur.execute("""SELECT d.Candidate
                                    FROM directmandate d, party p
                                    WHERE d.party = p.id
                                    AND d.wahlkreis = %s
                                    AND d.election = %s
                                    AND p.name = %s""",(curWkID,electionID,party[:-3],))

                        cID = cur.fetchone()

                        cur.execute("SELECT p.id FROM party p WHERE p.name = %s",(party[:-3],))

                        pID = cur.fetchone()

                        print("Generating " + amount + " votes for: " + party + " in wahlkreis: " + curWkID)

                        erststimmen = []
                        for i in range(1,int(amount)):
                            erststimmen.append((False,cID,curWkID))

                        records_list_template = ','.join(['%s'] * len(erststimmen))
                        insert_query = 'INSERT INTO ERSTSTIMME(isInvalid,Candidate,Wahlkreis) VALUES {0}'.format(records_list_template)
                        cur.execute(insert_query, erststimmen)

                        conn.commit()

                elif party.endswith('_S2') and not party.startswith('Übrige'):
                    if amount != "":
                        cur.execute("SELECT p.id FROM party p WHERE p.name = %s",(party[:-3],))

                        pID = cur.fetchone()

                        print("Generating " + amount + " votes for: " + party + " in wahlkreis: " + curWkID)

                        zweitstimmen = []
                        for i in range(1,int(row[(party[:-3] + '_S2')])):
                            zweitstimmen.append((False,pID[0],curWkID))

                        records_list_template = ','.join(['%s'] * len(zweitstimmen))
                        insert_query = 'INSERT INTO Zweitstimme(isInvalid,Party,Wahlkreis) VALUES {0}'.format(records_list_template)
                        cur.execute(insert_query, zweitstimmen)

                        conn.commit()

if  __name__ =='__main__': main()
