#!/bin/bash
function checkPreqs {
    required_tools=( git curl ssh ssh-keygen rrdtool nmap collectd redis-server ) # ruby rvm nodejs graphviz
    unresolvable_tools=()
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
    			missing_tools+=("${tool}")
    			ret=1
 		fi
	done

	# TODO ruby command may be provided by PATH or .rvm
    if ! which ruby > /dev/null 2>&1 ; then
        debug "Couldn't find 'ruby' in $PATH\n" >&2 ;
        missing_tools+=("ruby")
        ret=1;
    fi
    #if [ -d "${HOME}/.rvm" ] ; then
    #    rvm_pathes=(`find "${HOME}/.rvm/rubies/" -maxdepth 2 -type d -name 'bin'`)
	#    debug "Found RVM pathes: ${rvm_pathes[@]}"
    #fi

	# some tools are missing, try to install
	if [ $ret = 1 ] ; then
	    #echo "Missing tools: ${missing_tools[*]}"
		log-red "Oh snap! This system lacks software needed to install Openmetrics: ${missing_tools[*]}\n"
		while true; do
		    read -p "I'll try to fix this for you. Ok? [$dialogInstallPreqs]: "; evalYesNo dialogInstallPreqs
        done
        return 1
	fi

	# install dir already exists? better quit...
    test -d "${OM_BASE_DIR}" &&
    log-red "Apparently there already exists an Openmetrics installation in '${OM_BASE_DIR}'\n" &&
    log "You may want to run '${SELF_LOCATION}/om-update.sh' instead.\n" &&
    exit 42

	# prerequisites check succeeded
	return 0
}
