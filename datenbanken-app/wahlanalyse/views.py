from django.template import RequestContext, loader
from django.http import HttpResponse

from .models import Bundestag_Members

import psycopg2

conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres")
cur = conn.cursor()
conn.autocommit = True

bm = Bundestag_Members()

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

    template = loader.get_template('bundestag_overview.html')
    context = RequestContext(request, {
        'members' : bm.getMembers(2),
    })

    return HttpResponse(template.render(context))