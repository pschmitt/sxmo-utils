#!/bin/sh

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

applyptrmatrix() {
	[ -n "$SXMO_TOUCHSCREEN_ID" ] && xinput set-prop "$SXMO_TOUCHSCREEN_ID" --type=float --type=float "Coordinate Transformation Matrix" "$@"
	[ -n "$SXMO_STYLUS_ID" ] && xinput set-prop "$SXMO_STYLUS_ID" --type=float --type=float "Coordinate Transformation Matrix" "$@"
}

swayfocusedtransform() {
	swaymsg -t get_outputs | jq -r '.[] | select(.focused == true) | .transform'
}

swayfocusedname() {
	swaymsg -t get_outputs | jq -r '.[] | select(.focused == true) | .name'
}

xorgisrotated() {
	rotation="$(
		xrandr | grep primary | cut -d' ' -f 5 | sed s/\(//
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

swayisrotated() {
	rotation="$(
		swayfocusedtransform | sed -e s/90/right/ -e s/270/left/ -e s/180/reverse/
	)"
	if [ "$rotation" = "normal" ]; then
		return 1;
	fi
	printf %s "$rotation"
	return 0;
}

xorgrotnormal() {
	sxmo_keyboard.sh close
	xrandr -o normal
	applyptrmatrix 0 0 0 0 0 0 0 0 0
	sxmo_hook_lisgdstart.sh &
	sxmo_hook_rotate.sh normal
	exit 0
}

swayrotnormal() {
	swaymsg -- output "-" transform 0
	focused_name="$(swayfocusedname)"
	swaymsg -- input type:touch map_to_output "$focused_name"
	swaymsg -- input type:tablet_tool map_to_output "$focused_name"
	sxmo_hook_lisgdstart.sh &
	sxmo_hook_rotate.sh normal
	exit 0
}

xorgrotright() {
	sxmo_keyboard.sh close
	xrandr -o right
	applyptrmatrix 0 1 0 -1 0 1 0 0 1
	sxmo_hook_lisgdstart.sh &
	sxmo_hook_rotate.sh right
	exit 0
}

swayrotright() {
	swaymsg -- output "-" transform 90
	focused_name="$(swayfocusedname)"
	swaymsg -- input type:touch map_to_output "$focused_name"
	swaymsg -- input type:tablet_tool map_to_output "$focused_name"
	sxmo_hook_lisgdstart.sh &
	sxmo_hook_rotate.sh right
	exit 0
}

xorgrotleft() {
	sxmo_keyboard.sh close
	xrandr -o left
	applyptrmatrix 0 -1 1 1 0 0 0 0 1
	sxmo_hook_lisgdstart.sh &
	sxmo_hook_rotate.sh left
	exit 0
}

swayrotleft() {
	swaymsg -- output "-" transform 270
	focused_name="$(swayfocusedname)"
	swaymsg -- input type:touch map_to_output "$focused_name"
	swaymsg -- input type:tablet_tool map_to_output "$focused_name"
	sxmo_hook_lisgdstart.sh &
	sxmo_hook_rotate.sh left
	exit 0
}

isrotated() {
	case "$SXMO_WM" in
		sway)
			"swayisrotated"
			;;
		dwm)
			"xorgisrotated"
			;;
	esac
}

if [ -z "$1" ] || [ "rotate" = "$1" ]; then
	shift
	if isrotated; then
		set -- rotnormal "$@"
	else
		set -- rotright "$@"
	fi
fi

case "$SXMO_WM" in
	sway)
		"sway$1" "$@"
		;;
	dwm)
		"xorg$1" "$@"
		;;
esac
