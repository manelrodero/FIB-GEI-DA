#!/bin/bash

D=/home/alumne/lab9/demo
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }

echo "[1/3] Aturant Wazuh Agent..."
sudo systemctl stop wazuh-agent

echo "[2/3] Afegint backdoor fictici a $D/preexistent.sh..."
echo "backdoor" > $D/preexistent.sh

echo "[3/3] Iniciant Wazuh Agent..."
sudo systemctl start wazuh-agent

echo "Fet. Espera que acabi l'escaneig inicial i revisa el Dashboard o executa la comanda jq."
