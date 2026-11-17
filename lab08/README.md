# Lab 8 - Funcionalitats EDR-XDR amb Wazuh

## Slides

* [Lab8.pdf](./Lab8.pdf)

## Exercicis dirigits

### D0 - Preparació i comprovació de l'entorn

**Pas 1**) Crear el directori per aquest laboratori:

```bash
mkdir -p ~/lab8
```

**Pas 2**) Actualitzar el repo dels laboratoris:

```bash
cd ~/github-da
git pull
```

**Pas 3**) Comprovar que els contenidors Docker de Wazuh estan en marxa:

```bash
cd ~/wazuh-docker/single-node
docker compose ps --format "table {{.Service}}\t{{.RunningFor}}\t{{.Status}}"
```

El resultat hauria de ser similar a aquest:

```text
SERVICE           CREATED       STATUS
wazuh.dashboard   12 days ago   Up 12 days
wazuh.indexer     12 days ago   Up 12 days
wazuh.manager     12 days ago   Up 12 days
```

**Pas 4**) Comprovar que l'Agent de Wazuh està en execució:

```bash
sudo /var/ossec/bin/wazuh-control status
```

El resultat hauria de ser aquest:

```text
wazuh-modulesd is running...
wazuh-logcollector is running...
wazuh-syscheckd is running...
wazuh-agentd is running...
wazuh-execd is running...
```

**Pas 5**) Comprovar que aquest agent està actiu al Manager:

```bash
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l
```

El resultat hauria de ser similar a aquest:

```text
Wazuh agent_control. List of available agents:
   ID: 000, Name: wazuh.manager (server), IP: 127.0.0.1, Active/Local
   ID: 001, Name: xxxxx, IP: any, Active
```

**Pas 6**) (Opcional) Comprovar la versió de Wazuh Manager:

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-control info
```

El resultat hauria de ser similar a aquest:

```text
WAZUH_VERSION="v4.14.8"
WAZUH_REVISION="rc2"
WAZUH_TYPE="server"
```

### D1 - Quins mòduls estan actius?

**Pregunta**: per a cada mòdul, quina etiqueta i quin valor indiquen que està actiu?

Els mòduls a comprovar són:

* FIM (File Integrity Monitoring)
* SCA (Security Configuration Assessment)
* Inventari de paquets (base de la detecció de vulnerabilitats)
* Log collection
* Detecció de vulnerabilitats
* Connector a l'Indexer

El **mòdul FIM** s'activa amb `syscheck` &rarr; `disabled` = **no**:

```bash
sudo grep -A2 '<syscheck>' /var/ossec/etc/ossec.conf
```

```text
  <syscheck>
    <disabled>no</disabled>
```

El **mòdul SCA** s'activa amb `sca` &rarr; `enabled` = **yes**:

```bash
sudo grep -A2 '<sca>' /var/ossec/etc/ossec.conf
```

```text
  <sca>
    <enabled>yes</enabled>
```

El **mòdul d'inventari** s'activa amb `syscollector` &rarr; `disabled` = **no**. L'inventari de paquets s'activa amb `<packages>` = **yes**:

```bash
sudo grep -A7 'name="syscollector"' /var/ossec/etc/ossec.conf
```

```text
  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
