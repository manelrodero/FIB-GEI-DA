# Lab 7 - Integració de YARA amb Wazuh

## Slides

* [Lab7.pdf](./Lab7.pdf)

## Exercicis dirigits

Abans de començar els exercicis dirigits, cal clonar el repo dels laboratoris de l'assignatura:

```bash
# Crear el directori per al repo local dels laboratoris l'assignatura
mkdir -p ~/github-da

# Clonar el repo des de GitHub
cd ~/github-da
git clone https://github.com/manelrodero/FIB-GEI-DA.git .
```

Si ja s'havia clonat anteriorment, cal actualitzar-ho:

```bash
# Actualitzar el repo local des de GitHub
cd ~/github-da
git pull
```

### D0 - Preparació i comprovació de l'entorn

**Pas 1**) Instal·lar `jq`, un processador de JSON lleuger, flexible i de línia de comandes

```bash
sudo apt install -y jq
```

**Pas 2**) Comprovar que YARA està instal·lat i la seva versió

```bash
# Esperat /usr/bin/yara
which yara

# Esperat 4.5+
yara --version
```

**Pas 3**) Comprovar que l'Agent de Wazuh està en execució

```bash
sudo /var/ossec/bin/wazuh-control status
```

El resultat hauria de ser:

```text
wazuh-modulesd is running...
wazuh-logcollector is running...
wazuh-syscheckd is running...
wazuh-agentd is running...
wazuh-execd is running...
```

**Pas 4**) Comprovar que l'Agent envia logs d'Active Responses al Manager

```bash
sudo grep -B3 -A2 active-responses.log /var/ossec/etc/ossec.conf
```

El resultat hauria de ser:

```xml
<localfile>
  <log_format>syslog</log_format>
  <location>/var/ossec/logs/active-responses.log</location>
</localfile>
```

El fitxer a vigilar és `active-responses.log` i aquí escriuen els scripts d'Active Response.

**Pas 5**) Crear els directoris `watch` i `rules` per aquest Lab

```bash
mkdir -p ~/lab7/{watch,rules} 
```

**Pas 6**) Comprovar que l'Agent està actiu al Manager

```bash
cd ~/wazuh-docker/single-node
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l
```

L'Agent hauria d'estar marcat com actiu:

```text
Wazuh agent_control. List of available agents:
   ID: 000, Name: wazuh.manager (server), IP: 127.0.0.1, Active/Local
   ID: 001, Name: xxxxx, IP: any, Active
```

### D1 - FIM sol, sense YARA

**Pas 1**) Afegir el directori `/home/alumne/lab7/watch` al `syscheck` de l'Agent

Cal editar el fitxer `/var/ossec/etc/ossec.conf`

```bash
sudo nano /var/ossec/etc/ossec.conf
```

i afegir la següent línia a la secció `Directories to check` just abans de la secció `Files/directories to ignore`:

```text
<directories realtime="yes">/home/alumne/lab7/watch</directories>
```

**Pas 2**) Reiniciar l'Agent i comprovar que s'activa el FIM en temps real

```bash
# Reiniciar i esperar uns segons
sudo systemctl restart wazuh-agent

# Comprovar que s'activa el FIM en temps real
sudo grep -i "real-time file integrity monitoring started" /var/ossec/logs/ossec.log
```

El resultat hauria de ser similar a:

```text
2026/10/26 08:15:36 wazuh-syscheckd: INFO: (6012): Real-time file integrity monitoring started.
```

**Pas 3**) Afegir regles filles del FIM al fitxer de regles locals del Manager

Les regles locals del Manager estan al fitxer `/var/ossec/etc/rules/local_rules.xml` dins del contenidor `wazuh.manager`.

Ara bé, aquest contenidor no conté cap editor (`nano`, `vi`, etc.). Donat que la imatge d'aquest contenidor està basada en **Amazon Linux (Fedora)**, cal fer servir la comanda `dnf` per instal·lar-ne un.

> **Nota**: Aquesta instal·lació es perd si es recrea el contenidor (`docker compose down/up`) o s'actualitzar la imatge Docker.

```bash
# Amazon Linux (Fedora) -> dnf per instal·lar nano
docker compose exec -u root wazuh.manager dnf install -y nano

# Editar les regles locals
docker compose exec wazuh.manager nano /var/ossec/etc/rules/local_rules.xml
```

> **Nota**: Si es va mapejar el volum `wazuh_etc`, es pot editar localment amb `sudo nano ./volumes/wazuh_etc/rules/local_rules.xml`. Molt més senzill ;-)

Afegir les següents regles filles del FIM al final del fitxer:

