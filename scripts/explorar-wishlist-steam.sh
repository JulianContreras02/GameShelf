#!/usr/bin/env bash
#
# Averigua que endpoint de wishlist de Steam funciona hoy, y con que forma.
#
# La wishlist no tiene un endpoint estable: el antiguo de la tienda
# (store.steampowered.com/wishlist/.../wishlistdata) dejo de responder, y el
# nuevo (IWishlistService) devuelve solo appids. Este script prueba los
# candidatos contra la cuenta real antes de escribir codigo contra ninguno.
#
# Lee las credenciales de Config/Secrets.xcconfig y NUNCA las imprime: las
# respuestas se guardan en un directorio temporal fuera del repositorio.
#
# Uso:  ./scripts/explorar-wishlist-steam.sh
#
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETOS="$RAIZ/Config/Secrets.xcconfig"
TMP="$(mktemp -d)"

if [[ ! -f "$SECRETOS" ]]; then
  echo "✘ No existe Config/Secrets.xcconfig"
  exit 1
fi

leer_clave() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$SECRETOS" \
    | head -1 | cut -d'=' -f2- | tr -d '[:space:]'
}

API_KEY="$(leer_clave STEAM_API_KEY)"
STEAM_ID="$(leer_clave STEAM_ID)"

if [[ -z "$API_KEY" || -z "$STEAM_ID" ]]; then
  echo "✘ Faltan STEAM_API_KEY o STEAM_ID en Config/Secrets.xcconfig"
  exit 1
fi

probar() {
  local nombre="$1"; shift
  local url="$1"; shift
  local archivo="$TMP/$nombre.json"

  local codigo
  codigo="$(curl -sS -o "$archivo" -w '%{http_code}' -G "$url" "$@" \
    --max-time 25 2>/dev/null || echo "000")"

  local tam
  tam="$(wc -c < "$archivo" | tr -d ' ')"
  printf '  %-28s HTTP %-4s %6s bytes\n' "$nombre" "$codigo" "$tam"

  if [[ "$codigo" == "200" && "$tam" -gt 2 ]]; then
    echo "      $(head -c 220 "$archivo")"
  fi
  echo
}

echo "→ Probando endpoints de wishlist"
echo

probar "IWishlistService" \
  "https://api.steampowered.com/IWishlistService/GetWishlist/v1/" \
  --data-urlencode "key=$API_KEY" \
  --data-urlencode "steamid=$STEAM_ID"

probar "IWishlistService-sin-key" \
  "https://api.steampowered.com/IWishlistService/GetWishlist/v1/" \
  --data-urlencode "steamid=$STEAM_ID"

probar "tienda-wishlistdata" \
  "https://store.steampowered.com/wishlist/profiles/$STEAM_ID/wishlistdata/" \
  --data-urlencode "p=0"

echo "→ Respuestas guardadas en: $TMP"
echo "  (fuera del repositorio; se borran solas al reiniciar)"
