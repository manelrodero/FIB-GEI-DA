# Lab 9 - Integritat de fitxers (File Integrity Monitoring)

## Slides

* [Lab9.pdf](./Lab9.pdf)

## Exercicis dirigits

### D0 - Preparació i comprovació de l'entorn

**Pas D0.1**) Crear el directori per aquest laboratori:

```bash
mkdir -p ~/lab9
```

**Pas D0.2**) Actualitzar el repo dels laboratoris:

```bash
cd ~/github-da
git pull
```

**Pas D0.3**) Comprovar que els contenidors Docker de Wazuh estan en marxa:

```bash
cd ~/wazuh-docker/single-node
docker compose ps --format "table {{.Service}}\t{{.RunningFor}}\t{{.Status}}"
```

El resultat hauria de ser similar a aquest:

```text
SERVICE           CREATED       STATUS
wazuh.dashboard   3 weeks ago   Up 3 weeks
wazuh.indexer     3 weeks ago   Up 3 weeks
wazuh.manager     3 weeks ago   Up 3 weeks
```

**Pas D0.4**) Comprovar que l'Agent de Wazuh està en execució:

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

**Pas D0.5**) Comprovar que aquest agent està actiu al Manager:

```bash
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l
```

El resultat hauria de ser similar a aquest:

```text
Wazuh agent_control. List of available agents:
   ID: 000, Name: wazuh.manager (server), IP: 127.0.0.1, Active/Local
   ID: 001, Name: xxxxx, IP: any, Active
```

Per realitzar aquests exercicis cal tenir a mà dues finestres:

* Terminal al host on està instal·lat l'agent de Wazuh
* Dashboard de Wazuh (**Endpoint security** &rarr; **File Integrity Monitoring**), filtrat per l'agent (`agent.id` o `agent.name`)

### D1. Configurar i verificar que FIM vigila el directori

**Enunciat**: configurar FIM en temps real sobre `/home/alumne/lab9` i demostrar que l'agent l'està vigilant abans de tocar-hi res.

**Pas D1.1**) Crear els directoris (`demo/` per als dirigits, `entrega/` per als autònoms) **abans** de reiniciar l'agent:

```bash
mkdir -p /home/alumne/lab9/{demo,entrega}
```

**Pas D1.2**) Afegir la comprovació del directori dins de `<syscheck>` a `/var/ossec/etc/ossec.conf`:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

```xml
<directories realtime="yes" report_changes="yes" check_all="yes">/home/alumne/lab9</directories>
```

Una sola entrada sobre `lab9` cobreix `demo/` i `entrega/` perquè FIM és recursiu per defecte. Al XML s'escriu el path absolut perquè `~` no s'expandeix.

**Pas D1.3**) Reiniciar l'agent:

```bash
sudo systemctl restart wazuh-agent
```

**Pas D1.4**) Comprovar el log de l'agent:

```bash
sudo grep -i "integrity monitoring" /var/ossec/logs/ossec.log | tail -5
```

**Resultat esperat**: línies de l'escaneig inicial acabat i del temps real iniciat. Si el directori no existia en reiniciar, el temps real no s'hi aplicarà:

```text
wazuh-syscheckd: INFO: (6010): File integrity monitoring scan frequency: 43200 seconds
wazuh-syscheckd: INFO: (6008): File integrity monitoring scan started.
wazuh-syscheckd: INFO: (6009): File integrity monitoring scan ended.
wazuh-syscheckd: INFO: (6012): Real-time file integrity monitoring started.
```

### D2. Llegir `changed_attributes`

**Enunciat**: executar la seqüència [lab09_d2_sequence.sh](lab09_d2_sequence.sh) i, per a cada alerta, dir quin `rule_id` s'ha disparat i quins atributs han canviat.

**Pas D2.1**: Executar l'script amb la seqüència:

```bash
bash ~/github-da/lab09/lab09_d2_sequence.sh
```

| Pas | Acció | Esdeveniment FIM esperat |
| --- | --- | --- |
| 1 | Crear fitxer | added |
| 2 | Canviar el contingut | modified (contingut) |
| 3 | Canviar els permisos | modified (permisos) |
| 4 | Esborrar fitxer | deleted |

**Pas D2.2**: Revisar les alertes a **Endpoint security → File Integrity Monitoring → Events**.

> **Nota**: És recomanable afegir `syscheck.changed_attributes` com a columna des del selector de camps. Sense aquesta columna, les dues `modified` semblen idèntiques quan no ho són.