```

> **Nota**: L'Agent envia la llista de paquets al Manager i és aquest qui la creua amb el _feed_ de CVEs.

El **mòdul per recollir logs** s'activa amb 1 o més blocs `<localfile>`:

```bash
sudo grep -c '<localfile>' /var/ossec/etc/ossec.conf
```

Aquests logs poden ser de diferents tipus:

| `log_format` | Font | Què és un esdeveniment? |
| --- | --- | --- |
| `syslog` | Un fitxer de text a `<location>` | Cada línia nova del fitxer |
| `command` | La sortida d'una comanda que l'agent executa cada `<frequency>` segons | Cada línia de la sortida, per separat |
| `full_command` | La sortida d'una comanda, igual que l'anterior | Tota la sortida sencera, com un sol esdeveniment |
| `journald` | El `journald` de `systemd`, no un fitxer | Cada entrada del journal, amb els seus camps (unitat, prioritat, etc.) |

Per exemple, l'Agent de Wazuh executa les següents comandes per defecte:

```bash
# (Command) Mostra l'ocupació de cada partició del disc (format POSIX per compatibilitat)
df -P
# (Full Command) Llista els ports TCP/UDP en escolta amb el procés que els ha obert
netstat -tulpn | sed 's/\([[:alnum:]]\+\)\ \+[[:digit:]]\+\ \+[[:digit:]]\+\ \+\(.*\):\([[:digit:]]*\)\ \+\([0-9\.\:\*]\+\).\+\ \([[:digit:]]*\/[[:alnum:]\-]*\).*/\1 \2 == \3 == \4 \5/' | sort -k 4 -g | sed 's/ == \(.*\) ==/:\1/' | sed 1,2d
# (Full Command) Mostra els 20 últims inicis de sessió al sistema
last -n 20
```

> **Nota**: Normalment s'utilitza `<command>` quan es vol tractar cada línia (per exemple una regla pot avisar quan una partició supera el llindar d'ocupació). Si només es vol comparar respecte a l'execució anterior (`check_diff`) aleshores es pot enviar el bloc sencer amb `<full_command>`.

Les comandes definides a l'Agent s'executen sempre. Les que arriben per configuració centralitzada des del Manager (`agent.conf`) estan bloquejades per defecte. Si un atacant controlés el Manager, podria fer executar qualsevol cosa als agents.

També recull les entrades `journald` i el contingut d'alguns fitxers de `syslog`:

```text
  <localfile>
    <log_format>journald</log_format>
    <location>journald</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/ossec/logs/active-responses.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/dpkg.log</location>
  </localfile>
```

El **mòdul per detectar vulnerabilitats** s'activa amb `vulnerability-detection` &rarr; `enabled` = **yes**:

```bash
cd ~/wazuh-docker/single-node
docker compose exec wazuh.manager grep -A4 '<vulnerability-detection>' /var/ossec/etc/ossec.conf
```

```text
  <vulnerability-detection>
    <enabled>yes</enabled>
    <index-status>yes</index-status>
    <feed-update-interval>60m</feed-update-interval>
  </vulnerability-detection>
```

El **mòdul connector amb l'Indexer** s'activa amb `indexer` &rarr; `enabled` = **yes**:

```bash
docker compose exec wazuh.manager grep -A1 '<indexer>' /var/ossec/etc/ossec.conf
```

```text
  <indexer>
    <enabled>yes</enabled>
```

> **Nota**: si la detecció de vulnerabilitats està activada però l'Indexer no, el Dashboard no mostrarà vulnerabilitats.

Tot això que s'ha vist a la configuració es pot comprovar que està funcionant mirant els logs de l'Agent de Wazuh:

```bash
sudo grep -E 'sca:|syscollector:|syscheckd:' /var/ossec/logs/ossec.log \
  | tac | awk 'vist[$3]++ < 2' | tac
```

I també als logs del Manager:

```bash
# Si el contenidor ha arrencat avui
docker compose exec wazuh.manager grep -i 'vulnerability' /var/ossec/logs/ossec.log | tail -n 5

# Si el contenidor va arrencar fa dies, es pot buscar als logs rotats
docker compose exec wazuh.manager sh -c \
  "find /var/ossec/logs -name 'ossec-*.log.gz' | sort | xargs zgrep -i vulnerability | tail -n 5"
```

### D2 - Llegir l'SCA per l'API

**Pregunta**: quina és la puntuació de la política CIS de l'Agent que s'executa al _host_ on està Wazuh Manager? Quadra amb 100 x `pass` / (`pass + fail`)?

L'API de Wazuh Manager escolta al port **55000** i les credencials es defineixen al fitxer `docker-compose.yml`:

```bash
grep -E 'API_(USERNAME|PASSWORD)' ~/wazuh-docker/single-node/docker-compose.yml
```

El primer que s'ha de fer per utilitzar una API és autenticar-se per obtenir un TOKEN que s'utilitzarà en les peticions posteriors:

```bash
API_USER=$(grep -m1 -oP 'API_USERNAME=\K.*' ~/wazuh-docker/single-node/docker-compose.yml)
API_PASS=$(grep -m1 -oP 'API_PASSWORD=\K.*' ~/wazuh-docker/single-node/docker-compose.yml)
TOKEN=$(curl -s -k -u "$API_USER:$API_PASS" -X POST "https://localhost:55000/security/user/authenticate?raw=true")
# El TOKEN ha de començar per eyJ
echo "${TOKEN:0:20}..."
```

> **Nota**: Aquest TOKEN caduca als 15 minuts (900 segons). Si les peticions a l'API responen amb `Invalid token`, caldrà executar de nou les tres línies anteriors.

Per obtenir l'identificador de l'Agent d'aquesta màquina:

```bash
AGENT_ID=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
  "https://localhost:55000/agents?name=$(hostname)&select=id" \
  | jq -r '.data.affected_items[0].id')
