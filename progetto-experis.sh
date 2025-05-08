 #!/bin/bash

echo " 1. INSTALLAZIONE DOCKER"
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

echo " 2. INSTALLAZIONE K3s SULLA MASTER"
curl -sfL https://get.k3s.io | sh -

echo " Verifica cluster:"
sudo kubectl get nodes

echo " 3. PREPARAZIONE APP"
cd ~/hello-docker

echo " 4. BUILD IMMAGINE DOCKER"
docker build -t hello-docker .

echo " 5. ESPORTO L'IMMAGINE DOCKER"
docker save hello-docker:latest -o hello-docker.tar

echo " 6. COPIO L'IMMAGINE SULLA WORKER (IP 10.0.1.4)"
scp hello-docker.tar darienzogaia@10.0.1.4:/home/darienzogaia/

echo " 7. IMPORT IMMAGINE NELLA MASTER"
sudo k3s ctr images import hello-docker.tar

echo " Ora accedo alla WORKER ed eseguo:"
echo "    sudo k3s ctr images import hello-docker.tar"
echo

echo " 8. DEPLOY DELL'APPLICAZIONE"
kubectl apply -f deploymentTest.yaml
kubectl apply -f servicetest.yaml

echo " 9. VERIFICA STATO POD E SERVIZIO"
kubectl get pods -o wide
kubectl get svc

echo " 10. TEST DELL'APPLICAZIONE"
echo "Una volta controllato lo stato dei pod entrare nell'app usando l'IP pubblico:"
echo " http://20.160.162.77:30081"

echo " OPERAZIONE COMPLETATA! L'app è disponibile in locale su porta 30081 e restituisce: Hello, World!




