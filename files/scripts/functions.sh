#!/bin/sh
#
# some functions depend on sourced in variables of instance.env!
#

# resolve all occurances of $OM_* from infile and substitute with their value
# argument #1 should be the name of infile w/o .in file extension, e.g. collectd.conf
function env2conf() {
    conffile=$1
	env_vars="`env | grep -e '^OM_'`"
	find ${OM_BASE_DIR}/config/ -type f -iname "${conffile}.in" | while read infile
	do
		#conffile="`echo ${infile} | sed -e 's/\.in$//g'`"
		dir=`dirname "${infile}"`
		tmpfile="`mktemp`"
		echo "# DONT EDIT this file!!! Use ${infile} for modifications" | cat - "${infile}" > "${tmpfile}"
		for var in $env_vars; do
			vkey="`echo $var | cut -f1 -d=`"
			vvalue="`echo $var | cut -f2 -d=`"
			sed -e "s!\$${vkey}!`echo $vvalue`!g" -i "${tmpfile}" # don't use slashes here, use !
		 done
		 mv "${tmpfile}" "${dir}/${conffile}"
	done
}
