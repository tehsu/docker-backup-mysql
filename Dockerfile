FROM mariadb:latest

LABEL org.opencontainers.image.source=https://github.com/tehsu/docker-backup-mysql

ARG GOCRONVER=v0.0.10
ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN set -x \
        && apt-get update && apt-get install -y curl \
	&& curl -L https://github.com/prodrigestivill/go-cron/releases/download/$GOCRONVER/go-cron-$TARGETOS-$TARGETARCH-static.gz | zcat > /usr/local/bin/go-cron \
	&& chmod a+x /usr/local/bin/go-cron

ENV MYSQL_DB="**None**" \
    MYSQL_DB_FILE="**None**" \
    MYSQL_HOST="**None**" \
    MYSQL_PORT=5432 \
    MYSQL_USER="**None**" \
    MYSQL_USER_FILE="**None**" \
    MYSQL_PASSWORD="**None**" \
    MYSQL_PASSWORD_FILE="**None**" \
    MYSQL_PASSFILE_STORE="**None**" \
    MYSQL_EXTRA_OPTS="-Z9" \
    MYSQL_CLUSTER="FALSE" \
    SCHEDULE="@daily" \
    BACKUP_DIR="/backups" \
    BACKUP_SUFFIX=".sql.gz" \
    BACKUP_KEEP_DAYS=7 \
    BACKUP_KEEP_WEEKS=4 \
    BACKUP_KEEP_MONTHS=6 \
    HEALTHCHECK_PORT=8080

COPY backup.sh /backup.sh

VOLUME /backups

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["exec /usr/local/bin/go-cron -s \"$SCHEDULE\" -p \"$HEALTHCHECK_PORT\" -- /backup.sh"]

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f "http://localhost:$HEALTHCHECK_PORT/" || exit 1
