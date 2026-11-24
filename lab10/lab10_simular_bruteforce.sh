#!/bin/bash
# lab10_simular_bruteforce.sh - Simula un atac de força bruta SSH injectant línies al journald
#
# Ús: bash lab10_simular_bruteforce.sh <grup> [tipus] [n] [ip]
#   grup  : número de grup amb dos dígits (01...20)
#   tipus : failed  -> "Failed password for root"  (5760 -> 5763)
#           invalid -> "Invalid user admin"        (5710 -> 100210 / 5712)
#           Per defecte: failed
#   n     : nombre d'intents. Per defecte: 8
#   ip    : IP atacant. Per defecte: 203.0.113.(100+grup)

GRUP=$1
TIPUS=${2:-failed}
N=${3:-8}
ESPERA=15

[[ "$GRUP" =~ ^([01][0-9]|20)$ ]] || { echo "Ús: bash $0 <grup> [failed|invalid] [n] [ip]   (grup 01..20, amb dos dígits)"; exit 1; }
IP=${4:-203.0.113.$((100 + 10#$GRUP))}

case "$TIPUS" in
  failed)  MSG="Failed password for root from $IP port %d ssh2" ;;
  invalid) MSG="Invalid user admin from $IP port %d" ;;
  *) echo "Tipus desconegut: $TIPUS (failed|invalid)"; exit 1 ;;
esac

ara()         { date '+%F %T'; }
bloquejada()  { sudo iptables -C INPUT -s "$IP" -j DROP 2>/dev/null; }
mostra_drop() {
  echo "[$(ara)] Regles DROP per a $IP:"
  sudo iptables -L INPUT -n | grep -w "$IP" || echo "  (cap)"
}

sudo -v || exit 1

echo "[$(ara)] Grup $GRUP - tipus $TIPUS - $N intents - IP $IP"
mostra_drop
if bloquejada; then
  echo "[$(ara)] La IP $IP ja està bloquejada. Espera que venci el timeout."
  exit 1
fi

for i in $(seq 1 "$N"); do
  LINIA=$(printf "$MSG" $((50000 + i)))
  logger -p auth.info -t sshd "$LINIA"
  echo "[$(ara)] Intent $i/$N: sshd: $LINIA"
  sleep 1
done

echo "[$(ara)] Esperant la resposta activa (màxim ${ESPERA}s)..."
for t in $(seq 1 "$ESPERA"); do
  bloquejada && break
  sleep 1
done

mostra_drop
if bloquejada; then
  echo "[$(ara)] RESULTAT: IP $IP BLOQUEJADA (${t}s després de l'últim intent)"
else
  echo "[$(ara)] RESULTAT: IP $IP NO bloquejada"
fi
