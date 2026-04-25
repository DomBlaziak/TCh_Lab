# Zadanie nr 1 (Część Nieobowiązkowa)
Niniejsze sprawozdanie opisuje realizację wymagań dodatkowych, w tym wdrożenie zaawansowanego procesu budowania obrazu z wykorzystaniem 
narzędzia Docker BuildX oraz Wariantu 3 (pobieranie źródeł przez SSH).

# 1. Konfiguracja środowiska BuildX
Zgodnie z wymaganiami, do realizacji budowy wieloplatformowej oraz obsługi zaawansowanych mechanizmów cache, niezbędne jest utworzenie nowego buildera 
korzystającego ze sterownika docker-container. Standardowy builder "default" nie wspiera zaawansowanych funkcji, takich jak eksport cache'u do rejestru 
czy budowa wieloarchitekturowa. 

Utworzenie i jednoczesne uruchomienie nowego buildera z obsługą silnika BuildKit:
  
    docker buildx create --name mybuilder --driver docker-container --bootstrap --use

# 2. Architektura pliku Dockerfile.multi
W tej części zadania opracowano dedykowany plik Dockerfile_Multi, który implementuje zaawansowany mechanizm pobierania kodu źródłowego za pomocą SSH Mount.

**Separacja źródeł:** Kod nie jest kopiowany z lokalnego systemu plików (COPY), lecz klonowany bezpośrednio z repozytorium GitHub wewnątrz tymczasowej warstwy budowania.

**Bezpieczeństwo (BuildKit):** Klucz prywatny SSH jest montowany tylko na czas wykonania instrukcji RUN. Nie jest on kopiowany do obrazu, nie zostaje w warstwach i nie wycieka do rejestru Docker Hub.

**Dedykowany Builder:** Proces wykorzystuje obraz bazowy z zainstalowanym klientem git i openssh, który zostaje całkowicie odrzucony w końcowym etapie (multi-stage).

Treść pliku Dockerfile_Multi:
```dockerfile
# Rozszerzony frontend dla aplikacji pogodowej
# syntax=docker/dockerfile:1.3

# Budowanie i pobieranie źródeł (Builder)
FROM node:24-alpine AS builder

# Instalacja narzędzi niezbędnych do klonowania przez SSH
RUN apk add --no-cache git openssh-client

# Konfiguracja bezpiecznych hostów dla GitHub
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts

# Ustawienie katalogu roboczego dla budowania
WORKDIR /build

# Pobieranie kodu z repozytorium przez SSH Mount
RUN --mount=type=ssh,id=z1_git git clone git@github.com:DomBlaziak/TCh_Lab.git repo && \
    cp -r repo/src . && \
    cp repo/package.json . && \
    rm -rf repo

# Instalacja zależności produkcyjnych
RUN npm install --production && npm cache clean --force

# Obraz końcowy (Produkcyjny)
FROM node:24-alpine

# Metadane OCI
LABEL org.opencontainers.image.authors="Dominik Blaziak" \
      org.opencontainers.image.title="WeatherApp_Zadanie_1" \
      org.opencontainers.image.description="Aplikacja pogodowa - Zadanie 1 - Technologie Chmurowe" \
      org.opencontainers.image.source="https://github.com/DomBlaziak/TCh_Lab"

# Aktualizacja systemu i instalacja curl dla healthcheck
RUN apk update && apk upgrade --no-cache && apk add --no-cache curl

# Dedykowany użytkownik (Bezpieczeństwo)
RUN addgroup -S nodeapp && adduser -S nodeapp -G nodeapp

# Przełączamy się na użytkownika nodeapp
USER nodeapp

# Ustawiamy katalog roboczy dla aplikacji
WORKDIR /home/nodeapp/app

# Kopiowanie plików z uprawnieniami dla użytkownika nodeapp
COPY --from=builder --chown=nodeapp:nodeapp /build/node_modules ./node_modules
COPY --from=builder --chown=nodeapp:nodeapp /build/src ./src
COPY --from=builder --chown=nodeapp:nodeapp /build/package.json ./package.json

# Healthcheck - z użyciem curl
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Port aplikacji
EXPOSE 3000

# Uruchomienie aplikacji
ENTRYPOINT ["node", "src/bin/www"]
```
# 3. Realizacja budowy wieloplatformowej (Multi-arch)
Wykorzystując wcześniej skonfigurowany builder oraz zaawansowane flagi silnika BuildKit, uruchomiono proces budowania obrazu dla dwóch architektur:

  **-> linux/amd64** – architektura dla standardowych procesorów Intel/AMD.

  **-> linux/arm64** – architektura dla procesorów Apple Silicon (M1/M2/M3) oraz układów typu Raspberry Pi.

Pełne polecenie budujące:

    docker buildx build -f Dockerfile_Multi --platform linux/amd64,linux/arm64 \
    --ssh z1_git=$PATH_TO_SSH_KEY \
    -t $DOCKER_USER/$REPOSITORY_NAME:$TAG \
    --cache-to type=registry,ref=$CACHE_REPO,mode=max \
    --cache-from type=registry,ref=$CACHE_REPO \
    --push .

  Objaśnienie zmiennych:

  **$PATH_TO_SSH_KEY** – lokalna ścieżka do klucza prywatnego SSH (np. ~/.ssh/id_rsa).

  **$DOCKER_USER/$REPOSITORY_NAME:$TAG** – pełny identyfikator obrazu w formacie wymaganym przez Docker Hub (użytkownik/nazwa:wersja).

  **$CACHE_REPO** – adres repozytorium przeznaczonego na dane cache (zazwyczaj to samo repozytorium z dodatkowym tagiem :cache).

