#!/bin/sh
# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

stderr() {
	printf "sxmo_mms %s: %s\n" "$(date)" "$*" >&2
}

checkmmsd() {
	if [ -f "$HOME/.mms/modemmanager/mms" ]; then
		pgrep mmsdtng > /dev/null && return
		printf "%s: MMSDTNG not found, restarting it!\n" "$(date)" >> ~/mms.debug.log
		printf "sxmo_mms: mmsdtng not found, attempting to start it.\n" >&2
		setsid -f mmsdtng
		nmcli d disconnect cdc-wdm0
		nmcli d connect cdc-wdm0
	fi
}

# SXMO deletes each mms from the server once it is processed.
# However, sometimes things don't always go as planned.
# This function checks to see if there are mms on the server
# and processes them.
checkforlostmms() {
	ALL_MMS_TEMP="$(mktemp)"
	dbus-send --dest=org.ofono.mms --print-reply /org/ofono/mms/modemmanager org.ofono.mms.Service.GetMessages | grep "object path" | cut -d'"' -f2 | rev | cut -d'/' -f1 | rev | sort -u > "$ALL_MMS_TEMP"
	count="$(wc -l < "$ALL_MMS_TEMP")"
	if [ "$count" -gt 0 ]; then
		stderr "Found $count unprocessed messages! Processing them..."
		while read -r line; do
			stderr "Processing $line"
			processmms "/org/ofono/mms/modemmanager/$line" "Unknown"
		done < "$ALL_MMS_TEMP"
		stderr "Done!"
	else
		stderr "No outstanding messages. Done!"
	fi
	rm "$ALL_MMS_TEMP"
}

