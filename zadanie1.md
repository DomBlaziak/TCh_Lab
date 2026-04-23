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
    #Budowanie obrazu (Builder)
    #Wykorzystanie lekkiego obrazu bazowego Alpine w celu optymalizacji
    FROM node:20-alpine AS builder

    #Katalog roboczy dla procesu budowania
    WORKDIR /build

    #Optymalizacja cache-a: najpierw kopiujemy tylko pliki definicji zależności
    COPY package.json .

    #Instalacja tylko zależności produkcyjnych i czyszczenie cache npm
    RUN npm install --production && npm cache clean --force

    #Kopiowanie reszty kodu źródłowego z folderu src
    COPY src/ ./src/

    #Finalny obraz produkcyjny
    FROM node:20-alpine

    #Dane autora zgodnie ze standardem OCI (Open Container Initiative)
    LABEL org.opencontainers.image.authors="Dominik Błaziak"

    #Instalacja curl niezbędnego do działania mechanizmu HEALTHCHECK
    RUN apk add --no-cache curl

    #Tworzenie dedykowanej grupy i użytkownika (bezpieczeństwo - unikanie konta root)
    RUN addgroup -S nodeapp && adduser -S nodeapp -G nodeapp
    USER nodeapp

    WORKDIR /home/nodeapp/app

    #Kopiowanie tylko niezbędnych plików z etapu budowania (minimalizacja warstw)
    COPY --from=builder --chown=nodeapp:nodeapp /build/node_modules ./node_modules
    COPY --from=builder --chown=nodeapp:nodeapp /build/src ./src
    COPY --from=builder --chown=nodeapp:nodeapp /build/package.json .

    #Definicja mechanizmu Healthcheck
    HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
        CMD curl -f http://localhost:3000/ || exit 1

    #Port, na którym nasłuchuje kontener
    EXPOSE 3000

    #Uruchomienie aplikacji
    ENTRYPOINT ["node", "src/bin/www"]
```
-> **Multi-stage Build:** Pozwala na odizolowanie środowiska kompilacji od środowiska uruchomieniowego, 
dzięki czemu obraz końcowy nie zawiera zbędnych narzędzi.

-> **Alpine Linux:** Zastosowanie tej dystrybucji pozwala zredukować rozmiar obrazu do minimum.

-> **Zasada najniższych uprawnień:** Aplikacja działa jako użytkownik nodeapp, a nie root, co ogranicza skutki potencjalnego ataku.

# 3. Instrukcja wdrożeniowa i polecenia
Przed przystąpieniem do budowy należy pobrać repozytorium i  wejść do folderu z plikami:
    
    git clone https://github.com/DomBlaziak/TCh_Lab.git
    cd TCh_Lab
    
a) Budowanie obrazu
Przykładowy proces budowania wykorzystuje lokalny kontekst i standardowe narzędzie Docker Build:
    
    docker build -t dblaziak/repozytorium_1:latest .
    
b) Uruchomienie kontenera
Uruchomienie w trybie odłączonym (-d) z przekierowaniem portu 3000 z hosta na port 3000 kontenera (Przykładowe polecenie):

    docker run -d -p 3000:3000 --name weather-app-container dblaziak/repozytorium_1:latest

c) Uzyskanie informacji z logów
Weryfikacja danych startowych:

    docker logs weather-app-container

d) Sprawdzenie warstw i rozmiaru obrazu
Aby sprawdzić rozmiar obrazu zapisanego lokalnie:

    docker images dblaziak/repozytorium_1:latest

Aby przeanalizować strukturę warstw oraz ich wielkość:

    docker history dblaziak/repozytorium_1:latest

# 4. Potwierdzenie działania
Poprawność wdrożenia aplikacji można zweryfikować na dwa sposoby:

1. **Interfejs WWW:** Pod adresem `http://localhost:3000` dostępny jest UI, który pozwala wybrać miasto z listy i wyświetlić aktualne dane pogodowe.
2. **Weryfikacja logów:** Wykonanie polecenia `docker logs weather-app-container` potwierdza poprawną inicjalizację aplikacji. 
W terminalu wyświetlane są dane autora, aktualna data oraz port nasłuchiwania..



*Zrzuty ekranu potwierdzające powyższe punkty zostały dołączone do sprawozdania głównego (PDF).*
    


