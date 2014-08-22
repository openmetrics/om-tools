#!/bin/bash

function debian_preqs_install {

    # TODO install recent postgres
    # echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" | sudo tee -a /etc/apt/sources.list
    # wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    # sudo apt-get update
    # install postgres server, dev package to build ruby pg extension and postgres-contrib for hstore extension
    # sudo apt-get install postgresql-9.3 libpq-dev postgresql-contrib-9.3
    # install hstore extension as db superuser
    # CREATE EXTENSION hstore; 
    # setup pg-user and db
    # createuser --createdb --login --pwprompt kobold
    # createdb --owner=kobold openmetrics_development
    # createdb --owner=kobold openmetrics_test

    # suggest package to install
    if [ ! -z "${missing_tools[*]}" ] ; then
        local suggested_pkgs pkg_name tool command
        spinner $!
        local tool
        for tool in ${missing_tools[@]} ; do
            # try to find package with dpkg
            if dpkg-query -S "*bin/${tool}" >> /dev/null 2>&1 ; then
                # get package name from first hit
                pkg_name=$( dpkg-query -S "\*bin/${tool}" | head -n1 | cut -d ':' -f1 )
                debug "Suggesting to install package ${pkg_name} for tool ${tool}\n"
                suggested_pkgs+=("${pkg_name}")
            else
                log "Couldn't find package suggestion for $tool\n"
                unresolvable_tools+=("${tool}")
            fi
        done
    fi

    # better quit if there are any tools not installed yet
	if [ ${#unresolvable_tools[@]} -gt 0 ] ; then
	    log-red "Sorry, but I can't find suitable packages for: ${unresolvable_tools[*]}! Please install these tools to \$PATH and rerun this script afterwards.\n"
	    return 1
	fi

    # prepare command
    command=":" # bash noop
    if [ ${#suggested_pkgs[@]} -gt 0 ] ; then
        debug "Suggested packages to install: ${suggested_pkgs[@]}\n"
        if [[ $_V -eq 0 ]]; then
            command="apt-get --quiet -y install ${suggested_pkgs[@]}"
        else
            command="apt-get install ${suggested_pkgs[@]}"
        fi
    fi

    if [ ! "${command}" = ":" ] ; then
        log "Based on missing packages, I will issue this command for you now:"
        log-cyan "\n\t${command}\n"

        while true; do
            read -p "Is this ok for you? [$dialogAcceptSuggest]: "; evalYesNo dialogAcceptSuggest
        done

        # run the suggested command
        if $dialogAcceptSuggest ; then
            debug "Executing ${command} "
            spinner
            ${command}
        fi
    fi
}

function redhat_preqs_install {

#https://wiki.postgresql.org/wiki/YUM_Installation#Configure_your_YUM_repository
#http://yum.postgresql.org/repopackages.php#pg93

    # suggest package to install
    if [ ! -z "${missing_tools[*]}" ] ; then
        local suggested_pkgs pkg_full pkg_name command
        spinner $!
        local tool
        for tool in ${missing_tools[@]} ; do
            # try to find package with rpm
            if yum --quiet whatprovides $tool >> /dev/null 2>&1 ; then
                # get package name from first hit
                pkg_full=$( yum --quiet whatprovides $tool | head -n1 | cut -d ' ' -f1 )
                pkg_name=$( redhat_package_name "${pkg_full}" )
                debug "Suggesting to install package ${pkg_name} ${pkg_full} for tool ${tool}\n"
                suggested_pkgs+=("${pkg_name}")
            else
                log "Couldn't find package suggestion for $tool\n"
                unresolvable_tools+=("${tool}")
            fi
        done
    fi

    # better quit if there are any tools not installed yet
	if [ ${#unresolvable_tools[@]} -gt 0 ] ; then
	    log-red "Sorry, but I can't find suitable packages for: ${unresolvable_tools[*]}! Please install these tools to \$PATH and rerun this script afterwards.\n"
	    return 1
	fi

    # prepare command
    command=":" # bash noop
    if [ ! -z "${suggested_pkgs[*]}" ] ; then
        debug "Suggested packages to install: ${suggested_pkgs[@]}\n"
        if [[ $_V -eq 0 ]]; then
            command="yum --quiet -y install ${suggested_pkgs[@]}"
        else
            command="yum install ${suggested_pkgs[@]}"
        fi
    fi

    log "Based on missing packages, I will issue this command for you now:"
    log-cyan "\n\t${command}\n"

    while true; do
        read -p "Is this ok for you? [$dialogAcceptSuggest]: "; evalYesNo dialogAcceptSuggest
    done

    # run the suggested command
    if $dialogAcceptSuggest ; then
        debug "Executing ${command} "
        spinner
        ${command}
    fi

	#yum install collectd
	#yum install sqlite libsqlite3x-devel
    #yum install redis-server

	# or rvm
	#yum install ruby ruby-devel
	#yum install rubygems rubygem-rails
	# cd webdir bundle install
	# rake db:migrate RAILS_ENV=development
}

function installPreqs {
	case "${DistroBasedOn}" in
			debian)
				debian_preqs_install
				;;

			redhat)
				redhat_preqs_install
				;;
			*)
				log-red "Unsupported distribution. Sorry.\n"
				exit 42
	esac

    # rvm install
    log "I'm installing Ruby by rvm now...\n"
    curl -sSL https://get.rvm.io | bash

}

function prepareUserAccount() {
    #user exists?
    log "Checking for Openmetrics user account...\n"
    if cut -d ':' -f 1 /etc/passwd | grep -e "^${OM_USER}\$" >> /dev/null 2>&1; then
        log "User '${OM_USER}' already exists on this system. Using it...\n"
    else
        # preferred user account does not exist, ask to create it
        log-red "User account '${OM_USER}' does not exist on this system.\n"
        while true ; do
            read -p "Do you want me to create a new user on this host? [$dialogAddUser]: "; evalYesNo dialogAddUser
        done

        if $dialogAddUser ; then
            read -p "username: [$OM_USER]: "; evalInput OM_USER
            export OM_USER
            log "Creating a new user with username '${OM_USER}'...\n"
            if ERROR=$( useradd -c "Openmetrics system user" -m -s /bin/bash --user-group ${OM_USER} 2>&1 ) ; then
                : #noop
            else
                log-red "${ERROR}"
                exit 42
            fi
        fi
    fi

    log "Checking user '${OM_USER}' for usable SSH keypair...\n"
    if su - $OM_USER -c "test -f \$HOME/.ssh/id_rsa_om" ; then
        debug "SSH keypair already in place. No need to create a new one...\n"
    else
        # generate ssh keys
        if su - ${OM_USER} -c "ssh-keygen -q -t rsa -b 2048 -f \$HOME/.ssh/id_rsa_om -P '' " ; then
            debug "Successfully created SSH keypair for '${OM_USER}'...\n"
        else
            log-red "Failed to generate SSH keypair\n"
            exit 42
        fi
    fi
}
