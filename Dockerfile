# Usa un'immagine base di Node.js
FROM node:14

# Imposta la cartella di lavoro
WORKDIR /usr/src/app

# Copia il file package.json e installa le dipendenze
COPY package*.json ./
RUN npm install

# Copia il resto dell'applicazione
COPY . .

# Espone la porta su cui l'app ascolta
EXPOSE 3000

# Comando per avviare l'app
CMD ["npm", "start"]
