#!/bin/bash

#author: http://stackoverflow.com/questions/19151510/get-the-number-of-days-since-file-is-last-modified#answer-19151646

mod=0
if [ -f $1 ]; then
	mod=$(date -r $1 +%s)
fi
now=$(date +%s)          
days=$(expr \( $now - $mod \) )
printf $days
