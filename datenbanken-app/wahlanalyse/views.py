from django.template import RequestContext, loader
from django.http import HttpResponse
import psycopg2

conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
cur = conn.cursor()
conn.autocommit = True

def index(request):
    return HttpResponse("Hallo, Welt!")


def wk_detail(request, wk_id):

    cur.execute("SELECT * FROM wahlkreis w WHERE w.id = %s", (wk_id,))
    members = cur.fetchone();

    template = loader.get_template('wahlkreis.html')
    context = RequestContext(request, {
        'wk_id' : wk_id,
        'wk_name' : members[1]
    })

    return HttpResponse(template.render(context))


def bundestag_overview(request):
    cur.execute("""SELECT mb.firstname, mb.lastname, mb.party, mb.bundesland, dw.wahlkreis
          FROM members_of_bundestag_2013 mb LEFT JOIN directmandate_winners dw ON mb.id = dw.candidate AND dw.election = 2
          ORDER BY mb.lastname""")
    members = cur.fetchall();

    template = loader.get_template('bundestag_overview.html')
    context = RequestContext(request, {
        'members' : members,
    })

    return HttpResponse(template.render(context))
