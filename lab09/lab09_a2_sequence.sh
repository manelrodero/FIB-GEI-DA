#!/bin/bash

G=$1
[[ "$G" =~ ^([01][0-9]|20)$ ]] || { echo "Ús: bash $0 <grup>   (01..20, amb dos dígits)"; exit 1; }

D=/home/alumne/lab9/entrega
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }
F=$D/lab09_a2_app.conf
ALERTS=/var/ossec/logs/alerts/alerts.json
OUT=/home/alumne/lab9/lab09_a2_grup$G.md
cd ~/wazuh-docker/single-node/ || exit 1

rm -f $F $F.bak; sleep 3
N=$(docker compose exec -T wazuh.manager wc -l $ALERTS | cut -d' ' -f1)

echo "[1/7] Creant $F..."
echo "config v1 grup$G" > $F; sleep 3

echo "[2/7] Canviant el contingut de lab09_a2_app.conf..."
echo "config v2 grup$G" > $F; sleep 3

echo "[3/7] chmod 600 lab09_a2_app.conf..."
chmod 600 $F; sleep 3

echo "[4/7] touch lab09_a2_app.conf..."
touch $F; sleep 3

echo "[5/7] Creant $D/lab09_a2_cache.tmp..."
echo "temp grup$G" > $D/lab09_a2_cache.tmp; sleep 3

echo "[6/7] Reanomenant lab09_a2_app.conf a lab09_a2_app.conf.bak..."
mv $F $F.bak; sleep 3

echo "[7/7] Esborrant lab09_a2_app.conf.bak..."
rm $F.bak

echo "Esperant 10 seg les últimes alertes..."; sleep 10

{
  echo "| Hora | Fitxer | Event | rule.id | rule.level | changed_attributes | Permisos | md5_after |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
  docker compose exec -T wazuh.manager tail -n +$((N+1)) $ALERTS \
    | jq -r --arg d "$D/lab09_a2_" '
        select(.syscheck.path? // "" | startswith($d))
        | "| \(.timestamp[11:19]) | `\(.syscheck.path | split("/") | last)` | \(.syscheck.event) | \(.rule.id) | \(.rule.level) | \((.syscheck.changed_attributes // []) | join(", ")) | \(if .syscheck.perm_before then "\(.syscheck.perm_before) → \(.syscheck.perm_after)" else (.syscheck.perm_after // "") end) | \(.syscheck.md5_after // "") |"'
} | tee $OUT

echo "Taula desada a $OUT"
