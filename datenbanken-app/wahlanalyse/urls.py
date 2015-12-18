from django.conf.urls import url

from . import views

urlpatterns = [
    # / : Query1
    url(r'^(?P<e_id>[0-9]+)/$', views.overview, name='overview'),

    # /e_id/abgeordnete/ : Query2
    url(r'^(?P<e_id>[0-9]+)/abgeordnete/$', views.bundestag_overview, name='bundestag_overview'),

    # /e_id/wk/5 : Query3
    url(r'^(?P<e_id>[0-9]+)/wk/(?P<wk_id>[0-9]+)/$', views.wk_detail, name='wk_detail'),

    # /e_id/wk/
    url(r'^(?P<e_id>[0-9]+)/wk/', views.wk_overview, name='wk_overview'),

    # /e_id/ks/5 : Query6
    url(r'^(?P<e_id>[0-9]+)/ks/(?P<party_id>[0-9]+)/$', views.ks_detail, name='ks_detail'),

    # /e_id/ks/
    url(r'^(?P<e_id>[0-9]+)/ks/', views.ks_overview, name='ks_overview'),

    # /e_id/ueh/
    url(r'^(?P<e_id>[0-9]+)/ueh/', views.overhang_overview, name='overhang_overview'),

    # /e_id/wkmap/
    url(r'^(?P<e_id>[0-9]+)/wkmap/', views.wk_map, name='wk_map'),

]
