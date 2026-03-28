# Multi-stage Dockerfile for Meshtastic Web Client
# Stage 1: Build the web application
FROM node:24-alpine AS builder

RUN npm install -g pnpm@10.32.1

WORKDIR /app

# Copy workspace config and lockfile first for better caching
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY packages/core/package.json packages/core/
COPY packages/transport-http/package.json packages/transport-http/
COPY packages/transport-web-bluetooth/package.json packages/transport-web-bluetooth/
COPY packages/transport-web-serial/package.json packages/transport-web-serial/
COPY packages/web/package.json packages/web/
COPY packages/ui/package.json packages/ui/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source files
COPY tsconfig.base.json tsconfig.json ./
COPY packages/ packages/

# Build the web package and its workspace dependencies
RUN pnpm run --filter '@meshtastic/core' \
    --filter '@meshtastic/transport-http' \
    --filter '@meshtastic/transport-web-bluetooth' \
    --filter '@meshtastic/transport-web-serial' \
    --filter 'meshtastic-web' build

# Stage 2: Serve with nginx
FROM nginx:1.29.1-alpine-slim

RUN rm -rf /usr/share/nginx/html && \
    mkdir -p /usr/share/nginx/html /etc/nginx/conf.d

COPY packages/web/infra/default.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/packages/web/dist /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
