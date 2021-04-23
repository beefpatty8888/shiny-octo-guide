from flask import Flask
from flask import render_template
import os
import requests
import subprocess
from subprocess import PIPE


app = Flask(__name__)
# https://stackoverflow.com/questions/34066804/disabling-caching-in-flask
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
properName = "Elvis Presley"
nickName = "The King"
name = properName+" - "+nickName

metadataURLGKE = "http://metadata.google.internal"
metadataHeaderGKE = {'Metadata-flavor': 'Google'}

metadataURLEKS = "http://169.254.169.254"

if not os.environ['ENV']:
    raise RuntimeError("ENV environment variable not set.")

def getInstanceName():

    if os.environ['ENV'] == 'GKE':
        metadataRequest = requests.get(metadataURLGKE+"/computeMetadata/v1/instance/name",headers=metadataHeader)
        returnText = metadataRequest.text
    elif os.environ['ENV'] == 'EKS':
        metadataRequest = requests.get(metadataURLEKS+"/latest/meta-data/instance-id")
        returnText = metadataRequest.text
    else:
        returnText = "App Not Deployed in public cloud"

    return returnText

def getInstanceExternalIP():
    if os.environ['ENV'] == 'GKE':
        metadataRequest = requests.get(metadataURLGKE+"/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip",headers=metadataHeader)
        returnText = metadataRequest.text
    elif os.environ['ENV'] == 'EKS':
        metadataRequest = requests.get(metadataURLEKS+"/latest/meta-data/public-ipv4")
        # https://stackoverflow.com/questions/15258728/requests-how-to-tell-if-youre-getting-a-404
        if metadataRequest.ok:
            returnText = metadataRequest.text
        else:
            returnText = "No external IP"
    else:
        returnText = "App Not Deployed in public cloud"

    return returnText

def getEgressIP():
    egressIP = subprocess.run(["dig", "+short","myip.opendns.com", "@resolver1.opendns.com"], stdout=PIPE, stderr=PIPE).stdout
    returnText = egressIP.decode('ascii')

    return returnText

@app.route('/')
def index_page():

    instanceName = getInstanceName()
    instanceExternalIP = getInstanceExternalIP()
    egressIP = getEgressIP()

    homeStateCSS = "active"
    alwaysOnMyMindStateCSS = ""
    return render_template ('index.html', title=nickName+" - "+properName,properName=properName,instanceName=instanceName, instanceExternalIP=instanceExternalIP, egressIP=egressIP, homeStateCSS=homeStateCSS, alwaysOnMyMindStateCSS=alwaysOnMyMindStateCSS)

@app.route('/always-on-my-mind')
def always_on_my_mind_page():
    
    instanceName = getInstanceName()
    instanceExternalIP = getInstanceExternalIP()
    egressIP = getEgressIP()

    homeStateCSS = ""
    alwaysOnMyMindStateCSS = "active"
    return render_template ('always-on-my-mind.html',title=nickName+" - "+properName,instanceName=instanceName, instanceExternalIP=instanceExternalIP, egressIP=egressIP, homeStateCSS=homeStateCSS, alwaysOnMyMindStateCSS=alwaysOnMyMindStateCSS)

