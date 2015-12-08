from django.shortcuts import render
from django.template import RequestContext

from .models import Ballot


def overview(request, e_id, wk_id):
    context = RequestContext(request, Ballot.get_ballot(e_id, wk_id))

    return render(request, 'ballot.html', context)
