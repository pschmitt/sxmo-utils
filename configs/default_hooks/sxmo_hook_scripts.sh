#!/bin/sh

# This script will output the content of the scripts menu

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(which sxmo_common.sh)"
# shellcheck source=configs/default_hooks/sxmo_hook_icons.sh
. sxmo_hook_icons.sh

write_line() {
	printf "%s ^ 0 ^ %s\n" "$1" "$2"
}

get_title() {
	title=""
	# Process substitution because source won't work with data piped from stdin.
	source <(head "$1" | grep '# title="[^\\"]*"' | sed 's/^# //g')
	if [ -n "$title" ]; then
		echo "$title"
	else
		basename="$(basename "$1")"
		echo "$icon_itm $basename"
	fi
}

if [ -f "$XDG_CONFIG_HOME/sxmo/userscripts" ]; then
	cat "$XDG_CONFIG_HOME/sxmo/userscripts"
elif [ -d "$XDG_CONFIG_HOME/sxmo/userscripts" ]; then
	find "$XDG_CONFIG_HOME/sxmo/userscripts" -type f -o -type l | sort -f | while read script; do
		title="$(get_title "$script")"
		write_line "$title" "$script"
	done
fi

write_line "$icon_cfg Edit Userscripts" "sxmo_terminal.sh $EDITOR $XDG_CONFIG_HOME/sxmo/userscripts/*"

# System Scripts
find /usr/share/sxmo/appscripts -type f -o -type l | sort -f | while read script; do
	title="$(get_title "$script")"
	write_line "$title" "$script"
done
