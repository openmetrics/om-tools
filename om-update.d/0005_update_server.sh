#!/bin/bash
function updateServer() {
    # create dir structure
    debug "Updating server in directory ${OM_BASE_DIR}...\n"

    # update webapp in OM_BASE_DIR/om-server
    cd "${OM_BASE_DIR}/om-server"
    OM_GIT_URL=`git config --get remote.origin.url`
    OM_GIT_BRANCH=`git symbolic-ref HEAD 2>/dev/null | cut -d"/" -f 3` # from http://stackoverflow.com/questions/1593051/how-to-programmatically-determine-the-current-checked-out-git-branch
    debug "OM_GIT_URL: ${OM_GIT_URL}\n"
    debug "OM_GIT_BRANCH: ${OM_GIT_BRANCH}\n"

    log "Updating Openmetrics server sources...\n"
    # force git to load latest sources
    #su - $OM_USER -c "cd ${OM_BASE_DIR}/om-server && git pull origin ${OM_GIT_BRANCH}" # may raise error: Your local changes to the following files would be overwritten by merge...
    su - $OM_USER -c "cd ${OM_BASE_DIR}/om-server && git fetch --all && git reset --hard origin/${OM_GIT_BRANCH}"
    su - $OM_USER -c "cd ${OM_BASE_DIR}/om-server && git submodule update"

    # update bundle
    log "Updating Ruby gems..."
    cd "${OM_BASE_DIR}/om-server" && bundle update
    su - $OM_USER -c "cd ${OM_BASE_DIR}/om-server && bundle install --path vendor/bundle"

    # migrate db
    log "Migrating Openmetrics database...\n"
    su - $OM_USER -c "cd ${OM_BASE_DIR}/om-server && rake db:migrate"
}
