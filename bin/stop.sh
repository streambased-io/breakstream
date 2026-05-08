#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../
cd $SCRIPT_DIR/environment

# --profile activates profile-gated services so they fall into scope for stop/rm.
# Listing all defined profiles here is harmless — unknown profiles are silently ignored.
# Non-profiled services are always in scope, so one sweep covers everything.
PROFILES=(--profile background --profile prepopulate --profile cdc_deletes)
docker --log-level ERROR compose "${PROFILES[@]}" stop
docker --log-level ERROR compose "${PROFILES[@]}" rm -f

if [ -d "$SCRIPT_DIR/environment/shadowtraffic" ]
then
  rm -rf "$SCRIPT_DIR/environment/shadowtraffic"
fi

sleep 3
#clear
echo "Environment stopped."