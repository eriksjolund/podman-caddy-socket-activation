return to [main page](../..)

``` mermaid
graph TB

    a1[curl] -.->a2[caddy container reverse proxy]
    a2 -->|"for http&colon;//whoami.example.com&colon;80"| a3["whoami container"]
```

status: experimental

> [!WARNING]  
> :warning: Running rootless podman in a systemd systemd service with the systemd directive `User=` is not supported by podman project.
> Podman writes the warning [`use at your own risk`](https://github.com/containers/podman/blob/2fbecb48e166ed79662ea5e45f2d56081ad08d3b/cmd/quadlet/main.go#L369).
> For details, see [_Socket activation (systemd system service with User=)_](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#socket-activation-systemd-system-service-with-user)

--------------

Set up a systemd system service _caddy.service_ that is configured with the systemd directive `User=` where rootless podman is
running the container image _docker.io/library/caddy_. Configure _socket activation_ for TCP port 80.
The caddy container is acting as a HTTP reverse proxy that forwards requests to 1 backend.
Requests to http://whoami.example.com are forwarded to the _whoami_ container.

In this example the curl option __--resolve__ option is used for name resolution.
In other words, the domain name _whoami.example.com_ does not need to be
resolvable in public DNS.

Note, even though caddy is run by rootless podman, it is possible to use the default setting
for _ip_unprivileged_port_start_.

```
$ cat /proc/sys/net/ipv4/ip_unprivileged_port_start
1024
```

This is possible because the service is a systemd system service with a `User=` directive.


Containers:

| Container image | Type of service | Role | Network | Socket activation |
| --              | --              | --   | --      | --                |
| docker.io/library/caddy | systemd system service with `User=test99` | HTTP reverse proxy | [internal bridge network](example99-net.network) | :heavy_check_mark: |
| docker.io/traefik/whoami | systemd user service | backend web server | [internal bridge network](example99-net.network) | |

## Install instructions

These install instructions will create the new user _test99_ and install these files:

```
/etc/systemd/system/example99.socket
/etc/containers/systemd/example99.container
/home/test99/.config/containers/systemd/whoami.container
/home/test99/.config/containers/systemd/example99-net.network
/home/test99/caddy_etc/Caddyfile
```

1. Clone this GitHub repo
   ```
   $ git clone URL
   ```
2. Change directory
   ```
   $ cd podman-caddy-socket-activation
   ```
3. Choose a username that will be created and used for the test
   ```
   $ user=test99
   ```
4. Run install script
   ```
   $ sudo bash ./examples.under-development/example99/install.bash ./ $user
   ```
5. Check the status of the backend containers
   ```
   $ sudo systemctl --user -M ${user}@ is-active whoami.service
   active
   ```
6. Check the status of the HTTP reverse proxy socket
   ```
   $ sudo systemctl is-active example99.socket
   active
   ```
   
## Test the caddy reverse proxy

1. Test the caddy HTTP reverse proxy
   ```
   $ curl -s -S --resolve whoami.example.com:80:127.0.0.1 whoami.example.com:80
   Hostname: d640b809096a
   IP: 127.0.0.1
   IP: ::1
   IP: 10.89.0.2
   IP: fe80::bcc6:1fff:fe00:c054
   RemoteAddr: 10.89.0.3:41404
   GET / HTTP/1.1
   Host: whoami.example.com
   User-Agent: curl/8.18.0-rc2
   Accept: */*
   Accept-Encoding: gzip
   Via: 1.1 Caddy
   X-Forwarded-For: 127.0.0.1
   X-Forwarded-Host: whoami.example.com
   X-Forwarded-Proto: http
   ```
   Result: Success. The caddy reverse proxy fetched the output from the whoami container.

## Discussion about service dependencies

systemd does not support having dependencies between _systemd system services_ and _systemd user services_.
Because of that we need to make sure that _example99.service_ is started after

* podman has created the network _systemd-example99-net_
* podman has started _whoami_ (_whoami.service_)
