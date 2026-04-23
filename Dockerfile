# Obraz Node.js w wersji 20-alpine jako bazowego dla etapu budowania
FROM node:20-alpine AS builder

WORKDIR /build

# Kopiujemy pliki z lokalnego folderu (to co wgrałeś na GitHuba)
COPY package.json .
COPY src/ ./src/

# Instalujemy zależności i budujemy aplikację
RUN npm install --production && npm cache clean --force

FROM node:20-alpine
# Metadane OCI
LABEL org.opencontainers.image.authors="Dominik Blaziak"

# Instalacja curl do HEALTHCHECK
RUN apk add --no-cache curl

# Tworzymy użytkownika i grupę, aby aplikacja nie była uruchamiana jako root
RUN addgroup -S nodeapp && adduser -S nodeapp -G nodeapp
USER nodeapp

# Ustawiamy katalog roboczy dla aplikacji
WORKDIR /home/nodeapp/app

# Kopiujemy zbudowane pliki z etapu buildera do finalnego obrazu
COPY --from=builder --chown=nodeapp:nodeapp /build/node_modules ./node_modules
COPY --from=builder --chown=nodeapp:nodeapp /build/src ./src

# Dodajemy HEALTHCHECK - sprawdzamy, czy aplikacja jest dostępna na porcie 3000
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Port, na którym nasza aplikacja będzie nasłuchiwać
EXPOSE 3000

# Uruchamiamy aplikację
ENTRYPOINT ["node", "src/bin/www"]