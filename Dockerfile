FROM ubuntu:bionic

RUN apt update
RUN apt install curl git gnupg2 build-essential zlib1g-dev sudo python3-pip -y
RUN pip3 install Flask gunicorn requests
RUN useradd -m app
RUN echo 'app ALL=(ALL) NOPASSWD: /usr/bin/apt,/usr/bin/apt-get' >> /etc/sudoers.d/app
RUN mkdir /app
COPY app /app
RUN chown -R app:app /app
USER app

ENV FLASK_APP=app.py
ENTRYPOINT cd /app && gunicorn --config=gunicorn_config.py app:app
