#! /bin/sh

set -e

if [ "${MYSQL_DB}" = "**None**" -a "${MYSQL_DB_FILE}" = "**None**" ]; then
  echo "You need to set the MYSQL_DB or MYSQL_DB_FILE environment variable."
  exit 1
fi

if [ "${MYSQL_HOST}" = "**None**" ]; then
  if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ]; then
    MYSQL_HOST=${MYSQL_PORT_3306_TCP_ADDR}
    MYSQL_PORT=${MYSQL_PORT_3306_TCP_PORT}
  else
    echo "You need to set the MYSQL_HOST environment variable."
    exit 1
  fi
fi

if [ "${MYSQL_USER}" = "**None**" -a "${MYSQL_USER_FILE}" = "**None**" ]; then
  echo "You need to set the MYSQL_USER or MYSQL_USER_FILE environment variable."
  exit 1
fi

if [ "${MYSQL_PASSWORD}" = "**None**" -a "${MYSQL_PASSWORD_FILE}" = "**None**" -a "${MYSQL_PASSFILE_STORE}" = "**None**" ]; then
  echo "You need to set the MYSQL_PASSWORD or MYSQL_PASSWORD_FILE or MYSQL_PASSFILE_STORE environment variable or link to a container named MYSQL."
  exit 1
fi

#Process vars
if [ "${MYSQL_DB_FILE}" = "**None**" ]; then
  MYSQL_DBS=$(echo "${MYSQL_DB}" | tr , " ")
elif [ -r "${MYSQL_DB_FILE}" ]; then
  MYSQL_DBS=$(cat "${MYSQL_DB_FILE}")
else
  echo "Missing MYSQL_DB_FILE file."
  exit 1
fi
if [ "${MYSQL_USER_FILE}" = "**None**" ]; then
  export MYSQLUSER="${MYSQL_USER}"
elif [ -r "${MYSQL_USER_FILE}" ]; then
  export MYSQLUSER=$(cat "${MYSQL_USER_FILE}")
else
  echo "Missing MYSQL_USER_FILE file."
  exit 1
fi
if [ "${MYSQL_PASSWORD_FILE}" = "**None**" -a "${MYSQL_PASSFILE_STORE}" = "**None**" ]; then
  export MYSQLPASSWORD="${MYSQL_PASSWORD}"
elif [ -r "${MYSQL_PASSWORD_FILE}" ]; then
  export MYSQLPASSWORD=$(cat "${MYSQL_PASSWORD_FILE}")
elif [ -r "${MYSQL_PASSFILE_STORE}" ]; then
  export PGPASSFILE="${MYSQL_PASSFILE_STORE}"
else
  echo "Missing MYSQL_PASSWORD_FILE or MYSQL_PASSFILE_STORE file."
  exit 1
fi
export PGHOST="${MYSQL_HOST}"
export PGPORT="${MYSQL_PORT}"
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=`expr $(((${BACKUP_KEEP_WEEKS} * 7) + 1))`
KEEP_MONTHS=`expr $(((${BACKUP_KEEP_MONTHS} * 31) + 1))`

#Initialize dirs
mkdir -p "${BACKUP_DIR}/daily/" "${BACKUP_DIR}/weekly/" "${BACKUP_DIR}/monthly/"

#Loop all databases
for DB in ${MYSQL_DBS}; do
  #Initialize filename vers
  DFILE="${BACKUP_DIR}/daily/${DB}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
  WFILE="${BACKUP_DIR}/weekly/${DB}-`date +%G%V`${BACKUP_SUFFIX}"
  MFILE="${BACKUP_DIR}/monthly/${DB}-`date +%Y%m`${BACKUP_SUFFIX}"
  #Create dump
  echo "Creating dump of ${DB} database from ${MYSQL_HOST}..."
  mysqldump -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -d "${DB}" > "${DFILE}"
  #Copy (hardlink) for each entry
  if [ -d "${DFILE}" ]; then
    WFILENEW="${WFILE}-new"
    MFILENEW="${MFILE}-new"
    rm -rf "${WFILENEW}" "${MFILENEW}"
    mkdir "${WFILENEW}" "${MFILENEW}"
    cp "${DFILE}/"* "${WFILENEW}/"
    cp "${DFILE}/"* "${MFILENEW}/"
    rm -rf "${WFILE}" "${MFILE}"
    mv -v "${WFILENEW}" "${WFILE}"
    mv -v "${MFILENEW}" "${MFILE}"
  else
    cp "${DFILE}" "${WFILE}"
    cp "${DFILE}" "${MFILE}"
  fi
  #Clean old files
  echo "Cleaning older than ${KEEP_DAYS} days for ${DB} database from ${MYSQL_HOST}..."
  find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime +${KEEP_DAYS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
  find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime +${KEEP_WEEKS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
  find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime +${KEEP_MONTHS} -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rf '{}' ';'
done

echo "SQL backup created successfully"
