#!/usr/bin/env bash
# Run this script with sudo (or root privileges) to configure .local domains in /etc/hosts on Linux and macOS.

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo: sudo ./scripts/add-local-domains.sh"
  exit 1
fi

HOSTS_FILE="/etc/hosts"
DOMAINS=(
  "n8n.local"
  "redis.local"
  "radis.local"
  "search.local"
  "searxng.local"
  "docling.local"
  "ollama.local"
  "qdrant.local"
  "crawl.local"
  "crawl4ai.local"
  "neo.local"
  "neo4j.local"
  "files.local"
)

echo "Updating $HOSTS_FILE with .local domain mappings..."

for DOMAIN in "${DOMAINS[@]}"; do
  if ! grep -qE "^\s*127\.0\.0\.1\s+$DOMAIN(\s|$)" "$HOSTS_FILE"; then
    echo "127.0.0.1 $DOMAIN" >> "$HOSTS_FILE"
    echo "Added: 127.0.0.1 $DOMAIN"
  else
    echo "Already mapped: $DOMAIN"
  fi
done

echo ""
echo "All .local domains are now mapped to 127.0.0.1."
