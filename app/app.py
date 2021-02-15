from flask import Flask
from flask import render_template
app = Flask(__name__)
# https://stackoverflow.com/questions/34066804/disabling-caching-in-flask
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
name = "The King - Elvis Presley"

@app.route('/')
def index_page():
    return render_template ('index.html', name=name)