```xml
<group name="syscheck,">
  <rule id="100300" level="7">
    <if_sid>550</if_sid>
    <field name="file">/home/alumne/lab7/watch/</field>
    <description>Fitxer modificat a /home/alumne/lab7/watch/</description>
  </rule>
  <rule id="100301" level="7">
    <if_sid>554</if_sid>
    <field name="file">/home/alumne/lab7/watch/</field>
    <description>Fitxer afegit a /home/alumne/lab7/watch/</description>
  </rule>
</group>
```

**Pas 4**) Reiniciar el contenidor

```bash
docker compose restart wazuh.manager
```

**Pas 5**) Crear un fitxer al directori vigilat `watch`

```bash
echo prova > /home/alumne/lab7/watch/prova1.txt
```

**Pas 6**) Comprovar que apareix al Dashboard

* Home &rarr; Threat Hunting
* Visualitzar tots els esdeveniments o afegir un filtre per `rule.id` o `rule.groups`

Hauria d'aparèixer 1 esdeveniment:

* `rule.description`: Fitxer afegit a /home/alumne/lab7/watch/
* `rule.level`: 7
* `rule.id`: 100301

Es poden inspeccionar els detalls d'aquest document en format **taula** o en format **JSON**:

* `rule.groups`: syscheck
* `syscheck.event`: added
* `syscheck.path`: /home/alumne/lab7/watch/prova1.txt

> **Nota**: No apareix cap 554 per al mateix fitxer perquè, quan una regla filla coincideix, l'alerta és la de la filla.

### D2 - Decoder i regles YARA

**Pas 1**) Afegir un decoder que reconegui les respostes de YARA i n'estregui alguns camps

```xml
<decoder name="yara_decoder">
  <prematch>wazuh-yara:</prematch>
</decoder>

<decoder name="yara_decoder1">
  <parent>yara_decoder</parent>
  <regex>wazuh-yara: (\S+) - Scan result: (\S+) (\S+)</regex>
  <order>log_type, yara_rule, yara_scanned_file</order>
</decoder>
```

Per editar el fitxer `/var/ossec/etc/decoders/local_decoder.xml`:

```bash
# Si no s'ha mapejat el volum local
docker compose exec wazuh.manager nano /var/ossec/etc/decoders/local_decoder.xml

# Si s'ha mapejat el volum local
sudo nano ./volumes/wazuh_etc/decoders/local_decoder.xml
```

**Pas 2**) Afegir regles per agrupar i alertar si és necessari

```xml
<group name="yara,">
  <rule id="108000" level="0">
    <decoded_as>yara_decoder</decoded_as>
    <description>Regla d'agrupació YARA</description>
  </rule>
  <rule id="108001" level="12">
    <if_sid>108000</if_sid>
    <match>wazuh-yara: INFO - Scan result: </match>
    <description>Fitxer "$(yara_scanned_file)" coincideix amb la regla YARA $(yara_rule)</description>
  </rule>
</group>
```

Per editar el fitxer `/var/ossec/etc/rules/local_rules.xml`:

```bash
# Si no s'ha mapejat el volum local
docker compose exec wazuh.manager nano /var/ossec/etc/rules/local_rules.xml

# Si s'ha mapejat el volum local
sudo nano ./volumes/wazuh_etc/rules/local_rules.xml
```

**Pas 3**) Comprovar la sintaxi dels fitxers XML

Per comprovar que la sintaxi dels fitxers `local_decoder.xml` i `local_rules.xml` siguin correcta:

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-analysisd -t
```

> **Nota**: Aquesta comanda no treu cap resultat per pantalla si la sintaxi dels fitxers és correcta.

**Pas 4**) Provar el decoder i les regles per YARA amb una línia d'exemple

La comanda `wazuh-logtest` permet analitzar una línia de log sense generar cap alerta real:

```bash
docker compose exec wazuh.manager /var/ossec/bin/wazuh-logtest
```

A continuació es pot enganxar la següent línia d'exemple:

```text
wazuh-yara: INFO - Scan result: EICAR_Test_File /home/alumne/lab7/watch/eicar.com
```

El resultat hauria de ser aquest:

```text
**Phase 1: Completed pre-decoding.
        full event: 'wazuh-yara: INFO - Scan result: EICAR_Test_File /home/alumne/lab7/watch/eicar.com'

**Phase 2: Completed decoding.
        name: 'yara_decoder'
        log_type: 'INFO'
        yara_rule: 'EICAR_Test_File'
        yara_scanned_file: '/home/alumne/lab7/watch/eicar.com'

**Phase 3: Completed filtering (rules).
        id: '108001'
        level: '12'
        description: 'Fitxer "/home/alumne/lab7/watch/eicar.com" coincideix amb la regla YARA EICAR_Test_File'
        groups: '['yara']'
        firedtimes: '1'
        mail: 'True'
