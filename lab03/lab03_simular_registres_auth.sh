#!/bin/bash

IPS=(
    203.0.113.5
    198.51.100.23
    203.0.113.5
    192.0.2.44
    203.0.113.5
    198.51.100.23
    203.0.113.5
    192.0.2.44
    203.0.113.5
    203.0.113.5
)

echo "[$(date '+%F %T')] Iniciant simulació d'atac SSH..."

contador=1

for ip in "${IPS[@]}"; do
    echo "[$(date '+%F %T')] Event $contador: Failed password des de $ip"

    logger -p auth.warning -t sshd \
        "Failed password for admin from $ip port 22 ssh2"

    ((contador++))
    sleep 1
done

echo "[$(date '+%F %T')] Event final: Accepted password des de 203.0.113.5"

logger -p auth.notice -t sshd \
    "Accepted password for admin from 203.0.113.5 port 22 ssh2"

echo "[$(date '+%F %T')] Simulació completada."
