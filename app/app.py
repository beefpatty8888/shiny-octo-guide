from flask import Flask
from flask import render_template
app = Flask(__name__)
name = "The King - Elvis Presley"

@app.route('/')
def index_page():
    return render_template ('index.html', name=name)