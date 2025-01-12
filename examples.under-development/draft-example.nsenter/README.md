return to [main page](../..)

## Example draft-example.nsenter

> [!NOTE]
> Not much has been written on the internet about
> using `nsenter` to run a command in the network
> namespace of rootless Podman,
> As of now consider this example a bit experimental.
> There is a discussion topic in the Podman Github project
> https://github.com/containers/podman/discussions/24626

_draft-example.nsenter_ is similar to _Example 4_ but here Caddy is not run by Podman.
Instead the executable `/usr/local/bin/caddy` (from the host file system) is
running in a systemd system service with a `User=` directive.  `nsenter` executes `caddy`
in the network namespace of rootless Podman.

Note, even though caddy is running rootless, it is possible to use the default setting
for _ip_unprivileged_port_start_.

```
$ cat /proc/sys/net/ipv4/ip_unprivileged_port_start
1024
```

This is possible because the service is a systemd system service with a `User=` directive.
The most interesting part of the file _caddy.service_ is

```
User=test
ExecStart=bash -c "exec nsenter \
   --net=/proc/$(pgrep -u test aardvark-dns)/ns/net \
   --user=/proc/$(pgrep -u test catatonit)/ns/user \
   --mount=/proc/$(pgrep -u test catatonit)/ns/mnt \
   /usr/local/bin/caddy run --environ --config /srv/caddy/Caddyfile"
```

Diagram:

``` mermaid
graph TB

    a1[curl] -.->a2["/usr/local/bin/caddy (from the host file system)"]
    a2 -->|"for https&colon;//static.example.com"| a3["handled internally by caddy file_server"]
    a2 -->|"for https&colon;//whoami.example.com"| a4["whoami container"]
```

