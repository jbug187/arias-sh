# Runs nginx as a non-root user on port 8080. Version pinned; Dependabot proposes updates.
FROM nginxinc/nginx-unprivileged:1.31.6-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY public/ /usr/share/nginx/html/

EXPOSE 8080
