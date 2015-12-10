from django.http import HttpResponseRedirect
from django.shortcuts import render

from .forms import BallotForm
from .models import Ballot
from .models import VoteHandler


def vote(request, e_id, wk_id):
    # handle incoming vote
    if request.method == 'POST':
        form = BallotForm(request.POST, wk_id=wk_id, e_id=e_id)

        if form.is_valid():
            candidate = form.cleaned_data['erststimme']
            party = form.cleaned_data['zweitstimme']
            token = form.cleaned_data['token']

            if VoteHandler.check(token, candidate, party):
                if VoteHandler.vote(token, candidate, party):
                    return HttpResponseRedirect('../success')
                else:
                    # internal error, USER NOT AT FAULT:
                    # commit to database failed
                    # or token was used by other person between check() and vote() => wahlhelfer gave out token twice
                    # user should contact Wahlhelfer
                    # => WE HAVE TO FIX THIS
                    return HttpResponseRedirect('../internalerror')
            else:
                # invalid data, FAULT OF THE USER:
                # user entered wrong data (ill-formatted token, invalid token, id of party not on landesliste, ...
                # show error page and let user retry by herself
                # => USER HAS TO FIX THIS
                return HttpResponseRedirect('../invalidvote')

    # invalid data, see above
    return HttpResponseRedirect('../invalidvote')


def ballot(request, e_id, wk_id):
    form = BallotForm(wk_id=wk_id, e_id=e_id)

    context = Ballot.get_ballot(e_id, wk_id)
    context['form'] = form

    return render(request, 'ballot.html', context)


def invalidvote(request, e_id, wk_id):
    context = {
        'wk_id': wk_id,
        'e_id': e_id
    }

    return render(request, 'invalidvote.html', context)


def internalerror(request, e_id, wk_id):
    context = {
        'wk_id': wk_id,
        'e_id': e_id
    }

    return render(request, 'internalerror.html', context)


def success(request, e_id, wk_id):
    context = {
        'wk_id': wk_id,
        'e_id': e_id
    }

    return render(request, 'success.html', context)
