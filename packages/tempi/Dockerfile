# syntax=docker/dockerfile:1

FROM oven/bun:1.1.31-alpine AS build
WORKDIR /app

# Copy the Svelte timer source into the build stage
COPY Tempi.app/ ./

# Ensure dependencies are installed inside the container
RUN rm -rf node_modules \
    && bun install --frozen-lockfile \
    && bun run build

FROM nginx:1.27-alpine AS runner

# Clean default html assets and add the static build output
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /app/build /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