**Alert to be generated.
```

Si s'exganxa la següent línia:

```text
wazuh-yara: ERROR - Falten -yara_path o -yara_rules
```

El resultat hauria de ser aquest **sense alerta**:

```text
**Phase 1: Completed pre-decoding.
        full event: 'wazuh-yara: ERROR - Falten -yara_path o -yara_rules'

**Phase 2: Completed decoding.
        name: 'yara_decoder'

**Phase 3: Completed filtering (rules).
        id: '108000'
        level: '0'
        description: 'Regla d'agrupació YARA'
        groups: '['yara']'
        firedtimes: '1'
        mail: 'False'
```

**Pas 5**) Reiniciar el Manager

```bash
docker compose restart wazuh.manager
```

> **Nota**: És necessari fer-ho perquè `wazuh-analysisd`, el dimoni que processa els esdeveniments reals, només carrega les regles del disc en arrencar.

### D3 - Regla YARA i script

**Pas 1**) Crear fitxer `~/lab7/rules/eicar_rule.yar` amb la següent regla YARA:

```text
rule EICAR_Test_File
{
  strings:
    $eicar = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
  condition:
    $eicar at 0
}
```

**Pas 2**) Crear fitxer `~/lab7/rules/index.yar` amb un índex de regles YARA:

```text
include "eicar_rule.yar"
```

**Pas 3**) Provar les regles amd un fitxer `eicar.com` fora del directori vigilat

```bash
printf '%s' 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > ~/lab7/eicar.com

# esperat: EICAR_Test_File /home/alumne/lab7/eicar.com
yara -w /home/alumne/lab7/rules/index.yar ~/lab7/eicar.com
```

**Pas 4**) Crear script de resposta activa `resposta_yara.sh`

Copiar el fitxer `~/github-da/lab07/resposta_yara.sh` al directori `/var/ossec/active-response/bin`.

```bash
sudo cp ~/github-da/lab07/resposta_yara.sh /var/ossec/active-response/bin/
```

I protegir-lo correctament:

```bash
sudo chown root:wazuh /var/ossec/active-response/bin/resposta_yara.sh
sudo chmod 750 /var/ossec/active-response/bin/resposta_yara.sh
```

**Pas 5**) Simular comportament de `wazuh-execd`

Per simular el que faria `wazuh-execd` només cal passar un JSON mínim per STDIN a l'script de resposta:

```bash
# Copiar fitxer EICAR al directori temporal
cp ~/lab7/eicar.com /tmp/eicar_test.com

# Passar JSON a l'script de resposta
echo '{"version":1,"command":"add","parameters":{"extra_args":["-yara_path","/usr/bin","-yara_rules","/home/alumne/lab7/rules/index.yar"],"alert":{"syscheck":{"path":"/tmp/eicar_test.com"}}}}' \
| sudo /var/ossec/active-response/bin/resposta_yara.sh

# Comprovar que s'ha generat el log
sudo tail -n 2 /var/ossec/logs/active-responses.log
```

La darrera línia del fitxer `active-responses.log` hauria de ser aquesta:

```text
wazuh-yara: INFO - Scan result: EICAR_Test_File /tmp/eicar_test.com
```

Al Dashboard també hauria d'aparèixer una alerta **108001** (`Fitxer "/tmp/eicar_test.com" coincideix amb la regla YARA EICAR_Test_File`).

Això prova que el tram `logcollector` &rarr; `decoder` &rarr; `regla` del pipeline funciona correctament, encara que l'Active Response no estigui encara connectada.

### D4 - Connectar la resposta activa

**Pas 1**) Modificar la secció `<ossec_config>` del fitxer `ossec.conf` al contenidor

```bash
# Si no s'ha mapejat el volum local
docker compose exec wazuh.manager nano /var/ossec/etc/ossec.conf

# Si s'ha mapejat el volum local
sudo nano ./volumes/wazuh_etc/ossec.conf
```

Afegir la següent comanda per executar `resposta_yara.sh`:

```xml
<command>
  <name>yara_linux</name>
  <executable>resposta_yara.sh</executable>
  <extra_args>-yara_path /usr/bin -yara_rules /home/alumne/lab7/rules/index.yar</extra_args>
  <timeout_allowed>no</timeout_allowed>
</command>
```

Afegir la següent resposta activa per executar la comanda anterior:

```xml
<active-response>
  <disabled>no</disabled>
  <command>yara_linux</command>
  <location>local</location>
  <rules_id>100300,100301</rules_id>
