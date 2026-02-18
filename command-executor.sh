#!/bin/bash

# Copyright 2025 UDFSOFT
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# More details: https://smart.udfsoft.com/

set -euo pipefail

# =====================
# CONFIG
# =====================
COMMAND_URL="https://smart.udfsoft.com/api/v1/devices/commands"
SEND_URL="https://smart.udfsoft.com/api/v1/devices/commands"
API_KEY="xxxxxx"

DEVICE_ID=$(cat /etc/machine-id)

echo
echo " =========================================== "
echo "|                                           |"
echo "|  Welcome to the world of udfsoft.com !    |"
echo "|                                           |"
echo "|  If you have any questions about the      |"
echo "|  service or would like to obtain an API   |"
echo "|  key, please contact support@udfsoft.com  |"
echo "|                                           |"
echo " =========================================== "
echo
echo "  DEVICE_ID: $DEVICE_ID"
echo


# =====================
# GET COMMAND
# =====================
echo "[INFO] Requesting command..."

RESPONSE=$(curl -s -X GET "$COMMAND_URL?device_id=$DEVICE_ID" \
    -H "Content-Type: application/json" \
    -H "X-DEVICE-ID: $DEVICE_ID" \
    -H "X-Api-Key: $API_KEY" \
    -H "X-Platform: linux" \
    -w "\nHTTP_STATUS: %{http_code}\n"
)

COMMAND_URL_HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_STATUS" | awk '{print $2}')

if [ "$COMMAND_URL_HTTP_CODE" -ne 200 ]; then
    echo "Error! The server returned the code: $COMMAND_URL_HTTP_CODE"
    exit
fi

echo "HTTP_CODE: $COMMAND_URL_HTTP_CODE"
echo
# echo "RESPONSE: $RESPONSE"

CLEAN_JSON=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')
COMMAND=$(echo "$CLEAN_JSON" | jq -r '.command')

# COMMAND=$(echo "$RESPONSE" | jq -r '.command')
# REQUEST_ID=$(echo "$RESPONSE" | jq -r '.request_id')

if [[ "$COMMAND" == "null" || -z "$COMMAND" ]]; then
  echo "[INFO] No command received"
  exit 0
fi

echo "[INFO] Command received: $COMMAND"



# =====================
# Functions
# =====================
get_base_info() {
  HOSTNAME=$(hostname)
  echo
#  echo "DEVICE_ID: $DEVICE_ID"
  echo "HOSTNAME: $HOSTNAME"
  echo
}

get_cpu_info() {
  lscpu
}

get_sensors_info() {
  if command -v sensors >/dev/null; then
    sensors
  else
    echo "Sensors utility not installed"
  fi
}

get_ram_info() {
  free -h
}

get_disk_info() {
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
}

get_battery_info() {
  BATTERY_PATH=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)

  echo "BATTERY_PATH: $BATTERY_PATH"
  
  if [[ -n "${BATTERY_PATH:-}" ]]; then
    BAT_PERCENT=$(cat "$BATTERY_PATH/capacity" 2>/dev/null || echo 0)
    BAT_STATUS=$(cat "$BATTERY_PATH/status" 2>/dev/null || echo "Unknown")

    if [[ -f "$BATTERY_PATH/energy_full" ]]; then
      BAT_FULL=$(cat "$BATTERY_PATH/energy_full")
      BAT_DESIGN=$(cat "$BATTERY_PATH/energy_full_design")
    elif [[ -f "$BATTERY_PATH/charge_full" ]]; then
      BAT_FULL=$(cat "$BATTERY_PATH/charge_full")
      BAT_DESIGN=$(cat "$BATTERY_PATH/charge_full_design")
    else
      BAT_FULL=0
      BAT_DESIGN=0
    fi

    if [[ "$BAT_DESIGN" -gt 0 ]]; then
      BAT_HEALTH=$(( BAT_FULL * 100 / BAT_DESIGN ))
    else
      BAT_HEALTH=null
    fi
  
  echo "BAT_PERCENT: $BAT_PERCENT"
  echo "BAT_STATUS: $BAT_STATUS"
  echo "BAT_HEALTH: $BAT_HEALTH"

  # BATTERY_JSON=$(jq -n -c \
  #   --arg percent "$BAT_PERCENT" \
  #   --arg status "$BAT_STATUS" \
  #   --arg health "$BAT_HEALTH" \
  #   '{
  #     percent: ($percent|tonumber),
  #     status: $status,
  #     health: ($health|tonumber?)
  #   }')

  fi
}

# =====================
# END Functions
# =====================



# =====================
# EXECUTE COMMAND
# =====================

# COMMAND="SEND_ALL_INFO"

get_base_info

case "$COMMAND" in
  NO_COMMAND)
    exit
    ;;

  SEND_CPU_INFO)
    DATA=$(get_cpu_info)
    TYPE="cpu"
    ;;

  SEND_SENSORS_INFO)
    DATA=$(get_sensors_info)
    TYPE="sensor"
    ;;

  SEND_RAM_INFO)
    DATA=$(get_ram_info)
    TYPE="ram"
    ;;

  SEND_DISK_INFO)
    DATA=$(get_disk_info)
    TYPE="disk"
    ;;

  SEND_BATTERY_INFO)
    DATA=$(get_battery_info)
    TYPE="battery"
    ;;

  SEND_ALL_INFO)
    DATA=$(cat <<EOF
CPU:
$(get_cpu_info)

SENSORS:
$(get_sensors_info)

RAM:
$(get_ram_info)

DISK:
$(get_disk_info)

BATTERY:
$(get_battery_info)
EOF
)
    TYPE="all"
    ;;

  *)
    echo "[WARN] Unknown command: $COMMAND"
    exit 1
    ;;
esac

if [ -z "$DATA" ]; then DATA="No data available"; fi

# echo "$DATA"

# =====================
# SEND DATA
# =====================

echo "[INFO] Sending data..."

SEND_URL_RESPONSE=$(curl -s -X POST "$SEND_URL/$COMMAND" \
  -H "Content-Type: text/plain" \
  -H "X-DEVICE-ID: $DEVICE_ID" \
  -H "X-Api-Key: $API_KEY" \
  -H "X-Platform: linux" \
  --data-binary "$DATA" \
  -w "\nHTTP_STATUS: %{http_code}\n"
)

  SEND_URL_HTTP_CODE=$(echo "$SEND_URL_RESPONSE" | grep "HTTP_STATUS" | awk '{print $2}')
  if [ "$SEND_URL_HTTP_CODE" -ne 200 ]; then
    echo "Error! The server returned the code: $SEND_URL_HTTP_CODE"
    exit
  fi

  echo "[INFO] Done."
