#!/bin/bash
function checkPreqs {
    required_tools=( ruby git ssh ssh-keygen rrdtool nmap collectd redis-server ) #graphviz
    local ret=0
    log "Checking system for required tools & libraries...\n"
    debug "PATH is set to: $PATH\n"

    # check tools, special treatment for ruby
    missing_tools=()
    local tool
	for tool in "${required_tools[@]}"
	do
	    if [ "$tool" = "ruby" ]; then continue; fi
 		if ! which $tool > /dev/null 2>&1
 		then
    			debug "Couldn't find '$tool' in $PATH\n" >&2
    			missing_tools=("${missing_tools[@]} $tool")
    			ret=1
 		fi
	done

	# TODO ruby command may be provided by PATH or .rvm
    if ! which ruby > /dev/null 2>&1 ; then
        debug "Couldn't find 'ruby' in $PATH\n" >&2 ;
        missing_tools=("${missing_tools[@]} ruby")
        ret=1;
    fi
    #if [ -d "${HOME}/.rvm" ] ; then
    #    rvm_pathes=(`find "${HOME}/.rvm/rubies/" -maxdepth 2 -type d -name 'bin'`)
	#    debug "Found RVM pathes: ${rvm_pathes[@]}"
    #fi

	# some tools are missing
	if [ $ret = 1 ] ; then
	    #echo "Missing tools: ${missing_tools[@]}"
		log-red "Oh snap! This system lacks software needed to run openmetrics.\n"
		while true; do
		    read -p "I'll try to fix this for you. Ok? [$dialogInstallPreqs]: "; evalYesNo dialogInstallPreqs
        done
        return 1
	fi

	# install dir already exists? better quit...
    su - $OM_USER -c "test -d \"${OM_INSTALL_DIR}\"" &&
    log-red "Apparently there already exists an openmetrics installation in '${OM_INSTALL_DIR}'\n" &&
    log "I'll better quit myself. You may want to run '${SELF_LOCATION}/om-update.sh' instead." &&
    exit 42

	# prerequisites check succeeded
	return 0
}
