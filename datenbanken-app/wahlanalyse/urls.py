from django.conf.urls import url

from . import views

urlpatterns = [
    # / : Query1
    url(r'^$', views.overview, name='overview'),


    # /abgeordnete/ : Query2
    url(r'^abgeordnete/$', views.bundestag_overview, name='bundestag_overview'),

    # /wk/5 : Query3
    url(r'^wk/(?P<wk_id>[0-9]+)/$',views.wk_detail, name='wk_detail'),

    # /wk/
    url(r'^wk/',views.wk_overview, name='wk_overview'),

    # /ks/5 : Query6
    url(r'^ks/(?P<party_id>[0-9]+)/$',views.ks_detail, name='ks_detail'),

    # /ks/
    url(r'^ks/', views.ks_overview, name='ks_overview'),



    # chartasjson
    url(r'^chart_as_json$', views.chart_as_json, name='chart_as_json'),


]