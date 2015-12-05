from locust import HttpLocust, TaskSet, task

class UserBehavior(TaskSet):

    @task(25)
    def q1(self):
        self.client.get("/wahlanalyse/2/")

    @task(10)
    def q2(self):
        self.client.get("/wahlanalyse/2/abgeordnete")

    @task(25)
    def q3(self):
        self.client.get("/wahlanalyse/2/wk/1")

    @task(10)
    def q4(self):
        self.client.get("/wahlanalyse/2/wk/")

    @task(10)
    def q5(self):
        self.client.get("/wahlanalyse/2/ueh/")
    @task(20)
    def q6(self):
        self.client.get("/wahlanalyse/2/ks/")


class WebsiteUser(HttpLocust):
    task_set = UserBehavior
    min_wait = 5000
    max_wait = 9000
