#!/bin/bash
#
# This script is meant to be executed on openmetrics server and will install openmetrics agent on a remote host
#
# Requirements:
#   * an SSH private key ~/.ssh/id_rsa_om
#	* working SSH pubkey authentication (~/.ssh/id_rsa_om.pub) for root-user on remote host (/root/.ssh/authorized_keys)
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
. "${SELF_LOCATION}/om-install.d/defaults.env"
. "${SELF_LOCATION}/om-install.d/functions.env"


# dialog defaults
dialogAddUser="YES"
dialogPathToInstall="YES"


#
# help & usage
function print_usage {
	echo -e "Usage: `basename $0` [<Options>] openmetrics_server target_host\n"
	echo -e "Options:"
	echo -e "  -v\t\t\tenable verbose output"
	echo -e "  -h\t\t\tprint this help"
}


# get and set opts
#
_V=0
NO_ARGS=0
OPTERROR=65
while getopts ":vh" Option ; do
	case $Option in
	    v) _V=1 ;;
	    h) print_usage; exit 0;;
		* ) log_red "Invalid option!\n"; print_usage; exit 42;;
	esac
done
shift $(($OPTIND - 1)) # Decrements the argument pointer so it points to next argument.


# FIXME check arguments more acurate
if [ -z "$2" ] ;then
	print_usage
	exit 42 
else
	HOST="$2"
	export HOST 
fi

if [ -z "$1" ] ;then
	print_usage
	exit 42 
else
	OM_SERVER="$1"
	export OM_SERVER
fi



# read in om-server configuration (instance.env)
echo -n "Looking for openmetrics server configuration... "
if [ -f "/opt/openmetrics/config/instance.env" ] ; then
	. /opt/openmetrics/config/instance.env
	echo "OK" 

	if [[ $_V -eq 1 ]] ; then
		echo "I will use these settings for agent installation:"
		env | grep -e '^OM_' | grep -v -e '^OM_DB' | grep -v 'OM_USER' | sort
	fi
else
	log "FAILED\n"
	log_red "Could not load /opt/openmetrics/config/instance.env\n"
	exit 42
fi



# create temporary directory for setup files
TMPDIR=`mktemp --tmpdir=/tmp -d om-agent-install.XXXXXX`
TMPDIR_E=`echo ${TMPDIR} | sed -e 's/.*om-agent-install\(.*\)/\1/'`
#tmp=`mktemp -d om-agent-install.XXXXXX`
#TMPDIR="/tmp/${tmp}"
#mkdir ${TMPDIR}
#echo "TMPDIR is set to $TMPDIR"
LOGFILE="${TMPDIR}/remote-install.log"

# some options to get ssh/scp/svn working for remote access
SSH_OPTIONS="-i ${HOME}/.ssh/id_rsa_om -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"


function prepareInstall() {	
	# substitute some placeholders in collectd config
	env_vars="`env | grep 'OM_'`"
	for var in $env_vars; do
		vkey="`echo $var | cut -f1 -d=`"
		vvalue="`echo $var | cut -f2 -d=`"		
		sed -e "s:\$${vkey}:`echo $vvalue`:g" -i "${TMPDIR}/om-agent/etc/collectd/collectd.conf"
	done
	
}
# end prepareInstall

function installAgent() {
	echo -e -n "Starting installation (this may take a while)... "
	# transfer files
	if scp -q ${SSH_OPTIONS} -r ${TMPDIR} root@${HOST}:/tmp ; then
		:
	else
		log_red "Failed to transfer install files"
		exit 42
	fi
	# execute installation
	if ssh -q ${SSH_OPTIONS} root@${HOST} "/tmp/om-agent-install${TMPDIR_E}/installOMAgent.sh" ; then
		log_green "Installation succeeded!\n"
	else 
		log_red "FAILED\n"
		exit 42
	fi
} 
# end InstallAgent

function checkInput() {
	# overwrite passed variable with last line of user input
	if [ ! -z "$REPLY" ]; then
		eval $*=\""$REPLY"\"
	fi
}
# end checkInput

