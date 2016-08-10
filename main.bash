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
configFile="$HOME/.dumuzid.conf"

#=== BEGIN Unique instance ============================================
#Ensure only one copy is running
pidfile=$HOME/.${__base}.pid
if [ -f ${pidfile} ]; then
   #verify if the process is actually still running under this pid
   oldpid=`cat ${pidfile}`
   result=`ps -ef | grep ${oldpid} | grep ${__base} || true`

   if [ -n "${result}" ]; then
     echo "Script already running! Exiting"
     exit 255
   fi
fi

#grab pid of this process and update the pid file with it
echo ${pid} > ${pidfile}

# Create trap for lock file in case it fails
trap "rm -f $pidfile" INT QUIT TERM ERR
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
        echo "I need a file at $configFile with an email address to warn"
        exit 1
fi

export DISPLAY=:0

echo Begin `date`  .....

echo; echo; echo;

### BEGIN SCRIPT ###############################################################

#(a.k.a set -x) to trace what gets executed
set -o xtrace

recipient=`cat $configFile`
hostname=`hostname`
scratchFile=/tmp/dumuzid.scratch
echo > $scratchFile

if [[ ! -f $__dir/dontRun.txt ]]; then
    touch $__dir/dontRun.txt
fi

sendAlert=0
echo > $scratchFile
for script in $__dir/*.bash ; do
    localAlert=0
    bn=`basename $script`
    if [[ "$bn" == "$__base" ]] || grep $bn $__dir/dontRun.txt; then
	continue
    fi
    $script > $scratchFile.one || localAlert=1

    if [ "$localAlert" -eq "1" ] ; then
	sendAlert=1
	echo >> $scratchFile.one
	~/bin/headline.bash "$script raised an alert" >> $scratchFile.one
	echo >> $scratchFile.one
	cat $scratchFile.one >> $scratchFile
    fi


done

if [ "$sendAlert" -eq "1" ] ; then
    subject="Alerts on `hostname`"
    echo  >> $scratchFile
    echo "Running on `hostname` by user `whoami`" >> $scratchFile
    cat $scratchFile
    if ~/bin/flagger.bash dumuzid 3600; then
        cat $scratchFile | mail -s "$subject" $recipient
    else
	echo "Too early to send another notice"
    fi
else
    ~/bin/flagger.bash dumuzid -1
    echo "No errors detected"
fi

set +x

### END SCIPT ##################################################################

cd $formerDir

END=$(date +%s.%N)
DIFF=$(echo "($END - $START)" | bc)
echo; echo; echo;
echo Done.  `date` - $DIFF seconds

#=== BEGIN Unique instance ============================================
if [ -f ${pidfile} ]; then
    rm ${pidfile}
fi
#=== END Unique instance ============================================
