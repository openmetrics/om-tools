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
#TMPDIR=`mktemp --tmpdir=/tmp -d om-agent-install.XXXXXX`
tmp=`mktemp -d om-agent-install.XXXXXX`
TMPDIR="/tmp/${tmp}"
mkdir ${TMPDIR}
LOGFILE="${TMPDIR}/install.log"

if [ -z "$1" ] ;then
	echo "Usage: `basename $0` <hostname|ip-adress>" >&2
	exit 42 
else
	HOST="$1"
	export HOST
fi

function prepareInstall() {
	
	return 0
}
# end prepareInstall

function installAgent() {
	echo -e "\n\nStarting installation... "
	scp -q ${SSH_OPTIONS} -r ${TMPDIR} root@${HOST}:/tmp
	ssh -q ${SSH_OPTIONS} root@${HOST} "sh /tmp/${tmp}/installOMAgent.sh"
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
mv /tmp/${tmp}/om-agent/* ${OM_AGENT_DIR}/
chown -R $OM_USER:$OM_USER ${OM_AGENT_DIR}
EOF
	cd ${TMPDIR}
	echo -e -n "\n\nFetching latest version of OpenMetrics agent... "
	if ` git clone git://github.com/mgrobelin/om-agent.git >> ${LOGFILE} 2>&1` ; then
		echo "DONE"
	else
		echo "FAILED"
	fi
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
