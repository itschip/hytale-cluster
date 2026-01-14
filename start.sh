#!/bin/bash

DATA_DIR="/app/data"
TEMP_ZIP="$DATA_DIR/hytale_update.zip"
VERSION_FILE="$DATA_DIR/current_version.txt"

echo "starting cluster"

if [ -f "$DATA_DIR/auth.enc" ]; then
    echo "sync auth files."
    cp "$DATA_DIR/auth.enc" ./auth.enc
    [ -f "$DATA_DIR/auth_tokens.json" ] && cp "$DATA_DIR/auth_tokens.json" ./auth_tokens.json
fi

if [ -f "/app/config/config.json" ]; then
    echo "syncing config.json"
    cp /app/config/config.json "$DATA_DIR/config.json"
    cp /app/config/config.json "$DATA_DIR/Server/config.json"
fi

if [ -f "/app/config/permissions-policy.json" ]; then
    mkdir -p "$DATA_DIR/Server"
    if [ -f "$DATA_DIR/Server/permissions.json" ]; then
        tmp=$(mktemp)
        jq -s '.[0] * .[1]' "$DATA_DIR/Server/permissions.json" "/app/config/permissions-policy.json" > "$tmp" && mv "$tmp" "$DATA_DIR/Server/permissions.json"
    else
        cp "/app/config/permissions-policy.json" "$DATA_DIR/Server/permissions.json"
    fi
fi

if [ -d "/app/mods" ]; then
    echo "syncing mods."
    mkdir -p "$DATA_DIR/Server/mods"
    find "$DATA_DIR/Server/mods" -mindepth 1 -delete
    cp -r /app/mods/. "$DATA_DIR/Server/mods/"
fi

echo "checking for updates..."

# I can just remove this. I thought shit was fucked, but shit was not fucked
#curl -Is https://api.hytale.com | head -n 1
#curl -Is https://accounts.hytale.com | head -n 1

mkdir -p "$HOME/.hytale"
if [ -f "./auth.enc" ]; then
    cp ./auth.enc "$HOME/.hytale/auth.enc"
    [ -f "./auth_tokens.json" ] && cp ./auth_tokens.json "$HOME/.hytale/auth_tokens.json"
fi

# now I have enough time to authenticate...yay
timeout 300s ./hytale-downloader -print-version || echo "timed out or failed to authenticate or refresh metadata?"

if [ -f "$HOME/.hytale/auth.enc" ]; then
    # kinda sus
    echo "updating auth files..."
    cp "$HOME/.hytale/auth.enc" "$DATA_DIR/auth.enc"
    [ -f "$HOME/.hytale/auth_tokens.json" ] && cp "$HOME/.hytale/auth_tokens.json" "$DATA_DIR/auth_tokens.json"
fi

LATEST_VERSION=$(./hytale-downloader -print-version 2>/dev/null | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}(-[a-f0-9]+)?' | tail -n 1)

INSTALLED_VERSION=$(cat "$VERSION_FILE" 2>/dev/null)

SERVER_JAR=$(find "$DATA_DIR" -name "HytaleServer.jar" | head -n 1)

if [ -z "$LATEST_VERSION" ]; then
    echo "falling back to local manifest." # this usually fails if I forget to authenticate
    LATEST_VERSION=$(./hytale-downloader -print-version -skip-update-check 2>/dev/null | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}(-[a-f0-9]+)?' | tail -n 1)
fi

echo "versions detected - installed: ${INSTALLED_VERSION:-None}, Latest: ${LATEST_VERSION:-Unknown}"

if [ -n "$LATEST_VERSION" ] && ([ "$LATEST_VERSION" != "$INSTALLED_VERSION" ] || [ -z "$SERVER_JAR" ] || [ ! -f "$DATA_DIR/Assets.zip" ]); then
    echo "starting download..."
    
    if [ ! -f "./auth.enc" ]; then
        echo "auth.enc not found"
        if [ -z "$SERVER_JAR" ]; then
             echo "no server files found"
             sleep infinity
        fi
    else
        echo "downloading zip stuff"
        ./hytale-downloader -download-path "$TEMP_ZIP" -skip-update-check
        
        if [ -f "$TEMP_ZIP" ]; then
            unzip -o "$TEMP_ZIP" -d "$DATA_DIR"
            rm "$TEMP_ZIP"
            echo "$LATEST_VERSION" > "$VERSION_FILE"
            SERVER_JAR=$(find "$DATA_DIR" -name "HytaleServer.jar" | head -n 1)
        else
            # most likely since TEMP_ZIP is not found
            echo "download failed."
        fi
    fi
else
    echo "Server is up to date (Version: $INSTALLED_VERSION)."
fi

if [ -f "$SERVER_JAR" ]; then
    JAR_DIR=$(dirname "$SERVER_JAR")
    cd "$JAR_DIR"
    
    # why i have this
    AOT_ARGS=""
    if [ -f "HytaleServer.aot" ]; then
        AOT_ARGS="-XX:AOTCache=HytaleServer.aot"
    fi
    
    java -Xmx8G $AOT_ARGS -jar "$SERVER_JAR" --assets "$DATA_DIR/Assets.zip"
else
    ls -R "$DATA_DIR"
    sleep infinity
fi
