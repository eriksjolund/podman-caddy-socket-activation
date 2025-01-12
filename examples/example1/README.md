return to [main page](../..)

## Example 1

``` mermaid
graph TB

    a1["curl http&colon;//localhost:8080"] -.->a2[caddy container]
```

Set up a systemd user service _example1.service_ for the user _test_ where rootless podman
is running a _docker.io/library/caddy_ container. Configure _socket activation_ for TCP port 8080.
Caddy is configured to reply _hello world_.

1. Create a test user
   ```
   sudo useradd --create-home test
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
   cp podman-caddy-socket-activation/examples/example1/caddy.container \
      ~/.config/containers/systemd/
   ```
1. Install the socket unit files
   ```
   cp podman-caddy-socket-activation/examples/example1/caddy.socket \
      ~/.config/systemd/user/
   ```
1. Install the _Caddyfile_
   ```
   cp podman-caddy-socket-activation/examples/example1/Caddyfile \
      ~/Caddyfile
   ```
   (The path _~/Caddyfile_ was arbitrarily chosen)
1. Reload the systemd user manager
   ```
   systemctl --user daemon-reload
   ```
1. Start the caddy socket unit. A listening socket on port 8080/TCP will
   then be created.
   ```
   systemctl --user start caddy.socket
   ```
1. Run curl to download the hello world example
   ```
   curl -s http://localhost:8080
   ```
   The following output is printed
   ```
   Hello world
   ```

### Discussion

Note that the file _caddy.container_ has the configuration line

```
Network=none
```

This improves security. For details, see the blog post
[_How to limit container privilege with socket activation_](https://www.redhat.com/sysadmin/socket-activation-podman)
