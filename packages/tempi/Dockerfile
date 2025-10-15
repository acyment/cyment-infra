# syntax=docker/dockerfile:1

FROM node:22.12-alpine AS build
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache bash

# Install dependencies and build the static bundle
COPY Tempi.app/package.json ./
RUN npm install
COPY Tempi.app/ ./
RUN npm run build

FROM nginx:1.27-alpine AS runner

# Clean default html assets and add the static build output
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/build /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
