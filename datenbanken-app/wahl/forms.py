import psycopg2
from django import forms

conn = psycopg2.connect("host=localhost dbname=wahlsystem user=postgres password=Password01")
conn.autocommit = True


class BallotForm(forms.Form):
    def __init__(self, *args, **kwargs):
        wk_id = kwargs.pop('wk_id')
        e_id = kwargs.pop('e_id')
        super(BallotForm, self).__init__(*args, **kwargs)

        cur = conn.cursor()

        # get candidats for first vote
        cur.execute(
            """
              select c.id,c.firstname, c.lastname, p.name
              from directmandate d
	            join candidate c on c.id = d.candidate
	            left join party p on d.party = p.id
              where election = %s
              and wahlkreis = %s
            """, (e_id, wk_id)
        )

        first_vote = []

        for candidate in cur.fetchall():
            first_vote.append(
                (candidate[0],  # id
                 # DAS SIEHT HOFFENTLICH NIEMALS IRGENDJEMAND!!!!
                 '<td><b>' + candidate[2] + '</b>, ' + candidate[1] + '</td><td><b>' + str(candidate[3]) + '</b></td>'
                 ))

        # get parties for second vote
        cur.execute(
            """
              select p.id,p.name
              from wahlkreis w
	            join landesliste l on w.bundesland = l.bundesland
	            join bundesland b on w.bundesland = b.id
	            join party p on l.party = p.id
              where w.id = %s
              and l.election = %s
            """, (wk_id, e_id)
        )

        second_vote = []

        for party in cur.fetchall():
            second_vote.append(
                (party[0],  # id
                 party[1]  # name
                 ))

        self.fields['erststimme'] = forms.ChoiceField(widget=forms.RadioSelect, choices=first_vote)
        self.fields['zweitstimme'] = forms.ChoiceField(widget=forms.RadioSelect, choices=second_vote)

        self.fields['token'] = forms.CharField(label='Token', max_length=100)
