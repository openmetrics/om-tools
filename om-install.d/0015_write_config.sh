#!/bin/bash
function writeConfig() {
    # write all exported environment variables starting with OM_ to instance.env
    local env_vars var
    env_vars=` env | awk -F '=' '{print $1}' | grep -e '^OM_' `
    for var in $env_vars ; do
        eval value=\$$var
        echo "export ${var}=\"${value}\"" >> "${TEMPDIR}/instance.env"
    done

    # write om ssh pub key to instance.env
    if su - $OM_USER -c "touch ~/.ssh/id_rsa_om.pub" ; then
        OM_SSH_KEY=`su - $OM_USER -c "cat .ssh/id_rsa_om.pub"`
        echo "OM_SSH_KEY=\"${OM_SSH_KEY}\"" >> "${TEMPDIR}/instance.env"
    fi

    #
    # apply config
    #
    cp "${TEMPDIR}/instance.env" "${OM_BASE_DIR}/config/"
    cp -R "${SELF_LOCATION}/files/config/" "${OM_BASE_DIR}/"
    cp -R "${SELF_LOCATION}/files/scripts/" "${OM_BASE_DIR}/"

}