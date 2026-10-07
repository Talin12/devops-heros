FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Unprivileged nginx: runs as uid 101 and listens on 8080 instead of 80.
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
# Files in /etc/nginx/templates are run through envsubst at start-up, so the
# same image proxies to "backend" in Compose and "taskboard-backend" in Kubernetes.
COPY nginx.conf /etc/nginx/templates/default.conf.template
ENV BACKEND_URL=http://backend:8000
EXPOSE 8080
