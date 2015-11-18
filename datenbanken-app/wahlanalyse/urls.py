from django.conf.urls import url

from . import views

urlpatterns = [
    # /index/
    url(r'^$', views.bundestag_overview, name='bundestag_overview'),

    # /wk/5
    url(r'^wk/(?P<wk_id>[0-9]+)/$',views.wk_detail, name='wk_detail')
]