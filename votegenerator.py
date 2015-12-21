#!/usr/bin/env python3
import codecs
import csv
import sys

import psycopg2

### CONNECT TO POSTGRESQL ###
conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
cur = conn.cursor()

cur.execute("TRUNCATE Erststimme,zweitstimme,Voter,VotedOn")
conn.commit()

voters_total = {}


def main(argv):
    # temporally disable foreign key constraints (immense speedup!)
    # this is okay as we know that our data is consistent
    cur.execute("ALTER TABLE voter DISABLE TRIGGER ALL;")
    cur.execute("ALTER TABLE erststimme DISABLE TRIGGER ALL;")
    cur.execute("ALTER TABLE zweitstimme DISABLE TRIGGER ALL;")
    conn.commit()

    WToPopulate = 0
    if len(argv) == 2:
        WToPopulate = int(argv[1])
    print("Will only populate Wahlkreis: " + str(WToPopulate))
    addVotes('data/kerg_modified_unicode.csv', 2, WToPopulate)
    addVotes('data/wkumrechnung2013_modified_unicode.csv', 1, WToPopulate)

    cur.execute("ALTER TABLE voter ENABLE TRIGGER ALL;")
    cur.execute("ALTER TABLE erststimme ENABLE TRIGGER ALL;")
    cur.execute("ALTER TABLE zweitstimme ENABLE TRIGGER ALL;")
    conn.commit()


def addVotes(fileName, electionID, WahlkreisID):
    with codecs.open(fileName, 'r', encoding='utf8') as file:
        file.seek(0)
        freader = csv.DictReader(file, delimiter=",")

        curWkID = 0

        for row in freader:
            curWkID = row['WahlkreisNr']
            if WahlkreisID != 0 and int(curWkID) != WahlkreisID:
                print("Skipping Walkreis: " + str(curWkID))
                continue

            curUebrige = row['Übrige_S1']
            if curUebrige != "":
                # TODO: Actually doesn't create invalid votes, as party = NULL != party IS NULL
                # in postgres function generate_erststimmen

                print("Generating " + curUebrige + " votes for a partyless candidate in wahlkreis " + curWkID)
                cur.execute("SELECT * FROM generate_uebrige(%s,%s,%s)", (curWkID, electionID, int(curUebrige)))
                conn.commit()

            if curWkID not in voters_total:
                voters_total[curWkID] = 0
            voters = int(row["Voters"])
            voted = int(row["Voted"])
            if (voters > voters_total[curWkID]):
                voters = voters - voters_total[curWkID]
                print("Generating " + str(voters) + " voters for wahlkreis: " + curWkID)

                cur.execute("SELECT * FROM generate_voters(%s,%s,%s,%s)", (curWkID, electionID, voters, voted))
                conn.commit()
                voters_total[curWkID] += voters

            for party, amount in row.items():

                if party.endswith('Prev') or party == 'Voters' or party == 'Voted':
                    continue

                elif party.startswith('Invalid_S1'):

                    print("Generating " + amount + " invalid erststimmen for wahlkreis: " + curWkID)

                    cur.execute("SELECT * FROM generate_erststimmen(%s,%s,%s,%s,%s)",
                                (True, '0', curWkID, electionID, amount))
                    conn.commit()

                elif party.startswith('Invalid_S2'):

                    print("Generating " + amount + " invalid zweitstimmen for wahlkreis: " + curWkID)

                    cur.execute("SELECT * FROM generate_zweitstimmen(%s,%s,%s,%s,%s)",
                                (True, '0', curWkID, electionID, amount))
                    conn.commit()

                elif party.startswith('Valid_S2'):
                    # we don't need to handle valid votes because: valid = total - invalid
                    # we only handle the invalid votes
                    continue

                elif party.startswith('Valid_S1'):
                    continue

                elif party.endswith('_S1') and not party.startswith('Übrige'):
                    if amount != "":
                        print("Generating " + amount + " votes for: " + party + " in wahlkreis: " + curWkID)
                        cur.execute("SELECT * FROM generate_erststimmen(%s,%s,%s,%s,%s)",
                                    (False, party[:-3], curWkID, electionID, amount))
                        conn.commit()

                elif party.endswith('_S2') and not party.startswith('Übrige'):
                    if amount != "":
                        print("Generating " + amount + " votes for: " + party + " in wahlkreis: " + curWkID)

                        cur.execute("SELECT * FROM generate_zweitstimmen(%s,%s,%s,%s,%s)",
                                    (False, party[:-3], curWkID, electionID, amount))
                        conn.commit()


if __name__ == '__main__': main(sys.argv)
conn.close()
