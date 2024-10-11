return to [main page](../..)

## Example 4

_Example 4_ is similar to _Example 2_ but _Example 4_ also provides HTTP/3 support.

``` mermaid
graph TB

    a1[curl] -.->a2[caddy container reverse proxy]
    a2 -->|"for https&colon;//whoami.example.com"| a3["whoami container"]
    a2 -->|"for https&colon;//nginx.example.com"| a4["nginx container"]
```

Set up a systemd user service _example4.service_ for the user _test_ where rootless podman is running
the container image _localhost/caddy_.
Configure _socket activation_ for the ports 80/TCP, 443/TCP and 443/UDP.
A TLS certificate is automatically retrieved with the
[ACME](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment) prototol.
The caddy container is acting as a HTTP reverse proxy that forwards requests to 2 backends.
Requests to https://whoami.example.com are forwarded to the _whoami_ container.
Requests to https://nginx.example.com are forwarded to the _nginx_ container.

1. Verify that unprivileged users are allowed to open port numbers 80 and above.
   Run the command
   ```
   cat /proc/sys/net/ipv4/ip_unprivileged_port_start
   ```
   Make sure the number printed is not higher than 80. To configure the number,
   see https://rootlesscontaine.rs/getting-started/common/sysctl/#allowing-listening-on-tcp--udp-ports-below-1024
1. Verify that the domain names _nginx.example.com_ and _whoami.example.com_ resolve to
   the IP address of the host's main IPv4 interface.
   Run commands to resolve the hostnames.
   ```
   host nginx.example.com
   ```
   and
   ```
   host whoami.example.com
   ```
   Verify that the results match the left-most IPv4 address shown by the command `hostname -I`.
1. Create a test user
   ```
   sudo useradd test
   ```
1. Open a shell for user _test_
   ```
   sudo machinectl shell --uid=test
   ```
1. Optional step: enable lingering to avoid services from being stopped when
   the user _test_ logs out.
   ```
   loginctl enable-linger test
   ```
1. Create directories
   ```
   mkdir -p ~/.config/systemd/user
   mkdir -p ~/.config/containers/systemd
   ```
1. Pull the caddy container image
   ```
   podman pull docker.io/library/caddy
   ```
1. Pull the _whoami_ container image
   ```
   podman pull docker.io/traefik/whoami
   ```
1. Clone git repo
   ```
   git clone https://github.com/eriksjolund/podman-caddy-socket-activation.git
   ```
1. Install the container unit files
   ```
   cp podman-caddy-socket-activation/examples/example4/*.container \
      ~/.config/containers/systemd/
   ```
1. Install the network unit file
   ```
   cp podman-caddy-socket-activation/examples/example4/mynet.network \
      ~/.config/containers/systemd/
   ```
1. Install the socket unit file
   ```
   cp podman-caddy-socket-activation/examples/example4/caddy.socket \
      ~/.config/systemd/user/
   ```
1. Install the _Caddyfile_
   ```
   cp podman-caddy-socket-activation/examples/example4/Caddyfile \
      ~/Caddyfile
   ```
   (The path _~/Caddyfile_ was chosen rather arbitrarily)
1. Edit _~/Caddyfile_ so that _example.com_ is replaced with the hostname of
   your computer.
1. Reload the systemd user manager
   ```
   systemctl --user daemon-reload
   ```
1. Start the _whoami_ container
   ```
   systemctl --user start whoami.service
   ```
1. Start the _whoami_ container
   ```
   systemctl --user start nginx.service
   ```
1. Start the caddy socket
   ```
   systemctl --user start caddy.socket
   ```
1. Download the URL __https://whoami.example.com__ and see that the request is
   proxied to the container _whoami_.
   Resolve _whoami.example.com_ to _127.0.0.1_ so that curl connects to localhost.
   ```
   curl -s --resolve whoami.example.com:443:127.0.0.1 \
     https://whoami.example.com | grep X-Forwarded-For
   ```
   The following output is printed
   ```
   X-Forwarded-For: 127.0.0.1
   ```
   __result:__ The IPv4 address  127.0.0.1 matches the IP address of
   _X-Forwarded-For_
1. Check the IPv4 address of the main network interface.
   Run the command
   ```
   hostname -I
   ```
   The following output is printed
   ```
   192.0.2.5 fd25:c7f8:948a:0:912d:3900:d5c4:45ad
   ```
   __result:__ The IPv4 address of the main network interface is _192.0.2.5_
   (the address furthest to the left)
1. Download the URL __https://whoami.example.com__ from the caddy
   container and see that the request is proxied to the container _whoami_.
   Resolve _whoami.example.com_ to the IPv4 address of the main network interface.
   Run the command
   ```
   curl -s https://whoami.example.com | grep X-Forwarded-For
   ```
   The following output is printed
   ```
   X-Forwarded-For: 192.0.2.5
   ```
   __result:__ IPv4 address of _X-Forwarded-For_ matches address of the main network interface
1. From another computer download the URL __https://whoami.example.com__ from the caddy
   container and see that the request is proxied to the container _whoami_.
   ```
   curl -s https://whoami.example.com | grep X-Forwarded-For
   ```
   The following output is printed
   ```
   X-Forwarded-For: 192.0.2.18
   ```
   Check the IP address of the other computer (which in this example runs macOS).
   In the macOS terminal run the command
   ```
   ipconfig getifaddr en0
   ```
   The following output is printed
   ```
   192.0.2.18
   ```
   __result:__ The IPv4 address of _X-Forwarded-For_ matches the IP address of the other computer.
1. Download the URL __https://nginx.example.com__ and see that the request is proxied to the container _nginx_.
   Run the command
   ```
   curl https://nginx.example.com | head -4
   ```
   The following output is printed
   ```
   <!DOCTYPE html>
   <html>
   <head>
   <title>Welcome to nginx!</title>
   ```

### Using `Internal=true`

In the example caddy fetches a TLS certificate with the ACME protocol.

An alternative to this is to provide the TLS certificate yourself by specifying
a path to a cert file and a path to a key file. For details, see
https://caddyserver.com/docs/caddyfile/directives/tls

Creating outgoing connections is needed when using the ACME protocol.
If you provide the TLS certificate yourself, then the caddy container does not use the
ACME protocol. You could then append the line

```
Internal=true
```

to [mynet.network](mynet.network).

This improves security. For details, see the blog post
[_How to limit container privilege with socket activation_](https://www.redhat.com/sysadmin/socket-activation-podman)

However, `Internal=true` will also prevent the other containers on the network _mynet_ from connecting to the internet.
