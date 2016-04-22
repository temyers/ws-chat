Based on the this original post: https://blog.jverkamp.com/2015/07/20/configuring-websockets-behind-an-aws-elb/

With reference to:
* https://www.built.io/blog/2014/11/websockets-on-aws-elb/
* https://chrislea.com/2014/03/20/using-proxy-protocol-nginx/

Playing with AWS + ELB and SSL passthrough and SSL Termination and Proxy Protocol

CAVEAT:
There are no SSL certificates included in this repo.
Notice the `nginx/test-cert.key` and `nginx/test-cert.pem` are included in the configuration but ignored (.gitignore)
You will need to create a certificate:
 * https://letsencrypt.org/

Build the image:

```
ws-chat$ docker build app
Sending build context to Docker daemon 20.99 kB
Sending build context to Docker daemon 
Step 0 : FROM ubuntu:14.04
 ---> a572fb20fc42
Step 1 : WORKDIR /app
 ---> Using cache
 ---> 2cebf05f3e7f
Step 2 : RUN apt-get update
 ---> Using cache
 ---> 906ec93df557
Step 3 : RUN apt-get install -y python3 python3-pip
 ---> Using cache
 ---> 6aa545436e1c
Step 4 : RUN apt-get install -y software-properties-common     && add-apt-repository -y ppa:nginx/stable     && apt-get update     && apt-get upgrade -y nginx
 ---> Using cache
 ---> 973da0765c8b
Step 5 : RUN apt-get dist-upgrade -y
 ---> Using cache
 ---> 3ce445487b44
Step 6 : ADD requirements.txt requirements.txt
 ---> Using cache
 ---> 70fde276b182
Step 7 : RUN pip3 install -r requirements.txt
 ---> Using cache
 ---> 69b0eeb6ba84
Step 8 : ADD nginx /etc/nginx
 ---> Using cache
 ---> 3a81d73eb984
Step 9 : ADD . /app
 ---> Using cache
 ---> a38f060edeef
Step 10 : EXPOSE 80
 ---> Using cache
 ---> 795ef7c9c770
Step 11 : CMD nginx && python3 web-server.py & python3 ws-server.py
 ---> Using cache
 ---> 9094114c74ca
Successfully built 9094114c74ca
```

Run the image:

```
export IMAGE=9094114c74ca
docker run -p 8443:443 -t -i $IMAGE
```

Where 8443 is the local port that you will connect to
443 is the port exposed by the docker container.

If you're playing with HTTP, then the above will need to change to port 80 and you'll need to update the Dockerfile to expose it.

```$ docker run -p 8443:443 -t -i $IMAGE
Enter PEM pass phrase:
 * Running on http://0.0.0.0:8000/ (Press CTRL+C to quit)
 * Restarting with stat
 * Debugger is active!
 * Debugger pin code: 216-433-971

```


Test it (locally):

```
$ curl -kvvvvL https://localhost:8443
* Rebuilt URL to: https://localhost:8443/
* Hostname was NOT found in DNS cache
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8443 (#0)
* successfully set certificate verify locations:
*   CAfile: none
  CApath: /etc/ssl/certs
* SSLv3, TLS handshake, Client hello (1):
* SSLv3, TLS handshake, Server hello (2):
* SSLv3, TLS handshake, CERT (11):
* SSLv3, TLS handshake, Server key exchange (12):
* SSLv3, TLS handshake, Server finished (14):
* SSLv3, TLS handshake, Client key exchange (16):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSL connection using ECDHE-RSA-AES256-GCM-SHA384
* Server certificate:
* 	 redacted
* 	 start date: 2016-03-17 03:37:50 GMT
* 	 expire date: 2017-03-17 03:37:50 GMT
* 	 redacted
* 	 SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8443
> Accept: */*
> 
< HTTP/1.1 200 OK
* Server nginx/1.8.1 is not blacklisted
< Server: nginx/1.8.1
< Date: Fri, 22 Apr 2016 07:25:10 GMT
< Content-Type: text/html; charset=utf-8
< Content-Length: 1657
< Connection: keep-alive
< 
<html>
<head>
    <title>Chat example</title>

    <script src="//cdnjs.cloudflare.com/ajax/libs/jquery/3.0.0-alpha1/jquery.min.js"></script>
</head>

<body>
    <input id="text" type="text" />
    <input id="send" type="submit" />
    <div id="chat-log"></div>
</body>

<script>
$(function() {
    var is_secure = (window.location.protocol === "https:");
    var ws = new WebSocket((is_secure ? "wss://" : "ws://") + document.location.host + "/ws/");

    ws.onopen = function (event) {
        console.log('READY');
        $('div#chat-log').prepend('<p>Connected to chat server</p>');
    };

    ws.onmessage = function (event) {
        var msg = JSON.parse(event.data);
        console.log(msg);

        if ('hello' in msg) {
            $('div#chat-log').prepend('<p>' + msg['hello'] + ' has joined the chat</p>');
        } else if ('goodbye' in msg) {
            $('div#chat-log').prepend('<p>' + msg['goodbye'] + ' has left the chat</p>');
        } else if ('name' in msg) {
            $('div#chat-log').prepend('<p>' + msg['name']['old'] + ' is now known as ' + msg['name']['new'] + '</p>');
        } else if ('say' in msg) {
            $('div#chat-log').prepend('<p>' + msg['say']['name'] + ': ' + msg['say']['msg'] + '</p>');
        }
    };

    $('input#send').click(function() {
        var cmd = $('input#text').val();
        var msg = {};

        if (cmd.match('^/name')) {
            msg['name'] = cmd.split(' ').slice(1).join(' ');
        } else {
            msg['say'] = cmd;
        }

        console.log('SEND: ' + msg);
        ws.send(JSON.stringify(msg));
        $('input#text').val('');
    });
});
</script>
* Connection #0 to host localhost left intact
```

