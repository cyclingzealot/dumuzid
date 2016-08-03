#!/usr/bin/env bash

START=$(date +%s.%N)

arg1=${1:-''}

if [[ $arg1 == '--help' || $arg1 == '-h' ]]; then
    echo "Script author should have provided documentation"
    exit 0
fi

#exit when command fails (use || true when a command can fail)
set -o errexit

#exit when your script tries to use undeclared variables
set -o nounset

# in scripts to catch mysqldump fails
set -o pipefail

# Resolve first directory of script
PRG="$BASH_SOURCE"
progname=`basename "$BASH_SOURCE"`

while [ -h "$PRG" ] ; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=`dirname "$PRG"`"/$link"
    fi
done

__dir=$(dirname "$PRG")


# Set magic variables for current file & dir
__root="$(cd "$(dirname "${__dir}")" && pwd)"           # Dir of the dir of the script
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"       # Full path of the script
__base="$(basename ${__file})"                          # Name of the script
ts=`date +'%Y%m%d-%H%M%S'`
ds=`date +'%Y%m%d'`
pid=`ps -ef | grep ${__base} | grep -v 'vi ' | head -n1 |  awk ' {print $2;} '`
formerDir=`pwd`

# If you require named arguments, see
# http://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

#Set the config file
configFile="$HOME/.${__base}.conf"




#=== END Unique instance ============================================


#Capture everything to log
mkdir -p ~/log
log=~/log/$__base-${ts}.log
exec >  >(tee -a $log)
exec 2> >(tee -a $log >&2)
touch $log
chmod 600 $log


#Check that the config file exists
if [[ ! -f "$configFile" ]] ; then
        echo "I need a file at $configFile with urls to test (as many as you like)" 
fi

export DISPLAY=:0

echo; echo; echo;

### BEGIN SCRIPT ###############################################################

#(a.k.a set -x) to trace what gets executed
set -o xtrace

sendAlert=0
body=''

if [[ ! -f $configFile ]]; then
	sendAlert=1
	body="No pages to test for $__base"
fi

for page in `cat $configFile | sort | uniq | sort -R | head -n 7`; do
	START=$(date +%s.%N)
	TH=5
	if ! curl -I -fs --max-time $TH $page | head -n 1 ; then
		END=$(date +%s.%N)
		DIFF=$(echo "$END - $START" | bc)
		sendAlert=1
		body="$page not loading or took $DIFF to load"
	fi
done

echo $body

exit $sendAlert

