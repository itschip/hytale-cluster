FROM eclipse-temurin:25-jre

RUN apt-get update && apt-get install -y curl unzip binutils jq && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -L https://downloader.hytale.com/hytale-downloader.zip -o hytale-downloader.zip \
    && unzip hytale-downloader.zip \
    && mv hytale-downloader-linux-amd64 hytale-downloader || mv linux-amd64/hytale-downloader hytale-downloader || true \
    && chmod +x hytale-downloader \
    && rm hytale-downloader.zip

COPY config/ /app/config/
COPY server-files/mods/ /app/mods/

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

EXPOSE 5520
EXPOSE 7003

VOLUME /app/data

ENTRYPOINT ["/app/start.sh"]
