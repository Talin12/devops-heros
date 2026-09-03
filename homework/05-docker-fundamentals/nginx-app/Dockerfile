# ---- Nginx Hello World ----
FROM nginx:alpine

# nginx serves everything inside /usr/share/nginx/html/
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
# base image already runs: nginx -g 'daemon off;'
