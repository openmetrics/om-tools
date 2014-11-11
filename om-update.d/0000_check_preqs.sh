#!/bin/bash
function checkPreqs {
    log "Trying to find existing Openmetrics installation...\n"
    debug "PATH is set to: $PATH\n"

    # find instance.env file
    OM_INSTALL_ENVFILE=`find / -type f -name 'instance.env' 2>/dev/null | head -n1`
    OM_ENVFILE_DIR=`dirname "${OM_INSTALL_ENVFILE}"`
    debug "OM_INSTALL_ENVFILE: ${OM_INSTALL_ENVFILE}\n"
    debug "OM_ENVFILE_DIR: ${OM_ENVFILE_DIR}\n"
    OM_UPDATE_DIR=`echo "${OM_ENVFILE_DIR}" | sed -e "s/\/[^\/]*$//"`
    if test -z "${OM_INSTALL_ENVFILE}" ; then
            log-red "Couldn't find any Openmetrics instance.env file on this system!\n" >&2
            return 1
    fi


    # source in instance.env
    log-green "Found an instance.env file in ${OM_ENVFILE_DIR}!\n"
    debug "Loading environment from ${OM_INSTALL_ENVFILE}...\n"
    . "${OM_INSTALL_ENVFILE}"
    for env_var in `env | grep '^OM_'` ; do
        debug "${env_var}\n"
    done

    if test -d "${OM_BASE_DIR}" ; then
        while true; do
            read -p "I will prepare to update the Openmetrics installation located in ${OM_BASE_DIR}. Proceed? [$dialogUpdateProceed]: "; evalYesNo dialogUpdateProceed
        done
    else
        log-red "Failed to locate Openmetrics OM_BASE_DIR!\n"
        return 1
    fi

	# prerequisites check succeeded
	return 0
}
