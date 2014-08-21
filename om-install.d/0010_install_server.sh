#!/bin/bash
function installServer() {
    # install dir already exists? better quit...
    su - $OM_USER -c "test -d \"${OM_INSTALL_DIR}\"" &&
    log-red "Apparently there already exists a server in '${OM_INSTALL_DIR}'\n" &&
    log-cyan "You may want to run '${SELF_LOCATION}/om-update.sh' instead of this script.\n" &&
    exit 42

    # create dir structure
    debug "Installing server in directory ${OM_INSTALL_DIR}...\n"
	log "Creating directory structure...\n"
	mkdir -p "${OM_INSTALL_DIR}" && chown -R ${OM_USER} "${OM_INSTALL_DIR}"
	su - $OM_USER -c "mkdir -p ${OM_INSTALL_DIR}/conf/om-server conf/nginx"
	su - $OM_USER -c "mkdir -p ${OM_INSTALL_DIR}/htdocs"
	su - $OM_USER -c "mkdir -p ${OM_INSTALL_DIR}/logs/nginx logs/openmetrics-server"
	su - $OM_USER -c "mkdir -p ${OM_INSTALL_DIR}/om-server"
	su - $OM_USER -c "mkdir -p ${OM_INSTALL_DIR}/nginx"
	su - $OM_USER -c "mkdir -p ${OM_INSTALL_DIR}/run"
	su - $OM_USER -c "mkdir -p ${OM_INSTALL_DIR}/scripts"

	log "Fetching openmetrics server sources...\n"
	debug "Using this git clone command: ${OM_GIT_CMD}\n"
	su - $OM_USER -c "cd \"${OM_INSTALL_DIR}\" && ${OM_GIT_CMD} om-server >> /dev/null 2>&1" # checks out selected branch to dir om-server
	if [ $? -gt 0 ] ; then
	    log-red "Failed to execute ${OM_GIT_CMD}!\n"
	fi

	log "Installing missing Ruby gems...\n"
	debug "Running bundle install\n"
    su - $OM_USER -c "cd \"${OM_INSTALL_DIR}/om-server\" && bundle install >> /dev/null 2>&1"
    if [ $? -gt 0 ] ; then
	    log-red "Failed to execute bundle install!\n"
	fi
}
