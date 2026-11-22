#!/bin/bash

G=$1
[[ "$G" =~ ^([01][0-9]|20)$ ]] || { echo "Ús: bash $0 <grup>   (01..20, amb dos dígits)"; exit 1; }

D=/home/alumne/lab9/entrega
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }
F=$D/lab09_a4_script.sh
ALERTS=/var/ossec/logs/alerts/alerts.json
cd ~/wazuh-docker/single-node/ || exit 1

rm -f $F; sleep 3
N=$(docker compose exec -T wazuh.manager wc -l $ALERTS | cut -d' ' -f1)

echo "[1/2] Creant $F..."
echo "echo hola grup$G" > $F; sleep 3

echo "[2/2] chmod +x lab09_a4_script.sh..."
chmod +x $F

echo "Esperant 10 seg les alertes..."; sleep 10

echo "| Hora | Fitxer | Event | rule.id | rule.level | rule.description | changed_attributes | Permisos |"
echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
docker compose exec -T wazuh.manager tail -n +$((N+1)) $ALERTS \
  | jq -r --arg f "$F" '
      select(.syscheck.path? == $f)
      | "| \(.timestamp[11:19]) | `\(.syscheck.path | split("/") | last)` | \(.syscheck.event) | \(.rule.id) | \(.rule.level) | \(.rule.description) | \((.syscheck.changed_attributes // []) | join(", ")) | \(if .syscheck.perm_before then "\(.syscheck.perm_before) → \(.syscheck.perm_after)" else (.syscheck.perm_after // "") end) |"'