Per veure-ho també des de la consola del manager (útil per a la captura del lliurament):

```bash
cd ~/wazuh-docker/single-node/
docker compose exec -T wazuh.manager tail -n 50 /var/ossec/logs/alerts/alerts.json \
  | jq -c 'select(.syscheck != null) | {rule: .rule.id, ev: .syscheck.event, path: .syscheck.path, changed: .syscheck.changed_attributes}'
```

> **Nota**: El `-T` desactiva la TTY perquè la sortida es pugui passar per una canonada. El `jq` s'executa a la VM, no dins del contenidor, així que cal tenir-lo instal·lat a la VM.

Es pot veure que el mateix `rule.id` (**550**) cobreix dos fets molt diferents, i és `changed_attributes` el que els separa:

| Acció | `rule.id` | `syscheck.event` | `changed_attributes` | Observació clau |
| --- | --- | --- | --- | --- |
| Crear fitxer | 554 | added | — | Fitxer nou |
| Canviar el contingut | 550 | modified | `size, mtime, md5, sha1, sha256` | El hash canvia; hi ha `syscheck.diff` |
| Canviar els permisos | 550 | modified | `permission` | El hash **no** canvia; hi ha `syscheck.perm_before` i `syscheck.perm_after` |
| Esborrar fitxer | 553 | deleted | — | Desapareix de l'inventari |

### D3. `nodiff`: veure què ha canviat sense filtrar secrets

**Enunciat**: demostrar que FIM pot ensenyar la línia exacta que s'ha afegit a un fitxer, i com evitar-ho per a un fitxer amb credencials.

**Pas D3.1**: Amb la configuració de D1 (`report_changes="yes"`) executar l'script:

```bash
bash ~/github-da/lab09/lab09_d3_secrets.sh
```

**Pas D3.2**: Revisar el camp `syscheck.diff` de l'alerta 550 del fitxer `/home/alumne/lab9/demo/app.conf` que mostra la següent diferència:

```text
1a2
> admin_password=1234
```

Ès bona idea que una contrasenya acabi dins de l'índex d'alertes? Òbviament, no ho és.

**Pas D3.3**: Afegir una excepció dins de `<syscheck>` a `/var/ossec/etc/ossec.conf`:

```bash
sudo nano /var/ossec/etc/ossec.conf
```

```xml
<nodiff>/home/alumne/lab9/demo/app.conf</nodiff>
```

**Pas D3.4**) Reiniciar l'agent:

```bash
sudo systemctl restart wazuh-agent
```

**Pas D3.5**) Executar de nou l'script, aquesta vegada amb el paràmetre `nodiff`:

```bash
bash ~/github-da/lab09/lab09_d3_secrets.sh nodiff
```

**Pas D3.6**) Revisar de nou el camp `syscheck.diff` de l'alerta 550 del fitxer `/home/alumne/lab9/demo/app.conf` que ara mostra el següent missatge:

```text
Diff truncated due to 'nodiff' configuration detected for this file.
```

> **Nota**: Quan `report_changes` está habilitat, Wazuh guarda còpies dels fitxers a `/var/ossec/queue/diff/` per calcular les diferències.

```bash
sudo ls -R /var/ossec/queue/diff/ | head
```

### D4. El baseline no avisa del que ja hi era

**Enunciat**: comprovar si FIM detecta un fitxer mliciós que ja existía abans de començar a vigilar.

**Pas D4.1**: Executar l'script:

```bash
bash ~/github-da/lab09/lab09_d4_backdoor.sh
```

**Resultat esperat**: no apareix cap alerta `added` per al fitxer `/home/alumne/lab9/demo/preexistent.sh`, però sí que surt a la pestanya **Inventory**.

* Last analysis
* Last modified
* User/Group
* User ID/Group ID
* Size
* Inode
* MD5/SHA1/SHA256
* Permissions

Si es modifica el fitxer ara que l'agent està en marxa, sí que apareix l'alerta 550:

```bash
echo "Ara si ;-)" >> /home/alumne/lab9/demo/preexistent.sh
```

FIM detecta **canvis respecte del baseline**, no fitxers dolents. Si el sistema ja està compromès quan s'activa, el baseline "legitima" el compromís. Per això el FIM es combina amb YARA o VirusTotal.

## Exercicis autònoms

Tots els exercicis es fan a `~/lab9/entrega` que ja està vigilat per la configuració del D1.