```

Per obtenir un resum del SCA d'aquest Agent (una entrada per política):

```bash
curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/sca/$AGENT_ID" \
      | jq '.data.affected_items[] | {policy_id, name, pass, fail, invalid, total_checks, score}'
```

> **Nota**: es pot fer servir `?pretty=true` o `&pretty=true` per veure el JSON en un format "més humà" ;-)

Per obtenir l'identificador de la política CIS:

```bash
POLICY_ID=$(curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/sca/$AGENT_ID" \
      | jq -r '.data.affected_items[] | select(.policy_id | startswith("cis_")) | .policy_id')
```

Per consultar els 5 primers checks fallits:

```bash
curl -s -k -H "Authorization: Bearer $TOKEN" \
      "https://localhost:55000/sca/$AGENT_ID/checks/$POLICY_ID?result=failed&limit=5&select=id,title" \
      | jq -r '.data.affected_items[] | "\(.id)  \(.title)"'
```

L'`score` es calcula amb la següent fórmula on, com es pot veure, els `invalid` (no aplicables) no compten:

```text
         100 x pass
score = -------------
        (pass + fail)
```

> **Nota**: Per veure la política al Dashboard, cal anar a `Endpoint security` &rarr; `Configuration Assessment` i seleccionar l'agent que es vol explorar (per exemple el **001**).

### D3 - Correlació en sandbox: força bruta SSH

**Pregunta**: amb quina repetició salta la regla de força bruta? Amb quin nivell? Què passa a la repetició següent?

**Pas 1**) Llegir la regla **5712** de sèrie abans de provar-la:

```bash
docker compose exec wazuh.manager grep -B1 -A8 'id="5712"' /var/ossec/ruleset/rules/0095-sshd_rules.xml
```

La definició de la regla indicarà, com a mínim:

* `id` (5712)
* `level` (10)
* `frequency` (8)
* `timeframe` (120)
* `ignore` (60)
* `if_matched_sid` (5710)
* `same_source_ip` (actualment es fa servir `same_srcip`)

**Pas 2**) Executar `wazuh-logtest` i enganxar la mateixa línia 9 vegades seguides (en menys de 2 minuts) dins d'una sola sessió

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-logtest
```

```text
Oct 25 10:00:01 lab-agent sshd[1234]: Invalid user admin from 203.0.113.50 port 50001
```

També es pot fer la prova d'una forma més automatitzada:

```bash
# T: entrada des de fitxer
# 2>&1: wazuh-logtest escriu per stderr
docker compose exec -T wazuh.manager /var/ossec/bin/wazuh-logtest < ~/github-da/lab08/lab08_bruteforce.log 2>&1 \
      | grep -E "^\s+(id|level|description|firedtimes):|Alert to be generated"
```

La resolució esperada és:

| Repetició | `id` | `level` | Observació |
| --- | --- | --- | --- |
| 1-7 | 5710 | 5 | `firedtimes` puja d'1 a 7 |
| 8 | 5712 | 10 | `frequency="8"` complerta dins de `timeframe` des de la mateixa IP |
| 9 | 5710 | 5 | 5712 queda muda 60 segons (`ignore`): la correlació no és un "interruptor" que queda encès |

### D4 - Correlació real amb la regla YARA del Lab 7

Per fer aquest exercici cal que la cadena YARA del Lab 7 continuï funcionant.

La regla nova no detecta res per ella mateixa. Només compta quantes vegades salta la regla YARA del Lab 7.

**Pas 1**) Comprovar que el watch del Lab 7 està configurat:

```bash
sudo grep -B2 -A3 'lab7/watch' /var/ossec/etc/ossec.conf
```

**Pas 2**) Comprovar que les regles YARA del Lab 7 estan configurades:

