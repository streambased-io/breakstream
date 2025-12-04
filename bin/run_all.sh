#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../

for SPEC in $(ls specs)
do
  echo "Running SPEC: $SPEC"
  $SCRIPT_DIR/bin/start.sh $SPEC
  if (( $? != 0 ))
  then
    # setup failed
    echo "SPEC: $SPEC FAILED"
    exit 222
  fi
done

echo "ALL SPECS PASSED"