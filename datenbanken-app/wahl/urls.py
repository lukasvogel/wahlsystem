from django.conf.urls import url

from . import views

urlpatterns = [
    # /e_id/wk_id
    url(r'^(?P<e_id>[0-9]+)/(?P<wk_id>[0-9]+)/$', views.overview, name='ballot'),

]
