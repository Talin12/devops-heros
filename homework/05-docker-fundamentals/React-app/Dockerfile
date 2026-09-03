# ---- React Hello World (multi-stage build) ----

# Stage 1: build the React app with Node
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build          # produces the static bundle in /app/dist

# Stage 2: serve the static bundle with Nginx (tiny final image)
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
