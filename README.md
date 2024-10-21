# podman-caddy-socket-activation

This demo shows how to run a socket-activated caddy container with Podman.
See also the tutorials [Podman socket activation](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md) and
[podman-nginx-socket-activation](https://github.com/eriksjolund/podman-nginx-socket-activation).

Overview of the examples

| Example | Type of service | Ports | Using quadlet | DNS entry required (ACME) | HTTP/3 | rootful/rootless podman | Comment |
| --      | --              |   -- | --      | --   | --  |  -- | -- |
| [Example 1](examples/example1) | systemd user service | 8080/TCP | :heavy_check_mark: |  |  | rootless podman | hello world web server |
| [Example 2](examples/example2) | systemd user service | 8080/TCP | :heavy_check_mark: |  |  | rootless podman | http reverse proxy with TCP backends |
| [Example 3](examples/example3) | systemd user service | 80/TCP, 443/TCP, 443/UDP | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | rootless podman | hello world web server |
| [Example 4](examples/example4) | systemd user service | 80/TCP, 443/TCP, 443/UDP | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | rootless podman | http reverse proxy with TCP backends |
| [Example 5](examples/example5) | systemd system service | 80/TCP, 443/TCP, 443/UDP | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | rootful podman | http reverse proxy with TCP backends |

> [!WARNING]
> Currently I have only verified that _Example 1_ and _Example 2_ works. Consider _Example 3_, _Example 4_ as being work in progress.

### Advantages of using rootless Podman with socket activation

See https://github.com/eriksjolund/podman-nginx-socket-activation?tab=readme-ov-file#advantages-of-using-rootless-podman-with-socket-activation

### Support for socket activation in Caddy

Socket activation support was added to Caddy in

* https://github.com/caddyserver/caddy/pull/6573

Socket activation support is planned for Caddy 2.9.0 (yet to be released).
I have not found any official pre-release Caddy container image with _socket activation_ support.

For instructions of how to build a Caddy container image from source code with Podman,
see [./build_caddy_container_image.md](./build_caddy_container_image.md)

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
