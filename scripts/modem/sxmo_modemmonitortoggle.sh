#!/usr/bin/env sh

# This script toggles the modem monitor
# It optionally takes a parameter "on" or "off"
# forcing it to toggle only to that desired state if applicable.
# It may also take a "reset" parameter that forces the
# entire modem subsystem to reload

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

daemon_start() {
	case "$OS" in
		"Alpine Linux"|postmarketOS)
			sudo rc-service "$1" start
			;;
		"Arch Linux ARM"|alarm)
			[ "$1" = "modemmanager" ] && set -- ModemManager
			sudo systemctl start "$1"
			;;
	esac
}

daemon_stop() {
	case "$OS" in
		"Alpine Linux"|postmarketOS)
			sudo rc-service "$1" stop
			;;
		"Arch Linux ARM"|alarm)
			[ "$1" = "modemmanager" ] && set -- ModemManager
			sudo systemctl stop "$1"
			;;
	esac
}

daemon_isrunning() {
	daemon_exists "$1" || return 0
	case "$OS" in
		"Alpine Linux"|postmarketOS)
			rc-service "$1" status | grep -q started
			;;
		"Arch Linux ARM"|alarm)
			[ "$1" = "modemmanager" ] && set -- ModemManager
			systemctl status "$1" | grep -q running
			;;
	esac
}

daemon_exists() {
	case "$OS" in
		"Alpine Linux"|postmarketOS)
			[ -f /etc/init.d/"$1" ]
			;;
		"Arch Linux ARM"|alarm)
			systemctl status "$1" >/dev/null
			;;
	esac
}

ensure_daemon() {
	TRIES=0
	while ! daemon_isrunning "$1"; do
		if [ "$TRIES" -eq 10 ]; then
			return 1
		fi
		TRIES=$((TRIES+1))
		daemon_start "$1"
		sleep 5
	done

	return 0
}

ensure_daemons() {
	if (daemon_isrunning eg25-manager) && \
			(daemon_isrunning modemmanager); then
		return
	fi

	echo "sxmo_modemmonitortoggle: forcing modem restart" >&2
	notify-send "Resetting modem daemons, this may take a minute..."

	daemon_stop modemmanager
	daemon_stop eg25-manager
	sleep 2

	if ! (ensure_daemon eg25-manager && ensure_daemon modemmanager); then
		printf "failed\n" > "$MODEMSTATEFILE"
		notify-send --urgency=critical "We failed to start the modem daemons. We may need hard reboot."
		return 1
	fi
}

on() {
	rm "$NOTIFDIR"/incomingcall*

	TRIES=0
	while ! printf %s "$(mmcli -L)" 2> /dev/null | grep -qoE 'Modem\/([0-9]+)'; do
		TRIES=$((TRIES+1))
		if [ "$TRIES" -eq 10 ]; then
			notify-send --urgency=critical "We failed to start the modem monitor. We may need hard reboot."
		fi
		sleep 5
	done

	setsid -f sxmo_modemmonitor.sh &

	sleep 1
}

off() {
	pkill -TERM -f sxmo_modemmonitor.sh
}

if [ -z "$1" ]; then
	if pgrep -f sxmo_modemmonitor.sh; then
		set -- off
	else
		set -- on
	fi
fi

case "$1" in
	restart) off; ensure_daemons && on;;
	on) ensure_daemons && on;;
	off) off;;
esac

sleep 1
sxmo_statusbarupdate.sh
