#!/usr/bin/env bash

LOG_DIR="${HOME}/.local/state"
LOG_NAME="logout_sniper.log"
LOG="${LOG_DIR}/${LOG_NAME}"

SCRIPT_DIR="${HOME}/.local/share"
SCRIPT_NAME="logout_sniper.sh"
SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}"

SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_NAME="logout_sniper.service"
SERVICE="${SERVICE_DIR}/${SERVICE_NAME}"

function log () {
	function _log_stdin {
		while read -r; do
			echo "[$(date -Im)]" "$REPLY" | tee -a "${LOG}"
		done
	}
	if [ $# -eq 0 ]; then
		_log_stdin
	else
		echo "[$(date -Im)]" "$@" | tee -a "${LOG}"
	fi
}

function make_service {
	mkdir -p "${SERVICE_DIR}" |& log
	cat <<- EOF > "${SERVICE}" 2> >(log)
	[Unit]
	Description="Logout when idle for too long"
	After=gnome-session-x11-services-ready.target
	Wants=gnome-session-x11-services-ready.target

	[Service]
	Environment=DISPLAY=${DISPLAY}
	ExecStart=${SCRIPT} --run

	[Install]
	WantedBy=default.target
	EOF
}

function run {
	function _lse_enabled {
		local enable_file="/sgoinfre/mifelida_share/.lse"
		builtin test -f "${enable_file}"
		return $?
	}
	function _wait_xprintdidle_valid {
		if ! xprintidle > /dev/null 2>&1 ; then
			xhost +local:
			log "xprintidle failed:" "$(xprintidle)"
			while ! xprintidle > /dev/null 2>&1 ; do
				sleep 5;
			done
			log "xprintidle success"
		fi
	}

	MAX_IDLE_M=40
	MAX_IDLE_MS="$((MAX_IDLE_M * 60 * 1000))"

	while true; do
		_wait_xprintdidle_valid
		IDLE_TIME_MS=$(xprintidle)
		if [ "$IDLE_TIME_MS" -gt "$MAX_IDLE_MS" ]; then
			log "Logout sniped"
			if _lse_enabled; then
				loginctl terminate-user $UID
			fi
			exit 0
		else
			SLEEP_TIME_S=$(((MAX_IDLE_MS - $(xprintidle)) / 1000 + 1))
			sleep $SLEEP_TIME_S
		fi
	done
}

function install {
	if [ -z "$DISPLAY" ]; then
		echo "Error: DISPLAY not found in env. Service can't functon without it."
		exit 1
	fi
	make_service;
	if [[ "$_" == *INSTALL.sh ]] && [ -f "$_" ]; then
		cp "$_" "${SCRIPT}" |& log
	fi
	if ! [ -f "${SCRIPT}" ]; then
		echo "Script file not found. rtfm"
	fi
	chmod u+x "${SCRIPT}" | log
	systemctl --user enable "${SERVICE_NAME}" | log
	systemctl --user start "${SERVICE_NAME}" | log
}

if [[ $1 == --run ]]; then
	run
	exit 0
else
	install
	exit 0
fi
