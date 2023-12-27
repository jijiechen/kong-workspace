#!/bin/bash

test -f /root/.ssh/host/ssh_host_ecdsa_key || /usr/bin/ssh-keygen -q -t ecdsa -f /root/.ssh/host/ssh_host_ecdsa_key -C '' -N ''
test -f /root/.ssh/host/ssh_host_rsa_key || /usr/bin/ssh-keygen -q -t rsa -f /root/.ssh/host/ssh_host_rsa_key -C '' -N ''
test -f /root/.ssh/host/ssh_host_ed25519_key || /usr/bin/ssh-keygen -q -t ed25519 -f /root/.ssh/host/ssh_host_ed25519_key -C '' -N ''


# Now start ssh.
/usr/sbin/sshd -D