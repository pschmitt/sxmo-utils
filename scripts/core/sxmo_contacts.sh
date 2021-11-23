#!/usr/bin/env sh
# This script prints in reverse chronological order unique entries from the
# modem log merged with contact names defined in contacts file tsv.
#   Wherein $CONTACTSFILE is tsv with two fields: number\tcontact name
#   Wherein $LOGFILE is *sorted* tsv with three fields: date\tevt\tnumber
#
#   Most normal numbers should be a full phone number starting with + and the country number
#   Some special numbers (ie. 2222, "CR AGRICOLE") can ignore this pattern
#
# Prints in output format: "number: contact"

# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

CONTACTSFILE="$XDG_CONFIG_HOME"/sxmo/contacts.tsv
LOGFILE="$XDG_DATA_HOME"/sxmo/modem/modemlog.tsv

prepare_contacts_list() {
	cut -f3 |
	tac |
	awk '!($0 in a){a[$0]; print}' |
	sed '/^[[:space:]]*$/d' |
	awk -F '\t' -v CONTACTSFILE="$CONTACTSFILE" '
		FILENAME == CONTACTSFILE {
			if (!length) next;
			a[$1] = $2;
			next
		}
		{
			if (!a[$1]) a[$1] = "???";
			print a[$1] ": " $0
		}
	' "$CONTACTSFILE" -
}

contacts() {
	prepare_contacts_list < "$LOGFILE"
}

texted_contacts() {
	grep "\(recv\|sent\)_\(txt\|mms\)" "$LOGFILE" | prepare_contacts_list
}

called_contacts() {
	grep "call_\(pickup\|start\)" "$LOGFILE" | prepare_contacts_list
}

all_contacts() {
	awk -F'\t' '{
		print $2 ": " $1
	}' "$CONTACTSFILE" | sort -f -k 1
}

unknown_contacts() {
	contacts \
		| grep "^???" \
		| cut -d: -f2 \
		| grep "^ +[0-9]\{9,14\}" \
		| sed 's/^ //'
}

[ -f "$CONTACTSFILE" ] || touch "$CONTACTSFILE"

if [ "$1" = "--all" ]; then
	all_contacts
elif [ "$1" = "--unknown" ]; then
	unknown_contacts
elif [ "$1" = "--texted" ]; then
	texted_contacts
elif [ "$1" = "--called" ]; then
	called_contacts
elif [ "$1" = "--me" ]; then
	all_contacts \
		| grep "^Me: " \
		| sed 's|^Me: ||'
elif [ "$1" = "--name" ]; then
	if [ -z "$2" ]; then
		printf "???\n"
	else
		all_contacts \
			| xargs -0 printf "???: %s\n%b" "$2" \
			| tac \
			| grep -m1 ": $2$" \
			| sed -e 's/\(.*\):\(.*\)/\1/' -e 's/^[ \t]*//;s/[ \t]*$//'
	fi
elif [ -n "$*" ]; then
	all_contacts | grep -i "$*"
else
	contacts
fi
