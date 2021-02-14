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

## References
* https://www.digitalocean.com/community/tutorials/how-to-deploy-a-flask-app-using-gunicorn-to-app-platform - tutorial of a flask app using guicorn
* https://docs.gunicorn.org/en/stable/settings.html - gunicorn settings
* https://flask.palletsprojects.com/en/1.1.x/quickstart/ - official Flask documentation
* https://getbootstrap.com/docs/5.0/examples/ - Bootstrap javascript examples