Test against ELB:

```
$ curl -kvL https://testElb.us-east-1.elb.amazonaws.com:443
* Rebuilt URL to: https://testElb.us-east-1.elb.amazonaws.com:443/
* Hostname was NOT found in DNS cache
*   Trying x.x.x.x...
* Connected to testElb.us-east-1.elb.amazonaws.com (x.x.x.x) port 443 (#0)
* successfully set certificate verify locations:
*   CAfile: none
  CApath: /etc/ssl/certs
* SSLv3, TLS handshake, Client hello (1):
* SSLv3, TLS handshake, Server hello (2):
* SSLv3, TLS handshake, CERT (11):
* SSLv3, TLS handshake, Server key exchange (12):
* SSLv3, TLS handshake, Server finished (14):
* SSLv3, TLS handshake, Client key exchange (16):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSLv3, TLS change cipher, Client hello (1):
* SSLv3, TLS handshake, Finished (20):
* SSL connection using ECDHE-RSA-AES256-GCM-SHA384
* Server certificate:
* 	 redacted
* 	 start date: 2016-03-17 03:37:50 GMT
* 	 expire date: 2017-03-17 03:37:50 GMT
* 	 redacted
* 	 SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: testElb.us-east-1.elb.amazonaws.com
> Accept: */*
> 
< HTTP/1.1 200 OK
* Server nginx/1.8.1 is not blacklisted
< Server: nginx/1.8.1
< Date: Fri, 22 Apr 2016 07:52:00 GMT
< Content-Type: text/html; charset=utf-8
< Content-Length: 1657
< Connection: keep-alive
< 
<html>
<head>
    <title>Chat example</title>

    <script src="//cdnjs.cloudflare.com/ajax/libs/jquery/3.0.0-alpha1/jquery.min.js"></script>
</head>

<body>
    <input id="text" type="text" />
    <input id="send" type="submit" />
    <div id="chat-log"></div>
</body>

<script>
$(function() {
    var is_secure = (window.location.protocol === "https:");
    var ws = new WebSocket((is_secure ? "wss://" : "ws://") + document.location.host + "/ws/");

    ws.onopen = function (event) {
        console.log('READY');
        $('div#chat-log').prepend('<p>Connected to chat server</p>');
    };

    ws.onmessage = function (event) {
        var msg = JSON.parse(event.data);
        console.log(msg);

        if ('hello' in msg) {
            $('div#chat-log').prepend('<p>' + msg['hello'] + ' has joined the chat</p>');
        } else if ('goodbye' in msg) {
            $('div#chat-log').prepend('<p>' + msg['goodbye'] + ' has left the chat</p>');
        } else if ('name' in msg) {
            $('div#chat-log').prepend('<p>' + msg['name']['old'] + ' is now known as ' + msg['name']['new'] + '</p>');
        } else if ('say' in msg) {
            $('div#chat-log').prepend('<p>' + msg['say']['name'] + ': ' + msg['say']['msg'] + '</p>');
        }
    };

    $('input#send').click(function() {
        var cmd = $('input#text').val();
        var msg = {};

        if (cmd.match('^/name')) {
            msg['name'] = cmd.split(' ').slice(1).join(' ');
        } else {
            msg['say'] = cmd;
        }

        console.log('SEND: ' + msg);
        ws.send(JSON.stringify(msg));
        $('input#text').val('');
    });
});
</script>
* Connection #0 to host testElb.us-east-1.elb.amazonaws.com left intact
</html>
```

Connect to the Docker instance:

```$ docker ps
CONTAINER ID        IMAGE                 COMMAND                CREATED             STATUS              PORTS                           NAMES
a2b6ce8e6c80        958b4f752023:latest   "/bin/sh -c 'nginx &   6 seconds ago       Up 6 seconds        80/tcp, 0.0.0.0:8443->443/tcp   pensive_wozniak     
ubuntu@ip-10-3-0-76:~/tops-184/ws-chat$ sudo docker exec -i -t a2b6ce8e6c80 bash
root@a2b6ce8e6c80:/app# exit
```

logs:
* /var/log/nginx
* /tmp
