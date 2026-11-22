#!/bin/bash

G=$1
[[ "$G" =~ ^(0[1-9]|1[0-9]|20)$ ]] || { echo "Ús: bash $0 <grup>   (01..20, amb dos dígits)"; exit 1; }

D=/home/alumne/lab9/entrega
[ -d "$D" ] || { echo "No existeix $D: fes primer el D1"; exit 1; }

echo "[1/7] Creant $D/app.conf..."
echo "config v1 grup$G" > $D/app.conf; sleep 3

echo "[2/7] Canviant el contingut de app.conf..."
echo "config v2 grup$G" > $D/app.conf; sleep 3

echo "[3/7] chmod 600 app.conf..."
chmod 600 $D/app.conf; sleep 3

echo "[4/7] touch app.conf..."
touch $D/app.conf; sleep 3

echo "[5/7] Creant $D/cache.tmp..."
echo "temp grup$G" > $D/cache.tmp; sleep 3

echo "[6/7] Reanomenant app.conf a app.conf.bak..."
mv $D/app.conf $D/app.conf.bak; sleep 3

echo "[7/7] Esborrant app.conf.bak..."
rm $D/app.conf.bak

echo "Fet. Revisa el Dashboard o executa la comanda jq."