**===========================================================================================**
  
  **Wyjaśnienie poszczególnych etapów polecenia:**

**--platform:** Pozwala stworzyć jeden obraz, który zadziała na różnych procesorach. Docker sam zadba o to, by użytkownik pobrał wersję pasującą do jego sprzętu.

**--ssh z1_git:** Umożliwia bezpieczne połączenie z GitHubem podczas budowania obrazu. Dzięki temu Docker może pobrać kod źródłowy za pomocą Twojego klucza SSH, ale sam klucz nie zostanie zapisany wewnątrz gotowego obrazu (jest bezpieczny).

**--cache-to/from:** Implementacja Cache Registry. Zamiast przechowywać warstwy cache lokalnie, są one przesyłane do zewnętrznego rejestru Docker Hub. 
Pozwala to na drastyczne przyspieszenie budowania obrazu w środowiskach rozproszonych i CI/CD. 

**--push:** Powoduje, że po zakończeniu budowania obraz od razu trafia na Twój profil na Docker Hub. Nie musisz wpisywać dodatkowego polecenia docker push.

# 4. Analiza bezpieczeństwa i optymalizacja (Docker Scout)

Obraz został poddany szczegółowej analizie pod kątem podatności (CVE) przy użyciu narzędzia Docker Scout. 
Proces optymalizacji pozwolił na redukcję łącznej liczby luk z 33 do zaledwie kilku pozycji o niskim wpływie na działanie aplikacji.

**Proces optymalizacji:**

W początkowej fazie projektowania obraz bazowy node:20 generował 33 podatności (w tym 2 krytyczne i 13 wysokich). Wprowadzono następujące zmiany:

  **Zmiana fundamentu obrazu:** Przejście na node:24-alpine zredukowało liczbę podatności systemowych o ponad 80%.

  **Zarządzanie zależnościami:** Zastąpienie biblioteki request nowoczesnym klientem axios oraz użycie sekcji overrides w package.json pozwoliło wyeliminować krytyczne luki w paczkach ejs, tar oraz form-data.

  **Aktualizacja systemowa:** Instrukcja RUN apk update && apk upgrade --no-cache wymusiła instalację najnowszych łatek bezpieczeństwa dostępnych w repozytoriach Alpine.

Polecenie wykonujące skanowanie:
    
    docker scout quickview $DOCKER_USER/$REPOSITORY_NAME:$TAG

    docker scout cves $DOCKER_USER/$REPOSITORY_NAME:$TAG


Wynik analizy Scout wykazał osiągnięcie 0 podatności krytycznych (Critical). 
W obrazie pozostały jedynie 3 luki klasy High, których szczegółowa analiza wykazała brak realnego zagrożenia dla projektu:

**1. Luka aplikacji: picomatch 4.0.3 (Status: Pozostawiona świadomie)**

  Zagrożenie: CVE-2026-33671 (Inefficient Regular Expression Complexity).

  Podatność ta dociągana jest jako zależność przechodnia przez framework Express. Chociaż wersja 4.0.4 zawiera poprawkę, zdecydowano o pozostaniu przy 4.0.3. 
  Luka ta polega na teoretycznej możliwości spowolnienia procesora przy specyficznych zapytaniach, co w przypadku prostej aplikacji pogodowej nie stanowi realnego        ryzyka. Ręczne wymuszanie nowszej wersji (overrides) mogłoby spowodować regresję i błędy w działaniu serwera, gdyż picomatch jest krytycznym modułem niskiego           poziomu.

**2. Luki systemowe: curl oraz nghttp2 (Status: Unfixable)**

  Zagrożenie: Luki w bibliotekach obsługujących protokoły sieciowe dostarczanych przez obraz Alpine 3.23.

Mimo wykonania pełnej aktualizacji systemu (apk upgrade), raport Scout klasyfikuje te luki jako "unfixable". Oznacza to, że w oficjalnych repozytoriach dystrybucji Alpine nie ma obecnie nowszych wersji binariów rozwiązujących te problemy. Są one niemożliwe do usunięcia na poziomie konfiguracji kontenera do czasu wydania łatek przez opiekunów dystrybucji.


Dzięki wdrożonym poprawkom wyeliminowano wszystkie błędy pozwalające na zdalne wykonanie kodu czy wyciek danych (Path Traversal). 
Obecny obraz charakteryzuje się najwyższym możliwym poziomem bezpieczeństwa przy zachowaniu stabilności środowiska uruchomieniowego Node.js.


# 5. Weryfikacja wieloplatformowości
Wykorzystano narzędzie imagetools, które odpytuje zdalne repozytorium o dostępne wersje architekturalne bez konieczności pobierania całego obrazu na dysk.

Polecenie weryfikujące:

     docker buildx imagetools inspect $DOCKER_USER/$REPOSITORY_NAME:$TAG

Wynik potwierdza, że pod jednym tagiem ukryte są dwie wersje binarne. W sekcji Platforms widnieją wpisy dla linux/amd64 oraz linux/arm64, co stanowi dowód poprawnej realizacji zadania.


*Zrzuty ekranu potwierdzające powyższe punkty zostały dołączone do sprawozdania głównego (PDF).*