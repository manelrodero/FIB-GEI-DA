#!/bin/bash

D=/home/alumne/lab9/demo
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }

# Seqüència 1: Afegir fitxer
echo "[1/4] Creant $D/config.txt (added)..."
echo "config v1" > $D/config.txt; sleep 3

# Seqüència 2: Modificar fitxer (contingut)
echo "[2/4] Canviant el contingut (modified)..."
echo "config v2 - updated" > $D/config.txt; sleep 3

# Seqüència 3: Modificar fitxer (permisos)
echo "[3/4] chmod 600 (modified)..."
chmod 600 $D/config.txt; sleep 3

# Seqüència 4: Esborrar fitxer
echo "[4/4] Esborrant el fitxer (deleted)..."
rm $D/config.txt

echo "Fet. Revisa el Dashboard o executa la comanda jq."
