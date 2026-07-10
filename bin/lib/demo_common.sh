#! /bin/bash
# Source this file to get shared demo/test helpers. Expects DEMO_MODE,
# INTERACTIVE_MODE, SLEEP_TIME and (optionally) DEBUG_MODE to already be set by
# callers that use demo_paragraph().

DEMO_COMMON_LIB_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEMO_COMMON_BIN_DIR=$( cd -- "$DEMO_COMMON_LIB_DIR/.." &> /dev/null && pwd )
DEMO_COMMON_BASE_DIR=$( cd -- "$DEMO_COMMON_BIN_DIR/.." &> /dev/null && pwd )

valid_env_file() {
    ENV_FILE=$1
    VALID_LINE_COUNT=0

    [ -s "$ENV_FILE" ] || return 1

    while IFS= read -r LINE || [ -n "$LINE" ]
    do
      LINE=${LINE%$'\r'}
      if [[ -z "$LINE" || "$LINE" =~ ^[[:space:]]*# ]]
      then
        continue
      fi
      [[ "$LINE" =~ ^([[:space:]]*export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*= ]] || return 1
      VALID_LINE_COUNT=$((VALID_LINE_COUNT + 1))
    done < "$ENV_FILE"

    [ "$VALID_LINE_COUNT" -gt 0 ]
}

prepare_shadowtraffic_license() {
    BASE_DIR=${BREAKSTREAM_HOST_DIR:-$DEMO_COMMON_BASE_DIR}
    LICENSE_FILE="$BASE_DIR/environment/shadowtraffic_license.env"
    LICENSE_URL="https://raw.githubusercontent.com/ShadowTraffic/shadowtraffic-examples/refs/heads/master/free-trial-license.env"
    TMP_LICENSE_FILE="$LICENSE_FILE.tmp"

    if valid_env_file "$LICENSE_FILE"
    then
      return 0
    fi

    if [ -f "$LICENSE_FILE" ]
    then
      echo "Ignoring invalid ShadowTraffic license env file at $LICENSE_FILE"
    fi

    if ! curl -fsSL "$LICENSE_URL" -o "$TMP_LICENSE_FILE"
    then
      rm -f "$TMP_LICENSE_FILE"
      die "Failed to download ShadowTraffic license env file from $LICENSE_URL. Create $LICENSE_FILE with valid KEY=value entries and rerun."
    fi

    if ! valid_env_file "$TMP_LICENSE_FILE"
    then
      echo "Downloaded ShadowTraffic license env file is not valid:"
      sed -n '1,5p' "$TMP_LICENSE_FILE"
      rm -f "$TMP_LICENSE_FILE"
      die "Refusing to use invalid ShadowTraffic license env file. Create $LICENSE_FILE with valid KEY=value entries and rerun."
    fi

    mv "$TMP_LICENSE_FILE" "$LICENSE_FILE"
}

demo_paragraph() {
    if [ "$DEMO_MODE" = "true" ]
    then
      "$DEMO_COMMON_BIN_DIR/demo_script.sh" "$1"
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