</active-response>
```

> **Nota**: Per fer-ho bé, seria convenient editar el fitxer `~/wazuh-docker/single-node/config/wazuh_cluster/wazuh_manager.conf` que és la plantilla que s'utilitza per crear `ossec.conf` quan es recrea el contenidor.

**Pas 2**) Reiniciar el contenidor i comprovar que la configuració persisteix

```bash
docker compose restart wazuh.manager
docker compose exec wazuh.manager grep -A4 -B2 yara_linux /var/ossec/etc/ossec.conf
```

Si tot és correcte, haurien d'aparèixer els blocs de la comanda i la resposta activa afegits al pas anterior.

**Pas 3**) Reiniciar l'Agent per seguretat

```bash
sudo systemctl restart wazuh-agent
```

**Pas 4**) Provar la resposta activa copiant eicar.com al **directori vigilat**

```bash
cp ~/lab7/eicar.com /home/alumne/lab7/watch/eicar1.com
```

Es comprova el log de respostes actives:

```bash
sudo tail -f /var/ossec/logs/active-responses.log
```

I hauria d'aparèixer:

```text
wazuh-yara: INFO - Scan result: EICAR_Test_File /home/alumne/lab7/watch/eicar1.com
```

**Pas 5**) Comprovar que apareix al Dashboard

* Home &rarr; Threat Hunting
* Visualitzar tots els esdeveniments o afegir un filtre per `rule.id` o `rule.groups`

Hauria d'aparèixer 1 esdeveniment:

* `rule.description`: Fitxer afegit a /home/alumne/lab7/watch/
* `rule.level`: 7
* `rule.id`: 100301

I a continuació 1 esdeveniment:

* `rule.description`: Fitxer "/home/alumne/lab7/watch/eicar1.com" coincideix amb la regla YARA EICAR_Test_File
* `rule.level`: 12
* `rule.id`: 108001

## Exercicis autònoms

Tot el que es demana als exercicis autònoms deixa una evidència textual (línia de log o camps d'alerta).

Les línies de log es poden consultar al fitxer `/var/ossec/logs/active-responses.log` de l'Agent.

Per extreure camps d'alerta, es pot executar la següent comanda al host (Manager) substituïnt `<nom>` pel fitxer de l'exercici:

```bash
docker compose exec -T wazuh.manager cat /var/ossec/logs/alerts/alerts.json \
| grep '<nom>' | jq -c '{id: .rule.id, level: .rule.level, desc: .rule.description, yara: .data.yara_rule}'
```

### A1. La vostra regla del Lab 6

_Apareix alguna nova línia al fitxer `active-responses.log`? Quina?_

_Apareix alguna alerta al Dashboard? Quines?_

_Recollir les alertes des del fitxer `alerts.json` mitjançant la comanda `jq`_

### A2. Control amb fitxer net

_Apareixen noves línies al fitxer `active-responses.log`? Quines?_

_S'ha executat la resposta activa? Qui l'ha disparada?_

_Apareixen noves alertes al Dashboard? Quines?_

_Recollir les alertes des del fitxer `alerts.json` mitjançant la comanda `jq`_

### A3. Experiments amb predicció

| Experiment | Acció a l'Agent | Alertes esperades | Alertes observades | Per què? |
| --- | --- | --- | --- | --- |
| E1 | `cat ~/lab6/mostres/sample_suspicious1.txt >> ~/lab7/watch/sample_clean.txt` | | | |
| E2 | `cp ~/lab7/eicar.com /tmp/eicar_e2.com` | | | |
| E3 | `mkdir ~/lab7/watch/sub && cp ~/lab7/eicar.com ~/lab7/watch/sub/eicar_e3.com` | | | |
| E4 | `rm ~/lab7/watch/eicar1.com` | | | |

### A4. Quarentena automàtica (opcional)

Modificar l'script de resposta YARA per afegir el codi que mogui el fitxer al directori de quarentena i ho registri al fitxer de log:

```bash
if [ -n "$yara_output" ]; then
  while read -r line; do
    echo "wazuh-yara: INFO - Scan result: $line" >> "$LOG_FILE"
  done <<< "$yara_output"

  # <-- Modificació aquí

fi
```

_Quin codi s'ha afegit?_

Crear una nova regla 108002 i nivell 10 al fitxer de regles locals del Manager:

```xml
<rule id="xxxxx" level="xxxxx">
  <if_sid>xxxxx</if_sid>
  <match>xxxxx</match>
  <description>xxxxx</description>
</rule>
```

Crear un nou decoder per extreure els camps necessaris del missatge:

```xml
<decoder name="xxxxx">
  <parent>xxxxx</parent>
  <regex>xxxxx</regex>
  <order>xxxxx</order>
</decoder>
```

Una vegada comprovada la sintaxi (amb wazuh-analysisd i/o wazuh-logtest) s'ha de reiniciar el contenidor:

```bash
docker compose restart wazuh.manager
```

A continuació, es pot copiar el fitxer `eicar.com` al directori vigilat:

```bash
cp ~/lab7/eicar.com ~/lab7/watch/eicar_a4.com
```

_Quantes alertes es generen? Quines?_
