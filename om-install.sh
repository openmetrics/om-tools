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

# get and set opts
_V=0
while getopts "v" OPTION
do
  case $OPTION in
    v) _V=1
       ;;
  esac
done

# read in some defaults
source "${SELF_LOCATION}/om-install.d/defaults.env"

# read in other functions
for f in ${SELF_LOCATION}/om-install.d/*.in; do source $f; done

# dialog defaults
dialogInstallPreqs="yes"
dialogAddUser="yes"

# we should be root to proceed
if [ "$UID" != "0" ]  ; then
	log-red "Run me with root privileges! Exiting.\n"
	exit 42
fi	

# create temporary directory for setup files
tempdir=`mktemp --tmpdir=/tmp -d om-install.XXXXXX`
INSTALL_DIR="${tempdir}"
cd "$INSTALL_DIR" || exit 42

# let's do it...
welcomeTeaser
systemInfo

# install missing tools if required
if ! checkPreqs ; then
    installPreqs
fi

read -p "Do you want to create a new user on this host? [$dialogAddUser]: "; evalInput dialogAddUser

if [ $dialogAddUser = "YES" ] ; then
	read -p "Username? [$OM_USER]: "; evalInput OM_USER
	echo -e -n "\n\nOk. I'm going to create a user called '${OM_USER}'... "

	if ERROR=$( useradd -c "OpenMetrics" -m -s /bin/bash --user-group ${OM_USER} 2>&1 ) ; then
		echo "DONE"
	else
		echo "FAILED"
		echo "$ERROR"
	fi
	
	echo -e -n "Creating RSA keys for SSH... "
	if su - $OM_USER -c "test -f \$HOME/.ssh/id_rsa_om" ; then
		echo "FAILED"
		echo "SSH keypair already in place."	
	else
		# generate ssh keys
		if su - $OM_USER -c "ssh-keygen -q -t rsa -b 2048 -f \$HOME/.ssh/id_rsa_om -P ''" ; then
			echo "DONE"
		else
			echo "FAILED"
		fi
	fi

fi

installServer
