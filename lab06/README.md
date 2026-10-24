# Lab 6 - Detecció (signatures, heurística) + YARA

## Slides

* [Lab6.pdf](./Lab6.pdf)

## Exercicis dirigits

### Instal·lació de YARA

```bash
sudo apt install yara -y
yara --version
```

### D1 - EICAR i primera regla YARA

Crear el fitxer `eicar.com` (també es pot [descarregar](https://secure.eicar.org/eicar.com)):

```bash
mkdir -p ~/lab6 && cd ~/lab6
echo -n 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar.com
```

Crear el fitxer `eicar_rule.yar`:

```text
rule EICAR_Test_File
{
    meta:
        description = "Fitxer de test EICAR"
    strings:
        $eicar_string = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
    condition:
        $eicar_string
}
```

Executar YARA:

```bash
yara eicar_rule.yar eicar.com
```

El resultat hauria de ser:

```text
EICAR_Test_File eicar.com
```

### D2 - Veure què ha trobat

Executar YARA amb `-s` i `-m`:

```bash
yara -s -m eicar_rule.yar eicar.com
```

El resultat hauria de ser:

```text
EICAR_Test_File [description="Fitxer de test EICAR"] eicar.com
0x0:$eicar_string: X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
```

> `0x0` = offset on comença la coincidència.

### D3 - `nocase`

Crear el fitxer `eicar_lower.com`:

```bash
echo -n 'x5o!p%@ap[4\pzx54(p^)7cc)7}$eicar-standard-antivirus-test-file!$h+h*' > eicar_lower.com
```

Executar YARA:

```bash
yara eicar_rule.yar eicar_lower.com
```

No hauria d'haver-hi cap sortida.

Afegir `nocase` al final de la línia `$eicar_string = "..." nocase` i escanejar el directori:

```bash
yara eicar_rule.yar .
```

El resultat hauria de ser:

```text
EICAR_Test_File ./eicar.com
EICAR_Test_File ./eicar_lower.com
```

### D4 - Hash vs. Patró

Crear el fitxer `eicar_mod.com`:

```bash
cp eicar.com eicar_mod.com
# canviem UN byte (afegint un caràcter)
echo -n 'X' >> eicar_mod.com
```

Calcular els SHA256 i executar YARA:

```bash
sha256sum eicar.com
sha256sum eicar_mod.com
yara eicar_rule.yar eicar_mod.com
```

El resultat hauria de ser:

```text
275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f  eicar.com
d01fa970d3e882abcd3df0673d2cb58a381205958512cb9d6e724e949fab23ac  eicar_mod.com
EICAR_Test_File eicar_mod.com
```

Hash totalment diferent, la detecció per hash cau. La regla YARA continua detectant.

### D5 - Heurística: entropia amb el mòdul `math`

Crear el fitxer `entropia.yar`:

```text
import "math"

rule Alta_Entropia
{
    meta:
        description = "Heurística: contingut probablement xifrat o empaquetat"
    condition:
        filesize > 1KB and math.entropy(0, filesize) >= 7.5
}
```

Crear els fitxers per provar la regla d'entropia:

```bash
# Simula un payload xifrat
head -c 8192 /dev/urandom > aleatori.bin

# Fitxer comprimit legítim
gzip -c /bin/ls > ls.gz
```

Executar YARA:

```bash
# Executar detecció
for f in aleatori.bin ls.gz /bin/ls /etc/services; do yara entropia.yar $f; done
```

El resultat hauria de ser:

```text
Alta_Entropia aleatori.bin
Alta_Entropia ls.gz
```

Es pot calcular l'entropia amb l'script [lab06_entropia.py](lab06_entropia.py):

```bash
python3 lab06_entropia.py aleatori.bin ls.gz /bin/ls
```

O utilitzant el mòdul `console` de YARA que permet imprimir el valor que calcula `math.entropy`.

Donat que `console.log` **sempre retorna cert**, la regla fa match amb tots els fitxers i cal posar-la al principi de la condició.

Com YARA deixa d'avaluar tan bon punt una part dona fals, si el `console.log` estigués al final, els fitxers per sota de 7,5 (com `/bin/ls`) no mostrarien el seu valor.

```text
import "math"
import "console"

rule Alta_Entropia
{
    meta:
        description = "Heurística: contingut probablement xifrat o empaquetat"
    condition:
        console.log("Entropia: ", math.entropy(0, filesize)) and filesize > 1KB and math.entropy(0, filesize) >= 7.5
}
```

## Exercicis autònoms

Abans de realitzar aquests exercicis, cal executar l'script [lab06_preparar_entorn.sh](./lab06_preparar_entorn.sh) per tal de generar els fitxers de mostra amb els quals s'ha de treballar.

```bash
bash lab06_preparar_entorn.sh
ls -l mostres
```

> **Nota**: El contingut dels fitxers de mostra són exemples estàndard de material formatiu; només s'utilitzen com a text per detectar-los, mai s'executen.

### Detecció Reverse Shell i falsos positius

* Crear la regla `Reverse_Shell_v1` al fitxer `reverse_shell_v1.yar`
  * La regla ha d'incloure 3 strings:
    * "/dev/tcp/"
    * "nc -e"
    * "bash -i"
  * La detecció s'ha de produir si al fitxer apareix **qualsevol** dels strings

Executar YARA:

```bash
yara reverse_shell.yar mostres
```

_Quina és la sortida de la comanda anterior?_

* Crear la regla `Reverse_Shell_v2` al fitxer `reverse_shell_v2.yar`
  * Ha de detectar **els 3 fitxers** `sample_suspicious*.txt`
  * **No** ha de fer match amb `admin_notes.txt`, `rsync_backup.sh` ni `sample_clean.txt`

> **Pista**: expressió regular per a `/dev/...` i el modificador adequat per a `nc -e`.

Executar YARA:

```bash
yara reverse_shell_v2.yar mostres
```

_Quina és la sortida de la comanda anterior?_

_Omplir la següent taula de resultats:_

| Fitxer | Match v1? | És realment maliciós? | Tipus v1 | Match v2? | Tipus v2 |
| --- | --- | --- | --- | --- | --- |
| sample_clean.txt | | | | | |
| sample_suspicious1.txt | | | | | |
| sample_suspicious2.txt | | | | | |
| sample_suspicious3.txt | | | | | |
| admin_notes.txt | | | | | |
| rsync_backup.sh | | | | | |

### Capçalera ELF i offsets

* Crear el fitxer `elf_binary.yar` amb dues regles:
  * `ELF_Anywhere` que busqui { 7F 45 4C 46 } a qualsevol lloc
  * `ELF_Binary` que faci el mateix però a l'offset 0

Executar YARA:

```bash
yara -s elf_binary.yar /bin/ls
yara -s elf_binary.yar mostres/sample_clean.txt
yara -s elf_binary.yar mostres/fake_elf.txt
```

* Afegir una tercera regla `ELF_Binary_uint32` **sense secció strings**
  * Cal fer servir `uint32(0) == ...`

_Quin valor hexadecimal heu escrit?_

_Per què l'ordre dels bytes és aquest?_

_Omplir la següent taula de resultats:_

| Fitxer | ELF_Anywhere? | ELF_Binary? | ELF_Binary_uint32? | Offset trobat |
| --- | --- | --- | --- | --- |
| /bin/ls | | | | |
| sample_clean.txt | | | | |
| fake_elf.txt | | | | |

### WebShell PHP

* Crear la regla `PHP_Webshell_Simple` al fitxer `php_webshell.yar`
  * La regla ha de fer match amb **totes** les condicions indicades a continuació:
    * El fitxer comença (offset 0) amb `<?php`
    * El fitxer conté **alguna** funció d'execució: `system(`, `exec(`, `passthru(`, `shell_exec(`
    * El fitxer conté **alguna** entrada d'usuari: `$_GET`, `$_POST`, `$_REQUEST`
* Cal utilitzar prefixos d'identificador: `$f1..$f4`, `$in1..$in3`
* Cal utilitzar la coincidència de conjunt amb comodí: `any of ($str*)`

Executar YARA:

```bash
yara php_webshell.yar mostres/webshell.php
yara php_webshell.yar mostres/index.php
```

_Amb quina mostra fa match?_

_Amb quina mostra **no** fa match?_

_Per què no fa match si llegeix $\_GET?_

### Configuració de minador

* Crear la regla `Cryptominer_Config` al fitxer `miner.yar`
  * La regla ha de fer match amb **totes** les condicions indicades a continuació:
    * "stratum+tcp://" apareix almenys 2 vegades
    * apareix "xmrig" (sense distingir majúscules) o "donate-level"
  * Cal utilitzar l'operador de nombre d'ocurrències: #str

Executar YARA i comprovar que fa match:

```bash
yara -s miner.yar mostres/config.json
```

_Quantes vegades apareix `stratum+tcp://`?_

_A quins offsets?_

## Evasió per codificació

* El fitxer `encoded.sh` conté una Reverse Shell escrita en Base64
* Les regles `Reverse_Shell_v1` i `Reverse_Shell_v2` **no** la detecten
* Crear la regla `Reverse_Shell_Base64` al fitxer `reverse_shell_b64.yar`
  * Cal fer servir el modificador "base64" **únicament** sobre "/dev/tcp/"

Executar YARA i comprovar que fa match:

```bash
yara -s reverse_shell_b64.yar mostres/encoded.sh
```

_Quina comanda està ofuscada al fitxer `encoded.sh`?_

_A quin offset es troba la coincidència i quina cadena mostra YARA?_

Executar la següent comanda:

```bash
printf '/dev/tcp/' | base64
```

_Quin resultat dona?_

_Apareix dins d'encoded.sh?_

_Per què és diferent de la cadena mostrada per YARA?_