```bash
cd ~/wazuh-docker/single-node
docker compose exec wazuh.manager grep -B1 -A5 -i yara /var/ossec/etc/rules/local_rules.xml
```

**Pas 3**) Editar el fitxer `local_rules.xml` del contenidor:

```bash
sudo nano ./volumes/wazuh_etc/rules/local_rules.xml
```

i afegir la següent regla YARA al final:

```xml
<group name="yara,lab8,">
  <rule id="100101" level="14" frequency="3" timeframe="120">
    <if_matched_sid>108001</if_matched_sid>
    <description>Múltiples deteccions YARA en poc temps: possible incident actiu</description>
  </rule>
</group>
```

**Pas 4**) Comprovar la sintaxi del fitxer amb `wazuh-analysisd` i reiniciar el Manager:

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-analysisd -t
docker compose exec wazuh.manager /var/ossec/bin/wazuh-control restart
```

**Pas 5**) Comprovar si hi ha alertes de YARA:

```bash
docker compose exec wazuh.manager grep -oE '"id":"(108001|10010[12])"' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
```

**Pas 6**) Copiar fitxer `eicar.com` per generar alertes:

```bash
for i in 1 2 3; do cp ~/lab7/eicar.com ~/lab7/watch/d4_eicar$i.com; done
```

**Pas 7**) Comprovar que el nombre d'alertes i correlacions han augmentat:

```bash
#  108001 = +2; 100101 = +1
docker compose exec wazuh.manager grep -oE '"id":"(108001|10010[12])"' /var/ossec/logs/alerts/alerts.json | sort | uniq -c
```

## Exercicis autònoms

### A1 - Política SCA pròpia

Escriure una [política SCA custom](https://documentation.wazuh.com/current/user-manual/capabilities/sec-config-assessment/creating-custom-policies.html) que faci aquestes 5 comprovacions:

| ID | Títol | Passa si... |
| --- | --- | --- |
| 90001 | Existeix lab08_app.conf | Existeix /home/alumne/lab8/lab08_app.conf |
| 90002 | Mode debug desactivat | Hi ha una línia amb exactament `debug=false` |
| 90003 | Contrasenyes d'almenys 12 caràcters | `password_min_length` >= 12 (comparació numèrica) |
| 90004 | Accés anònim desactivat | Hi ha una línia `allow_anonymous=no` |
| 90005 | Sense fitxer sospitós | **No** existeix `/home/alumne/lab8/lab08_backdoor.sh` |

> **Nota**: Dins la política cal fer servir rutes absolutes (`/home/alumne/lab8/...`) perquè l'Agent s'executa com a root i no interpreta `~`.

La secció `policy` del fitxer de política ha de ser idèntica a aquesta:

```text
policy:
  id: "da_lab08"
  file: "lab08_sca.yml"
  name: "DA Lab 8 - Exercici autònom A1"
  description: "Política SCA per al Lab 8 de DA"
```

Es pot treballar localment al fitxer `~/lab8/lab08_sca.yml` i copiar-lo després al directori de l'Agent de Wazuh:

```bash
nano ~/lab8/lab08_sca.yml
sudo mkdir -p /var/ossec/etc/custom_sca
sudo install -o root -g wazuh -m 640 ~/lab8/lab08_sca.yml /var/ossec/etc/custom_sca/lab08_sca.yml
```

També es pot treballar directament amb el fitxer al directori de l'Agent de Wazuh `/var/ossec/etc/custom_sca/lab08_sca.yml`:

```bash
sudo mkdir -p /var/ossec/etc/custom_sca
sudo nano /var/ossec/etc/custom_sca/lab08_sca.yml
sudo chown root:wazuh /var/ossec/etc/custom_sca/lab08_sca.yml
sudo chmod 640 /var/ossec/etc/custom_sca/lab08_sca.yml
```

Per activar la política, cal afegir-la dins del bloc `<sca>` al fitxer de configuració de l'Agent (`/var/ossec/etc/ossec.conf`):

```xml
<sca>
   <policies>
      <policy enabled="yes">/var/ossec/etc/custom_sca/lab08_sca.yml</policy>
   </policies>
