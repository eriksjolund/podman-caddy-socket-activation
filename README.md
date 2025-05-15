# podman-caddy-socket-activation

This demo shows how to run a socket-activated caddy container with Podman.
See also

* [Podman socket activation](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md)
* The section _HTTP reverse proxy_ in [podman-networking-docs](https://github.com/eriksjolund/podman-networking-docs?tab=readme-ov-file#http-reverse-proxy)
* [podman-nginx-socket-activation](https://github.com/eriksjolund/podman-nginx-socket-activation)

Overview of the examples

| Example | Type of service | Ports | Using quadlet | DNS entry required (ACME) | HTTP/3 | rootful/rootless podman | Comment |
| --      | --              |   -- | --      | --   | --  |  -- | -- |
| [Example 1](examples/example1) | systemd user service | 8080/TCP | :heavy_check_mark: |  |  | rootless podman | hello world web server |
| [Example 2](examples/example2) | systemd user service | 8080/TCP | :heavy_check_mark: |  |  | rootless podman | http reverse proxy with TCP backends |
| [Example 3](examples/example3) | systemd user service | 80/TCP, 443/TCP, 443/UDP | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | rootless podman | hello world web server |
| [Example 4](examples/example4) | systemd user service | 80/TCP, 443/TCP, 443/UDP | :heavy_check_mark: |  :heavy_check_mark: | :heavy_check_mark: | rootless podman | http reverse proxy with TCP backends |

## Using Caddy with socket activation

While Caddy can create sockets by itself, there are security and performance advantages of using
a service manager, such as systemd, for creating the sockets.
Caddy does not need to create listening sockets as long as Caddy inherits those sockets
from its parent process. This technique, commonly named _socket activation_, is
supported for example when Caddy is running as a systemd service. Optionally Podman can start
Caddy in the systemd service in case you want to run Caddy inside a container.

Using _socket activation_ allows you to run Caddy with fewer privileges
because Caddy would not need the privilege to create a socket.
For example if Podman is running Caddy as a static web server, then it is possible
to enable the Podman option `--network=none` which improves security.
However, obtaining a publicly-trusted TLS certificate with the ACME protocol
is not possible when using `--network=none` because
Caddy then needs to connect to the internet.

Using _socket activation_ improves network performance when Caddy is run by rootless Podman in a systemd service.
When using rootless Podman, network traffic is normally passed through Slirp4netns or Pasta.
This comes with a performance penalty. Fortunately, communication over the socket-activated
socket does not pass through Slirp4netns or Pasta so it has the same performance characteristics
as the normal network on the host.

The source IP address in TCP connections is preserved when using socket activation.
This can otherwise be a problem when using rootless Podman with Pasta.
Source IP addresses are not preserved in TCP connections from ports that were published the
conventional way, that is with `--publish`, if the container is running in an internal network
by rootless Podman with Pasta.

For more details about advantages of using socket activation with Podman, see
https://github.com/eriksjolund/podman-nginx-socket-activation?tab=readme-ov-file#advantages-of-using-rootless-podman-with-socket-activation

### Support for socket activation in Caddy

Socket activation support was added to Caddy in

* https://github.com/caddyserver/caddy/pull/6573

Caddy does not make use of file descriptor names that can be retrieved with [sd_listen_fds_with_names()](https://www.freedesktop.org/software/systemd/man/latest/sd_listen_fds.html).
Instead file descriptor numbers are specified.
Do not use multiple socket units. Use one socket unit so that the file descriptor numbers can be mapped to the listening sockets that are configured with `ListenStream=` and `ListenDatagram=`.

| order of the sockets in the socket unit | Caddyfile syntax |
| -- | -- |
| 1st | `bind fd/3` or `bind fdgram/3` |
| 2nd | `bind fd/4` or `bind fdgram/4` |
| 3rd | `bind fd/5` or `bind fdgram/5` |
| ... |  ... |
| nth | follow the same pattern as above and specify a number n + 2 |

(`fd` should be used for `ListenStream=` and `fdgram` should be used for `ListenDatagram=`)

Quote from man page [systemd.socket(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.socket.html):
_"Sockets configured in one unit are passed in the order of configuration, but no ordering between socket units is specified"_

### Support for reloading the Caddy configuration

Here is an outline of how to allow reloading the Caddy configuration.

To support reloading the Caddy configuration, do the following steps

1. Bind-mount an empty directory into the Caddy container to the path `/caddy_adminsocket` (The path was arbitrarily chosen).
2. Add the global Caddyfile option [`admin`](https://caddyserver.com/docs/caddyfile/options#admin) to the Caddyfile.
   ```
   admin unix//caddy_adminsocket/sock|0200
   ```
3. Add the systemd directive `ExecReload` under the `[Service]` section in the caddy container unit (quadlet).
   ```
   ExecReload=podman exec caddy /usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
   ```
   (`caddy` is an arbitrarily chosen name. It should match the name of the container that can be set with `ContainerName=` under the `[Container]` section)


To reload the Caddyfile, run
```
systemctl --user reload caddy.service
```

See also:

[Example 4](examples/example4) that is configured to allow reloading the Caddy configuration.

> [!NOTE]
> Reloading the caddy configuration does not currently work when [`admin`](https://caddyserver.com/docs/caddyfile/options#admin) is set to
a file descriptor (see issue https://github.com/caddyserver/caddy/issues/6631).
