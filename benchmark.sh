#!/bin/sh

# APPDATA_PATH
#   IR8x9: /data/appdata
#   IR1101: /iox_data/appdata
APPENV_FILE="${APPDATA_PATH:=/data/appdata}/appenv.txt"

if test -f "${APPENV_FILE}" ; then
    . ${APPENV_FILE}
fi

# get params
profile=${PROFILE}
app_name=${APP_NAME}
cpu_units=${CPU_UNITS}
nb_tests=${NB_TESTS:=1}
nb_threads=${NB_THREADS:=1}
memory_size=${MEMORY_SIZE}
target=${TARGET:=sysbench}
exec_time=${EXEC_TIME}
log_file=${LOG_PATH:="/iox_data/logs"}/${LOG_FILE:=benchmark.log}
max_prime=${MAX_PRIME:=10000}
date=${DATE_CMD:=date}

exec 1> ${log_file}-$$ 2>&1

test_sysbench_sub()
{
    ${date} +"Start test $1: %Y-%m-%dT%H:%M:%S.%6N"
    sysbench \
        --threads=${nb_threads} \
        --cpu-max-prime=${max_prime} \
        cpu run
    ${date} +"End   test $1: %Y-%m-%dT%H:%M:%S.%6N"
}

test_sysbench()
{
    for i in `seq ${nb_tests}`
    do
        test_sysbench_sub $i
    done
}

test_openssl_sub()
{
    ${date} +"Start test $1: %Y-%m-%dT%H:%M:%S.%6N"
    if test ${nb_threads} -gt 1 ; then
        openssl speed -multi ${nb_threads} rsa2048
    else
        openssl speed rsa2048
    fi
    ${date} +"End   test $1: %Y-%m-%dT%H:%M:%S.%6N"
}

test_openssl()
{
    for i in `seq ${nb_tests}`
    do
        test_openssl_sub $i
    done
}

test_linpack()
{
    printf "\nq\n" | /bin/linpack
}

fixsec()
{
    if test -z "$1" ; then echo 0 ; else echo $1 ; fi
}

getsec()
{
    hms=$1
    h=$(fixsec $(echo $hms | cut -c1-2 | sed -e 's/0*//'))
    m=$(fixsec $(echo $hms | cut -c3-4 | sed -e 's/0*//'))
    s=$(fixsec $(echo $hms | cut -c5-6 | sed -e 's/0*//'))
    echo "$(($h*60*60 + $m*60 + $s))"
}

at()
{
    at_time=$(getsec $1)
    if test -z "${at_time}" ; then
        return
    fi
    while true
    do
        now=$(${date} +%H%M%S)
        now_sec=$(getsec $now)
        if test ${at_time} -le ${now_sec} ; then
            echo "$now"
            break
        fi
        #
        if test $((${now_sec}%60)) -eq 0 ; then
            echo $now
        else
            echo -n .
        fi
        sleep 1
    done
}

#
# main
#

echo "## Parameers"
echo "profile: ${profile}"
echo "app_name: ${app_name}"
echo "cpu_units: ${cpu_units}"
echo "nb_tests: ${nb_tests}"
echo "nb_threads: ${nb_threads}"
echo "memory_size: ${memory_size}"
echo "target: ${target}"
echo "exec_time: ${exec_time}"
echo "log_file: ${log_file}"
echo "max_prime: ${max_prime}"

${date} +"## Sleep: %Y-%m-%dT%H:%M:%S.%6N"
at ${exec_time}

${date} +"## Start: %Y-%m-%dT%H:%M:%S.%6N"
test_${target}

${date} +"## End  : %Y-%m-%dT%H:%M:%S.%6N"

exit 0
