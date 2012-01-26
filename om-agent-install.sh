#!/bin/bash
#
# this script will install OpenMetrics agent on a remote host
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
dialogPathToInstall="YES"


# create temporary directory for setup files
TMPDIR=`mktemp --tmpdir=/tmp -d om-agent-install.XXXXXX`
TMPDIR_E=`echo ${TMPDIR} | sed -e 's/.*om-agent-install\(.*\)/\1/'`
#tmp=`mktemp -d om-agent-install.XXXXXX`
#TMPDIR="/tmp/${tmp}"
#mkdir ${TMPDIR}
#echo "TMPDIR is set to $TMPDIR"
LOGFILE="${TMPDIR}/install.log"

# FIXME use getopts and check arguments more acurate
if [ -z "$2" ] ;then
	echo "Usage: `basename $0` <hostname|ip of OpenMetrics server> <hostname|ip of install target>" >&2
	exit 42 
else
	HOST="$2"
	export HOST 
fi

if [ -z "$1" ] ;then
	echo "Usage: `basename $0` <hostname|ip of OpenMetrics server> <hostname|ip of install target>" >&2
	exit 42 
else
	OM_SERVER="$1"
	export OM_SERVER
fi




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
	echo -e "\n\nStarting installation... "
	scp -q ${SSH_OPTIONS} -r ${TMPDIR} root@${HOST}:/tmp
	ssh -q ${SSH_OPTIONS} root@${HOST} "sh /tmp/om-agent-install${TMPDIR_E}/installOMAgent.sh"
	echo "DONE"
} 
# end InstallAgent

function checkInput() {
	# overwrite passed variable with last line of user input
	if [ ! -z "$REPLY" ]; then
		eval $*=\""$REPLY"\"
	fi
}
# end checkInput

# some options to get ssh/scp/svn working for remote access
SSH_OPTIONS="-o ForwardAgent=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# check ssh connectivity for remote host, first with pubkey auth...
echo -e -n "Checking passwordless SSH connectivity for host ${HOST}... "
if ` ssh -q -q -o "BatchMode=yes" ${SSH_OPTIONS} root@${HOST} ":" ` ; then 
	echo "DONE"
	# create user on remote host
	read -p "Do you want me to create a new user on remote host? [$dialogAddUser]: "; checkInput dialogAddUser
	if [ $dialogAddUser = "YES" ] ; then
		read -p "Username? [$OM_USER]: "; checkInput OM_USER
		cat > ${TMPDIR}/installOMAgent.sh << EOF
#!/bin/sh
useradd -c "OpenMetrics agent" -m -s /bin/bash --user-group ${OM_USER}
#install om server ssh-key 		
EOF
	else
		# ask for user account that should be used and overwrite OM_USER
		echo "FIXME select existing user"
	fi	
	
	#FIXME OM_INSTALL_DIR  should match do users home directory?
	read -p "Which directory should be used to install the OpenMetrics agent? [$OM_AGENT_DIR]: "; checkInput OM_AGENT_DIR
	cat >> ${TMPDIR}/installOMAgent.sh << EOF
if [ -d "${OM_AGENT_DIR}" ]; then echo "ERROR There already is a directory called ${OM_AGENT_DIR} in place. Aborting." && exit 42 ; fi
mkdir -p "${OM_AGENT_DIR}"
# this move doesnt include .git directory
cp -r /tmp/om-agent-install${TMPDIR_E}/om-agent/* ${OM_AGENT_DIR}/
chown -R $OM_USER:$OM_USER ${OM_AGENT_DIR}
# create env file for agent
echo OM_AGENT_DIR=\"${OM_AGENT_DIR}\" >> "${OM_AGENT_DIR}/om-agent.env"
echo OM_SERVER=\"${OM_SERVER}\" >> "${OM_AGENT_DIR}/om-agent.env"
EOF
	cd ${TMPDIR}
	echo -e -n "Fetching latest version of OpenMetrics agent... "
	if ` git clone git://github.com/mgrobelin/om-agent.git >> ${LOGFILE} 2>&1` ; then
		echo "DONE"
	else
		echo "FAILED"
	fi
	prepareInstall
	installAgent	
else
	echo "FAILED"
	# ... otherwise try again with password prompt
	echo -e "Trying again to connect to host ${HOST} with password authentication... "
	if ` ssh ${SSH_OPTIONS} root@${HOST} ":" ` ; then
		echo "FAILED"
	else
		echo "FOO"
	fi
fi

#if `ssh  root@${HOST} "" >> ${LOGFILE} 2>&1` ; then
	#echo "DONE"
#else
#	echo "FAILED"
#	exit 42
#fi
