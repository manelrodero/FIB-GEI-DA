#!/bin/bash

G=$1
[[ "$G" =~ ^(0[1-9]|1[0-9]|20)$ ]] || { echo "Ús: bash $0 <grup>   (01..20, amb dos dígits)"; exit 1; }

D=/home/alumne/lab9/entrega
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }
ALERTS=/var/ossec/logs/alerts/alerts.json
FILES="lab09_a1_file.sh lab09_a1_file.tmp lab09_a1_file.sh~ lab09_a1_file.tmp.sh cache/lab09_a1_file.sh"
cd ~/wazuh-docker/single-node/ || exit 1

echo "[1/3] Netejant execucions anteriors..."
for f in $FILES; do rm -f "$D/$f"; done
mkdir -p $D/cache; sleep 5
N=$(docker compose exec -T wazuh.manager wc -l $ALERTS | cut -d' ' -f1)

echo "[2/3] Creant els fitxers de prova..."
for f in $FILES; do echo "grup$G" > "$D/$f"; done

echo "[3/3] Esperant 15 s les alertes..."; sleep 15
NEW=$(docker compose exec -T wazuh.manager tail -n +$((N+1)) $ALERTS)

for f in $FILES; do
    if echo "$NEW" | jq -e --arg p "$D/$f" 'select(.syscheck.path? == $p)' >/dev/null; then
        st="DETECTAT"
    else
        st="NO detectat"
    fi
    printf "  %-26s %s\n" "$f" "$st"
done
