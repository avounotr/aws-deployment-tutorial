FROM node:8.9

WORKDIR /usr/src/app

COPY package.json .
RUN npm install
COPY . .

EXPOSE 3000
CMD [ "node", "server.js" ]
