return to [main page](../..)

## Example 5

> [!IMPORTANT]  
> This example does not currently work. The example makes use of `--userns auto`
> together with the volume option `idmap=uids=`. Somehow it does not work.
> A question related to this can be found here:
> https://github.com/containers/podman/discussions/24330

This example currently tries to combine

* `--userns auto`
* `idmap=uids=...`
* `--user 405:100`

_Example 5_ is similar to _Example 4_ but _Example 5_ also makes use of systemd system services.

``` mermaid
graph TB

    a1[curl] -.->a2[caddy container reverse proxy]
    a2 -->|"for https&colon;//static.example.com"| a3["handled internally by caddy file_server"]
    a2 -->|"for https&colon;//whoami.example.com"| a4["whoami container"]    
```

Set up a systemd system service _example5.service_ where rootful podman is running
the container image _docker.io/library/caddy_.
The caddy container is acting as an HTTP reverse proxy that forwards requests for
https://whoami.example.com are forwarded to a _whoami_ container.
Caddy is also configured to provide a static website for requests to 
Requests to https://static.example.com are handled internally by caddy. where files are
served from a static serves file_server.
Configure _socket activation_ for the ports 80/TCP, 443/TCP and 443/UDP. Let Caddy use these ports
for the HTTP reverse proxy.
A TLS certificate is automatically retrieved with the
[ACME](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment) prototol.
Configure _socket activation_ for the unix socket _/run/caddy.sock_. Let Caddy use this socket for the
[admin API endpoint](https://caddyserver.com/docs/api).

1. Run command
   ```
   sudo -i
   ```
   (TODO: rewrite these instructions to make less use of sudo)
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
1. Verify that the domain names _static.example.com_ and _whoami.example.com_ resolve to
   the IP address of the host's main IPv4 interface that was found in Step 2.
   Run commands to resolve the hostnames.
   ```
   host static.example.com
   ```
   and
   ```
   host whoami.example.com
   ```
   Verify that the results match the left-most IPv4 address shown by the command `hostname -I`.
1. Verify that idmapped mounts are supported by rootful Podman on your system. Run command
   ```
   podman --log-level=debug run --rm docker.io/library/alpine 2>&1 \
     | grep "Cached value indicated that idmapped mounts for overlay are supported"
   ```
   There is support if the command prints output similar to this:
   ```
   time="2024-10-17T16:34:07Z" level=debug msg="Cached value indicated that idmapped mounts for overlay are supported"
   ```
1. Pull the _whoami_ container image
   ```
   podman pull docker.io/traefik/whoami
   ```
1. Clone git repo
   ```
   git clone https://github.com/eriksjolund/podman-caddy-socket-activation.git
   ```
1. Edit _podman-caddy-socket-activation/examples/example5/Caddyfile_ so that _example.com_ is replaced with the hostname of
   your computer.
1. Build container image
   ```
   podman build -t caddy podman-caddy-socket-activation/examples/example5
   ```
1. Create a user on the host that will be the owner of files and directories in the volumes _example5-data_ and _example5-config_.
   ```
   useradd example5
   ```
1. Set environment variables `hostUID` and `hostGID` to the UID and GID
   of the user _example5_.
   These environment variables will be used by the `envsubst` command.
   In other words, they have no other role than being used for
   text replacement templating in this guide.
   ```
   export hostUID=$(id -u example5)
   export hostGID=$(id -g example5)
   ```
1. Install the quadlet files that need preprocessing with `envsubst` for text replacement
   ```
   for i in \
      caddy_config.volume \
      caddy_data.volume \
      caddy_srv.volume \
      caddy.container \
   do \
      cat podman-caddy-socket-activation/examples/example5/${i}.in \
      | envsubst > /etc/containers/systemd/$i
   done
1. Install the remaining quadlet files
   ```
   cp podman-caddy-socket-activation/examples/example5/mynet.network \
     /etc/containers/systemd/mynet.network
   ```
   ```
   cp podman-caddy-socket-activation/examples/example5/whoami.container \
     /etc/containers/systemd/whoami.container
   ```
1. Install the socket unit file
   ```
   cp podman-caddy-socket-activation/examples/example5/caddy.socket \
      /etc/systemd/system/
   ```
1. Optional step. Run command
   ```
   ls -ld /var/lib/containers/storage/volumes/example5-config/_data/
   ```
   The following output is printed
   ```
   drwxr-xr-x. 2 example5 example5 12 Oct 12 15:01 /var/lib/containers/storage/volumes/example5-config/_data/
   ```
   The directory is owned by the user _example5_ as is expected.
1. Reload the systemd user manager
   ```
   systemctl daemon-reload
   ```
1. Start the _whoami_ container
   ```
   systemctl start whoami.service
   ```
1. Start the caddy socket
   ```
   systemctl start caddy.socket
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
1. Download the URL __https://static.example.com/file.txt__
   Run the command
   ```
   curl https://static.example.com/file.txt
   ```
   The following output is printed
   ```
   hello
   ```
1. Access the _admin API endpoint_.
   ```
   curl -s -H "Host: " --unix-socket /run/caddy.sock http://localhost/config/ | jq . | head -5
   ```
   The following output is printed
   ```
   {
     "admin": {
       "listen": "fd/6"
     },
     "apps": {
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
