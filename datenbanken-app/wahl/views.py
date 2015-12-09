from django.http import HttpResponseRedirect
from django.shortcuts import render

from .forms import BallotForm
from .models import Ballot


def vote(request, e_id, wk_id):
    # handle incoming vote
    if request.method == 'POST':
        form = BallotForm(request.POST, wk_id=wk_id, e_id=e_id)
        print(form.data)

        if form.is_valid():
            return HttpResponseRedirect('/wahl/2/1')
    # handle normal request
    else:
        form = BallotForm(wk_id=wk_id, e_id=e_id)

        context = Ballot.get_ballot(e_id, wk_id)
        context['form'] = form

        return render(request, 'ballot.html', context)
