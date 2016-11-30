#!/usr/bin/env bash

# import utils
source /usr/local/bin/stats_utils.sh

# print usage
function print_usage(){
    echo -e "\nUsage: entrypoint.sh [OPTIONS] [LOCUST_OPTIONS]"
    echo -e   "                [-s|--setup-script FILE [SETUP_SCRIPT_ARGS]]"
    echo -e "\n       OPTIONS: \n"
    echo -e "\t  -d | --daemon           run as daemon"
    echo -e "\t  -w | --web-app          URL of the Web Application to test"
    echo -e "\t  -s | --setup-script     a bash script executed before Locust"
    echo -e "\t  --influxdb              <HOST>:<PORT> of the InfluxDB instance (default 'localhost:8086')"
    echo -e "\t  -h|--help               "
}

# telegraf hostname
TELEGRAF_HOSTNAME=$(hostname)

# set default influxDB
INFLUXDB_URL="localhost:8086"

# parse arguments
while [ -n "$1" ]; do
        # Copy so we can modify it (can't modify $1)
        OPT="$1"
        # Detect argument termination
        if [ x"$OPT" = x"--" ]; then
                shift
                for OPT ; do
                        OTHER_OPTS="$OTHER_OPTS \"$OPT\""
                done
                break
        fi
        # Parse current opt
        while [ x"$OPT" != x"-" ] ; do
                case "$OPT" in
                        # set daemon MODE
                        -d | --daemon )
                                DAEMON_MODE="true"
                                ;;
                        # telegraf hostname
                        -n=* | --name=* )
                                TELEGRAF_HOSTNAME="${OPT#*=}"
                                shift
                                ;;
                        -n | --name )
                                TELEGRAF_HOSTNAME="$2"
                                shift
                                ;;
                        # set web app
                        -w=* | --web-app=* )
                                WEB_APP_ADDRESS="${OPT#*=}"
                                shift
                                ;;
                        -w | --web-app )
                                WEB_APP_ADDRESS="$2"
                                shift
                                ;;
                        # setup script
                        -s=* | --setup-script=* )
                                SETUP_SCRIPT="${OPT#*=}"
                                shift
                                ;;
                        -s | --setup-script )
                                SETUP_SCRIPT="$2"
                                shift
                                ;;
                        # help
                        -h | --help )
                                print_usage
                                exit 0
                                ;;
                        # set InfluxDB
                        --influxdb=* )
                                INFLUXDB_URL="${OPT#*=}"
                                shift
                                ;;
                        --influxdb )
                                INFLUXDB_URL="$2"
                                shift
                                ;;
                        # timeout
                        --timeout=* )
                                TIMEOUT="${OPT#*=}"
                                shift
                                ;;
                        --timeout )
                                TIMEOUT="$2"
                                shift
                                ;;
                        -*=* )
                                LOCUST_OPTIONS="$LOCUST_OPTIONS $OPT"
                                ;;
                        -*  )
                                if [[ $2 == -* ]]; then
                                    LOCUST_OPTIONS="$LOCUST_OPTIONS $1"
                                else
                                    LOCUST_OPTIONS="$LOCUST_OPTIONS $1 $2"
                                    shift
                                fi
                                ;;
                        # Anything unknown is recorded for later
                        * )
                                OTHER_OPTS="$OTHER_OPTS $OPT"
                                break
                                ;;
                esac
                # Check for multiple short options
                # NOTICE: be sure to update this pattern to match valid options
                NEXTOPT="${OPT#-[cfr]}" # try removing single short opt
                if [ x"$OPT" != x"$NEXTOPT" ] ; then
                        OPT="-$NEXTOPT"  # multiple short opts, keep going
                else
                        break  # long form, exit inner loop
                fi
        done
        # move to the next param
        shift
done

echo "Configuration ..."
echo "TELEGRAF_HOSTNAME: ${TELEGRAF_HOSTNAME}"
echo "DAEMON: ${DAEMON_MODE}"
echo "WEBAPP: ${WEB_APP_ADDRESS}"
echo "INFLUXDB: ${INFLUXDB_URL}"
echo "SETUP_SCRIPT: $SETUP_SCRIPT"
echo "LOCUST_OPTIONS: $LOCUST_OPTIONS"
echo "OTHER: $OTHER_OPTS"

# extract web server protocol and root
WEB_PROTOCOL=${WEB_APP_ADDRESS%%://*}
WEB_ROOT=$(x=${WEB_APP_ADDRESS##*//} && echo ${x%%/*})

# set the supervisor config file
SUPERVISOR_CONF="/etc/supervisor/conf.d/supervisor.conf"

# update telegraf config
sed -i.bak "s/^\([[:space:]]*hostname = \).*/\1\"${TELEGRAF_HOSTNAME}\"/" /etc/telegraf/telegraf.conf
# update InfluxDB server
sed -i.bak "s/\(http:\/\/\)master:8086/\1${INFLUXDB_URL}/" /etc/telegraf/telegraf.conf
sed -i.bak "s,\(http://\)localhost\(/server-status?auto\),$WEB_PROTOCOL://${WEB_ROOT}\2," /etc/telegraf/telegraf.conf

# update supervisor config
#sed -i.bak "s/LOCUST_SCRIPT/${LOCUST_SCRIPT}/" ${SUPERVISOR_CONF}
sed -i.bak "s,WEB_APP_ADDRESS,${WEB_APP_ADDRESS}," ${SUPERVISOR_CONF}
sed -i.bak "s,LOCUST_OPTIONS,${LOCUST_OPTIONS}," ${SUPERVISOR_CONF}

# run the initialization script
if [[ -n ${SETUP_SCRIPT} ]]; then
    ${SETUP_SCRIPT} ${OTHER_OPTS}
fi

# output folder
OUTPUT_FOLDER="/results"


if [[ -n ${TIMEOUT} ]]; then
    #
    test_name=$(date +'%Y%m%d%H%M%S')
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    /etc/init.d/cron start &
    /etc/init.d/sysstat start &
    /usr/bin/influxd -pidfile /var/run/influxdb/influxd.pid -config /etc/influxdb/influxdb.conf &
    /usr/bin/telegraf -config /etc/telegraf/telegraf.conf -config-directory /etc/telegraf/telegraf.d &
    sleep 2
    locust --logfile="${OUTPUT_FOLDER}/locust.log" --host=${WEB_APP_ADDRESS} ${LOCUST_OPTIONS} &
    LOCUST_PID=$!
    sleep ${TIMEOUT}
    curl "http://localhost:8086/stop"
    sleep 2
    end_time=$(date +'%Y-%m-%d %H:%M:%S')

    # write test configuration
    echo -e "Start: ${start_time}\nEnd: ${end_time}\nLocust: ${LOCUST_OPTIONS}\n" >> "${OUTPUT_FOLDER}/${test_name}.config"
    echo -e "Locust Script: ${LOCUST_SCRIPT}\n" >> "${OUTPUT_FOLDER}/${test_name}.config"
    echo -e "WebApp: ${WEB_APP_ADDRESS}\n" >> "${OUTPUT_FOLDER}/${test_name}.config"

    # download stats from locust
    collect_outputs ${test_name}

    sleep 2
    kill -9 $LOCUST_PID
else
    # start supervisor
    /usr/bin/supervisord -n -c ${SUPERVISOR_CONF}
# download stats from locust
collect_outputs ${test_name}

fi