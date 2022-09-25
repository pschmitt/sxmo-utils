#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright 2022 Sxmo Contributors

# This script is executed after you received a text, mms, or vvm
# You can use it to play a notification sound or forward the sms elsewhere

# The following parameters are provided:
# $1 = Contact Name or Number (if number not in contacts)
# $2 = Text (or 'VVM' if a vvm)
# mms and vvm will include these parameters:
# $3 = MMS or VVM payload ID
# Finally, mms may include this parameter:
# $4 = Group Contact Name or Number (if number not in contacts)

# shellcheck source=scripts/core/sxmo_common.sh
. sxmo_common.sh

case "$(cat "$XDG_CONFIG_HOME"/sxmo/.ringmode)" in
	Mute)
		;;
	Vibrate)
		sxmo_vibrate 500
		;;
	Ring)
		mpv --no-resume-playback --quiet --no-video "$SXMO_TEXTSOUND" >/dev/null
		;;
	*) #Default: ring&vibrate
		mpv --no-resume-playback --quiet --no-video "$SXMO_TEXTSOUND" >/dev/null &
		sxmo_vibrate 500
		;;
esac
