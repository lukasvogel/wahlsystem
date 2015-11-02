import psycopg2
import csv

conn = psycopg2.connect("dbname=wahlsystem user=postgres")
cur = conn.cursor()

'''reset the Database '''
print ("Resetting the database...")

f = open('schema.sql','r')
setupSQL = f.read()
f.close

cur.execute(setupSQL)


''' Insert all Bundesländer in the bundesland relation: '''
print("Inserting Bundesländer...")

cur.execute("DELETE FROM bundesland")

cur.execute("""INSERT INTO bundesland VALUES
                (1,'Baden-Württemberg'),
                (2,'Bayern'),
                (3,'Berlin'),
                (4,'Brandenburg'),
                (5,'Bremen'),
                (6,'Hamburg'),
                (7,'Hessen'),
                (8,'Mecklenburg-Vorpommern'),
                (9,'Niedersachsen'),
                (10,'Nordrhein-Westfalen'),
                (11,'Rheinland-Pfalz'),
                (12,'Saarland'),
                (13,'Sachsen'),
                (14,'Sachsen-Anhalt'),
                (15,'Schleswig-Holstein'),
                (16,'Thüringen')""")


''' The file Wahlkreise.csv specifies the Wahlkreise including their number
and the bundesland they are a member of. We insert them into the wahlkreis-relation'''
print ("Inserting Wahlkreise...")

with open('data/inferred/Wahlkreise.csv') as wahlkreise:
    wkreader = csv.DictReader(wahlkreise, delimiter=',')
    for row in wkreader:
        id = int(row["Wahlkreisnummer"])
        name = row["Wahlkreisname"]
        BLand = row["Bundesland"]
        cur.execute("SELECT id FROM bundesland where name=%s",(BLand,))
        BLandId = cur.fetchone()[0]
        cur.execute("INSERT INTO wahlkreis VALUES (%s,%s,%s)", (id,name,BLandId))


conn.commit()


print("\r\n-----WAHLKREISE------")
cur.execute("SELECT w.id, w.name, b.name FROM bundesland b JOIN wahlkreis w ON b.id = w.bundesland")
for c in cur.fetchall():
    print(c)

cur.close()
conn.close()
