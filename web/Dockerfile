# syntax=docker/dockerfile:1

# Stage 1: build the static site with Vite.
FROM node:20-alpine AS build
ARG APP_VERSION=dev
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN APP_VERSION=${APP_VERSION} npm run build

# Stage 2: serve the static files with Caddy as an unprivileged user.
FROM caddy:2.10-alpine AS runtime
ARG APP_VERSION=dev
LABEL org.opencontainers.image.version="${APP_VERSION}"
# Port 8080 needs no privileges, so drop the file capability the upstream
# binary carries; with cap_drop: ALL and no-new-privileges it could not start.
RUN apk add --no-cache libcap \
 && setcap -r /usr/bin/caddy \
 && apk del libcap \
 && addgroup -S web && adduser -S -G web -H -h /nonexistent web
ENV XDG_CONFIG_HOME=/tmp/caddy-config XDG_DATA_HOME=/tmp/caddy-data
COPY Caddyfile /etc/caddy/Caddyfile
COPY --from=build /app/dist /srv
USER web
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8080/ || exit 1
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
