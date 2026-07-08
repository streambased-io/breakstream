#! /bin/bash
# Source this file to get demo_paragraph(). Expects DEMO_MODE, INTERACTIVE_MODE,
# SLEEP_TIME and (optionally) DEBUG_MODE to already be set by the caller.

DEMO_COMMON_LIB_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

demo_paragraph() {
    if [ "$DEMO_MODE" = "true" ]
    then
      $DEMO_COMMON_LIB_DIR/demo_script.sh $1
      echo "Press any key to continue"
      if [ "${INTERACTIVE_MODE}" = "true" ]; then
        read -s -t${SLEEP_TIME} -n1 key
      fi
      if [ "$DEBUG_MODE" != "true" ]
      then
        clear
      fi
    fi
}
