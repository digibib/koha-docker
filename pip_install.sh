#!/bin/bash
dpkg -l python-pip >/dev/null 2>&1
if [ $? -eq 0 ] ; then
	echo "python-pip installed, removing ...";
	sudo apt-get purge --assume-yes --quiet python-pip
fi

pip -V >/dev/null 2>&1
if [ $? -eq 0 ] ; then
    echo "pip already installed and presumably working."
else
	echo "Installing pip using easy install ...";
	sudo apt-get install --assume-yes --quiet python-setuptools
	sudo easy_install --script-dir=/usr/bin --upgrade pip
    echo "pip installed."
fi