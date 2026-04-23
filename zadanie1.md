# Zadanie nr 1 (Część Obowiązkowa)
Niniejsze repozytorium zawiera realizację zadania nr 1, polegającego na konteneryzacji autorskiej aplikacji pogodowej.

# 1. Architektura aplikacji
Aplikacja została zbudowana przy użyciu środowiska Node.js oraz frameworka Express. Została zaprojektowana zgodnie z architekturą klient-serwer, gdzie backend komunikuje się z zewnętrznymi usługami API w celu pobrania rzeczywistych danych meteorologicznych.

# 1a. Logowanie przy starcie
Podczas inicjalizacji serwer automatycznie wypisuje w standardowym strumieniu wyjściowym kluczowe informacje. 
Kod odpowiedzialny za tę funkcjonalność znajduje się w głównym pliku serwera src/bin/www:

Przykład implementacji z src/bin/www:
```javascript    
    #Implementacja logowania parametrów startowych
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
```
# 1b. Funkcjonalność pogodowa
Aplikacja udostępnia interfejs webowy, w którym użytkownik może wybrać miasto z predefiniowanej listy. 
Po zatwierdzeniu wyboru, serwer komunikuje się z zewnętrznym API pogodowym i wyświetla dane (temperaturę) bezpośrednio w przeglądarce.
Pełna logika znajduje się w katalogu src/.


# 2. Plik Dockerfile
Opracowany plik Dockerfile wykorzystuje zaawansowane techniki konteneryzacji w celu zapewnienia minimalnego rozmiaru obrazu oraz maksymalnego bezpieczeństwa.
```dockerfile
   # Obraz Node.js w wersji 20-alpine jako bazowy obraz do budowania aplikacji
FROM node:20-alpine AS builder

# Katalog roboczy dla procesu budowania
WORKDIR /build

# Kopiujemy plik zależności
COPY package.json .

# Instalujemy zależności i budujemy aplikację
RUN npm install --production && npm cache clean --force

# Kopiujemy resztę plików źródłowych do katalogu roboczego
COPY src/ ./src/

# Obraz Node.js w wersji 20-alpine jako finalny obraz do uruchomienia aplikacji
FROM node:20-alpine

# Metadane OCI
LABEL org.opencontainers.image.authors="Dominik Blaziak"

# Instalacja curl do HEALTHCHECK
RUN apk add --no-cache curl

# Tworzymy użytkownika i grupę, aby aplikacja nie była uruchamiana jako root
RUN addgroup -S nodeapp && adduser -S nodeapp -G nodeapp

# Przełączamy się na użytkownika nodeapp
USER nodeapp

# Ustawiamy katalog roboczy dla aplikacji
WORKDIR /home/nodeapp/app

# Kopiujemy zbudowane pliki z etapu buildera do finalnego obrazu
COPY --from=builder --chown=nodeapp:nodeapp /build/node_modules ./node_modules
COPY --from=builder --chown=nodeapp:nodeapp /build/src ./src
COPY --from=builder --chown=nodeapp:nodeapp /build/package.json ./package.json

# Dodajemy HEALTHCHECK - sprawdzamy, czy aplikacja jest dostępna na porcie 3000
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Port, na którym nasza aplikacja będzie nasłuchiwać
EXPOSE 3000

# Uruchamiamy aplikację
ENTRYPOINT ["node", "src/bin/www"]
```
-> **Multi-stage Build:** Pozwala na odizolowanie środowiska kompilacji od środowiska uruchomieniowego, 
dzięki czemu obraz końcowy nie zawiera zbędnych narzędzi.

-> **Alpine Linux:** Zastosowanie tej dystrybucji pozwala zredukować rozmiar obrazu do minimum.

-> **Zasada najniższych uprawnień:** Aplikacja działa jako użytkownik nodeapp, a nie root, co ogranicza skutki potencjalnego ataku.

# 3. Instrukcja wdrożeniowa i polecenia
Przed przystąpieniem do budowy należy pobrać repozytorium i wejść do folderu z plikami:
    
    git clone https://github.com/DomBlaziak/TCh_Lab.git
    cd TCh_Lab
    
a) Budowanie obrazu
Aby zbudować obraz lokalnie, należy wykorzystać poniższe polecenie.
    
    docker build -t [NAZWA_OBRAZU]:[TAG] .
    
b) Uruchomienie kontenera
Uruchomienie w trybie odłączonym (-d) z przekierowaniem portu 3000 z hosta na port 3000 kontenera:

    docker run -d -p 3000:3000 --name weather-app-container [NAZWA_OBRAZU]:[TAG]

c) Uzyskanie informacji z logów
Weryfikacja danych startowych:

    docker logs weather-app-container

d) Sprawdzenie warstw i rozmiaru obrazu
Weryfikacja rozmiaru obrazu na dysku:

    docker images [NAZWA_OBRAZU]:[TAG]

Aby przeanalizować strukturę warstw oraz ich wielkość:

    docker history [NAZWA_OBRAZU]:[TAG]

# 4. Potwierdzenie działania
Poprawność wdrożenia aplikacji można zweryfikować na dwa sposoby:

1. **Interfejs WWW:** Pod adresem `http://localhost:3000` dostępny jest UI, który pozwala wybrać miasto z listy i wyświetlić aktualne dane pogodowe.
2. **Weryfikacja logów:** Wykonanie polecenia `docker logs weather-app-container` potwierdza poprawną inicjalizację aplikacji. 
W terminalu wyświetlane są dane autora, aktualna data oraz port nasłuchiwania..



*Zrzuty ekranu potwierdzające powyższe punkty zostały dołączone do sprawozdania głównego (PDF).*
    