Els scripts són a `~/github-da/lab09/` i reben el número de grup com a argument, sempre amb dos dígits (`01`...`20`).

### A1. Configuració pròpia amb exclusió

Canviar la configuració de FIM perquè **no** vigili:

* els fitxers acabats en `.tmp`
* els fitxers acabats en `~` (còpies de seguretat d'editors com gedit o emacs)
* el subdirectori `/home/alumne/lab9/entrega/cache/`

Reiniciar l'agent i comprovar-ho amb:

```bash
bash ~/github-da/lab09/lab09_a1_check.sh <grup>
```

L'script crea cinc fitxers de prova i indica quins ha detectat FIM i quins no. Cal executar-lo amb el vostre número de grup.

**Pregunta**: la configuració per defecte de l'agent ja ignora dues extensions. Quines són? Amb quina línia de l'`ossec.conf`?

Cal lliurar:

* El bloc que heu afegit a `<syscheck>`
* La sortida completa de l'script `lab09_a1_check.sh` amb el vostre número de grup
* La resposta a la pregunta

### A2. Seqüència de 7 accions

Executar la seqüència [lab09_a2_sequence.sh](lab09_a2_sequence.sh) amb el vostre número de grup:

```bash
bash ~/github-da/lab09/lab09_a2_sequence.sh <grup>
```

L'script fa 7 accions sobre el fitxer `lab09_a2_app.conf`. En acabar, genera una taula Markdown amb les alertes FIM que han provocat.

Cal lliurar:

* La taula generada, és a dir, el contingut de `~/lab9/lab09_a2_grupXX.md`

### A3. Preguntes d'anàlisi

A partir de la taula que ha generat l'exercici A2 (i, per a la pregunta 6, del Dashboard), responeu:

1. Quantes alertes FIM ha generat la seqüència en total?
2. A l'acció 2, quin atribut **no** apareix a `changed_attributes`? Per què, i què demostra sobre la utilitat del hash?
3. Quin és l'únic atribut que canvia a l'acció 4? El contingut del fitxer ha canviat?
4. Per què `lab09_a2_cache.tmp` (acció 5) no apareix a la taula?
5. Quins esdeveniments genera l'acció 6 i per què n'hi ha més d'un?
6. Compara la columna Hora de la taula amb el timestamp de les mateixes alertes al Dashboard (**Endpoint security** &rarr; **File Integrity Monitoring** &rarr; **Events**). Quanta diferència hi ha? Quina de les dues hores és UTC, i amb quina comanda o dada ho pots demostrar? Per què convé treballar en UTC quan es correlacionen esdeveniments de diferents sistemes?
7. Al Dashboard apareixen dues alertes del fitxer `lab09_a2_grupXX.md` que no surten a la taula. Per què es generen? Per què no surten a la taula? I per què el `modified` del `.md` no inclou `mtime` a `changed_attributes`?

### A4. Regla pròpia: execució afegida a un script

Crear una regla al Manager una regla amb:

* Group name: `syscheck, lab9,`
* Identificador: `100510`
* Nivell: `10`
* Descripció: `Permís d'execució afegit a l'script $(file)`

Aquesta regla ha de penjar de la regla 550 i s'ha de disparar quan un fitxer `.sh` vigilat **guanyi permís d'execució del propietari** (fent servir els els camps `file`, `changed_fields` i `perm` per detectar-ho).

Provar-la amb l'script [lab09_a4_chmod.sh](./lab09_a4_chmod.sh):

```bash
bash ~/github-da/lab09/lab09_a4_chmod.sh <grup>
```

L'script crea `lab09_a4_script.sh`, li dona permís d'execució i, en acabar, mostra una taula Markdown amb les alertes que han provocat aquestes dues accions.

Cal lliurar:

* el XML de la regla
* la taula Markdown mostrada per l'script anterior

## Referències

* [File integrity monitoring / How it works](https://documentation.wazuh.com/current/user-manual/capabilities/file-integrity/how-it-works.html)
* [File integrity monitoring / Basic settings](https://documentation.wazuh.com/current/user-manual/capabilities/file-integrity/basic-settings.html)
* [File integrity monitoring / Creating custom FIM rules](https://documentation.wazuh.com/current/user-manual/capabilities/file-integrity/creating-custom-fim-rules.html)
* [File integrity monitoring / Advanced settings](https://documentation.wazuh.com/current/user-manual/capabilities/file-integrity/advanced-settings.html)
