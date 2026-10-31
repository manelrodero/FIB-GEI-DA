#!/bin/bash
# Lab 7 - YARA via Active Response
LOG_FILE="/var/ossec/logs/active-responses.log"

read INPUT_JSON
COMMAND=$(echo "$INPUT_JSON" | jq -r .command)
YARA_PATH=$(echo "$INPUT_JSON" | jq -r '.parameters.extra_args[1]')
YARA_RULES=$(echo "$INPUT_JSON" | jq -r '.parameters.extra_args[3]')
FILENAME=$(echo "$INPUT_JSON" | jq -r .parameters.alert.syscheck.path)

[ "$COMMAND" = "add" ] || exit 0
if [ "$YARA_PATH" = "null" ] || [ "$YARA_RULES" = "null" ]; then
  echo "wazuh-yara: ERROR - Falten -yara_path o -yara_rules" >> "$LOG_FILE"
  exit 1
fi
[ -f "$FILENAME" ] || exit 0

# Espera que el fitxer s'acabi d'escriure
size=-1
actual_size=$(stat -c %s "$FILENAME")
while [ "$size" -ne "$actual_size" ]; do
  sleep 1
  size=$actual_size
  actual_size=$(stat -c %s "$FILENAME")
done

yara_output="$("$YARA_PATH"/yara -w "$YARA_RULES" "$FILENAME")"
if [ -n "$yara_output" ]; then
  while read -r line; do
    echo "wazuh-yara: INFO - Scan result: $line" >> "$LOG_FILE"
  done <<< "$yara_output"
fi
exit 0
