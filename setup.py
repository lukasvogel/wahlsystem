import psycopg2
import csv
import datetime


### GLOBAL DEFINITIONS ###

#This function is the equivalent of an SQL-Projection on a CSV-file
def extractValues(fileName, colNames):
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


### CONNECT TO THE DATABASE ###
conn = psycopg2.connect("dbname=wahlsystem user=postgres")
cur = conn.cursor()


### DATABASE CREATION ###

print ("Resetting the database...")

f = open('schema.sql','r')
setupSQL = f.read()
f.close

cur.execute(setupSQL)


### DATABASE-FILLING ###

print("Generating 2013 Election...")
cur.execute("INSERT INTO election(date) VALUES (%s)",(datetime.date(2013,9,22),))

conn.commit()

#Insert all Bundesländer in the bundesland relation
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

print("Inserting all parties...")


for party in extractValues('data/Wahlbewerber2013/wahlbewerber_mit_platz.csv',['Partei']):
    name = party['Partei']
    if not name == '':
        cur.execute("INSERT INTO party(name) VALUES (%s)", (name,))
        print(name)

conn.commit()

print("Inserting all Landeslisten")

for liste in extractValues('data/Wahlbewerber2013/wahlbewerber_mit_platz.csv',['Bundesland','Partei','Wahltermin']):

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


print("Inserting Candidates...")

for candidate in extractValues('data/Wahlbewerber2013/wahlbewerber_mit_platz.csv',['Nachname','Vorname','Jahrgang','Kandidatennummer','Wahlkreis','Partei','Wahltermin','Listenplatz','Bundesland']):
    id = candidate['Kandidatennummer']
    lastname = candidate['Nachname']
    firstname = candidate['Vorname']
    wahltermin = datetime.datetime.strptime(candidate['Wahltermin'],"%Y-%m-%d")
    birthyear = int(candidate['Jahrgang']) #TODO: DOKU SCHEMADEFINITION UPDATEN: date -> smallint für birthyear
    if candidate['Wahlkreis'] == "":
        wahlkreis = 1 #TODO: WAHLKREISE MANCHMAL UNBEKANNT
    else:
        wahlkreis = int(candidate['Wahlkreis'])
    address = '' #TODO: DO WE KNOW THE ADDRESS?
    gender = '?' #TODO: DO WE KNOW THE GENDER?

    # Get the Party-ID of the voter (if one exists)
    cur.execute("SELECT id FROM party WHERE name=%s",(candidate['Partei'],))
    partyID = cur.fetchone() # ugly, but all party names in sample-db are unique

    #get Election ID of the candidate
    cur.execute("SELECT id FROM election WHERE date=%s",(wahltermin,))
    electionID = cur.fetchone()

    # Each candidate is also a voter, so insert voter-tuple first
    cur.execute("""INSERT INTO voter(id,firstname,lastname,birthyear,address,gender,wahlkreis)
                    VALUES (%s,%s,%s,%s,%s,%s,%s)""",(id,firstname,lastname,birthyear,address,gender,wahlkreis))

    # insert candidate and connect to his party if he has one
    if partyID == None:
        cur.execute("INSERT INTO candidate(id,profession) VALUES (%s,%s)",(id,"")) #TODO: Profession unbekannt
    else:
        cur.execute("INSERT INTO candidate(id,profession,party) VALUES (%s,%s,%s)",(id,"",partyID[0]))

    # check whether candidate wants to win a direct mandate as well
    if candidate['Wahlkreis'] != "":
        # if we know of the corresponding election, we add the direct mandate of the candidate
        if electionID != None:
            cur.execute("INSERT INTO DirectMandates VALUES (%s,%s,%s)",(int(electionID[0]),id,wahlkreis))

    # check whether candidate is on a landesliste
    if candidate['Partei'] != "" and candidate['Bundesland'] != "":

        #get Bundesland ID of the candidate
        cur.execute("SELECT id FROM bundesland where name=%s",(BLShortcuts[candidate['Bundesland']],)) #ugly, but names happen to be unique for the 16 Bundesländer
        BLandID = cur.fetchone()


        if electionID != None and partyID != None and BLandID != None:

            #get the corresponding landesliste
            cur.execute("SELECT ID FROM landesliste WHERE party=%s AND election=%s AND bundesland=%s",(partyID[0],electionID[0],BLandID[0]))
            ListID = cur.fetchone()

            if ListID != None:
                cur.execute("INSERT INTO listenplatz VALUES (%s,%s,%s)",(ListID[0],id,candidate['Listenplatz']))
conn.commit()

cur.close()
conn.close()
