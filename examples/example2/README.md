return to [main page](../..)

## Example 2

``` mermaid
graph TB

    a1[curl] -.->a2[caddy container reverse proxy]
    a2 -->|"for http&colon;//whoami.example.com&colon;8080"| a3["whoami container"]
    a2 -->|"for http&colon;//nginx.example.com&colon;8080"| a4["nginx container"]
```

Set up a systemd user service _example2.service_ for the user _test_ where rootless podman is
running the container image _docker.io/library/caddy_. Configure _socket activation_ for TCP port 8080.
The caddy container is acting as a HTTP reverse proxy that forwards requests to 2 backends.
Requests to http://whoami.example.com:8080 are forwarded to the _whoami_ container.
Requests to http://ngnix.example.com:8080 are forwarded to the _nginx_ container.

In this example the curl option __--resolve__ option is used for name resolution.
In other words, the domain names _whoami.example.com_ and _nginx.example.com_ do not need to be
resolvable in public DNS.

1. Create a test user
   ```
   sudo useradd --create-home test
   ```
1. Open a shell for user _test_
   ```
   sudo machinectl shell --uid=test
   ```
1. Optional step: enable lingering to avoid services from being stopped when the
   user _test_ logs out.
   ```
   loginctl enable-linger test
   ```
1. Create directories
   ```
   mkdir -p ~/.config/systemd/user
   mkdir -p ~/.config/containers/systemd
   ```
1. Pull _caddy_ container image
   ```
   podman pull docker.io/library/caddy
   ```
1. Pull _whoami_ container image
   ```
   podman pull docker.io/traefik/whoami
   ```
1. Clone git repo
   ```
   git clone https://github.com/eriksjolund/podman-caddy-socket-activation.git
   ```
1. Install the network unit file
   ```
   cp podman-caddy-socket-activation/examples/example2/mynet.network \
      ~/.config/containers/systemd/
   ```
1. Install the container unit files
   ```
   cp podman-caddy-socket-activation/examples/example2/*.container \
      ~/.config/containers/systemd/
   ```
1. Install the socket unit files
   ```
   cp podman-caddy-socket-activation/examples/example2/caddy.socket \
      ~/.config/systemd/user/
   ```
1. Install the _Caddyfile_
   ```
   cp podman-caddy-socket-activation/examples/example2/Caddyfile \
      ~/Caddyfile
   ```
   (The path _~/Caddyfile_ was arbitrarily chosen)
1. Reload the systemd user manager
   ```
   systemctl --user daemon-reload
   ```
1. Start the socket for TCP port 8080
   ```
   systemctl --user start caddy.socket
   ```
1. Pull the _whoami_ container image
   ```
   podman pull docker.io/traefik/whoami
   ```
1. Pull the nginx container image
   ```
   podman pull docker.io/library/nginx
   ```
1. Start the _nginx_ container
   ```
   systemctl --user start nginx.service
   ```
1. Start the _whoami_ container
   ```
   systemctl --user start whoami.service
   ```
1. Download the URL __http://nginx.example.com:8080__ from the caddy
   container and see that the request is proxied to the container _nginx_.
   Resolve _nginx.example.com_ to _127.0.0.1_.
   ```
   curl -s --resolve nginx.example.com:8080:127.0.0.1 \
     http://nginx.example.com:8080 | head -4
   ```
   The following output is printed
   ```
   <!DOCTYPE html>
   <html>
   <head>
   <title>Welcome to nginx!</title>
   ```
   __result:__ The default nginx web page was downloaded
1. Download the URL __http://whoami.example.com:8080__ from the caddy
   container and see that the request is proxied to the container _whoami_.
   Resolve _whoami.example.com_ to _127.0.0.1_.
   ```
   curl -s --resolve whoami.example.com:8080:127.0.0.1 \
     http://whoami.example.com:8080 | grep X-Forwarded-For
   ```
   The following output is printed
   ```
   X-Forwarded-For: 127.0.0.1
   ```
   __result:__ The IPv4 address 127.0.0.1 matches the IP address of
   _X-Forwarded-For_
1. Check the IPv4 address of the main network interface.
   Run the command
   ```
   hostname -I
   ```
   The following output is printed
   ```
   192.168.10.108 192.168.39.1 192.168.122.1 fd25:c7f8:948a:0:912d:3900:d5c4:45ad
   ```
   __result:__ The IPv4 address of the main network interface is _192.168.10.108_
   (the address furthest to the left). Note, the detected IP address will
   most probably be different when you try it out on your system.
1. Download the URL __http://whoami.example.com:8080__ from the caddy
   container and see that the request is proxied to the container _whoami_.
   Resolve _whoami.example.com_ to the IP address of the main network interface.
   Use the IP address that was detected in the previous step.
   ```
   curl -s --resolve whoami.example.com:8080:192.168.10.108 \
     http://whoami.example.com:8080 | grep X-Forwarded-For
   ```
   The following output is printed
   ```
   X-Forwarded-For: 192.168.10.108
   ```
   __result:__ The IPv4 address of the main network interface,
   _192.168.10.108_, matches the IPv4 address
   of _X-Forwarded-For_
1. From another computer download a web page __http://whoami.example.com:8080__ from the caddy
   container and see that the request is proxied to the container _whoami_.
   ```
   curl -s --resolve whoami.example.com:8080:192.168.10.108 \
     http://whoami.example.com:8080 | grep X-Forwarded-For
   ```
   The following output is printed
   ```
   X-Forwarded-For: 192.168.10.161
   ```
   Check the IP address of the other computer (which in this example runs macOS).
   In the macOS terminal run the command
   ```
   ipconfig getifaddr en0
   ```
   The following output is printed
   ```
   192.168.10.161
   ```
   __result:__ The IPv4 address of the other computer matches the IPv4 address
   of _X-Forwarded-For_

### Using `Internal=true`

The file [_mynet.network_](mynet.network) currently contains

```
[Network]
Internal=true
```

The line

```
Internal=true
```

prevents containers on the network _mynet_ to connect to the internet.
To allow containers on that network to download files from the internet you
would need to remove the line.
