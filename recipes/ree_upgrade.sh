#!/bin/bash

echo "Removing Ruby from apt"
apt-get remove -q -y ^ruby*

PREFIX="/usr"
REE="ruby-enterprise-1.8.6-20090421"

echo "Installing Ruby"

pushd /tmp
echo "Downloading REE"
wget -q http://rubyforge.org/frs/download.php/55511/$REE.tar.gz
echo "Untar REE"
tar xzf $REE.tar.gz
pushd $REE/

echo "Running installer"
./installer --dont-install-useful-gems -a $PREFIX

echo "Cleaning up REE download"
popd
rm -rf $REE*
popd