# Lab 3 - Logs de Linux. syslog, journald i eines locals

## Slides

* [Lab3.pdf](./Lab3.pdf)

## Exercicis dirigits

### Demo A: Generar un missatge de text

```bash
logger -p auth.warning -t sshd "Missatge des de $(whoami)"
tail -5 /var/log/auth.log
journalctl -t sshd -n 5
```

### Demo B: Simular una seqüència d'intents de login fallits

```bash
#!/bin/bash
IPS=(203.0.113.5 198.51.100.23 203.0.113.5 192.0.2.44 \
     203.0.113.5 198.51.100.23 203.0.113.5 192.0.2.44 \
     203.0.113.5 203.0.113.5)
for ip in "${IPS[@]}"; do
    logger -p auth.warning -t sshd \
        "Failed password for admin from $ip port 22 ssh2"
    sleep 1
done
logger -p auth.notice -t sshd \
    "Accepted password for admin from 203.0.113.5 port 22 ssh2"
```

```bash
journalctl -t sshd -n 10
```

```text
Aug 10 11:25:10 davm sshd[1474015]: Failed password for admin from 198.51.100.23 port 22 ssh2
Aug 10 11:25:11 davm sshd[1474054]: Failed password for admin from 203.0.113.5 port 22 ssh2
Aug 10 11:25:13 davm sshd[1474059]: Failed password for admin from 192.0.2.44 port 22 ssh2
Aug 10 11:25:14 davm sshd[1474061]: Failed password for admin from 203.0.113.5 port 22 ssh2
Aug 10 11:25:15 davm sshd[1474063]: Failed password for admin from 198.51.100.23 port 22 ssh2
Aug 10 11:25:16 davm sshd[1474065]: Failed password for admin from 203.0.113.5 port 22 ssh2
Aug 10 11:25:17 davm sshd[1474067]: Failed password for admin from 192.0.2.44 port 22 ssh2
Aug 10 11:25:18 davm sshd[1474069]: Failed password for admin from 203.0.113.5 port 22 ssh2
Aug 10 11:25:19 davm sshd[1474077]: Failed password for admin from 203.0.113.5 port 22 ssh2
Aug 10 11:25:20 davm sshd[1474098]: Accepted password for admin from 203.0.113.5 port 22 ssh2
```

### Demo C: Analitzar-ho amb grep i amb journalctl, comparant els dos mètodes

```bash
# Via fitxer de text
grep "Failed password" /var/log/auth.log | wc -l
grep "Failed password" /var/log/auth.log | grep -oP '(?<=from )[\d.]+' | sort
grep "Failed password" /var/log/auth.log | grep -oP '(?<=from )[\d.]+' | sort | uniq -c
grep "Failed password" /var/log/auth.log | grep -oP '(?<=from )[\d.]+' | sort | uniq -c | sort -rn
```

```bash
# Via journald (equivalent)
journalctl -t sshd --grep "Failed password" | wc -l
journalctl -t sshd --grep "Failed password" -o cat | grep -oP '(?<=from )[\d.]+' | sort
journalctl -t sshd --grep "Failed password" -o cat | grep -oP '(?<=from )[\d.]+' | sort | uniq -c
journalctl -t sshd --grep "Failed password" -o cat | grep -oP '(?<=from )[\d.]+' | sort | uniq -c | sort -rn
```

### Demo D: Omplir la fitxa de resultat #1

* Mètode(s) utilitzat(s):
  * `grep` sobre `/var/log/auth.log` i `journalctl -t sshd`
* Nombre total d'intents fallits:
  * 10
* Compte(s) objectiu i recompte:
  * `admin` (10)
* IP origen i recompte:
  * 203.0.113.5 (6), 198.51.100.23 (2) i 192.0.2.44 (2)
* Classificació MITRE ATT&CK:
  * [T1110.001](https://attack.mitre.org/techniques/T1110/001/) (password guessing)
* Coincideixen els resultats de grep i journalctl?:
  * Sí
* Conclusió breu:
  * L'atac s'origina majoritàriament des d'una única IP i acaba amb èxit contra el mateix compte objectiu des d'aquesta IP. És un patró clàssic de força bruta dirigida.
