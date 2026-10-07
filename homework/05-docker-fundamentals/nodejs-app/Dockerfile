# ---- Node.js Hello World ----
FROM node:20-alpine

WORKDIR /app

# copy only manifest first so npm install is cached
COPY package.json ./
RUN npm install --omit=dev

COPY server.js ./

EXPOSE 3000
CMD ["node", "server.js"]
