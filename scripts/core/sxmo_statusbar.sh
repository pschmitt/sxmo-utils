#!/usr/bin/env sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

percenticon() {
	if [ "$1" -lt 20 ]; then
		printf ""
	elif [ "$1" -lt 40 ]; then
		printf ""
	elif [ "$1" -lt 60 ]; then
		printf ""
	elif [ "$1" -lt 80 ]; then
		printf ""
	else
		printf ""
	fi
}

bar() {
	MMCLI="$(mmcli -m any -J)"

	# In-call.. show length of call
	if pgrep sxmo_modemcall.sh > /dev/null; then
		NOWS="$(date +"%s")"
		CALLSTARTS="$(date +"%s" -d "$(
			grep -aE 'call_start|call_pickup' "$XDG_DATA_HOME"/sxmo/modem/modemlog.tsv |
			tail -n1 |
			cut -f1
		)")"
		CALLSECONDS="$(printf "%s - %s" "$NOWS" "$CALLSTARTS" | bc)"
		printf "%ss " "$CALLSECONDS"
	fi

	MODEMSTATUS=""
	if [ -z "$MMCLI" ]; then
		printf ""
	else
		MODEMSTATUS="$(printf %s "$MMCLI" | jq -r .modem.generic.state)"
		case "$MODEMSTATUS" in
			locked)
				printf ""
				;;
			registered|connected)
				MODEMSIGNAL="$(printf %s "$MMCLI" | jq -r '.modem.generic."signal-quality".value')"
				percenticon "$MODEMSIGNAL"
				;;
			disconnected)
				printf "ﲁ"
				;;
		esac
	fi

	if [ "$MODEMSTATUS" = "connected" ]; then
		printf " "
		USEDTECHS="$(printf %s "$MMCLI" | jq -r '.modem.generic."access-technologies"[]')"
		case "$USEDTECHS" in
			*5gnr*)
				printf 5g # no icon yet
				;;
			*lte*)
				printf ﰒ
				;;
			*umts*|*hsdpa*|*hsupa*|*hspa*|*1xrtt*|*evdo0*|*evdoa*|*evdob*)
				printf ﰑ
				;;
			*edge*)
				printf E
				;;
			*pots*|*gsm*|*gprs*)
				printf ﰐ
				;;
		esac
	fi

	if pgrep -f sxmo_modemmonitor.sh > /dev/null; then
		printf " "
	fi

	WLANSTATE="$(tr -d "\n" < /sys/class/net/wlan0/operstate)"
	if [ "$WLANSTATE" = "up" ]; then
		printf " "
	fi

	# symbol if wireguard/vpn is connected
	VPNDEVICE="$(nmcli con show | grep vpn | awk '{ print $4 }')"
	WGDEVICE="$(nmcli con show | grep wireguard | awk '{ print $4 }')"
	if [ -n "$VPNDEVICE" ] && [ "$VPNDEVICE" != "--" ]; then
		printf " "
	elif [ -n "$WGDEVICE" ] && [ "$WGDEVICE" != "--" ]; then
		printf " "
	fi

	# Find battery and get percentage + status
	for power_supply in /sys/class/power_supply/*; do
		if [ "$(cat "$power_supply"/type)" = "Battery" ]; then
			PCT="$(cat "$power_supply"/capacity)"
			BATSTATUS="$(cut -c1 "$power_supply"/status)"
		fi
	done

	printf " "
	if [ "$BATSTATUS" = "C" ]; then
		if [ "$PCT" -lt 20 ]; then
			printf ""
		elif [ "$PCT" -lt 30 ]; then
			printf ""
		elif [ "$PCT" -lt 40 ]; then
			printf ""
		elif [ "$PCT" -lt 60 ]; then
			printf ""
		elif [ "$PCT" -lt 80 ]; then
			printf ""
		elif [ "$PCT" -lt 90 ]; then
			printf ""
		else
			printf ""
		fi
	else
		if [ "$PCT" -lt 10 ]; then
			printf ""
		elif [ "$PCT" -lt 20 ]; then
			printf ""
		elif [ "$PCT" -lt 30 ]; then
			printf ""
		elif [ "$PCT" -lt 40 ]; then
			printf ""
		elif [ "$PCT" -lt 50 ]; then
			printf ""
		elif [ "$PCT" -lt 60 ]; then
			printf ""
		elif [ "$PCT" -lt 70 ]; then
			printf ""
		elif [ "$PCT" -lt 80 ]; then
			printf ""
		elif [ "$PCT" -lt 90 ]; then
			printf ""
		else
			printf ""
		fi
	fi

	[ -z "$SXMO_BAR_HIDE_BAT_PER" ] && printf " %s%%" "$PCT"

	printf " "

	# Volume
	AUDIODEV="$(sxmo_audiocurrentdevice.sh)"
	AUDIOSYMBOL="$(printf %s "$AUDIODEV" | cut -c1)"
	if [ "$AUDIOSYMBOL" = "L" ] || [ "$AUDIOSYMBOL" = "N" ]; then
		printf "" #speakers or none, use no special symbol
	elif [ "$AUDIOSYMBOL" = "H" ]; then
		printf " "
	elif [ "$AUDIOSYMBOL" = "E" ]; then
		printf " " #earpiece
	fi
	VOL=0
	[ "$AUDIODEV" = "None" ] || VOL="$(
		amixer sget "$AUDIODEV" |
		grep -oE '([0-9]+)%' |
		tr -d ' %' |
		awk '{ s += $1; c++ } END { print s/c }'  |
		xargs printf %.0f
	)"
	if [ "$AUDIODEV" != "None" ]; then
		if [ "$VOL" -gt 66 ]; then
			printf ""
		elif [ "$VOL" -gt 33 ]; then
			printf ""
		elif [ "$VOL" -gt 0 ]; then
			printf ""
		elif [ "$VOL" -eq 0 ]; then
			printf "ﱝ"
		fi
	fi

	printf " %s\0" "$(date +%R)"
}

WM="$(sxmo_wm.sh)"

forceupdate() {
	kill "$SLEEPID"
}
trap "forceupdate" USR1

update() {
	BAR="$(bar)"
	[ -z "$SLEEPID" ] && return # to prevent mid rendering interuption
	printf %s "$BAR" | case "$WM" in
		sway|ssh) xargs -0 printf "%s\n";;
		dwm) xargs -0 xsetroot -name;;
	esac
}

while :
do
	sleep 10 &
	SLEEPID=$!

	update &
	UPDATEID=$!

	wait "$SLEEPID"
	unset SLEEPID
	wait "$UPDATEID"
done