# stdout extracted mms file paths
extractmmsattachement() {
	jq -r '.attrs.Attachments[] | join(",")' | while read -r aline; do
		ACTYPE="$(printf %s "$aline" | cut -d',' -f2 | cut -d';' -f1 | sed 's|^Content-Type: "\(.*\)"$|\1|')"
		AOFFSET="$(printf %s "$aline" | cut -d',' -f4)"
		ASIZE="$(printf %s "$aline" | cut -d',' -f5)"
		case "$ACTYPE" in
			text/plain)
				DATA_EXT="txt"
				;;
			image/jpeg)
				DATA_EXT="jpeg"
				;;
			video/*)
				DATA_EXT="video"
				;;
			*)
				DATA_EXT="bin"
				;;
		esac

		if [ -f "$MMS_RECEIVED_DIR/$MMS_FILE" ]; then
			OUTFILE="$MMS_FILE.$DATA_EXT"
			count=0
			while [ -f "$LOGDIR/$LOGDIRNUM/attachments/$OUTFILE" ]; do
				OUTFILE="$MMS_FILE-$count.$DATA_EXT"
				count="$((count+1))"
			done
			dd skip="$AOFFSET" count="$ASIZE" \
				if="$MMS_RECEIVED_DIR/$MMS_FILE" \
				of="$LOGDIR/$LOGDIRNUM/attachments/$OUTFILE" \
				bs=1 >/dev/null 2>&1
		fi

		if [ "$ACTYPE" != "text/plain" ]; then
			printf "$icon_att %s\n" \
				"$(basename "$LOGDIR/$LOGDIRNUM/attachments/$OUTFILE")" \
				>> "$LOGDIR/$LOGDIRNUM/sms.txt"

			printf "%s\0" "$LOGDIR/$LOGDIRNUM/attachments/$OUTFILE"
		fi
	done
}

processmms() {
	MESSAGE_PATH="$1"
	MESSAGE_TYPE="$2" # Sent or Received or Unknown
	MESSAGE="$(mmsctl -M -o "$MESSAGE_PATH")"
	stderr "DEBUG: processmms MESSAGE_PATH: $MESSAGE_PATH MESSAGE_TYPE: $MESSAGE_TYPE"
	echo "$(date) MMS processmms $MESSAGE_PATH $MESSAGE_TYPE" >> ~/mms.debug.log

	# If a message expires on the server-side, just chuck it
	if printf %s "$MESSAGE" | grep -q "Accept-Charset (deprecated): Message not found"; then
		stderr "$MESSAGE_PATH not found! Deleting."
		dbus-send --dest=org.ofono.mms --print-reply "$MESSAGE_PATH" org.ofono.mms.Message.Delete
		return
	fi

	# Unknown is what checkforlostmms() sends.
	if [ "$MESSAGE_TYPE" = "Unknown" ]; then
		MESSAGE_STATUS="$(printf %s "$MESSAGE" | jq -r '.attrs.Status')"
		case "$MESSAGE_STATUS" in
			sent)
				MESSAGE_TYPE="Sent"
				;;
			draft)
				stderr "Deleting draft ($MESSAGE_PATH)."
				dbus-send --dest=org.ofono.mms --print-reply "$MESSAGE_PATH" org.ofono.mms.Message.Delete
				return
				;;
			received)
				MESSAGE_TYPE="Received"
				;;
			*)
				stderr "Bad message type '$MESSAGE_TYPE' ($MESSAGE_PATH)."
				return
				;;
		esac
	fi

	MMS_FILE="$(printf %s "$MESSAGE_PATH" | rev | cut -d'/' -f1 | rev)"
	DATE="$(printf %s "$MESSAGE" | jq -r '.attrs.Date')"

	MYNUM="$(printf %s "$MESSAGE" | jq -r '.attrs."Modem Number"')"
	if [ -z "$MYNUM" ]; then
		MYNUM="$(sxmo_contacts.sh --me)"
		if [ -z "$MYNUM" ]; then
			stderr "We cannot determine the modem number." 
			stderr "Configure the Me contact."
			stderr "Using a fake number in the meanwhile: +12345670000."
			MYNUM="+12345670000"
		fi
	fi

	if [ "$MESSAGE_TYPE" = "Sent" ]; then
		FROM_NUM="$MYNUM"
	elif [ "$MESSAGE_TYPE" = "Received" ]; then
		FROM_NUM="$(printf %s "$MESSAGE" | jq -r '.attrs.Sender')"
	fi

	FROM_NAME="$(sxmo_contacts.sh --name "$FROM_NUM")"
	TO_NUMS="$(printf %s "$MESSAGE" | jq -r '.attrs.Recipients | join("\n")')"
	# generate string of contact names, e.g., "BOB, SUZIE, SAM"
	TO_NAMES="$(printf %s "$TO_NUMS" | xargs -n1 sxmo_contacts.sh --name | tr '\n' '\0' | xargs -0 printf "%s, " | sed 's/, $//')"

	count="$(printf "%s" "$TO_NUMS" | wc -l)"
	if [ "$count" -gt 0 ]; then
		# a group chat.  LOGDIRNUM = all numbers except one's own, sorted numerically
		LOGDIRNUM="$(printf "%b\n%s\n" "$TO_NUMS" "$FROM_NUM" | grep -v "^$MYNUM$" | sort -u | grep . | xargs printf %s)"
		mkdir -p "$LOGDIR/$LOGDIRNUM"
		printf "%s Group MMS from %s to %s at %s:\n" "$MESSAGE_TYPE" "$FROM_NAME" "$TO_NAMES" "$DATE" >> "$LOGDIR/$LOGDIRNUM/sms.txt"
	else
		# not a group chat
		if [ "$MESSAGE_TYPE" = "Sent" ]; then
			LOGDIRNUM="$TO_NUMS"
		elif [ "$MESSAGE_TYPE" = "Received" ]; then
			LOGDIRNUM="$FROM_NUM"
		fi
		mkdir -p "$LOGDIR/$LOGDIRNUM"
		printf "%s MMS from %s at %s:\n" "$MESSAGE_TYPE" "$FROM_NAME" "$DATE" >> "$LOGDIR/$LOGDIRNUM/sms.txt"
	fi
	stderr "$MESSAGE_TYPE MMS ($MMS_FILE) from number $FROM_NUM to number $TO_NUMS"

	mkdir -p "$LOGDIR/$LOGDIRNUM/attachments"

	if [ "$MESSAGE_TYPE" = "Received" ]; then
		printf "%s\trecv_mms\t%s\t%s\n" "$DATE" "$LOGDIRNUM" "$MMS_FILE" >> "$LOGDIR/modemlog.tsv"
		printf "%s\trecv_mms\t%s\t%s\n" "$DATE" "$LOGDIRNUM" "$MMS_FILE" >> ~/mms.debug.log
	elif [ "$MESSAGE_TYPE" = "Sent" ]; then
		printf "%s\tsent_mms\t%s\t%s\n" "$DATE" "$LOGDIRNUM" "$MMS_FILE" >> "$LOGDIR/modemlog.tsv"
		printf "%s\tsent_mms\t%s\t%s\n" "$DATE" "$LOGDIRNUM" "$MMS_FILE" >> ~/mms.debug.log
	fi

	# process 'content' of mms payload
	OPEN_ATTACHMENTS_CMD="$(printf %s "$MESSAGE" | extractmmsattachement | xargs -0 printf "sxmo_open.sh '%s'; " | sed "s/sxmo_open.sh ''; //")"
	if [ -f "$LOGDIR/$LOGDIRNUM/attachments/$MMS_FILE.txt" ]; then
		TEXT="$(cat "$LOGDIR/$LOGDIRNUM/attachments/$MMS_FILE.txt")"
		rm -f "$LOGDIR/$LOGDIRNUM/attachments/$MMS_FILE.txt"
	else
		TEXT="<Empty>"
	fi

	printf "%b\n\n" "$TEXT" >> "$LOGDIR/$LOGDIRNUM/sms.txt"

	if [ "$MESSAGE_TYPE" = "Received" ]; then
		[ -n "$OPEN_ATTACHMENTS_CMD" ] && TEXT="$icon_att $TEXT"
		[ "$FROM_NAME" = "???" ] && FROM_NAME="$FROM_NUM"
		sxmo_notificationwrite.sh \
			random \
			"${OPEN_ATTACHMENTS_CMD}sxmo_modemtext.sh tailtextlog \"$LOGDIRNUM\"" \
			"$LOGDIR/$LOGDIRNUM/sms.txt" \
			"$FROM_NAME: $TEXT ($MMS_FILE)"

		if [ "$count" -gt 0 ]; then
			GROUPNAME="$(sxmo_contacts.sh --name "$LOGDIRNUM")"
			[ "$GROUPNAME" = "???" ] && GROUPNAME="$LOGDIRNUM"
			sxmo_hooks.sh sms "$FROM_NAME <$GROUPNAME>" "$TEXT ($MMS_FILE)"
		else
			sxmo_hooks.sh sms "$FROM_NAME" "$TEXT ($MMS_FILE)"
		fi
	fi

	if [ "$MMS_AUTO_DELETE" -eq 1 ]; then
		dbus-send --dest=org.ofono.mms --print-reply "$MESSAGE_PATH" org.ofono.mms.Message.Delete
		stderr "Deleting $MESSAGE_PATH..."
	fi
}

"$@"
