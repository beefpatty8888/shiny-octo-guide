# shiny-octo-guide
A forthcoming basic flask site running on gunicorn, with kubernetes deployment yaml to GKE.

## Building the Dockerfile
```
docker system prune
docker build --no-cache -t flask-gunicorn:$(date +%F) .
```

## Running the Docker image
```
docker run -it --rm --expose 8000 -e ENV='local' -p 8000:8000/tcp flask-gunicorn:$(date +%F)
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
docker tag flask-gunicorn:$(date +%F) gcr.io/<project_id>/flask-gunicorn:v1.2

docker push gcr.io/<project_id>/flask-gunicorn:v1.2
```
## Install kubectl
For MacOS and Windows - https://kubernetes.io/docs/tasks/tools/install-kubectl/
```
sudo apt-get install kubectl
```
## Create GKE Cluster
NOTE: f1-micro cannot be selected as the machine type as there is insufficient memory.

Also, I have expanded the scope to allow read-only access to the Compute API. This is generally not recommended in production, but for this basic flask, gunicorn application, I plan to output some debugging information from the instance metadata such as the name of the instance, IP address, etc.

```
gcloud container clusters create <cluster-name> --num-nodes=2 --machine-type=g1-small --scopes=https://www.googleapis.com/auth/compute.readonly,gke-default
```

## Configure kubectl
Configuration will be at `~/.kube/config`
```
gcloud container clusters get-credentials <cluster_name> 
```

## Deployments To The GKE Cluster

### GKE App Deployment (YAML)
```
cd k8s-deployment

vi app-deployment.yml
```
On line 17, replace the `<project_id>` with the actual Google Cloud project id for the deployment.

Then, deploy the application.
```
kubectl apply -f app-deployment.yml
```

### GKE Service Deployment (YAML)
NOTE: In the service deployment, I had set the type to `LoadBalancer` which automatically assigns an external IP address. If this type is removed, then typically an Ingress deployment would also be required: https://kubernetes.io/docs/concepts/services-networking/ingress/, https://cloud.google.com/kubernetes-engine/docs/tutorials/http-balancer

```
kubectl apply -f service-deployment.yml
```

### GKE App Deployment (Command-Line)
```
kubectl create deployment flask-gunicorn --image=gcr.io/<project_id>/flask-gunicorn:v1.2
```

### GKE Service Deployment (Command-Line)
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
* https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ - Kubernetes - App Deployment
* https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer - Kubernetes - Load balancer Service Deployment
* https://cloud.google.com/sdk/gcloud/reference/container/clusters/create#--scopes - gke cluster creation API scopes