# check ssh connectivity for remote host, first with pubkey auth...
echo -e -n "Checking passwordless SSH connectivity for root@${HOST}... "
if ` ssh -q -q -o BatchMode=yes -o ConnectTimeout=3 ${SSH_OPTIONS} root@${HOST} ":" ` ; then 
	echo "DONE"
	
	# test ssh pubkey to be available
	if test -n "${OM_SSH_KEY}" ; then
		echo "Using SSH public key: $OM_SSH_KEY" 
	else
		echo "No usable SSH public key found."
		exit 42
	fi

	# create install script: append common functions to installer
	cat "${SELF_LOCATION}/om-install.d/functions.env" >> ${TMPDIR}/installOMAgent.sh

	# pass through debug mode
	if [[ $_V -eq 1 ]] ; then
		echo "_V=1" >> ${TMPDIR}/installOMAgent.sh	
	fi

	# set executable
	chmod +x ${TMPDIR}/installOMAgent.sh

	# create user on remote host
	read -p "Do you want me to create a new user on remote host? [$dialogAddUser]: "; checkInput dialogAddUser
	if [ $dialogAddUser = "YES" ] ; then
		read -p "Username? [$OM_USER]: "; checkInput OM_USER
		cat >> ${TMPDIR}/installOMAgent.sh << EOF
# openmetrics agent install
useradd -c "openmetrics agent" -m -s /bin/bash --user-group ${OM_USER}
# deploy om server ssh public key
su - $OM_USER -c "umask 077; mkdir ~/.ssh && touch ~/.ssh/authorized_keys && echo "${OM_SSH_KEY}" >> ~/.ssh/authorized_keys"
EOF

	else
		# ask for user account that should be used and overwrite OM_USER
		echo "FIXME select existing user... defaulting to ${OM_USER}"
	fi	
	
	#FIXME OM_INSTALL_DIR  should match do users home directory?
	read -p "Which directory should be used to install the OpenMetrics agent? [$OM_AGENT_DIR]: "; checkInput OM_AGENT_DIR

	# continue install procedure itself
	cat >> ${TMPDIR}/installOMAgent.sh << EOF
if [ -d "${OM_AGENT_DIR}" ]; then log_red "ERROR There already is a directory called ${OM_AGENT_DIR} in place. Aborting." && exit 42 ; fi

# get system info (prints in debug only)
systemInfo

# DistroBasedOn comes from appended functions.env
if [[ "\$DistroBasedOn" == "redhat" ]] ; then
	# redhat install
	yum -y install collectd >> /dev/null 2>&1
	systemctl stop collectd >> /dev/null 2>&1
	systemctl disable collectd >> /dev/null 2>&1
elif [[ "\$DistroBasedOn" == "debian" ]] ; then
	# debian install
	# install collectd
	apt-get -y install collectd >> /dev/null 2>&1
	/etc/init.d/collectd stop >> /dev/null 2>&1
	update-rc.d -f collectd remove >> /dev/null 2>&1
else
	log_red "ERROR Unsupported target operating system: $DistroBasedOn"
	exit 42
fi

mkdir -p "${OM_AGENT_DIR}"
# this move doesnt include .git directory
cp -r /tmp/om-agent-install${TMPDIR_E}/om-agent/* ${OM_AGENT_DIR}/
chown -R $OM_USER:$OM_USER ${OM_AGENT_DIR}
# create env file for agent
echo OM_AGENT_DIR=\"${OM_AGENT_DIR}\" >> "${OM_AGENT_DIR}/om-agent.env"
echo OM_SERVER=\"${OM_SERVER}\" >> "${OM_AGENT_DIR}/om-agent.env"
chown $OM_USER "${OM_AGENT_DIR}/om-agent.env"
# start the agent
# FIXME add some error handling if daemon doesn't starts
su - $OM_USER -c "${OM_AGENT_DIR}/scripts/rc.collectd start >> /dev/null 2>&1"
EOF
	cd ${TMPDIR}
	echo -e -n "Fetching latest version of openmetrics agent... "
	if ` git clone git://github.com/openmetrics/om-agent.git >> ${LOGFILE} 2>&1` ; then
		echo "DONE"
	else
		echo "FAILED"
		exit 42
	fi
	prepareInstall
	installAgent	
else
	echo "FAILED"
	exit 42
	# ... otherwise try again with password prompt
	#echo -e "Trying again to connect to host ${HOST} with password authentication... "
	#if ` ssh ${SSH_OPTIONS} -o ConnectTimeout=3 root@${HOST} ":" ` ; then
#		prepareInstall
#		installAgent
#	else
#		echo "FAILED"
#		exit 42
#	fi
fi
