#!/bin/bash
function installServer() {
    # create dir structure
    debug "Installing server in directory ${OM_BASE_DIR}...\n"
	log "Creating directory structure...\n"
	mkdir -p "${OM_BASE_DIR}" && chown -R ${OM_USER} "${OM_BASE_DIR}"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/config/collectd ${OM_BASE_DIR}/config/nginx"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/htdocs"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/logs/nginx ${OM_BASE_DIR}/logs/collectd"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/om-server"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/nginx"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/run ${OM_BASE_DIR}/run/collectd"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/scripts"

	log "Fetching Openmetrics server sources...\n"
	debug "Using this git clone command: ${OM_GIT_CMD}\n"
	su - $OM_USER -c "cd \"${OM_BASE_DIR}\" && ${OM_GIT_CMD} om-server >> /dev/null 2>&1" # checks out selected branch to dir om-server
	if [ $? -gt 0 ] ; then
	    log-red "Failed to execute ${OM_GIT_CMD}!\n"
	    exit 1
	fi

	log "Installing missing Ruby gems...\n"
    su - $OM_USER -c "cd \"${OM_BASE_DIR}/om-server\" && bundle install >> /dev/null 2>&1"
    if [ $? -gt 0 ] ; then
	    log-red "Failed to execute bundle install!\n"
	    exit 1
	fi

	writeConfig
}
