#!/bin/bash
function installServer() {
    # create dir structure
    debug "Installing server in directory ${OM_BASE_DIR}...\n"
	log "Creating directory structure...\n"
	mkdir -p "${OM_BASE_DIR}" && chown -R ${OM_USER} "${OM_BASE_DIR}"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/config/collectd ${OM_BASE_DIR}/config/nginx"
    su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/data ${OM_BASE_DIR}/data/collectd"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/htdocs"
	su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/logs/nginx ${OM_BASE_DIR}/logs/collectd"
	#su - $OM_USER -c "mkdir -p ${OM_BASE_DIR}/om-server"
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

	log "Installing Ruby and missing gems...\n"

    # rvm installer says one should to add the user to group rvm
    # dunno if needed or not
    usermod -G rvm "${OM_USER}"

    # TODO make less noisy
    su - $OM_USER -c "source /etc/profile.d/rvm.sh && rvm get stable"
    su - $OM_USER -c "rvm install 2.1.1 --disable-binary && rvm use 2.1.1"
    # TODO run gem install foreman
    su - $OM_USER -c "cd \"${OM_BASE_DIR}/om-server\" && bundle install --without development test >> /dev/null"
    if [ $? -gt 0 ] ; then
	    log-red "Failed to execute bundle install!\n"
	    # run bundle again to fetch full error output
	    if [[ $_V -eq 1 ]]; then
            su - $OM_USER -c "cd \"${OM_BASE_DIR}/om-server\" && bundle install"
	    fi
	    exit 1
	fi

    log "Create and migrate database...\n"
    # TODO make less noisy
	su - $OM_USER -c "export RAILS_ENV=development; cd \"${OM_BASE_DIR}/om-server\" && rake db:create && rake db:migrate"

	writeConfig
}
