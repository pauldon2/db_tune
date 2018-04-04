#!/bin/bash

# We want "OK" result to be green
echo_success() {
	echo -e "\033[70G[\033[1;32m OK \033[0;39m]"
}

# We want "FAIL" result to be red
echo_failure() {
	echo -e "\033[70G[\033[1;31m FAIL \033[0;39m]"
}



#PGDATA=/etc/postgresql/10/main
PGDATA=/root

# Find out, how much RAM can we use for tuning
DB_RAM=$(( `grep MemTotal /proc/meminfo | awk '{print $2}'` / 1024 - 512 ))
KERNEL_SHM=$DB_RAM


tunedb() {
	echo
	echo -n "Optimizing PostgreSQL configuration"
	if [[ ! -f $PGDATA/postgresql.conf ]]
	then
		echo_failure
		SCRIPT_RESULT=1
		echo
		echo -en "\033[0G[\033[1;31m Attention \033[0;39m]"
		echo "Can't find postgresql.conf at /etc/postgresql/10/main/"
		echo "It seems that database isn't initialized"
		echo "Try executing $0 initdb first"
	else
		PG_CONF=$PGDATA/postgresql.conf

	cp $PG_CONF $PG_CONF-`date +%Y-%m-%d_%Hh%Mm`
#	cp $PGHOME/share/postgresql/postgresql.conf.sample $PG_CONF
#	chown postgres:postgres $PG_CONF
#	chmod 600 $PG_CONF

		SHARED_BUFFERS=$(( DB_RAM / 5 * 3 ))
		sed -i "s/shared_buffers = 128MB/shared_buffers = ${SHARED_BUFFERS}MB/g" $PG_CONF

		MAX_CONNECTIONS=`grep "max_connections =" "$PG_CONF" | awk '{print $3}'`

		WORK_MEM=$(( DB_RAM * 1024 / MAX_CONNECTIONS / 2 ))
		sed -i "s/#work_mem = 4MB/work_mem = ${WORK_MEM}kB/g" $PG_CONF

		MAX_PREP_TRANS=$(( MAX_CONNECTIONS / 10 ))
		sed -i "s/#max_prepared_transactions = 0/max_prepared_transactions = ${MAX_PREP_TRANS}/g" $PG_CONF

		MAINTENANCE_WORK_MEM=$(( DB_RAM / 16 ))
		if [[ $MAINTENANCE_WORK_MEM -lt 256 ]]
		then
		MAINTENANCE_WORK_MEM=256
		fi
		sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = ${MAINTENANCE_WORK_MEM}MB/g" $PG_CONF

		MAX_STACK_DEPTH=$(( `ulimit -s` - 512 ))
		sed -i "s/#max_stack_depth = 2MB/max_stack_depth = ${MAX_STACK_DEPTH}kB/g" $PG_CONF

		EFFECTIVE_CACHE_SIZE=$(( DB_RAM / 4 * 3 ))
		sed -i "s/#effective_cache_size = 4GB/effective_cache_size = ${EFFECTIVE_CACHE_SIZE}MB/g" $PG_CONF

		TIMEZONE=`cat /etc/timezone 2>/dev/null`
		sed -i "s!GMT!$TIMEZONE!g" $PG_CONF

		echo_success
		echo
		echo -en "\033[0G[\033[1;32m Attention \033[0;39m]"
		echo " /etc/postgresql/10/main/postgresql.conf had been optimized"
		echo "Changes will take effect after configuration is reloaded"
	fi
}
