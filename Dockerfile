# Base
FROM node:24-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack install --global pnpm@9.15.9
COPY . /app
WORKDIR /app

# Runtime
FROM node:24-alpine AS runtime
WORKDIR /app

# Prod Dependencies
FROM base AS prod-deps
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --frozen-lockfile

# Build
FROM base AS build
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
RUN pnpm run build

# Build Artifacts
FROM scratch AS extract
COPY --from=build /app/dist /dist

# Pterodactyl Image
FROM runtime AS pterodactyl
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/dist /app/dist
RUN node --check /app/dist/main.js

ENV NODE_ENV="production"
ENV DATABASE_URL="file:/home/container/dynamica/db.sqlite"
ARG VERSION
ENV VERSION=$VERSION

RUN adduser -H -D container -s /bin/sh
ENV  USER=container HOME=/home/container
USER container

HEALTHCHECK  --interval=5m --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

COPY entrypoint.sh /entrypoint.sh

CMD [ "/bin/sh", "/entrypoint.sh" ]

# Default Image
FROM runtime
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/dist /app/dist
RUN node --check /app/dist/main.js

ENV NODE_ENV="production"
ENV DATABASE_URL="file:/app/config/db.sqlite"
ARG VERSION
ENV VERSION=$VERSION

HEALTHCHECK  --interval=5m --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

CMD [ "node", "--enable-source-maps", "dist/main" ]
