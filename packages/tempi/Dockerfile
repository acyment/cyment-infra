# syntax=docker/dockerfile:1

FROM oven/bun:1.1-alpine AS build
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache bash

# Install dependencies and build the static bundle
COPY Tempi.app/package.json ./
COPY Tempi.app/bun.lock ./bun.lock
RUN bun install
COPY Tempi.app/ ./
RUN bun run build

FROM nginx:1.27-alpine AS runner

# Clean default html assets and add the static build output
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/build /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
