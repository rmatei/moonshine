#!/bin/bash
# Needs to be run after the Ruby bootstrap so we have access to wget

echo "***Adding apt-get sources for OurDelta MySQL***"
wget -q http://ourdelta.org/deb/ourdelta.gpg -O- | apt-key add -
wget http://ourdelta.org/deb/sources/intrepid-ourdelta.list -O /etc/apt/sources.list.d/ourdelta.list
apt-get update