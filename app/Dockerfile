FROM ubuntu:14.04
WORKDIR /app

RUN apt-get update

# Install python
RUN apt-get install -y python3 python3-pip

# Install nginx
RUN apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:nginx/stable \
    && echo deb http://archive.ubuntu.com/ubuntu trusty-backports main universe | \
      tee /etc/apt/sources.list.d/backports.list \
    && apt-get update \
    && apt-get upgrade -y haproxy -t trusty-backports
#    && apt-get upgrade -y nginx

# Make sure everything is running shiny new versions
RUN apt-get dist-upgrade -y

# Install requirements
ADD requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

# Upload the application
#ADD nginx /etc/nginx
ADD haproxy /etc/haproxy
ADD . /app

# Start everything up
EXPOSE 80
EXPOSE 443
CMD haproxy -f /etc/haproxy/haproxy.cfg -p /etc/haproxy/haproxy.pid && python3 web-server.py & python3 ws-server.py
#CMD python3 web-server.py & python3 ws-server.py
