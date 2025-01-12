return to [main page](../..)

## Example 3

_Example 3_ is similar to [_Example 1_](../example1/README.md) but _Example 3_ also provides HTTP/3 support.

``` mermaid
graph TB

    a1[curl https&colon;//example.com] -.->a2[caddy container]
```

Set up a systemd user service _example3.service_ for the user _test_ where rootless podman is
running a _docker.io/library/caddy_ container. Configure _socket activation_ for the ports 80/TCP,
443/TCP and 443/UDP. A TLS certificate is automatically retrieved with the
[ACME](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment) prototol.
Caddy is configured to reply _hello world_.

1. Verify that unprivileged users are allowed to open port numbers 80 and above.
   Run the command
   ```
   cat /proc/sys/net/ipv4/ip_unprivileged_port_start
   ```
   Make sure the number printed is not higher than 80. To configure the number,
   see https://rootlesscontaine.rs/getting-started/common/sysctl/#allowing-listening-on-tcp--udp-ports-below-1024
1. Verify that the domain names _example.com_ resolves to
   the IP address of the host's main IPv4 interface.
   Run commands to resolve the hostnames.
   ```
   host example.com
   ```
   Verify that the result matches the left-most IPv4 address shown by the command `hostname -I`.
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
1. Pull _caddy_ container image
   ```
   podman pull docker.io/library/caddy
   ```
1. Clone git repo
   ```
   git clone https://github.com/eriksjolund/podman-caddy-socket-activation.git
   ```
1. Install the container unit files
   ```
   cp podman-caddy-socket-activation/examples/example3/caddy.container \
      ~/.config/containers/systemd/
   ```
1. Install the socket unit files
   ```
   cp podman-caddy-socket-activation/examples/example3/caddy.socket \
      ~/.config/systemd/user/
   ```
1. Install the _Caddyfile_
   ```
   cp podman-caddy-socket-activation/examples/example3/Caddyfile \
      ~/Caddyfile
   ```
   (The path _~/Caddyfile_ was arbitrarily chosen)
1. Edit _~/Caddyfile_ so that _example.com_ is replaced with the hostname of
   your computer.
1. Reload the systemd user manager
   ```
   systemctl --user daemon-reload
   ```
1. Start the caddy socket unit. Listening sockets on ports 80/TCP, 443/TCP, 443/UDP
   will then be created.
   ```
   systemctl --user start caddy.socket
   ```
1. Run curl to download the hello world example
   ```
   curl -s https://example.com
   ```
   The following output is printed
   ```
   Hello world
   ```

### Discussion

In the example caddy fetches a TLS certificate with the ACME protocol.

An alternative to this is to provide the TLS certificate yourself by specifying
a path to a cert file and a path to a key file. For details, see
https://caddyserver.com/docs/caddyfile/directives/tls

If you provide the TLS certificate yourself, then the caddy container does not
need to create any outgoing TCP connections for the ACME protocol.
You could then add the configuration line 

```
Network=none
```

to the file _caddy.container_. This improves security.
For details, see the blog post
[_How to limit container privilege with socket activation_](https://www.redhat.com/sysadmin/socket-activation-podman)
