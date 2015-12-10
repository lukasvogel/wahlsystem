from django.conf.urls import url

from . import views

urlpatterns = [
    # wahl/e_id/wk_id
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/$', views.ballot, name='ballot'),

    # wahl/e_id/wk_id/vote/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/vote/$', views.vote, name='vote'),

    # wahl/e_id/wk_id/invalidvote/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/invalidvote/$', views.invalidvote, name='invalidvote'),

    # wahl/e_id/wk_id/internalerror/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/internalerror/$', views.internalerror, name='internalerror'),

    # wahl/e_id/wk_id/success/
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/success/$', views.success, name='success'),


]
