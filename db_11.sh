#!/bin/bash

if [ -n "$1" ]
then
	MAX_CONNECTIONS=$1
else
	MAX_CONNECTIONS=100
fi

# We want "OK" result to be green
echo_success() {
	echo -e "\033[70G[\033[1;32m OK \033[0;39m]"
}

# We want "FAIL" result to be red
echo_failure() {
	echo -e "\033[70G[\033[1;31m FAIL \033[0;39m]"
}


# Find out, how much RAM can we use for tuning
DB_RAM=$(( `grep MemTotal /proc/meminfo | awk '{print $2}'` / 1024 - 512 ))


tunedb() {
	echo
	echo -n "Optimizing PostgreSQL configuration"


	version=$(ls /etc/postgresql | awk '{print $0}')
	echo "$version"
	PGDATA=/etc/postgresql/$version/main
	PG_CONF=$PGDATA/postgresql.conf

	if [[ ! -f $PG_CONF ]]
	then
		echo_failure
		SCRIPT_RESULT=1
		echo
		echo -en "\033[0G[\033[1;31m Attention \033[0;39m]"
		echo "Can't find $PG_CONF_ORG "
		echo "It seems that database isn't initialized"
		echo "Try executing $0 initdb first"
	else
	        cp $PG_CONF $PG_CONF-`date +%Y-%m-%d_%Hh%Mm`


		sed -i -E "s/^#?max_connections = [0-9]*/max_connections = ${MAX_CONNECTIONS}/" $PG_CONF

		SHARED_BUFFERS=$(( DB_RAM / 5 * 3 ))
		sed -i -E "s/^#?shared_buffers = [0-9]*[a-zA-Z]*/shared_buffers = ${SHARED_BUFFERS}MB/" $PG_CONF

		WORK_MEM=$(( DB_RAM * 1024 / MAX_CONNECTIONS / 2 ))
		sed -i -E "s/^#?work_mem = [0-9]*[a-zA-Z]*/work_mem = ${WORK_MEM}kB/" $PG_CONF

		MAX_PREP_TRANS=$(( MAX_CONNECTIONS / 10 ))
		sed -i -E "s/^#?max_prepared_transactions = [0-9]*[a-zA-Z]*/max_prepared_transactions = ${MAX_PREP_TRANS}/" $PG_CONF

		MAINTENANCE_WORK_MEM=$(( DB_RAM / 16 ))
		if [[ $MAINTENANCE_WORK_MEM -lt 256 ]]
		then
		MAINTENANCE_WORK_MEM=256
		fi
		sed -i -E "s/^#?maintenance_work_mem = [0-9]*[a-zA-Z]*/maintenance_work_mem = ${MAINTENANCE_WORK_MEM}MB/" $PG_CONF

		MAX_STACK_DEPTH=$(( `ulimit -s` - 512 ))
		sed -i -E "s/^#?max_stack_depth = [0-9]*[a-zA-Z]*/max_stack_depth = ${MAX_STACK_DEPTH}kB/" $PG_CONF

		EFFECTIVE_CACHE_SIZE=$(( DB_RAM / 4 * 3 ))
		sed -i -E "s/^#?effective_cache_size = [0-9]*[a-zA-Z]*/effective_cache_size = ${EFFECTIVE_CACHE_SIZE}MB/" $PG_CONF

	
		TIMEZONE=`cat /etc/timezone 2>/dev/null`
		sed -i "s!GMT!$TIMEZONE!g" $PG_CONF

		echo_success
		echo
		echo -en "\033[0G[\033[1;32m Attention \033[0;39m]"
		echo " /etc/postgresql/10/main/postgresql.conf had been optimized"
		echo "Changes will take effect after configuration is reloaded"
	fi
}

tunedb
