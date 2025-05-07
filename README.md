# progetto-finale-experis
Per affrontare questo progetto abbiamo bisogno dell'estensione Terraform in Visual studio code e di fare un az login per far si che terraform capisca che le risorse vengano create tutte su Azure.

# Con az login impostiamo il nostro account con la sottoscrizione
az login
az account set --subscription "20942a39-e96c-4873-90b7-2c3f63481183"

# Provisioning dell'infrastruttura con Terraform
Ho scritto uno script Terraform suddiviso in più file (main.tf, variables.tf, output.tf) per creare su azure le seguenti risorse:
1 gruppo risorse --> contenitore logico delle risorse
1 virtual network con una subnet
1 network security group con regole in ingresso
2 macchine virtuali linux Ubuntu con:
Ip pubblico per SSH e accesso web
autenticazione tramite username e password

# Ho configurato le regole di sicurezza per aprire le porte
22 --> accesso SSH
80 --> per l'accesso in HTTP
30080 --> porta Nodeport per esporre l'app in K8s 

![image](https://github.com/user-attachments/assets/81893a37-2a5c-45c5-881a-5b541c775fae)
il risultato atteso è il seguente.
#Errori principali riscontrati 
Terraform non riusciva a creare le VM 