</sca>
```

A continuació és necessari reiniciar l'Agent per tal que agafi la nova configuració:

```bash
# scan_on_start fa l'escaneig en arrencar
sudo systemctl restart wazuh-agent
```

Es pot comprovar que s'hagi carregat i avaluat correctament:

```bash
sudo grep -i "lab08_sca.yml" /var/ossec/logs/ossec.log
```

Finalment, provar la política en 3 fases i llegir el resultat (amb l'API com a l'exercici D2 o des del Dashboard &rarr; Endpoint security &rarr; Configuration Assessment) per cadascuna d'elles.

> **Nota**: Cal reiniciar l'Agent després de cada fase per assegurar que s'executa l'anàlisi de la configuració.

* **Fase 1**: Fitxer `lab08_app.conf` copiat del repo:

```bash
cp ~/github-da/lab08/lab08_app.conf ~/lab8/lab08_app.conf
cat ~/lab8/lab08_app.conf
```

* **Fase 2**: Remediació del fitxer `lab08_app.conf`:

```bash
sed -i 's/^debug=true/debug=false/; s/^password_min_length=6/password_min_length=12/' ~/lab8/lab08_app.conf
```

* **Fase 3**: Fitxer `lab08_backdoor.sh`:

```bash
touch ~/lab8/lab08_backdoor.sh
```

Cal entregar:

* Fitxer amb la definició de la política `lab08_sca.yml`
* Resultat de cada fase obtinguda amb la següent comanda:

```bash
curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/sca/$AGENT_ID?q=policy_id=da_lab08" \
  | jq '.data.affected_items[] | {policy_id, name, pass, fail, invalid, total_checks, score}'
```

### A2 - Ajust de nivells amb `wazuh-logtest`

Editar el fitxer `local_rules.xml` del contenidor Wazuh Manager per afegir un nou grup amb 3 regles:

* La regla 5710 sobreescrita a **nivell 7** (copiar l'original del fitxer `0095-sshd_rules.xml`)
* La regla **100200**, nivell 0, filla de 5710, que ignori la IP 10.10.10.10
* La regla **100210**, **nivell 12**, que salti amb **4** coincidències de 5710 en **60 segons** des de la **mateixa IP**

```xml
<group name="sshd,lab8,">
  <!-- Regla 5710 -->
  <!-- Regla 100200 -->
  <!-- Regla 100210 -->
</group>
```

Validar la sintaxi (`wazuh-analysisd -t`) i reiniciar Wazuh Manager (`wazuh-control restart`) per aplicar les noves regles.

Executar 4 proves amb `wazuh-logtest`, **cadascuna en una sessió nova**, carregant les línies des de fitxers locals:

```bash
cd ~/wazuh-docker/single-node
for p in 1 2 3 4; do
   echo "== Prova $p =="
   docker compose exec -T wazuh.manager /var/ossec/bin/wazuh-logtest < ~/github-da/lab08/lab08_a2_p$p.log 2>&1 \
| grep -E "^\s+(id|level):|Alert to be generated"
done | tee ~/lab8/a2_resultats.txt
```

Cal entregar:

* Bloc afegit al fitxer `local_rules.xml`
* Contingut del fitxer `~/lab8/a2_resultats.txt`

### A3 - Password spraying amb `different_srcuser`

> **Context**: A l'exercici A2, l'atacant insisteix des d'una mateixa adreça IP. En un _password spraying_, una mateixa adreça IP prova un usuari **diferent** cada vegada, de manera que cap compte arriba al límit de bloqueig.

Afegir una quarta regla al mateix grup de l'exercici anterior:

* Regla **100220**, nivell **13**, filla de 5710
* Que salti amb **3** intents en **60 segons** des de la **mateixa adreça IP** i amb **usuaris diferents**

```xml
<group name="sshd,lab8,">
  <!-- Regla 100220 -->
</group>
```

Validar la sintaxi (`wazuh-analysisd -t`) i reiniciar Wazuh Manager (`wazuh-control restart`) per aplicar les noves regles.

Executar 2 proves amb `wazuh-logtest`, **cadascuna en una sessió nova**, carregant les línies des de fitxers locals:

```bash
cd ~/wazuh-docker/single-node
for p in 5 6; do
  echo "== Prova $p =="
  docker compose exec -T wazuh.manager /var/ossec/bin/wazuh-logtest < ~/github-da/lab08/lab08_a3_p$p.log 2>&1 \
