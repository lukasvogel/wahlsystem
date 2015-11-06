#!/usr/bin/env python3
import psycopg2
import csv
import datetime


### GLOBAL DEFINITIONS ###
BLShortcuts = { 'BW' : 'Baden-Württemberg',
                 'BY' : 'Bayern',
                 'BE' : 'Berlin',
                 'BB' : 'Brandenburg',
                 'HB' : 'Bremen',
                 'HH' : 'Hamburg',
                 'HE' : 'Hessen',
                 'MV' : 'Mecklenburg-Vorpommern',
                 'NI' : 'Niedersachsen',
                 'NW' : 'Nordrhein-Westfalen',
                 'RP' : 'Rheinland-Pfalz',
                 'SL' : 'Saarland',
                 'SN' : 'Sachsen',
                 'ST' : 'Sachsen-Anhalt',
                 'SH' : 'Schleswig-Holstein',
                 'TH' : 'Thüringen'}

### CONNECT TO POSTGRESQL ###
conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
cur = conn.cursor()



def main():


    ### RESET AND RECREATE DATABASE ###
    print ("Resetting the database...")

    f = open('schema.sql','r')
    setupSQL = f.read()
    f.close

    cur.execute(setupSQL)

    ### FILLING DATABASE ###
    print("Initializing Bundesländer and Wahlkreise")
    addBundeslaender()
    addWahlkreise()

    print("Generating 2009 and 2013 Election...")
    cur.execute("INSERT INTO election(date) VALUES (%s)",(datetime.date(2009,9,27),))
    cur.execute("INSERT INTO election(date) VALUES (%s)",(datetime.date(2013,9,22),))

    addParties('data/Daten_2005_2009/wahlbewerber2009_mod.csv')
    addParties('data/Wahlbewerber2013/wahlbewerber_mit_platz.csv')
    addLandeslisten('data/Wahlbewerber2013/wahlbewerber_mit_platz.csv')
    addLandeslisten('data/Daten_2005_2009/wahlbewerber2009_mod.csv')
    addCandidates('data/Wahlbewerber2013/wahlbewerber_mit_platz.csv')
    addCandidates('data/Daten_2005_2009/wahlbewerber2009_mod.csv')

    cur.close()
    conn.close()

def extractValues(fileName, colNames):
    #This function is the equivalent of an SQL-Projection on a CSV-file

    with open(fileName) as file:
        dialect = csv.Sniffer().sniff(file.read(1024))
        file.seek(0)
        freader = csv.DictReader(file,dialect=dialect)

        resultSet = []

        for row in freader:
            rowVals = {}
            for col in colNames:
                rowVals[col] = row[col]

            if not rowVals in resultSet:
                resultSet.append(rowVals)
        return resultSet

def addBundeslaender():
    #Insert all Bundesländer into the bundesland relation
    print("Inserting Bundesländer...")

    cur.execute("""INSERT INTO bundesland(name) VALUES
                ('Baden-Württemberg'),
                ('Bayern'),
                ('Berlin'),
                ('Brandenburg'),
                ('Bremen'),
                ('Hamburg'),
                ('Hessen'),
                ('Mecklenburg-Vorpommern'),
                ('Niedersachsen'),
                ('Nordrhein-Westfalen'),
                ('Rheinland-Pfalz'),
                ('Saarland'),
                ('Sachsen'),
                ('Sachsen-Anhalt'),
                ('Schleswig-Holstein'),
                ('Thüringen')""")

    conn.commit()

def addWahlkreise():
    #The file Wahlkreise.csv specifies the Wahlkreise including their number
    #and the bundesland they are a member of. We insert them into the wahlkreis-relation
    print ("Inserting Wahlkreise...")


    for row in extractValues('data/inferred/Wahlkreise.csv',['Wahlkreisnummer','Wahlkreisname','Bundesland']):
        id = int(row["Wahlkreisnummer"])
        name = row["Wahlkreisname"]
        BLand = row["Bundesland"]
        cur.execute("SELECT id FROM bundesland where name=%s",(BLand,)) #ugly, but names happen to be unique for the 16 Bundesländer
        BLandId = cur.fetchone()[0]
        cur.execute("INSERT INTO wahlkreis VALUES (%s,%s,%s)", (id,name,BLandId))


    conn.commit()

def addParties(csvfile):
    print("Inserting all parties from file " + csvfile)


    for party in extractValues(csvfile,['Partei']):
        name = party['Partei']
        if name != '':
            cur.execute("""INSERT INTO party(name)
                            SELECT %s
                            WHERE NOT EXISTS (
                                SELECT * FROM party p WHERE p.name = %s)
                             """, (name,name))
    conn.commit()

