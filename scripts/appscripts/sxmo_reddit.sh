#!/usr/bin/env sh
[ -z "$SXMO_SUBREDDITS" ] && SXMO_SUBREDDITS="pine64official pinephoneofficial unixporn postmarketos linux"

menu() {
	pidof svkbd-sxmo || svkbd-sxmo &
	SUBREDDIT="$(
		printf %b "$(echo "$SXMO_SUBREDDITS" | tr " " '\n')" |
		dmenu -p "Subreddit:" -c -l 10 -fn Terminus-20
	)"
	pkill svkbd-sxmo

	REDDITRESULTS="$(
		reddit-cli "$SUBREDDIT" |
			grep -E '^((created_utc|ups|title|url):|===)' |
			sed -E 's/^(created_utc|ups|title|url):\s+/\t/g' |
			tr -d '\n' | 
			sed 's/===/\n/g' | 
			sed 's/^\t//g' |
			sort -rk3,3 |
			awk -F'\t' '{ printf "↑%4s", $3; print " " $4 " " $1 " " $2 }'
	)"

	RESULT="$(
		echo "$REDDITRESULTS" | 
		dmenu -c -l 10 -fn Terminus-20
	)"

	[ "CLOSE_MENU" = "$RESULT" ] && exit 0
	URL=$(echo "$RESULT" | awk -F " " '{print $NF}')

	$BROWSER "$URL"
}

menu
