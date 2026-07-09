#! /bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../

for SPEC in $(ls specs)
do
  LAUNCHER=$(jq -r '.launcher // "start_tests"' specs/$SPEC/spec.json)
  if [ "$LAUNCHER" != "start_tests" ]
  then
    continue
  fi
  echo "Running SPEC: $SPEC"
  $SCRIPT_DIR/bin/start_tests.sh $SPEC
  if (( $? != 0 ))
  then
    # setup failed
    echo "SPEC: $SPEC FAILED"
    exit 222
  fi
done

echo "ALL SPECS PASSED"