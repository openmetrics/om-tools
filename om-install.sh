#!/bin/bash
#
# this script will install OpenMetrics server (http://www.openmetrics.net)
#

set -o errexit # exit on all errors


# find our location
SELF_LOCATION=$(cd "$(dirname "$0")" ; pwd)

# was this invoked as a link ?
if [ -L "$0" ]
then
	LINKTO=$(/usr/bin/readlink "$0")

	# Is the link a relative path
	if [[ "${LINKTO}" = /* ]]
	then
	    # absolute path so just invoke it
		exec "${LINKTO}" "$@"
	else
	    # invoke by prepending our folder
		exec "${SELF_LOCATION}/${LINKTO}" "$@"
	fi
fi

# read in some defaults
source "${SELF_LOCATION}/om-install.d/defaults.env"

# dialog defaults
dialogAddUser="YES"
dialogInstallPreqs="YES"

# we should be root to proceed
if [ "$UID" != "0" ]  ; then
	echo -e '\nERROR run me with root privileges!'
	exit 42
fi	

# create temporary directory for setup files
tempdir=`mktemp --tmpdir=/tmp -d om-install.XXXXXX`
INSTALL_DIR="${tempdir}"
cd "$INSTALL_DIR" || exit 42

function checkPreqs {
	for tool in ruby ri irb git ssh-keygen postgres rrdtool memcached nmap collectd graphviz
	do
 		if ! which $tool > /dev/null
 		then
    			echo "no '$tool' found in $PATH" >&2
    			ret=1
 		fi
	done
	
	# some tools are missing
	if [ $ret = "1" ] ; then
		echo -e "\n\nThis system lacks of some software needed to run OpenMetrics Server."
		read -p "Do you want me to try installing the missing tools? [$dialogInstallPreqs]: "; checkInput dialogInstallPreqs

		if [ $dialogInstallPreqs = "YES" ] ; then
			installPreqs
			#read -p "Username? [$OM_USER]: "; checkInput OM_USER
			#echo -e "\n\nOk. I'm going to create a user called ${OM_USER}"
		fi
	fi
} 
# // checkPreqs

function installPreqs {
	# TODO one should use postgres-9.x in latest ubuntu
	aptitude install ruby1.8 ruby1.8-dev ri1.8 irb1.8 librrd-ruby1.8 \
					libopenssl-ruby1.8 libldap-ruby1.8 git postgresql-8.4 \
					postgresql-server-dev-8.4 rrdtool memcached nmap collectd graphviz

# basic check for ruby installation
# FIXME 
if [ ! `which ruby` ] ; then
	ln -s /usr/bin/ruby1.8 /usr/bin/ruby # ubuntu / debian
	ln -s /usr/bin/ri1.8 /usr/bin/ri # ubuntu / debian
	ln -s /usr/bin/irb1.8 /usr/bin/irb # ubuntu / debian
	ln -s /usr/lib/librrd.so.4 /usr/lib/librrd.so # ubuntu/debian
fi


# FIXME this whole ruby installation stuff needs to be smarter. use bundler and/or rvm?
# install latest Ruby gems
wget "http://production.cf.rubygems.org/rubygems/rubygems-1.8.15.tgz"
tar xfz rubygems-1.8.15.tgz 
cd rubygems-1.8.15
ruby setup.rb
if [ ! `which gem` ] ; then
	ln -s /usr/bin/gem1.8 /usr/bin/gem # ubuntu / debian
fi
# downgrade rubygems
gem update --system 1.5.3

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
#su - postgres -c "createuser -d -S -R -l om"

# configure collectd
echo -e "\n\nCreating collectd config"
cd /etc/collectd
mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf-dist
cat > /etc/collectd/collectd.conf.openmetrics <<EOF
# Config file for collectd(1) for OpenMetrics server installation
#

#Hostname "localhost"
FQDNLookup true
#BaseDir "/var/lib/collectd"
#PluginDir "/usr/lib/collectd"
TypesDB "/usr/share/collectd/types.db" "/etc/collectd/openmetrics_types.db"
Interval 10
#ReadThreads 5

LoadPlugin unixsock
<Plugin unixsock>
	SocketFile "/var/run/collectd-socket"
	SocketGroup "${OM_USER}"
	SocketPerms "0770"
</Plugin>

LoadPlugin logfile
<Plugin logfile>
  LogLevel "debug"
  File "/var/log/collectd.log"
  Timestamp true
  PrintSeverity true
</Plugin>

LoadPlugin syslog
<Plugin syslog>
	LogLevel info
</Plugin>

LoadPlugin network
<Plugin network>
	Listen "*" "25826"
</Plugin>

LoadPlugin rrdtool
<Plugin rrdtool>
	DataDir "/var/lib/collectd/rrd"
#	CacheTimeout 120
#	CacheFlush 900
#	WritesPerSecond 30
#	RandomTimeout 0
#
# The following settings are rather advanced
# and should usually not be touched:
#	StepSize 10
#	HeartBeat 20
#	RRARows 1200
#	RRATimespan 158112000
#	XFF 0.1
</Plugin>

Include "/etc/collectd/filters.conf"
Include "/etc/collectd/thresholds.conf"
EOF

ln -s collectd.conf.openmetrics collectd.conf
touch /etc/collectd/openmetrics_types.db
/etc/init.d/collectd restart

}
# // checkPreqs

function checkInput() {
	# overwrite passed variable with last line of user input
	if [ ! -z "$REPLY" ]; then
		eval $*=\""$REPLY"\"
	fi
}
# // checkInput


#cd "$OM_INSTALL_DIR"
#mkdir -p conf/nginx
#mkdir -p htdocs 
#mkdir -p logs/nginx
#mkdir -p mongrel_cluster/{conf,logs,webapps}
#mkdir -p nginx/{conf,logs,scgi_temp,tmp,uwsgi_temp}
#mkdir -p run
#mkdir -p scripts
#cd mongrel_cluster/webapps/
# FIXME fetch latest OpenMetrics from github or trac.openmetrics.net





# FIXME create dedicated user account and create ssh keys


echo -e '\n--------- Welcome to OpenMetrics ---------\n'


checkPreqs

echo -e "\n\nsome explaination"
read -p "Do you want to create a new user on this host? [$dialogAddUser]: "; checkInput dialogAddUser

if [ $dialogAddUser = "YES" ] ; then
	read -p "Username? [$OM_USER]: "; checkInput OM_USER
	echo -e "\n\nOk. I'm going to create a user called ${OM_USER}"
	# create ssh keypair
	useradd -c "OpenMetrics" -m -s /bin/sh --user-group ${OM_USER}
	# FIXME ssh-key requests a dialog for passphrase, we need to create a private key without passphrase by commandline only
	#su - $OM_USER -c "ssh-keygen -t rsa"
fi
