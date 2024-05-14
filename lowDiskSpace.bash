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
ignoreFile="$HOME/.${__base}.ignoreMountPoints.conf"
thresholdFile="$HOME/.${__base}.thresholdMountPoints.conf"

#=== END Unique instance ============================================


#Capture everything to log
mkdir -p ~/log
log=~/log/$__base-${ts}.log
exec >  >(tee -a $log)
exec 2> >(tee -a $log >&2)
touch $log
chmod 600 $log


#Check that the config file exists
if [[ ! -f "$ignoreFile" ]] ; then
        echo "You can have a file at $ignoreFile with a list of mountpoints to ignore"
fi

if [[ ! -f "$thresholdFile" ]] ; then
        echo "You can have a file at $thresholdFile with a list of thresholds for each mountpoint.  One per line, with threshold seperated by |"
fi

export DISPLAY=:0

echo; echo; echo;

### BEGIN SCRIPT ###############################################################

#(a.k.a set -x) to trace what gets executed
#set -o xtrace

hostname=`hostname`

sendAlert=0
body=''
IFS=$'\n'; for mount in `df`; do
    echo === $mount =========================================================================================
    if echo $mount | grep 'Filesystem\|fichiers' ; then
        continue
    fi

    CURRENT=$(echo $mount | awk '{ print $5}' | sed 's/%//g')
    mountPoint=$(echo $mount | awk '{ print $6}' | sed 's/%//g')
    filesystem=$(echo $mount | awk '{ print $1}' | sed 's/%//g')
    threshold=90

    if [[ -f "$ignoreFile" ]] && grep "^${mountPoint}$" $ignoreFile ; then
        echo "Ignoring $mountPoint"
        continue
    fi

    if [[ -f "$thresholdFile" ]] && grep "^${mountPoint}|" $thresholdFile ; then
      threshold=`grep "^${mountPoint}|" $thresholdFile | cut -d'|' -f 2`
      echo "Using threshold $threshold for $mountPoint"
    fi

    if [[ $(date +%u) -gt 5 ]] || [[ $(date +%_H) -lt 10 ]] || [[ $(date +%_H) -gt 18 ]] ; then
      let threshold+=5
    fi

    if [[ "$CURRENT" -gt "$threshold" ]] ; then
        sendAlert=1
        body=`echo -e "${body}
Your $mountPoint ($filesystem) partition remaining free space on $hostname is used at $CURRENT% \\n"`
    else
        echo $mountPoint $CURRENT OK.
    fi
done

echo $body

exit $sendAlert

