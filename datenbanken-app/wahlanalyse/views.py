from django.template import RequestContext
from django.shortcuts import render
from django.http import HttpResponse
import json
from .models import BundestagMembers
from .models import Wahlkreise
from .models import Overview

bm = BundestagMembers()
wk = Wahlkreise()
ov = Overview()


def index(request):
    context = RequestContext(request)

    return render(request, 'overview.html', context)


def overview(request):
    context = RequestContext(request, {
        'parties': ov.get_composition(2),
        'series': ov.get_percentages(2)
    })

    return render(request, 'overview.html', context)


def wk_detail(request, wk_id):
    context = RequestContext(request, wk.get_info(wk_id))

    return render(request, 'wahlkreis.html', context)


def bundestag_overview(request):
    context = RequestContext(request, {
        'members': bm.get_members(2),
    })

    return render(request, 'abgeordnete.html', context)


def chart_as_json(request):
    data = ov.get_composition(2)
    series = [{'data': data,
               'name': 'Sitze',
               'type': 'pie',
               'innerSize': '50%'}]
    return HttpResponse(json.dumps(series), content_type='application/json')

