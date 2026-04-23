Zadanie nr 1 (Część Obowiązkowa)
Niniejsze repozytorium zawiera realizację zadania nr 1, polegającego na konteneryzacji autorskiej aplikacji pogodowej.

a) Logowanie przy starcie
Podczas inicjalizacji serwer automatycznie wypisuje w standardowym strumieniu wyjściowym (logs) kluczowe informacje. 
Kod odpowiedzialny za tę funkcjonalność znajduje się w głównym pliku serwera (dostępny w folderze src/bin repozytorium):

// Przykład implementacji z src/bin/www:
const AUTHOR = "Dominik Błaziak";
const PORT = process.env.PORT || '3000';
const START_DATE = new Date().toLocaleString('pl-PL');

var server = http.createServer(app);

server.listen(PORT, () => {
    console.log(`[DATA]: ${START_DATE}`);
    console.log(`[AUTOR]: ${AUTHOR}`);
    console.log(`[PORT]: ${PORT}`);
    console.log(`Serwer pogodowy uruchomiony poprawnie.`);
});

b) Funkcjonalność pogodowa
Aplikacja udostępnia interfejs webowy, w którym użytkownik może wybrać miasto z predefiniowanej listy. 
Po zatwierdzeniu wyboru, serwer komunikuje się z zewnętrznym API pogodowym i wyświetla dane (temperaturę) bezpośrednio w przeglądarce.
Pełny kod źródłowy: Wszystkie pliki logiki, widoków i stylów znajdują się w folderze src/.

2. Plik Dockerfile
Opracowany plik Dockerfile został zoptymalizowany pod kątem wydajności budowania oraz bezpieczeństwa środowiska uruchomieniowego.

# Budowanie obrazu (Builder)
# Wykorzystanie lekkiego obrazu bazowego Alpine w celu optymalizacji
FROM node:20-alpine AS builder

# Katalog roboczy dla procesu budowania
WORKDIR /build

# Optymalizacja cache-a: najpierw kopiujemy tylko pliki definicji zależności
COPY package.json .

# Instalacja zależności produkcyjnych
RUN npm install --production && npm cache clean --force

# Kopiowanie reszty kodu źródłowego z folderu src
COPY src/ ./src/

# ETAP 2: Finalny obraz produkcyjny
FROM node:20-alpine

# Dane autora zgodnie ze standardem OCI (Open Container Initiative)
LABEL org.opencontainers.image.authors="Dominik Błaziak"

# Instalacja curl niezbędnego do działania mechanizmu HEALTHCHECK
RUN apk add --no-cache curl

# Tworzenie dedykowanej grupy i użytkownika (bezpieczeństwo - unikanie konta root)
RUN addgroup -S nodeapp && adduser -S nodeapp -G nodeapp
USER nodeapp

WORKDIR /home/nodeapp/app

# Kopiowanie tylko niezbędnych plików z etapu builder (minimalizacja warstw)
COPY --from=builder --chown=nodeapp:nodeapp /build/node_modules ./node_modules
COPY --from=builder --chown=nodeapp:nodeapp /build/src ./src
COPY --from=builder --chown=nodeapp:nodeapp /build/package.json .

# Definicja mechanizmu Healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Port, na którym nasłuchuje kontener
EXPOSE 3000

# Uruchomienie aplikacji
ENTRYPOINT ["node", "src/bin/www"]


3. Instrukcja obsługi i polecenia
Poniżej znajdują się polecenia niezbędne do zarządzania kontenerem:
Zanim rozpoczniemy budowę należy pobrać dostępne repozytorium i przejść do wnętrza katalogu:
git clone 
cd Tch_Lab
a) Budowanie obrazu
Przykładowy proces budowania wykorzystuje lokalny kontekst i standardowe narzędzie Docker Build:

docker build -t dblaziak/repozytorium_1:latest .

b) Uruchomienie kontenera
Uruchomienie w trybie odłączonym (-d) z przekierowaniem portu 3000 z hosta na port 3000 kontenera (Przykładowe polecenie:

docker run -d -p 3000:3000 --name weather-app-container dblaziak/repozytorium_1:latest

c) Uzyskanie informacji z logów
Weryfikacja danych startowych:

docker logs weather-app-container

d) Sprawdzenie warstw i rozmiaru obrazu
Aby sprawdzić rozmiar obrazu zapisanego lokalnie:

docker images dblaziak/repozytorium_1:latest

Aby przeanalizować strukturę warstw oraz ich wielkość:

docker history dblaziak/repozytorium_1:latest

4. Potwierdzenie działania

W sprawozdaniu (plik PDF) zamieszczono zrzuty ekranu okna przeglądarki potwierdzające:
    
  -> Prawidłowe wyświetlanie logów w terminalu (polecenie z punktu 3c).

  -> Interfejs użytkownika z poprawnie pobraną pogodą dla wybranego miasta pod adresem http://localhost:3000 po uruchomieniu kontenera.
