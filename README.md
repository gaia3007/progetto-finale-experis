# Progetto-finale-experis
Per affrontare questo progetto abbiamo bisogno dell'estensione Terraform in Visual studio code e di fare un az login per far si che terraform capisca che le risorse vengano create tutte su Azure.

### Con az login impostiamo il nostro account con la sottoscrizione
```az login```

```az account set --subscription "xxx"```

### Provisioning dell'infrastruttura con Terraform
Ho creato uno script Terraform suddiviso in più file (main.tf, variables.tf, output.tf) per creare su azure le seguenti risorse:

1 gruppo risorse --> contenitore logico delle risorse

1 virtual network con una subnet

1 network security group con regole in ingresso

2 macchine virtuali linux Ubuntu con:

Ip pubblico per SSH e accesso web

autenticazione tramite username e password

![image](https://github.com/user-attachments/assets/81893a37-2a5c-45c5-881a-5b541c775fae)

il risultato atteso da portale è il seguente.

### configurazione delle regole di sicurezza per aprire le porte
22 --> accesso SSH

80 --> per l'accesso in HTTP

30080 --> porta Nodeport per esporre l'app in K8s 


### Errori principali riscontrati durante la creazione del codice in Terraform
Terraform non riusciva a creare le VM --> ```PlatformImageNotFound: The platform image 'Canonical:UbuntuServer:22_04-lts:latest' is not available.```

Causa: quella specifica immagine non è disponibile nella location che ho scelto (West Europe)

Risolto: ho sostituito con una versione compatibile:

publisher = "Canonical"
offer     = "0001-com-ubuntu-server-jammy"
sku       = "22_04-lts-gen2"
Adesso l'infrastruttura è pronta per installare e testare Docker, cluster k3S (che è una distribuzione leggera di Kubernetes) e Node.js

## Installazione manuale di Docker e K3s
ho installato docker su entrambe le vm usando questo comando:
```curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker 
```

Docker ci serve per buildare, esportare e gestire le immagini Docker dall'app 

Poi mi sono spostata sulla prima VM (master) per installare il nodo principale del cluster
```curl -sfL https://get.k3s.io | sh -
Questo comando ha avviato il server K3s e kubectl
```

In questo modo ho anche generato un node-token,
ossia una stringa segreta fornita automaticamente da K3s sulla VM master 
che serve ad autenticare i nodi worker che vogliono entrare nel cluster ed evitare che i nodi non autorizzati si uniscano.

Il token è stato salvato in questo percorso: ``` /var/lib/rancher/k3s/server/node-token```
Dopodichè sono entrata nella seconda VM per unirla al cluster (usando il token) con questo comando:

``` curl -sfL https://get.k3s.io | K3S_URL=https://10.0.1.4:6443 K3S_TOKEN=<token_copiato> sh ```

usando l'IP privato.

![image](https://github.com/user-attachments/assets/186d0d7d-abd6-4d49-94be-ca1c58068434)


## Creazione di un'app Node.js containerizzata
Ho creato un'applicazione web con Node.js ed Express. I file principali sono app.js e package.json (contenuti presenti nella lista file)
e poi ho installato Express con: npm install

### Creazione del Dockerfile
per containerizzare l'app, ho creato un dockerfile (contenuto presente nella lista file) 
questo script dice a docker di usare node.js, copiare e installare le dipendenze, esporre la porta 3000 e avviare l'app con npm start.

ho costruito l'immagine con: ```docker build -t hello-docker .```
E per completezza di test ho voluto lanciare un container per verificarne l'efficacia con: 
```docker run -d -p 3000:3000 hello-docker```

![image](https://github.com/user-attachments/assets/deaa1cd0-e281-4a46-bde2-49bd38768e06)

e da come si può notare, usando poi il comando  
```curl http://localhost:3000/```
la VM restituisce hello, world! così come dichiarato nel file app.js

## Deployment su K3s
Ho iniziando creando un deployment.yaml (contenuto presente nella lista dei file) che contiene le istruzioni per
k3s per creare e gestire i pod dell'app. 

E' importante specificare che nello script ho indicato la replica a 3 per garantire un'alta disponibilità, così se uno
dovesse bloccarsi, ne verrebbe subito creato uno nuovo.

Ho continuato creando un file service.yaml (contenuto presente nella lista file) che esponde i pod verso l'esterno tramite
una risorsa di tipo Nodeport, la quale consente di accedere all'applicazione da fuori il cluster, attraverso l'ip pubblico della 
VM master su una porta generata casualmente, nel mio caso è stata la 30080. 

![image](https://github.com/user-attachments/assets/a66a44ea-d6c2-4892-b558-c505163a38d9)

Poi ho eseguito questi comandi: 
```kubectl apply -f deployment.yaml```
```kubectl apply -f service.yaml```

kubectl apply dice a k3s di creare e aggiornare le risorse specificate nei file YAML.

### Errori riscontrati 
Inizialmente, avendo sempre usato sempre kubernetes, ho inserito un service di tipo load balancer, scoprendo
poi dopo che k3s non riesce a supportarlo da solo. Quindi l'ho modificato in Nodeport e ho potuto ottenere una 
porta alta ed esporla manualmente via IP pubblico in HTTP, in quanto non ha bisogno di componenti esterni e funziona sia in
ambienti cloud che su VM locali.

Nello screenshot sottostante mostro nel dettaglio le regole di sicurezza di ingresso che ho impostato prima di eseguire i test

![image](https://github.com/user-attachments/assets/de7b190e-e3a9-4bc4-8e74-0e03c629b866)




### ImagePullBackoff nel pod
causa: l'immagine era stata creata solo sulla VM master, perchè i nodi non condividono automaticamente le immagini tra loro.

soluzione: ho preso la mia immagine locale e l'ho salvata in .tar
```docker save hello-docker:latest -o hello-docker.tar```

poi, ho copiato il file .tar sulla VM worker e ho usato scp per spostarlo usando anche l'IP privato
```scp hello-docker.tar darienzogaia@10.0.1.4:/home/darienzogaia/```

Infine ho importato l'immagine sempre sulla VM worker eseguendo:
```sudo k3s ctr images import hello-docker.tar```

![e8f8b569-dc32-4b26-83d8-6fd1be91f482](https://github.com/user-attachments/assets/7eb28f08-600b-47cd-8ed6-7d6db4614f98)

Il risultato è che ora anche il nodo worker conosce l'immagine hello-docker:latest, quindi può avviare il pod correttamente
che risulterà regolarmente in stato running come dimostrato nello screenshot sottostante.

![609f5f78-e57e-42f8-882a-64ee6d7ac8dc](https://github.com/user-attachments/assets/6e192821-4e45-4db4-96e4-7087c5915a65)

Come volevasi dimostrare, il meccanismo "scheduling" è stato attuato correttamente per bilanciare il carico tra i nodi disponibili in modo efficiente.

L'obiettivo finale del mio progetto era quello di realizzare un'infrastruttura completa e funzionante che integra provisioning cloud,
containerizzazione, orchestrazione, gestione del codice, seguendo le migliori pratiche DevOps.
```Nello screenshot sottostante mostro che a progetto concluso, inserendo l'IP pubblico della VM master,
e usando il protocollo HTTP e la porta 30080 assegnatami, avrò questo risultato:
```

![image](https://github.com/user-attachments/assets/02daee58-1d1d-4c5c-9e8e-ad33d81056b2)


# Parte 2 del progetto con file SH
La seconda parte del progetto prevede la creazione di un file SH, nel mio caso l'ho chiamato progetto-experis.sh (contenuto presente in lista file)
e l'ho creato nella VM master per evitare di creare altre di inizzializzare un progetto da 0 e rischiare che la sottoiscrizione gratuita non lo permettesse.

Lo scopo è quello di ripercorrere step by step tutti i comandi che hanno portato alla riuscita del progetto principale e di ordinarli e testarli nuovamente.

## Preparazione file sh
Ho usato la stessa cartella del progetto principale (Hello docker) e all'interno ho creato il file progetto-experis.sh e ne ho modificato il contenuto in nano.

### Installazione docker
il comando è il seguente: ```curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker```

### Installazione di K3s sulla VM master
Ho usato questo comando: ```curl -sfL https://get.k3s.io | sh -```
E ho verificato se fosse andato a buon fine utilizzando: ```kubectl get nodes ```

### Build dell'app Node.js
Ho direttamente lanciato il comando per buildare l'app in quanto usando la stessa cartella della prima parte del progetto
i file package.json, app,js e Dockerfile erano già pronti e funzionanti.
```docker build -t hello-docker-test .```

### Esportazione e trasferimento immagine
Da qui ho avuto vari problemi con i comandi usati in precedenza: ```docker save hello-docker-test:latest -o hello-docker-test.tar```

```scp hello-docker-test.tar darienzogaia@10.0.1.4:/home/darienzogaia/``` 

Perchè l'immagine docker risultava corrotta o incompleta quando cercavo di trasferirla sulla VM worker

![image](https://github.com/user-attachments/assets/8112f306-941c-4f63-8890-623cc657f580)

Ho avuto modo di capire che quest'errore succede spesso quando la copia del file .tar non è stata completamente
generato o chiusa correttamente da docker save.

### Risoluzione errore
Ho ricreato il file .tar sulla VM master con un nome nuovo
![image](https://github.com/user-attachments/assets/c9c86e6e-a443-40bf-b50f-6c6fafc2e8d1)

Poi ho verificato che avesse una dimensione non elevata
![image](https://github.com/user-attachments/assets/a06ba981-dff0-430e-9a0b-01a93bac84ff)

Ho rimosso i file corrotti eventualmente presenti usando: ```rm -f hello-docker-test-backup.tar```
e ho continuato importando correttamente l'immagine sulla VM worker

![image](https://github.com/user-attachments/assets/37be3aad-2de4-470c-8399-17c7a4723507)

Mi sono assicurata che ci fosse, senza compromettere l'immagine della parte iniziale del progetto poichè ne ho creata una
nuova con un nome diverso per distinguerle.

![image](https://github.com/user-attachments/assets/5c60e9e3-4ff7-45d7-964f-58429adff2e4)


### Deployment su k3s
qui ho creato 2 file diversi per evitare che andassero a compromettere i POD della prima parte del progetto
ecco il deployment.yaml:

![image](https://github.com/user-attachments/assets/8616bb6c-ea5c-44b2-b47f-2dfb707ca707)

mentre il service.yaml è così:

![image](https://github.com/user-attachments/assets/9d786e0d-725e-414c-9980-271504898f6a)

li ho entrambi deployati usando i seguenti comandi:
```kubectl apply -f deploymentTest.yaml```
```kubectl apply -f servicetest.yaml```

Nel servicetest.yaml ho usato la porta 30081 perchè la 30080 era già occupata dalla prima parte del progetto.

Fatto ciò mi sono assicuarata che i pod girassero correttamente prima di testare:
![image](https://github.com/user-attachments/assets/78613cd8-3687-42b8-bc0d-1eb99b0b0924)

I primi 3 riguardano la prima parte del progetto, gli ultimi 3 la seconda, e come volevasi dimostrare, lo status è regolarmente in "running"

Verificato ciò, ho provato ad accedere all'app cercando ```http://20.160.77:30081``` e il risultato è il seguente:

![image](https://github.com/user-attachments/assets/6d56ce2a-a349-4818-9277-193d440108ad)


## Conclusione
Alla fine, ho rifatto tutto l’esercizio utilizzando uno script .sh, seguendo gli stessi passaggi del progetto principale ma con qualche comando modificato.
Ho lavorato direttamente dalla VM master, senza dover ricreare tutto da capo, così da non toccare l’infrastruttura già funzionante.
Questo mi ha permesso di testare l’intero processo da zero, verificare che tutto funzionasse correttamente e soprattutto di consolidare quanto imparato su Docker, K3s e il funzionamento dei pod.

































