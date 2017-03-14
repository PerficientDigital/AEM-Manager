#!/bin/bash

# a script to make it easier for developers to start multiple AEM instances

# Default Settings
instance=default
root=~/dev/aem
publish=
debug="true"
gui=-gui
vmargs="-Xmx2g -XX:MaxPermSize=512m"
debugport=30303
jmxport=9999
port=4502
action="start"


function help
{
	usage
	echo ""
	echo "---Actions---"
	echo " compact - compacts the oak repository"
	echo " reset   - deletes the contents of the crx-quickstart folder"
	echo " start   - Starts the specified AEM"
	echo " stop    - stops the specified AEM instance"
	echo ""
	echo "---Parameters---"
	echo "-i  | --instance - Sets the AEM instance to use, will be a sub-folder of the root folder"
	echo "-vm | --vm-args  - Arguments passed to the JVM"
	echo "-r  | --root     - Sets root directory under which the script will look for AEM instances"
	echo "-p  | --publish  - Starts publish instances.  These instances are assumed to be folders under the root with names like [instance]-publish-[NN] or [instance]-publish"
	echo "-ng | --no-gui   - Flag for not starting AEM's GUI"
	echo "-nd | --no-debug - Flag for not starting AEM in debug mode"
	echo "-h  | --help     - Displays this message"
}

function compact
{
	today="$(date +'%d-%m-%Y')"
	repodir="$aemdir/crx-quickstart/repository"
	oakrun="$aemdir/help/oak-run-*.jar"
	logfile="$aemdir/help/logs/compact-$today.log"
	
	mkdir -p $aemdir/help/logs
	
	repospace=$(du -hs $repodir)
	echo "Pre-compaction repository size: ${repospace}..."
	
	echo "Finding old checkpoints..."
	java -jar $oakrun checkpoints $repodir/segmentstore >> $logfile

	echo "Deleting unreferenced checkpoints..."
	java -jar $oakrun checkpoints $repodir/segmentstore rm-unreferenced >> $logfile
	
	echo "Running compaction. This may take a while..."
	java -jar $oakrun compact $repodir/segmentstore >> $logfile

	echo "Compaction complete. Please check the log at: $logfile"
	
	repospace=$(du -hs $repodir)
	echo "Post-compaction repository size: ${repospace}..."
}

function resetaem
{
	echo "Clearing AEM repository at $aemdir"
	rm -rf $aemdir/crx-quickstart
	echo "Repository successfully cleared"
}

function startaem
{
	aemjar=$(ls $aemdir | grep -m 1 ^.*aem.*\.jar$)
    if [ "$aemjar" = "" ]; then
        aemjar=$(ls $aemdir | grep -m 1 ^.*cq.*\.jar$)
    fi
    if [ "$aemjar" = "" ]; then
        echo "No AEM JAR found in $aemdir"
        exit 1
    fi
    
	cd $aemdir
	echo "Clearing logs"
	rm -f $aemdir/crx-quickstart/logs/*
	mkdir -p $aemdir/crx-quickstart/logs
	mkdir -p $aemdir/crx-quickstart/conf
	echo "Starting AEM instance $instance"
	echo "Using JAR $aemjar"
	if [ "$debug" = "true" ]; then
		echo "Using Debug Port $debugport"
		echo "Using JMX Port $jmxport"
		java -Xdebug $vmargs -Xrunjdwp:transport=dt_socket,server=y,address=$debugport,suspend=n -Dcom.sun.management.jmxremote.port=$jmxport -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -jar $aemjar $gui -nofork -port $port &
		echo $! > $aemdir/crx-quickstart/conf/cq.pid
	else
		java $vmargs -jar $aemjar $gui -nofork -port $port &
		echo $! > $aemdir/crx-quickstart/conf/cq.pid
	fi
    echo "AEM Instance $instance Started Successfully!"
}

function stopaem
{
	echo "Stopping AEM"
	$aemdir/crx-quickstart/bin/stop
	echo "AEM Stop Command Issued Successfully"
}

function usage
{
	echo "usage: aem-mgr [start|stop|reset|compact] [-i aem-instance] [-r root-path] [-p] [-vm '-Xmx2g'] [-nd]"
}


# Parse the command line arguments from the parameters
while [ "$1" != "" ]; do
	case $1 in
		-i | --instance )		shift
								instance=$1
								;;
		-vm | --vm-args )		shift
								vmargs=$1
								;;
		-r | --root )	        shift
								root=$1
								;;
		-p | --publish )		publish="1"
								;;
		-ng | --no-gui )		gui=
								;;
		-nd | --no-debug )		debug="false"
								;;
		-h | --help )		    help
								exit
								;;
		compact )				action="compact"
								;;
		reset )					action="reset"
								;;
		start )					action="start"
								;;
		stop )					action="stop"
								;;
		* )						usage
								exit 1
	esac
	shift
done

# Perform the actions
if [ "$action" = "compact" ]; then
	aemdir=$root/$instance
	compact
	if [ "$publish" = "1" ]; then
		ls $root | grep ^$instance-publish.*$ | while read pub
		do
			aemdir=$root/$pub
			compact
		done
	fi
elif [ "$action" = "start" ]; then
	aemdir=$root/$instance
	startaem
	if [ "$publish" = "1" ]; then
		ls $root | grep ^$instance-publish.*$ | while read pub
		do
			debugport=$(expr $debugport + 1)
			jmxport=$(expr $jmxport + 1)
			port=$(expr $port + 1)
			jmxport=$(expr $jmxport + 1)
			aemdir=$root/$pub
			startaem
		done
	fi
elif [ "$action" = "reset" ] ; then
	aemdir=$root/$instance
	resetaem
	if [ "$publish" = "1" ]; then
		ls $root | grep ^$instance-publish.*$ | while read pub
		do
				aemdir=$root/$pub
				resetaem
		done
	fi
elif [ "$action" = "stop" ] ; then
	aemdir=$root/$instance
	stopaem
	if [ "$publish" = "1" ]; then
		ls $root | grep ^$instance-publish.*$ | while read pub
		do
				
				aemdir=$root/$pub
				stopaem
		done
	fi
fi
