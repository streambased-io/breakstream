#!/bin/bash
# Launches the Flink SQL client with the breakstream Iceberg catalogs pre-registered.
# The isk catalog is only registered when directstream is part of the environment, since
# creating an Iceberg REST catalog contacts the catalog server immediately.
# Extra args are passed through to sql-client.sh, e.g. -f /tmp/test.sql
set -e

INIT_FILE=/tmp/breakstream-init.sql
cat /opt/flink/breakstream-sql/direct.sql > $INIT_FILE
if getent hosts directstream > /dev/null 2>&1
then
  cat /opt/flink/breakstream-sql/isk.sql >> $INIT_FILE
fi

exec /opt/flink/bin/sql-client.sh -i $INIT_FILE "$@"
