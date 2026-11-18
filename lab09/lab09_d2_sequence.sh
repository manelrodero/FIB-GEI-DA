#!/bin/bash

D=/home/alumne/lab9/demo
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }

# Sequència 1: Afegir fitxer
echo "config v1" > $D/config.txt; sleep 3

# Sequència 2: Modificar fitxer (contingut)
echo "config v2 - updated" > $D/config.txt; sleep 3

# Sequència 3: Modificar fitxer (permisos)
chmod 600 $D/config.txt; sleep 3

# Sequència 4: Esborrar fitxer
rm $D/config.txt

echo "Fet. Revisa el Dashboard o executa la comanda jq."
