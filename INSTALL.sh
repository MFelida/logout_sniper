#!/usr/bin/env bash

function make_service {
	cat <<- EOF > ${HOME}/.config/systemd/user/logout_sniper.service
	[Unit]
	Description="Logout when idle for too long"
	After=gnome-session-x11-services-ready.target
	Wants=gnome-session-x11-services-ready.target

	[Service]
	Environment=DISPLAY=${DISPLAY}
	ExecStart=%h/.local/share/logout_sniper.sh --run

	[Install]
	WantedBy=default.target
	EOF
}

function log () {
	local LOG_STRING="$(date -Im) $@"
	echo $LOG_STRING
	echo $LOG_STRING >> ${HOME}/.local/state/logout_sniper.log
}

function run {
	if ! xprintidle > /dev/null 2>&1 ; then
		xhost +local:
		log "xprintidle failed"
		while ! xprintidle > /dev/null 2>&1 ; do
			sleep 5;
		done
		log "xprintidle success"
	fi

	MAX_IDLE_M=40
	MAX_IDLE_MS="$(($MAX_IDLE_M * 60 * 1000))"

	while true; do
		IDLE_TIME_MS=$(xprintidle)
		if [ $IDLE_TIME_MS -gt $MAX_IDLE_MS ]; then
			log "Logout sniped"
			if [ -f /sgoinfre/mifelida_share/.lse ]; then
				loginctl terminate-user $UID
			fi
			exit 0
		else
			SLEEP_TIME=$((($MAX_IDLE_MS - $(xprintidle)) / 1000 + 1))
			sleep $SLEEP_TIME
		fi
	done
}

function install {
	make_service;
	cp -f "$0" "${HOME}/.local/share/logout_sniper.sh"
	> "${HOME}/.local/state/logout_sniper.log"
}

if [ $# -lt 1 ]; then
	install;
	exit 0;
elif [[ $1 == --run ]]; then
	run
	exit 0;
fi
