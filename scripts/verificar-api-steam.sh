#!/usr/bin/env bash
#
# Compara la respuesta REAL de la Steam Web API contra los DTOs del proyecto.
#
# Lee las credenciales de Config/Secrets.xcconfig y nunca las imprime: la
# respuesta cruda se guarda fuera del repositorio, en un directorio temporal.
#
# Uso:  ./scripts/verificar-api-steam.sh
#
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETOS="$RAIZ/Config/Secrets.xcconfig"
SALIDA="$(mktemp -d)/respuesta-steam.json"

if [[ ! -f "$SECRETOS" ]]; then
  echo "✘ No existe Config/Secrets.xcconfig"
  echo "  Corre: cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig"
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

echo "→ Consultando GetOwnedGames..."

URL="https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/"
CODIGO="$(curl -sS -o "$SALIDA" -w '%{http_code}' -G "$URL" \
  --data-urlencode "key=$API_KEY" \
  --data-urlencode "steamid=$STEAM_ID" \
  --data-urlencode "include_appinfo=1" \
  --data-urlencode "include_played_free_games=1" \
  --data-urlencode "format=json" 2>/dev/null)"

# A partir de aca las credenciales ya no se usan
unset API_KEY STEAM_ID

echo "→ HTTP $CODIGO"

if [[ "$CODIGO" == "401" || "$CODIGO" == "403" ]]; then
  echo "✘ Credenciales rechazadas. Revisa que la API key sea correcta."
  exit 1
elif [[ "$CODIGO" != "200" ]]; then
  echo "✘ Respuesta inesperada del servidor."
  exit 1
fi

echo "→ Respuesta cruda guardada FUERA del repo: $SALIDA"
echo
python3 "$RAIZ/scripts/analizar_respuesta_steam.py" "$SALIDA"
