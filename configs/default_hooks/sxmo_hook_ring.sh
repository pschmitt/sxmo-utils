#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# This script is executed (asynchronously) when you get an incoming call
# You can use it to play a ring tone

# $1 = Contact Name or Number (if not in contacts)

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

# Only vibrate if you already got an active call
if sxmo_modemcall.sh list_active_calls \
	| grep -v ringing-in \
	| grep -q .; then
	sxmo_vibrate 1500
	exit
fi

# Shallow if you have more than one ringing call
if ! sxmo_modemcall.sh list_active_calls \
	| grep -c ringing-in \
	| grep -q 1; then
	exit
fi

# RING & VIBRATE MODE (DEFAULT)
if [ ! -f "$XDG_CONFIG_HOME"/sxmo/.noring ] && [ ! -f "$XDG_CONFIG_HOME"/sxmo/.novibrate ]; then
	sxmo_log "RING AND VIBRATE"

	# In order for this to work, you will need to install playerctl and run playerctld
	# In order for this to work with mpv, you will need to install mpv-mdis.
	sxmo_playerctl.sh pause_all

	timeout "$SXMO_RINGTIME" mpv --no-resume-playback --quiet --no-video \
		--loop="$SXMO_RINGNUMBER" "$SXMO_RINGTONE" >/dev/null &
	MPVID=$!
	echo "$MPVID" > "$XDG_RUNTIME_DIR/sxmo.ring.pid"
	# vibrate while mpv is running
	while kill -0 $MPVID; do
		sxmo_vibrate 1500
		sleep 0.5
	done

# RING-ONLY MODE
elif [ ! -f "$XDG_CONFIG_HOME"/sxmo/.noring ] && [ -f "$XDG_CONFIG_HOME"/sxmo/.novibrate ]; then
	sxmo_log "RING ONLY"

	# In order for this to work, you will need to install playerctl and run playerctld
	# In order for this to work with mpv, you will need to install mpv-mdis.
	sxmo_playerctl.sh pause_all

	timeout "$SXMO_RINGTIME" mpv --no-resume-playback --quiet --no-video \
		--loop="$SXMO_RINGNUMBER" "$SXMO_RINGTONE" >/dev/null &
	echo "$!" > "$XDG_RUNTIME_DIR/sxmo.ring.pid"

# VIBRATE-ONLY MODE
elif [ ! -f "$XDG_CONFIG_HOME"/sxmo/.novibrate ] && [ -f "$XDG_CONFIG_HOME"/sxmo/.noring ]; then
	smxo_log "VIBRATE ONLY"
	for _ in $(seq 5); do
		sxmo_vibrate 1500
		sleep 0.5
	done &
	echo "$!" > "$XDG_RUNTIME_DIR/sxmo.ring.pid"
fi
