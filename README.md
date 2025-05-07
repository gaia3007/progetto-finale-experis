# Progetto-finale-experis
Per affrontare questo progetto abbiamo bisogno dell'estensione Terraform in Visual studio code e di fare un az login per far si che terraform capisca che le risorse vengano create tutte su Azure.

### Con az login impostiamo il nostro account con la sottoscrizione
```az login```

```az account set --subscription "20942a39-e96c-4873-90b7-2c3f63481183"```

### Provisioning dell'infrastruttura con Terraform
Ho scritto uno script Terraform suddiviso in più file (main.tf, variables.tf, output.tf) per creare su azure le seguenti risorse:

1 gruppo risorse --> contenitore logico delle risorse

1 virtual network con una subnet

1 network security group con regole in ingresso

2 macchine virtuali linux Ubuntu con:

Ip pubblico per SSH e accesso web

autenticazione tramite username e password

### configurazione delle regole di sicurezza per aprire le porte
22 --> accesso SSH

80 --> per l'accesso in HTTP

30080 --> porta Nodeport per esporre l'app in K8s 

![image](https://github.com/user-attachments/assets/81893a37-2a5c-45c5-881a-5b541c775fae)
il risultato atteso è il seguente.
### Errori principali riscontrati 
Terraform non riusciva a creare le VM --> ```PlatformImageNotFound: The platform image 'Canonical:UbuntuServer:22_04-lts:latest' is not available.```

Causa: quella specifica immagine non è disponibile nella location che ho scelto (West Europe)

Risolto: ho sostituito con una versione compatibile:

publisher = "Canonical"
offer     = "0001-com-ubuntu-server-jammy"
sku       = "22_04-lts-gen2"
Adesso l'infrastruttura è pronta per installare e testare Docker, cluster k3S (che è una distribuzione leggera di Kubernetes) e Node.js

## Installazione manuale di Docker e K3s
ho installato docker su entrambe le vm usando questo comando:
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
Docker ci serve per buildare, esportare e gestire le immagini Docker dall'app 

Poi mi sono spostata sulla prima VM (master) per installare il nodo principale del cluster
```curl -sfL https://get.k3s.io | sh -```
Questo comando ha avviato il server K3s e kubectl

In questo modo ho anche generato un node-token, ossia una stringa segreta fornita automaticamente da K3s sulla VM master 
che serve ad autenticare i nodi worker che vogliono entrare nel cluster ed evitare che i nodi non autorizzati si uniscano.

Il token è stato salvato in questo percorso: ```/var/lib/rancher/k3s/server/node-token```
Dopodichè sono entrata nella seconda VM per unirla al cluster (usando il token) con questo comando: curl -sfL https://get.k3s.io | K3S_URL=https://10.0.1.4:6443 K3S_TOKEN=<token_copiato> sh -
usando l'IP privato.

![image](https://github.com/user-attachments/assets/186d0d7d-abd6-4d49-94be-ca1c58068434)


## Creazione di un'app Node.js containerizzata
Ho creato un'applicazione web con Node.js ed Express. I file principali sono app.js e package.json (contenuti presenti nella lista file)
e poi ho installato Express con: npm install

### Creazione del Dockerfile
per containerizzare l'app, ho creato un dockerfile (contenuto presente nella lista file) 
questo script dice a docker di usare node.js, copiare e installare le dipendenze, esporre la porta 3000 e avviare l'app con npm start.

ho costruito l'immagine con: docker build -t hello-docker .
E per completezza di test ho voluto lanciare un container per verificarne l'efficacia con: docker run -d -p 3000:3000 hello-docker

![image](https://github.com/user-attachments/assets/deaa1cd0-e281-4a46-bde2-49bd38768e06)

e da come si può notare, usando poi il comando curl http://localhost:3000/
la VM restituisce hello, world! così come dichiarato nel file app.js

### Errori riscontrati 
ImagePullBackoff nel pod
causa: l'immagine era stata creata solo sulla VM master, perchè i nodi non condividono automaticamente le immagini tra loro.
soluzione: ho preso la mia immagine locale e l'ho salvata in .tar
docker save hello-docker:latest -o hello-docker.tar
poi, ho copiato il file .tar sulla VM worker e ho usato scp per spostarlo usando anche l'IP privato
scp hello-docker.tar darienzogaia@10.0.1.4:/home/darienzogaia/
Infine ho importato l'immagine sulla VM worker eseguendo:
sudo k3s ctr images import hello-docker.tar

![image](https://github.com/user-attachments/assets/e8f8b569-dc32-4b26-83d8-6fd1be91f482)

Ora anche il nodo worker conosce l'immagine hello-docker:latest, quindi puù avviare il pod correttamente

![image](https://github.com/user-attachments/assets/609f5f78-e57e-42f8-882a-64ee6d7ac8dc)














