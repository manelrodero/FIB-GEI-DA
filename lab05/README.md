# Lab 5 - Primer contacte amb un agent EDR (Wazuh)

## Slides

* [Lab5.pdf](./Lab5.pdf)

## Exercicis dirigits

### Requeriments Wazuh

> Es realitza una [instal·lació de Wazuh en un únic node fent servir Docker](https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html#single-node-stack).

* Assegurar que la VM està actualitzada

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

* Ampliar les Virtual Memory Areas (VMA) per l'indexador

```bash
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-wazuh.conf
sudo sysctl -n vm.max_map_count
sudo sysctl --system
sudo sysctl -n vm.max_map_count
```

* Confirmar l'espai de disc disponible a `/dev/vda1` (~50 GB)

```bash
df -h
```

* Confirmar la memòria RAM disponible (~8 GB)

```bash
free -h
```

> Si tenim 4 GB, aleshores caldrà assegurar-se que la memòria RAM reservada per la Java VM d'OpenSearch sigui mínima.

```yaml
environment:
- "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"
```

* Instal·lar [Docker Engine a Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

```bash
# Esborrar versions antigues
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc | cut -f1)

# Afegir la clau GPG oficial de Docker
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Afegir el repositori als 'sources' d'APT
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Actualitzar APT i instal·lar els paquets de Docker
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Afegir el nostre usuari al grup 'docker'
sudo usermod -aG docker $USER

# Comprovar els nous permisos
newgrp docker
id
docker run hello-world
```

### Instal·lació de Wazuh

* Clonar el [repositori Docker](https://github.com/wazuh/wazuh-docker) de Wazuh

```bash
git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.8
```

* Accedir al directori per desplegar-lo en un únic node

```bash
 cd wazuh-docker/single-node/
```

* Generar els certificats auto-signats de Wazuh

```bash
docker compose -f generate-indexer-certs.yml run --rm generator

# Comprovar que s'han generat correctament
sudo ls -l config/wazuh_indexer_ssl_certs/
```

* Modificar fitxer `docker-compose.yaml` per canviar el mapeig local dels volums `wazuh_etc` i `wazuh_logs` al **Wazuh Manager**

```yaml
services:
  wazuh.manager:
    volumes:
      - ./volumes/wazuh_etc:/var/ossec/etc
      - ./volumes/wazuh_logs:/var/ossec/logs

volumes:
#  wazuh_etc:
#  wazuh_logs:
```

* Modificar fitxer `docker-compose.yaml` per canviar la contrasenya de l'indexador al **Wazuh Manager** i al **Wazuh Dashboard**

```yaml
services:
  wazuh.manager:
    environment:
      - INDEXER_PASSWORD=NouPasswordMesSecret

  wazuh.dashboard:
    environment:
      - INDEXER_PASSWORD=NouPasswordMesSecret
```

* Generar el hash Bcrypt de la nova contrasenya

```bash
docker run --rm httpd:2.4 htpasswd -bnBC 12 "" 'NouPasswordMesSecret' | cut -d: -f2
```

* Modificar fitxer `config/wazuh_indexer/internal_users.yml` per canviar el hash de la contrasenya de l'usuari **admin**

```yaml
# Aquest és el hash de "NouPasswordMesSecret" obtingut anteriorment
admin:
  hash: "$2a$12$ZQlzW3DnzysSyEP.y.f.YuaFO2YfTwvXwcoG9rrlSXjBNoTeNLd9q"
```

### Executar Wazuh

* Desplegar l'stack de Wazuh (~2-3 minuts)

> Si en aquesta VM s'havia activat la recepció UDP/514 de `rsyslog`, caldrà desactivar-la abans.

```bash
docker compose up -d
```

* Revisar la salut dels contenidors

```bash
docker compose ps
docker stats --no-stream
```

* Revisar els logs i esperar fins que s'estabilitzi el servidor

```bash
docker compose logs wazuh.indexer --tail=50
docker compose logs wazuh.manager --tail=50
docker compose logs -f
```

* Si tot és correcte, accedir al Dashboard a `https://<Wazuh_Host_IP>`

### Desplegar agent local

```bash
# Instal·lar paquets necessaris
sudo apt-get install gnupg apt-transport-https curl -y

# Instal·lar la clau GPG de Wazuh
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && sudo chmod 644 /usr/share/keyrings/wazuh.gpg

# Afegir el repositori
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list

# Actualitzar la informació dels paquets
sudo apt update

# Instal·lar l'agent (amb la IP local)
sudo WAZUH_MANAGER="$(ip route get 1.1.1.1 | awk '{print $7; exit}')" apt install wazuh-agent=4.14.8-1 -y

# Habilitar i posar en marxa el servei de l'agent
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Desactivar actualitzacions per garantir Wazuh Manager >= Wazuh Agent
# sudo sed -i "s/^deb /#deb /" /etc/apt/sources.list.d/wazuh.list
# sudo apt update
# sudo apt-mark hold wazuh-agent

# Verificar l'estat de l'agent
sudo /var/ossec/bin/wazuh-control status
sudo head -n 20 /var/ossec/logs/ossec.log
```

### Comprovar agent al Dashboard

* Localitzar l'agent i seu identificador al Dashboard
* Generar alertes "reals" amb l'script [`lab03_simular_registres_auth.sh`](../lab03/lab03_simular_registres_auth.sh)
* Localitzar l'alerta al Dashboard

## Exercicis autònoms

### Desinstal·lar Wazuh Agent

Si en algun moment és necessari desinstal·lar l'agent de Wazuh, es pot fer de la següent manera:

```bash
# Comprovar estat
sudo systemctl status wazuh-agent

# Aturar l'agent
sudo systemctl stop wazuh-agent

# Desinstalar el paquet
sudo apt purge wazuh-agent -y

# (Opcional) Esborrar restes de configuració
sudo rm -rf /var/ossec
```

> També cal esborrar-lo des d'Agents Management &rarr; Summary, sobretot si es vol tornar a instal·lar.