Set up a systemd system service _caddy.service_ with the systemd configuration `User=test` that
runs `/usr/local/bin/caddy` from the host file system.
Caddy is acting as an HTTP reverse proxy that forwards requests for
https://whoami.example.com to a _whoami_ container.
Caddy is also configured to be a static file server for requests to https://static.example.com.
Configure _socket activation_ for the ports 80/TCP, 443/TCP and 443/UDP. Let Caddy use these ports
for the HTTP reverse proxy and the static file server.
A TLS certificate is automatically retrieved with the
[ACME](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment) prototol.
Configure _socket activation_ for the unix socket _/srv/caddy/caddy.sock_. Let Caddy use this socket for the
[admin API endpoint](https://caddyserver.com/docs/api).

### Install /usr/local/bin/caddy on the host

Alternative 1.

Pull _docker.io/library/caddy_ and extract the caddy binary
from the container image, then save the binary to `/usr/local/bin/caddy`

<details>
<summary>Click me</summary>


1. Create user
   ```
   sudo useradd test
   ```
2. Open a login shell
   ```
   sudo machinectl shell --uid=test
   ```
3. Pull the caddy container image
   ```
   podman pull docker.io/library/caddy
   ```
4. Create a temporary container that will be used for mounting the container file system.
   ```
   podman create --name tmpctr docker.io/library/caddy
   ```
5. Run command
   ```
   mkdir ~/bin
   ```
6. Run command
   ```
   podman unshare
   ```
7. Run command
   ```
   dir=$(podman container mount tmpctr)
   ```
8. Copy caddy binary to home directory
   ```
   cp $dir/usr/bin/caddy $HOME/
   ```
9. Run command
   ```
   podman container unmount tmpctr
   ```
10. Exit `podman unshare`
   ```
   exit
   ```
11. Exit the login shell
    ```
    exit
    ```
12. Copy caddy binary to _/usr/local/bin/caddy_
    ```
    sudo cp /home/test/caddy /usr/local/bin/caddy
    ```

</details>

Alternative 2.

Build and install /usr/local/bin/caddy from [caddy source code](https://github.com/caddyserver/caddy)

### Set up quadlets and systemd services

1. Verify that the domain names _static.example.com_ and _whoami.example.com_ resolve to
   the IP address of the host's main IPv4 interface.
   Run commands to resolve the hostnames.
   ```
   host static.example.com
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
1. Pull the _whoami_ container image
   ```
   podman pull docker.io/traefik/whoami
   ```
1. Clone git repo
   ```
   git clone https://github.com/eriksjolund/podman-caddy-socket-activation.git
   ```
1. Install the caddy.service file
   ```
   sudo cp $PWD/podman-caddy-socket-activation/examples.under-development/draft-example.nsenter/caddy.service \
      /etc/systemd/system/
   ```
1. Install the container unit file
   ```
   cp podman-caddy-socket-activation/examples.under-development/draft-example.nsenter/whoami.container \
      ~/.config/containers/systemd/
   ```
1. Create directory
   ```
   sudo mkdir /srv/caddy
   ```
1. Create directory
   ```
   sudo mkdir /srv/caddy/caddy_config
   ```
1. Create directory
   ```
   sudo mkdir /srv/caddy/caddy_data
   ```
1. Create directory
   ```
   sudo mkdir /srv/caddy/caddy_static
   ```
1. Chown directories
   ```
   sudo chown test:test /srv/caddy/caddy_*
   ```
1. Create directory
   ```
   sudo mkdir /srv/caddy/socket
   ```
1. Install the _Caddyfile_
   ```
   sudo cp $PWD/podman-caddy-socket-activation/examples.under-development/draft-example.nsenter/Caddyfile \
      /srv/caddy/Caddyfile
   ```
1. Edit _/srv/caddy/Caddyfile_ so that _example.com_ is replaced with the hostname of
   your computer.
1. Create directory
   ```
   mkdir /srv/caddy/caddy_static
   ```
1. Create directory
   ```
   mkdir /srv/caddy/caddy_config
   ```
1. Create directory
   ```
   mkdir /srv/caddy/caddy_data
   ```
1. Create static file
   ```
   echo "my static file" > /srv/caddy/caddy_static/file.txt
   ```
1. Install the socket unit file
   ```
   sudo cp $PWD/podman-caddy-socket-activation/examples.under-development/draft-example.nsenter/caddy.socket \
      /etc/systemd/system
   ```
1. Reload the systemd user manager
   ```
   systemctl --user daemon-reload
   ```
1. Start the _whoami_ container
   ```
   systemctl --user start whoami.service
   ```
1. Reload the systemd user manager
   ```
   systemctl daemon-reload
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
1. Download the URL __https://static.example.com/file.txt__
   Run the command
   ```
   curl https://static.example.com/file.txt
   ```
   The following output is printed
   ```
   my static file
   ```
1. Access the _admin API endpoint_.
   ```
   curl -s -H "Host: " --unix-socket $XDG_RUNTIME_DIR/caddy.sock http://localhost/config/ | jq . | head -4
   ```
   {
     "admin": {
       "listen": "fd/6"
     },
     "apps": {
   ```

### systemd-analyze security

The command

```
systemd-analyze security caddy.service
```

checks which restrictions have been set on the service _caddy.service_ and estimates the overall exposure level.

By running the command with the environment variable `SYSTEMD_UTF8` set to `0`, ✓ and ✗ are replaced with `+` and `-`.

Show restrictions that would lower the exposure level.

```
SYSTEMD_UTF8=0 systemd-analyze security caddy.service | grep "^- "
```

The following output is printed
```
- RootDirectory=/RootImage=                                   Service runs within the host's root directory                                      0.1
- RestrictNamespaces=~user                                    Service may create user namespaces                                                 0.3
- RestrictNamespaces=~net                                     Service may create network namespaces                                              0.1
- RestrictNamespaces=~mnt                                     Service may create file system namespaces                                          0.1
- RestrictAddressFamilies=~AF_UNIX                            Service may allocate local sockets                                                 0.1
- RestrictAddressFamilies=~AF_(INET|INET6)                    Service may allocate Internet sockets                                              0.3
- PrivateUsers=                                               Service has access to other users                                                  0.2
- DeviceAllow=                                                Service has a device ACL with some special devices: char-rtc:r                     0.1
```

Show the overall exposure level

```
systemd-analyze security caddy.service | grep "Overall exposure"
```

The following output is printed
```
-> Overall exposure level for caddy.service: 1.2 OK :-)
```