| grep -E "^\s+(srcuser|id|level):|Alert to be generated"
done | tee ~/lab8/a3_resultats.txt
```

Cal entregar:

* Bloc afegit al fitxer `local_rules.xml`
* Contingut del fitxer `~/lab8/a3_resultats.txt`

## Comandes d'utilitat

* Reiniciar Wazuh Manager (dins del contenidor)

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-control restart
```

* Reiniciar Wazuh Manager (tot el contenidor; és més lent)

```bash
docker compose restart wazuh.manager
```

* Executar `wazuh-logtest`

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-logtest
```

* Llistar agents

```bash
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l
```

* Comprovar sintaxi amb `wazuh-analysisd`

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-analysisd -t
```

* Comprovar errors o avisos de SCA a l'Agent

```bash
sudo grep -iE 'sca' /var/ossec/logs/ossec.log | grep -iE 'warn|error' | tail -n 10
```

* Comprovar si arriben esdeveniments de la política SCA al Manager

```bash
docker compose exec wazuh.manager grep -c 'da_lab08' /var/ossec/logs/alerts/alerts.json
docker compose exec wazuh.manager grep -i 'sca' /var/ossec/logs/ossec.log | tail -n 10
```

* Obtenir dades d'una política SCA concreta:

```bash
# Utilitzant el select de jq
curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/sca/$AGENT_ID" \
  | jq '.data.affected_items[] | select(.policy_id == "da_lab08") | {policy_id, name, pass, fail, invalid, total_checks, score}'

# Filtrant amb l'API del servidor
curl -s -k -H "Authorization: Bearer $TOKEN" "https://localhost:55000/sca/$AGENT_ID?q=policy_id=da_lab08" \
  | jq '.data.affected_items[] | {policy_id, name, pass, fail, invalid, total_checks, score}'
```

## Editar fitxers del contenidor

Per editar fitxers del contenidor (per exemple `local_rules.xml`) es poden utilitzar diferents mètodes:

* Instal·lar un editor al contenidor (p.ex. `nano`). Cal tenir en compte, però, que aquest editor desapareix en reiniciar el contenidor.

* Copiar els fitxers des del contenidor, editar-los en local i tornar-los a copiar al contenidor. Aquí cal anar en compte amb els permisos i propietaris dels fitxers a dins del contenidor.

```bash
cd ~/wazuh-docker/single-node

# 1. Treure la versió actual i fer-ne còpia de seguretat
docker compose cp wazuh.manager:/var/ossec/etc/rules/local_rules.xml ~/lab8/local_rules.xml
cp ~/lab8/local_rules.xml ~/lab8/local_rules.xml.bak

# 2. Editar ~/lab8/local_rules.xml a la VM (nano, vim...)

# 3. Tornar-lo al contenidor amb el propietari correcte
docker compose cp ~/lab8/local_rules.xml wazuh.manager:/var/ossec/etc/rules/local_rules.xml
docker compose exec wazuh.manager chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml

# 4. Validar i aplicar
docker compose exec wazuh.manager /var/ossec/bin/wazuh-analysisd -t
docker compose exec wazuh.manager /var/ossec/bin/wazuh-control restart
```

* Editar-los directament en els volums mapejats localment (p.ex. `wazuh_etc`).

## Referències

* [Vulnerability detection / Configuration](https://documentation.wazuh.com/current/user-manual/capabilities/vulnerability-detection/configuring-scans.html)
* [Security Configuration Assessment / How to configure SCA](https://documentation.wazuh.com/current/user-manual/capabilities/sec-config-assessment/how-to-configure.html)
* [Security Configuration Assessment / Creating custom SCA policies](https://documentation.wazuh.com/current/user-manual/capabilities/sec-config-assessment/creating-custom-policies.html)
* [Tools / wazuh-logtest](https://documentation.wazuh.com/current/user-manual/reference/tools/wazuh-logtest.html)
* [Local configuration (ossec.conf) / alerts](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/alerts.html)
* [Rules / Rules classification](https://documentation.wazuh.com/current/user-manual/ruleset/rules/rules-classification.html)
* [Rules XML syntax / Rules Syntax](https://documentation.wazuh.com/current/user-manual/ruleset/ruleset-xml-syntax/rules.html)
