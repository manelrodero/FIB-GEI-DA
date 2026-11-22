#!/bin/bash

D=/home/alumne/lab9/demo
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }

if [ "$1" != "nodiff" ]; then
    # Fase 1: report_changes actiu, encara sense <nodiff>
    echo "[1/2] Creant $D/app.conf amb 'port'..."
    echo "port=8080" > $D/app.conf; sleep 3

    echo "[2/2] Afegint 'admin_password' a $D/app.conf..."
    echo "admin_password=1234" >> $D/app.conf
else
    # Fase 2: després d'afegir <nodiff> i reiniciar l'agent
    echo "[1/1] Afegint una nova 'admin_password' a $D/app.conf..."
    echo "admin_password=5678" >> $D/app.conf
fi

echo "Fet. Revisa el Dashboard o executa la comanda jq."
