#!/bin/bash
#
# this script will install OpenMetrics server (http://www.openmetrics.net)
#
# this script requires: bash, ssh, yum (Redhat) or apt-get and dpkg (Debian)
#

set -o errexit # exit on all errors

#
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


# some defaults
source "${SELF_LOCATION}/om-install.d/functions.env"
source "${SELF_LOCATION}/om-install.d/defaults.env"

# read in other globals & functions
for f in ${SELF_LOCATION}/om-install.d/*.sh; do source $f; done

# dialog defaults
dialogInstallPreqs="yes"
dialogAddUser="yes"
dialogAcceptSuggest="no"
dialogStartServices="yes"

#
# help & usage
function print_usage {
	echo -e "Usage: `basename $0` [<Option> ...]\n"
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

# we should be root to proceed
if [ "$UID" != "0" ]  ; then
	log_red "Run me with root privileges! Exiting.\n"
	exit 42
fi

# let's do it...
welcomeTeaser
systemInfo

# install missing tools if required
if ! checkPreqs ; then
    installPreqs
fi

log_green "Prerequisits seem satisfied!\n"

prepareUserAccount

if installServer ; then
    log_green "Installation of Openmetrics server finished successfully!\n"
fi

exit 0
