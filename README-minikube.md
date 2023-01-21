## Start Minikube
```
minikube start
```
## Add ingress add-on
```
minikube addons enable ingress
```

## Run minikube tunnel, sudo level may be asked
```
minikube tunnel
```

## Export, Save the Docker image
```
docker save flask-gunicorn:2023-01-21 --output flask-gunicorn.tar
```
## Import into MiniKube
```
minikube image load flask-gunicorn.tar
```
## Verify loaded image
```
minikube image ls
```
It will show with a path with something like `docker.io/library/flask-gunicorn:2023-01-21`

## Apply the Kubernetes service yaml
```
kubectl apply -f service-deployment.yml
```
## Apply the Kubernetes deployment yaml
```
kubectl apply -f app-deployment-minikube.yml
```