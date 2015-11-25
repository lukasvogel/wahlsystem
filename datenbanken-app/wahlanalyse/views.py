import json

from django.http import HttpResponse
from django.shortcuts import render
from django.template import RequestContext

from .models import BundestagMembers
from .models import ClosestWinners
from .models import Overview
from .models import Wahlkreise

bm = BundestagMembers()
wk = Wahlkreise()
ov = Overview()
cw = ClosestWinners()


def index(request):
    context = RequestContext(request)

    return render(request, 'overview.html', context)


def overview(request):
    context = RequestContext(request, {
        'parties': ov.get_composition(2),
        'series': ov.get_percentages(2)
    })

    return render(request, 'overview.html', context)


def wk_overview(request):
    context = RequestContext(request, {
        'wahlkreise': wk.get_overview(2)
    })

    return render(request, 'wk_overview.html', context)


def wk_detail(request, wk_id):
    context = RequestContext(request, wk.get_details(wk_id))

    return render(request, 'wahlkreis.html', context)


def bundestag_overview(request):
    context = RequestContext(request, {
        'members': bm.get_members(2),
    })

    return render(request, 'abgeordnete.html', context)


def ks_overview(request):
    context = RequestContext(request, {
        'parties': cw.overview(2)
    })

    print(cw.overview(2))

    return render(request, 'closest_outcome_overview.html', context)


def ks_detail(request, party_id):
    context = RequestContext(request, {
        'closest': cw.get_winners(2, party_id),
        'party_id': party_id

    })

    return render(request, 'closest_outcome_detail.html', context)


def chart_as_json(request):
    data = ov.get_composition(2)
    series = [{'data': data,
               'name': 'Sitze',
               'type': 'pie',
               'innerSize': '50%'}]
    return HttpResponse(json.dumps(series), content_type='application/json')
