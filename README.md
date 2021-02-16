# shiny-octo-guide
A forthcoming basic flask site running on gunicorn, with kubernetes deployment yaml to GKE.

## Building the Dockerfile
```
docker system prune
docker build --no-cache -t flask-gunicorn:$(date +%F) .
```

## Running the Docker image
```
docker run -it --rm --expose 8000 -p 8000:8000/tcp flask-gunicorn:$(date +%F)
```

Then, from the desktop, go to http://localhost:8000/

# GKE Deployment
NOTE: A prerequisite is for the gcloud CLI to be installed on the local machine. See https://cloud.google.com/sdk/docs/install for the Google Cloud CLI install instructions.

## Find and Set project_id
The project id can be found with the command `gcloud projects list`. 

Set and verify the proper project with the commands `gcloud config set project <project_id>` and `gcloud config get-value project`

## Configure Docker to authenticate with the Google Cloud Container Registry
Configuration will be under `~/.docker/config.json`
```
gcloud auth configure-docker 
```

## Enable the APIs in the project
```
gcloud services enable container.googleapis.com

gcloud services enable containerregistry.googleapis.com
```

## Properly Tag The Container And Push To Google Cloud Container Registry
```
docker tag flask-gunicorn:$(date +%F) gcr.io/<project_id>/flask-gunicorn:$(date +%F)

docker push gcr.io/<project_id>/flask-gunicorn:$(date +%F)
```
## Install kubectl
For MacOS and Windows - https://kubernetes.io/docs/tasks/tools/install-kubectl/
```
sudo apt-get install kubectl
```
## Create GKE Cluster
NOTE: f1-micro cannot be selected as the machine type as there is insufficient memory.
```
gcloud container clusters create <cluster-name> --num-nodes=2 --machine-type=g1-small
```

## Configure kubectl
Configuration will be at `~/.kube/config`
```
gcloud container clusters get-credentials <cluster_name> 
```

## GKE Container Deployment
```
kubectl create deployment flask-gunicorn --image=gcr.io/<project_id>/flask-gunicorn:$(date +%F)
```

## GKE Service, Ingress Deployment
```
kubectl expose deployment flask-gunicorn --type=LoadBalancer --name=flask-gunicorn-service --port=80 --target-port=8000
```

## Verify GKE Service Deployment and View External IP
```
kubectl get services flask-gunicorn-service
```

From browser on local desktop, go to http://<EXTERNAL_IP>

## References
* https://www.digitalocean.com/community/tutorials/how-to-deploy-a-flask-app-using-gunicorn-to-app-platform - tutorial of a flask app using guicorn
* https://docs.gunicorn.org/en/stable/settings.html - gunicorn settings
* https://flask.palletsprojects.com/en/1.1.x/quickstart/ - official Flask documentation
* https://getbootstrap.com/docs/5.0/examples/ - Bootstrap javascript examples
* https://cloud.google.com/kubernetes-engine/docs/quickstart - GKE deployment Quickstart

