#!/bin/sh

VIBS=5
VIBI=0
while [ $VIBI -lt $VIBS ]; do
	sxmo_vibrate 400 &
	sleep 0.5
	VIBI=$(echo $VIBI+1 | bc)
done