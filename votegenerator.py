#!/usr/bin/env python3
import psycopg2
import csv
import datetime
import sys
from faker import Factory

### CONNECT TO POSTGRESQL ###
conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
cur = conn.cursor()

cur.execute("TRUNCATE Erststimme,zweitstimme,Voter,VotedOn")
conn.commit()
faker = Factory.create('de_DE')

voters_total = { } ;
def main(argv):
    WToPopulate = 0;
    if len (argv) == 2:
        WToPopulate = int(argv[1]);
        print ("Will only populate Wahlkreis: " + str(WToPopulate))
    addVotes('data/kerg_modified_unicode.csv',2, WToPopulate)
    addVotes('data/wkumrechnung2013_modified_unicode.csv',1,WToPopulate )

def addVotes(fileName, electionID, WahlkreisID):



    with open(fileName) as file:
        file.seek(0)
        freader = csv.DictReader(file,delimiter=",")

        curWkID = 0

        for row in freader:
            curWkID = row['WahlkreisNr']
            if WahlkreisID != 0 and int(curWkID) != WahlkreisID:
                print ("Skipping Walkreis: " + str (curWkID) )
                continue
         
            curUebrige = row['Übrige_S1']
            if curUebrige != "" :
                cur.execute('SELECT candidate FROM directmandate d WHERE d.party IS NULL and d.wahlkreis = %s and d.election = %s',(curWkID,electionID))
                result = cur.fetchone() 
                if result != None: #TODO: fix candidates for re-names Wahlkreise
                    print("Generating" + curUebrige + " votes for party less candidate in wahlkreis: " + curWkID)
                    luckyGuy = result[0]; #TODO: Distribute votes fairly if multiple partyless candidates per wk

                    uebrigeVotes = []
                    for i in range(0,int(curUebrige)):
                        uebrigeVotes.append((True,luckyGuy,curWkID,electionID))

                    records_list_template = ','.join(['%s'] * len(uebrigeVotes))
                    insert_query = 'INSERT INTO ERSTSTIMME(isInvalid,Candidate,Wahlkreis,election) VALUES {0}'.format(records_list_template)
                    cur.execute(insert_query, uebrigeVotes)
                    conn.commit()


            if curWkID not in voters_total:
                 voters_total[curWkID] =0
            voters = int(row["Voters"])
            if (voters > voters_total[curWkID]):
                voters = voters - voters_total[curWkID]
                print("Generating " + str(voters) + " voters for wahlkreis: " + curWkID)

                voter = []
                for i in range(1,voters):
                    voter.append((faker.first_name(),faker.last_name(),faker.date_time_between(start_date="-100y", end_date="-26y"),faker.address(),'?',curWkID))
                    #voter.append(("fn","ln","1991-01-01","addr","?",curWkID))
                records_list_template = ','.join(['%s'] * len(voter))
                insert_query = 'INSERT INTO Voter(FirstName,LastName,BirthDate,Address,Gender,Wahlkreis) VALUES {0} RETURNING id; '.format(records_list_template)
                cur.execute(insert_query,voter)
                #ids = cur.fetchall()
                conn.commit()
                voters_total[curWkID] += voters

            #print("Generating " + str(voted) + " votedOn relationships for wahlkreis: " + curWkID)


            #for i in range(0,voted - 1):
            #    votedOn.append((electionID,ids[i]));
            #records_list_template = ','.join(['%s'] * len(votedOn))
            #insert_query = 'INSERT INTO votedon(election,voter) VALUES {0}'.format(records_list_template)
            #cur.execute(insert_query,votedOn)

            #conn.commit()

            for party, amount in row.items():

                if party.endswith('Prev') or party == 'Voters' or party == 'Voted':
                    continue

                elif party.startswith('Invalid_S1'):

                    print("Generating " + amount + " invalid erststimmen for wahlkreis: " + curWkID)

                    invalid = []

                    for i in range(1,int(amount)):
                        invalid.append((True,None,curWkID,electionID))

                    records_list_template = ','.join(['%s'] * len(invalid))
                    insert_query = 'INSERT INTO ERSTSTIMME(isInvalid,Candidate,Wahlkreis,election) VALUES {0}'.format(records_list_template)
                    cur.execute(insert_query, invalid)

                    conn.commit()
                elif party.startswith('Invalid_S2'):


                    print("Generating " + amount + " invalid zweitstimmen for wahlkreis: " + curWkID)

                    invalid = []

                    for i in range(1,int(amount)):
                        invalid.append((True,None,curWkID,electionID))

                    records_list_template = ','.join(['%s'] * len(invalid))
                    insert_query = 'INSERT INTO Zweitstimme(isInvalid,Party,Wahlkreis,election) VALUES {0}'.format(records_list_template)
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
                            erststimmen.append((False,cID,curWkID,electionID))

                        records_list_template = ','.join(['%s'] * len(erststimmen))
                        insert_query = 'INSERT INTO ERSTSTIMME(isInvalid,Candidate,Wahlkreis,election) VALUES {0}'.format(records_list_template)
                        cur.execute(insert_query, erststimmen)

                        conn.commit()

                elif party.endswith('_S2') and not party.startswith('Übrige'):
                    if amount != "":
                        cur.execute("SELECT p.id FROM party p WHERE p.name = %s",(party[:-3],))

                        pID = cur.fetchone()

                        print("Generating " + amount + " votes for: " + party + " in wahlkreis: " + curWkID)

                        zweitstimmen = []
                        for i in range(1,int(row[(party[:-3] + '_S2')])):
                            zweitstimmen.append((False,pID[0],curWkID,electionID))

                        records_list_template = ','.join(['%s'] * len(zweitstimmen))
                        insert_query = 'INSERT INTO Zweitstimme(isInvalid,Party,Wahlkreis,election) VALUES {0}'.format(records_list_template)
                        cur.execute(insert_query, zweitstimmen)

                        conn.commit()


if  __name__ =='__main__': main( sys.argv )
conn.close()
