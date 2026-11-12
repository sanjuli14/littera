#!/usr/bin/env bash
# Sube a GitHub (como secretos cifrados del repositorio) la clave de firma,
# para que el flujo "Release" pueda firmar los APK. No muestra nada en
# pantalla. Requiere `gh` con sesión iniciada.
#   uso: tool/upload_signing_secrets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
repo="sanjuli14/littera"
props="android/key.properties"
[ -f "$props" ] || { echo "Falta $props" >&2; exit 1; }

get() { grep -E "^$1=" "$props" | cut -d= -f2-; }
store_file="android/app/$(get storeFile)"
[ -f "$store_file" ] || { echo "Falta la clave: $store_file" >&2; exit 1; }

base64 -w0 "$store_file" | gh secret set LITTERA_KEYSTORE_BASE64 --repo "$repo"
printf '%s' "$(get storePassword)" | gh secret set LITTERA_KEYSTORE_PASSWORD --repo "$repo"
printf '%s' "$(get keyPassword)" | gh secret set LITTERA_KEY_PASSWORD --repo "$repo"
printf '%s' "$(get keyAlias)" | gh secret set LITTERA_KEY_ALIAS --repo "$repo"
echo "Secretos subidos:"
gh secret list --repo "$repo"
