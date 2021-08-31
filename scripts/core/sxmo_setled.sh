#!/bin/sh

usage () {
	printf "usage: %s [red|green|blue|white] [0-255]\n" "$0"
	exit 1
}

[ $# -lt 2 ] && usage

case "$(cut -d, -f2 < /sys/firmware/devicetree/base/compatible)" in
	l8910qcom) # bq-paella
		color="white"; type="kbd_backlight";;
	*) # assume pinephone/pinetab
		case $1 in
			red|green|blue) color="$1"; type="indicator" ;;
			white) color="$1"; type="flash" ;;
			*) usage ;;
		esac
		;;
esac

if [ "$2" -lt 0 ] || [ "$2" -gt 255 ]
then
	usage
fi

brightness="$2"

printf "%s\n" "$brightness" > "/sys/class/leds/$color:$type/brightness"