def addLandeslisten(csvfile):
    print("Inserting all Landeslisten from file " + csvfile)

    for liste in extractValues(csvfile,['Bundesland','Partei','Wahltermin']):

        if liste['Bundesland'] != "":
            wahltermin = datetime.datetime.strptime(liste['Wahltermin'],"%Y-%m-%d")

            #get party,election and bundesland by name,year and name respectively. ugly, but all names and dates are unique in this case
            cur.execute("SELECT id FROM party WHERE name=%s",(liste['Partei'],))
            partyID = cur.fetchone()
            cur.execute("SELECT id FROM election WHERE date=%s",(wahltermin,))
            electionID = cur.fetchone()
            cur.execute("SELECT id FROM bundesland where name=%s",(BLShortcuts[liste['Bundesland']],)) #ugly, but names happen to be unique for the 16 Bundesländer
            BLandID = cur.fetchone()

            #include only those items that are well defined
            if partyID != None and electionID != None and BLandID != None:
                cur.execute("INSERT INTO landesliste(party,election,bundesland) VALUES (%s,%s,%s)",(partyID[0],electionID[0],BLandID[0]))
            else:
                print(liste['Partei'])

def addCandidates(csvfile):
    print("Inserting Candidates from file " + csvfile )

    for candidate in extractValues(csvfile,['Nachname','Vorname','Jahrgang','Wahlkreis','Partei','Wahltermin','Listenplatz','Bundesland']):
        lastname = candidate['Nachname']
        firstname = candidate['Vorname']
        wahltermin = datetime.datetime.strptime(candidate['Wahltermin'],"%Y-%m-%d")
        birthyear = int(candidate['Jahrgang'])
        wahlkreis = candidate['Wahlkreis']
        # Get the Party-ID of the voter (if one exists)
        cur.execute("SELECT id FROM party WHERE name=%s",(candidate['Partei'],))
        partyID = cur.fetchone() # ugly, but all party names in sample-db are unique

        #get Election ID of the candidate
        cur.execute("SELECT id FROM election WHERE date=%s",(wahltermin,))
        electionID = cur.fetchone()



        # insert candidate, only if he isn't already inserted
        cur.execute("""INSERT INTO candidate(firstname,lastname,birthyear)
                        SELECT %(fn)s,%(ln)s,%(by)s
                        WHERE NOT EXISTS (SELECT *
                                          FROM candidate c
                                          WHERE c.firstname = %(fn)s
                                          AND c.lastname = %(ln)s
                                          AND c.birthyear = %(by)s)
                        RETURNING id""",
                        {'fn' : firstname, 'ln' : lastname, 'by' : birthyear})

        cID = cur.fetchone()

        if cID == None:
            cur.execute("""SELECT id FROM candidate c  WHERE c.firstname = %(fn)s
                                                      AND c.lastname = %(ln)s
                                                      AND c.birthyear = %(by)s""",
                        {'fn' : firstname, 'ln' : lastname, 'by' : birthyear})

            cID = cur.fetchone()


        # check whether candidate wants to win a direct mandate as well
        if wahlkreis != "":
            # if we know of the corresponding election, we add the direct mandate of the candidate
            if electionID != None:
                if partyID != None:
                    cur.execute("INSERT INTO DirectMandate VALUES (%s,%s,%s,%s)",(int(electionID[0]),cID[0],wahlkreis,int(partyID[0])))
                else:
                    cur.execute("INSERT INTO DirectMandate VALUES (%s,%s,%s)",(int(electionID[0]),cID[0],wahlkreis))
            else: raise Error("a direct mandate couldn't be added, the database is missing an election key")

        # check whether candidate is on a landesliste
        if candidate['Partei'] != "" and candidate['Bundesland'] != "":
            # we have to get the right listenplatz on the right landesliste

            #get Bundesland ID of the candidate
            cur.execute("SELECT id FROM bundesland where name=%s",(BLShortcuts[candidate['Bundesland']],)) #ugly, but names happen to be unique for the 16 Bundesländer
            BLandID = cur.fetchone()


            if electionID != None and partyID != None and BLandID != None:

                #get the corresponding landesliste
                cur.execute("SELECT ID FROM landesliste WHERE party=%s AND election=%s AND bundesland=%s",(partyID[0],electionID[0],BLandID[0]))
                ListID = cur.fetchone()

                if ListID != None:
                    cur.execute("INSERT INTO listenplatz VALUES (%s,%s,%s)",(ListID[0],cID[0],candidate['Listenplatz']))
                else: raise Error("a listenplatz couldn't be added, the database is missing a landesliste")
            else: raise Error("a listenplatz couldn't be added, the database is missing an election/party/bundesland")

    conn.commit()


if  __name__ =='__main__': main()
