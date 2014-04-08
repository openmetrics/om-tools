#!/bin/bash
#
# this script will install OpenMetrics server (http://www.openmetrics.net)
#
# depends on: bash, ssh, yum or apt
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
for f in ${SELF_LOCATION}/om-install.d/*.sh; do source $f; done

# dialog defaults
dialogInstallPreqs="yes"
dialogAddUser="yes"
dialogAcceptSuggest="no"
dialogStartServices="yes"

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

prepareUserAccount

if installServer ; then
    log-green "Installation finished successfully!\n"
fi

exit 0
