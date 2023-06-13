#/bin/bash

# give read+write permission for all
chmod 666 /var/run/docker.sock

# start ssh service
service ssh start

# set jenkins user password (123456)
passwd jenkins
