# Rozszerzony frontend dla aplikacji pogodowej
# syntax=docker/dockerfile:1.3

# Budowanie i pobieranie źródeł (Builder)
FROM node:20-alpine AS builder

# Instalacja narzędzi niezbędnych do klonowania przez SSH
RUN apk add --no-cache git openssh-client

# Konfiguracja bezpiecznych hostów dla GitHub
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Ustawienie katalogu roboczego dla budowania
WORKDIR /build

# Pobieranie kodu z repozytorium przez SSH Mount
RUN --mount=type=ssh,id=s56git git clone git@github.com:DomBlaziak/TCh_Lab.git repo && \
    cp -r repo/src . && \
    cp repo/package.json . && \
    rm -rf repo

# Instalacja zależności produkcyjnych
RUN npm install --production && npm cache clean --force

# Obraz końcowy (Produkcyjny)
FROM node:20-alpine

# Metadane OCI
LABEL org.opencontainers.image.authors="Dominik Blaziak" \
      org.opencontainers.image.title="WeatherApp_Zadanie_1" \
      org.opencontainers.image.description="Aplikacja pogodowa - Zadanie 1 - Technologie Chmurowe" \
      org.opencontainers.image.source="https://github.com/DomBlaziak/TCh_Lab"

# Dołączamy curl do etapu końcowego (do healthchecka)
RUN apk add --no-cache curl

# Dedykowany użytkownik (Bezpieczeństwo)
RUN addgroup -S nodeapp && adduser -S nodeapp -G nodeapp
USER nodeapp
WORKDIR /home/nodeapp/app

# Kopiowanie plików z uprawnieniami dla użytkownika nodeapp
COPY --from=builder --chown=nodeapp:nodeapp /build/node_modules ./node_modules
COPY --from=builder --chown=nodeapp:nodeapp /build/src ./src

# Healthcheck - z użyciem curl
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Port aplikacji
EXPOSE 3000

# Uruchomienie aplikacji
ENTRYPOINT ["node", "src/bin/www"]