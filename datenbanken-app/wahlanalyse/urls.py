from django.conf.urls import url
from . import views

urlpatterns = [
    # / : Query1
    url(r'^(?P<e_id>[0-9]+)/$', views.overview, name='overview'),

    # /e_id/abgeordnete/ : Query2
    url(r'^(?P<e_id>[0-9]+)/abgeordnete/$', views.bundestag_overview, name='bundestag_overview'),

    # /e_id/wk/5 : Query3
    url(r'^(?P<e_id>[0-9]+)/wk/(?P<wk_id>[0-9]+)/$', views.wk_detail, name='wk_detail'),

    # /e_id/q7/wk:id ; Query7, unaggregated
    url(r'^(?P<e_id>[0-9]+)/q7/(?P<wk_id>[0-9]+)/$', views.wk_detail_unaggregated, name='wk_detail_unaggregated'),

    # /e_id/wk/
    url(r'^(?P<e_id>[0-9]+)/wk/', views.wk_overview, name='wk_overview'),

    # /e_id/ks/5 : Query6
    url(r'^(?P<e_id>[0-9]+)/ks/(?P<party_id>[0-9]+)/$', views.ks_detail, name='ks_detail'),

    # /e_id/ks/
    url(r'^(?P<e_id>[0-9]+)/ks/', views.ks_overview, name='ks_overview'),

    # /e_id/ueh/
    url(r'^(?P<e_id>[0-9]+)/ueh/', views.overhang_overview, name='overhang_overview'),

    # /e_id/wkmap/zweitstimmen
    url(r'^(?P<e_id>[0-9]+)/wkmap/zweitstimmen/$', views.wk_map_zweitstimmen, name='wk_map_zweitstimmen'),

    # /e_id/wkmap/zweitstimmen/p_id
    url(r'^(?P<e_id>[0-9]+)/wkmap/zweitstimmen/(?P<party_id>[0-9]+)/$', views.wk_map_zweitstimmen_party,
        name='wk_map_zweitstimmen_party'),

    # /e_id/wkmap/erststimmen
    url(r'^(?P<e_id>[0-9]+)/wkmap/erststimmen/$', views.wk_map_erststimmen, name='wk_map_erststimmen'),

    # /e_id/wkmap/erststimmen/p_id
    url(r'^(?P<e_id>[0-9]+)/wkmap/erststimmen/(?P<party_id>[0-9]+)/$', views.wk_map_erststimmen_party,
        name='wk_map_erststimmen_party')

]
