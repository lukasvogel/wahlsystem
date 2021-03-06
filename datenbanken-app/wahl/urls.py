from django.conf.urls import url
from . import views

urlpatterns = [


    # wahl/e_id/wk_id/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/$', views.ballot, name='ballot'),

    # wahl/e_id/wk_id/vote/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/vote/$', views.vote, name='vote'),

    # wahl/e_id/wk_id/invalidvote/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/invalidvote/$', views.invalidvote, name='invalidvote'),

    # wahl/e_id/wk_id/internalerror/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/internalerror/$', views.internalerror, name='internalerror'),

    # wahl/e_id/wk_id/success/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/success/$', views.success, name='success'),

    # wahl/tokens/e_id/wk_id/token_no/
    url(r'^tokens/(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/(?P<token_no>[0-9]+)/$', views.generatetokens, name='tokens'),

    # wahl/verify/e_id/v_id/
    url(r'^verify/(?P<e_id>[0-9]+)/(?P<v_id>[0-9]+)/$', views.verifyvoter, name='verify')

]
