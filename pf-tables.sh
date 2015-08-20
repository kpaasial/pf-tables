#!/bin/sh 

# Script for updating a set of IP/CIDR tables.

# TODO: do not hardcode paths to utilities. Detect them at run time.
# TODO: allow a mode that only downloads the files into the temporary directory
# for testing.

: ${PFTABLES_CONFIG:="/opt/etc/pf-tables.conf"}
: ${PFTABLES_DBDIR:="/var/db/pf-tables"}

COMMAND="fetch"



CP=/bin/cp
FTP=/usr/bin/ftp
MKTEMP=/usr/bin/mktemp
PFCTL=/sbin/pfctl
RM=/bin/rm
SED=/usr/bin/sed

MODES="download store"

if [ $# -eq 1 ]; then 
    COMMAND=$1
fi


case "${COMMAND}" in
    "fetch" ) MODES="download store";;
    "load" ) MODES="load";;
    "all" ) MODES="download store load";;
esac





if [ ! -r "${PFTABLES_CONFIG}" ]; then
    echo "ERROR: config file ${PFTABLES_CONFIG} is not readable."
    exit 1
fi

if [ ! -d "${PFTABLES_DBDIR}" ]; then
    echo "ERROR: database directory ${PFTABLES_DBDIR} does not exist."
    exit 1
fi


finish() {
    # Make sure we are deleting a temporary directory created by this script
    # and not something else. This script will be run as root, better safe than
    # sorry. The trick here is to test if the pattern on the right side of ##
    # "eats" everything in $SCRATCH. Zero length result means a complete match. 
    if test -z "${SCRATCH##/tmp/pftables-??????????}" ; then
         ${RM} -rf "${SCRATCH}"
    else
        echo "Unexpected value for SCRATCH: ${SCRATCH}"
    fi     
}


# Download a tablefile from URL and place its contents in TMPFILE.
download_tablefile() {
    URL=$1
    TMPFILE=$2

    ${FTP} -v -o - "${URL}" > "${TMPFILE}.orig" || exit 1
    ${SED} -e 's/[;#].*$//g' -e '/^\s*$/d' "${TMPFILE}.orig" > "${TMPFILE}" \
        || exit 1 

}


# Store TMPFILE into TABLEFILEPATH. 
store_tablefile() {
    TMPFILE=$1
    TABLEFILEPATH=$2

    if [ ! -r "${TMPFILE}" ]; then
        echo "ERROR: Temporary file ${TMPFILE} is not readable."
        exit 1
    fi

    ${CP} "${TMPFILE}" "${TABLEFILEPATH}" || exit 1

}

# Load contents of TABLEFILEPATH into PF table TABLE.
load_tablefile() {
    TABLEFILEPATH=$1
    TABLE=$2
    
    if [ ! -r "${TABLEFILEPATH}" ]; then
        echo "ERROR: table file ${TABLEFILEPATH} not readable."
        exit 1
    fi
 
    ${PFCTL} -T flush -t "${TABLE}" || exit 1
    ${PFCTL} -T add -t "${TABLE}" -f "${TABLEFILEPATH}" || exit 1
}

# Make multiple passes in different modes over the config file.
# The download mode downloads the files into the $SCRATCH directory and removes
# comments. Any error in the downloads aborts the script and cleans up $SCRATCH.
# The store pass stores the downloaded files at $PFTABLES_DBDIR.
# The load pass loads the stored table files into PF.

# TODO: The configuration file could be validated more strictly here.
# Now there is only a test that it has two fields per line.

# TODO: The default mode of operation should be just download+store and
# the load mode being optional.

# TODO: This whole loop could be in a function that gets called with modes
# parameter set as seen fit.

for mode in $MODES
do
    if [ "${mode}" == "download" ]; then
        # Create a unique temporary directory.
        TEMPLATE="XXXXXXXXXX"
        SCRATCH=$(${MKTEMP} -d /tmp/pftables-${TEMPLATE})
        trap finish EXIT
    fi

    while read line
    do
        line="${line%%#*}"

        if [ -z "${line}" ]; then
            continue
        fi

        set -- $line

        URL=$1
        TABLE=$2

        if [ -z "${URL}" ] || [ -z "${TABLE}" ]; then
            echo "Malformed line ${line} in config file ${PFTABLES_CONFIG}"
            exit 1
        fi

        TMPFILE="${SCRATCH}/${TABLE}"
        TABLEFILEPATH="${PFTABLES_DBDIR}/${TABLE}.txt"

        case "${mode}" in
            "download" )
                download_tablefile "${URL}" "${TMPFILE}"
                ;;
            "store" )
                store_tablefile "${TMPFILE}" "${TABLEFILEPATH}"
                ;;
            "load" )
                load_tablefile "${TABLEFILEPATH}" "${TABLE}"
                ;;
        esac
    done < ${PFTABLES_CONFIG}
done

exit 0
