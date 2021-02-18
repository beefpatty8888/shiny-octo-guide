from flask import Flask
from flask import render_template
import os
import requests

app = Flask(__name__)
# https://stackoverflow.com/questions/34066804/disabling-caching-in-flask
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
properName = "Elvis Presley"
nickName = "The King"
name = properName+" - "+nickName

metadataURL = "http://metadata.google.internal"
metadataHeader = {'Metadata-flavor': 'Google'}

if not os.environ['ENV']:
    raise RuntimeError("ENV environment variable not set.")

def getInstanceName():

    if os.environ['ENV'] == 'local':
        returnText = "App Not Deployed in GKE"
    else:
        metadataRequest = requests.get(metadataURL+"/computeMetadata/v1/instance/name",headers=metadataHeader)
        returnText = metadataRequest.text

    return returnText

def getInstanceExternalIP():
    if os.environ['ENV'] == 'local':
        returnText = "App Not Deployed in GKE"
    else:
        metadataRequest = requests.get(metadataURL+"/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip",headers=metadataHeader)
        returnText = metadataRequest.text

    return returnText

@app.route('/')
def index_page():

    instanceName = getInstanceName()
    instanceExternalIP = getInstanceExternalIP()
    return render_template ('index.html', title=nickName+" - "+properName,properName=properName,instanceName=instanceName, instanceExternalIP=instanceExternalIP)