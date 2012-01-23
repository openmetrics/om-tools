#!/bin/sh
#
# this script will install OpenMetrics server (http://www.openmetrics.net)
#

OM_INSTALL_DIR="/home/om/"

set -e # exit on error

# create temporary directory for setup files
tempdir=`mktemp --tmpdir=/tmp -d om-install.XXXXXX`
INSTALL_DIR="${tempdir}"
cd "$INSTALL_DIR" || exit 42

function installPreqs {
aptitude install ruby1.8 ruby1.8-dev ri1.8 librrd-ruby1.8 libopenssl-ruby1.8 libldap-ruby1.8 git postgresql-server rrdtool memcached nmap collectd graphviz

# basic check for ruby installation
if [ ! `which ruby` ] ; then
	ln -s /usr/bin/ruby1.8 /usr/bin/ruby # ubuntu / debian
	ln -s /usr/bin/ri1.8 /usr/bin/ri # ubuntu / debian
	ln -s /usr/lib/librrd.so.4 /usr/lib/librrd.so # ubuntu/debian
fi



# install latest Ruby gems
wget "http://production.cf.rubygems.org/rubygems/rubygems-1.8.15.tgz"
tar xfz rubygems-1.8.15.tgz 
cd rubygems-1.8.15
ruby setup.rb
if [ ! `which gem` ] ; then
	ln -s /usr/bin/gem1.8 /usr/bin/gem # ubuntu / debian
fi
#gem update --system

# install Ruby extensions
	gem install rake --version '0.8.7'
	gem install rails --version '2.3.12'
	gem install friendly_id --version "~> 3.2.1"
	gem install will_paginate --version "~> 2.3.16"
	gem install net-ssh net-sftp nmap-parser bb-ruby rrd-ffi chronic packet mongrel fastercsv json_pure

# FIXME this is pg specific 
	aptitude install postgresql-server-dev-8.4
	gem install pg

# create database user
su - postgres -c "createuser -d -S -R -l om"

# configure collectd
cd /etc/collectd
mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf-dist
# FIXME get collectd config
ln -s collectd.conf.openmetrics collectd.conf
# FIXME get openmetrics_types.db
/etc/init.d/collectd restart

}

cd "$OM_INSTALL_DIR"
mkdir -p conf/nginx
mkdir -p htdocs 
mkdir -p logs/nginx
mkdir -p mongrel_cluster/{conf,logs,webapps}
mkdir -p nginx/{conf,logs,scgi_temp,tmp,uwsgi_temp}
mkdir -p run
mkdir -p scripts
cd mongrel_cluster/webapps/

# FIXME create dedicated user account and create ssh keys

# FIXME fetch latest OpenMetrics from github or trac.openmetrics.net



