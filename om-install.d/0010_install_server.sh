function installServer() {
	echo -e -n "\n\nInstalling OpenMetrics server... "
	su - $OM_USER -c "mkdir -p conf/nginx"
	su - $OM_USER -c "mkdir -p htdocs"
	su - $OM_USER -c "mkdir -p logs/nginx"
	su - $OM_USER -c "mkdir -p mongrel_cluster/conf mongrel_cluster/logs mongrel_cluster/webapps"
	su - $OM_USER -c "mkdir -p nginx/conf nginx/logs nginx/scgi_temp nginx/tmp nginx/uwsgi_temp"
	su - $OM_USER -c "mkdir -p run"
	su - $OM_USER -c "mkdir -p scripts"

	# FIXME fetch latest OpenMetrics from github or trac.openmetrics.net
	su - $OM_USER -c "mkdir mongrel_cluster/webapps/openmetrics"

	#cp -r /home/mgrobelin/development/openmetrics/* $OM_INSTALL_DIR/mongrel_cluster/webapps/openmetrics

	echo "DONE"
}
# end installServer