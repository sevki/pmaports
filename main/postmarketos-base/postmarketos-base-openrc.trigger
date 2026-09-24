#!/bin/sh -e

# Runlevels get broken when services are moved, so we need to manually
# recreate the symlinks that OpenRC would normally make. Afterwards,
# OpenRC can handle the new service location.
# $1: runlevels path
# $2: rc path
rewrite_runlevel_symlinks() {
	# iterate runlevels and services
	for runlevel in "$1"/*; do
		for service in "$runlevel"/*; do
			# check each service for if it exists and is an invalid symlink
			if [ ! -e "$service" ] && [ -h "$service" ]; then
				# rewrite the symlink if the service has been moved
				service_name="$(basename "$service")"
				# OpenRC promotes symlinking services to new names, so the realpath
				# of the symlink needs to be used instead of just the filename
				service_realpath="$(realpath "$service")"
				service_realpath_name="$(basename "$service_realpath")"
				runlevel_name="$(basename "$runlevel")"
				if [ -e "$2"/init.d/"$service_realpath_name" ]; then
					printf "Found moved service! Rewriting runlevel symlink\n"
					ln -sf "$2"/init.d/"$service_realpath_name" \
						"$1"/"$runlevel_name"/"$service_name"
				fi
			fi
		done
	done
}

# Multiplexed services get broken when services are moved, so we have to
# manually recreate the local symlinks as absolute symlinks
# $1: etc rc path
# $2: libexec rc path
rewrite_multiplex_symlinks() {
	for service in "$1"/init.d/*; do
		# check each service for if it exists and is an invalid symlink
		if [ ! -e "$service" ] && [ -h "$service" ]; then
			service_name="$(basename "$service")"
			service_realpath="$(realpath "$service")"
			service_realpath_name="$(basename "$service_realpath")"
			for libexec_service in "$2"/init.d/*; do
				libexec_service_name="$(basename "$libexec_service")"
				if [ "$service_realpath_name" = "$libexec_service_name" ]; then
						printf "Found moved multiplexed service! Rewriting /etc/init.d symlink\n"
						ln -sf "$2"/init.d/"$libexec_service_name" \
						"$1"/init.d/"$service_name"
				fi
			done
		fi
	done
}

# Only run this if the libexec/rc exists
if [ -e /usr/libexec/rc ]; then
	printf "Checking if services have been moved\n"
	# system services
	rewrite_runlevel_symlinks /etc/runlevels /usr/libexec/rc
	rewrite_multiplex_symlinks /etc/ /usr/libexec/rc

	# user services
	homes="$(ls /home)"
	# there can be more than one user with user services
	for home in $homes; do
		config_dir="/home/$home/.config"
		if [ -e "$config_dir"/rc ]; then
			rewrite_runlevel_symlinks "$config_dir"/rc/runlevels /usr/libexec/rc/user
			rewrite_multiplex_symlinks "$config_dir"/rc /usr/libexec/rc/user
		fi
	done
fi

exit 0
