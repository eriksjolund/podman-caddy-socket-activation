#!/bin/bash

journalctl --user \
           --output json \
           --invocation 0 \
           --since "1 minute ago" \
            -u caddy.service \
               _SYSTEMD_USER_UNIT=caddy.service \
               CONTAINER_NAME=caddy \
  | jq 'select(.MESSAGE |
               fromjson |
               .logger == "http.log.access") |
        .MESSAGE |
        fromjson |
        .request'
