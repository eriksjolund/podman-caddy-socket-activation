### Build a caddy container image from git master branch

This file will probably be removed later when _socket activation_ support
is available in the standard caddy container image docker.io/library/caddy

caddy 2.9.0 (not yet relased) is expected to have  _socket activation_ support.

Currently the _socket activation_ functionality is only available if you build
a caddy container image from source code.

I searched github.com and found a [Dockerfile](https://github.com/unikraft/catalog/blob/main/library/caddy/2.7/Dockerfile) that seems to work fine
with just some minor modifications.

Follow these steps to build a caddy congtainer image from the git master branch:

1. `git clone https://github.com/unikraft/catalog.git`
2. `cd catalog/library/caddy/2.7`
3. `sed -i 's#FROM golang:1.21.3-bookworm#FROM docker.io/library/golang:bookworm#g' Dockerfile`
4. `sed -i 's/v${CADDY_VERSION}/master/g' Dockerfile`
5. `podman build . -t caddy`
