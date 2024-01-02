#!/bin/bash

env | grep _ | grep -v which | head -n -1 | awk -F'=' '{print "export " $1"="$2}' > /root/.ssh/host/container-envs
mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"

test -f /root/.ssh/host/ssh_host_ecdsa_key || /usr/bin/ssh-keygen -q -t ecdsa -f /root/.ssh/host/ssh_host_ecdsa_key -C '' -N ''
test -f /root/.ssh/host/ssh_host_rsa_key || /usr/bin/ssh-keygen -q -t rsa -f /root/.ssh/host/ssh_host_rsa_key -C '' -N ''
test -f /root/.ssh/host/ssh_host_ed25519_key || /usr/bin/ssh-keygen -q -t ed25519 -f /root/.ssh/host/ssh_host_ed25519_key -C '' -N ''


# Now start ssh.
/usr/sbin/sshd -D