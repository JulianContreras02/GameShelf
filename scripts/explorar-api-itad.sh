#!/usr/bin/env bash
#
# Explora la API de IsThereAnyDeal contra la cuenta real, para conocer la forma
# de las respuestas antes de escribir codigo contra ellas.
#
# Lee la clave de Config/Secrets.xcconfig y NUNCA la imprime: las respuestas se
# guardan en un directorio temporal fuera del repositorio.
#
# Uso:  ./scripts/explorar-api-itad.sh
#
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETOS="$RAIZ/Config/Secrets.xcconfig"
TMP="$(mktemp -d)"
PAIS="CO"

if [[ ! -f "$SECRETOS" ]]; then
  echo "✘ No existe Config/Secrets.xcconfig"
  exit 1
fi

CLAVE="$(grep -E "^[[:space:]]*ITAD_API_KEY[[:space:]]*=" "$SECRETOS" \
  | head -1 | cut -d'=' -f2- | tr -d '[:space:]')"

if [[ -z "$CLAVE" ]]; then
  echo "✘ Falta ITAD_API_KEY en Config/Secrets.xcconfig"
  echo "  Registra la app en https://isthereanydeal.com/apps/my/"
  exit 1
fi

# Juegos de la wishlist real, para probar con datos que importan.
APPIDS='[268910, 1151640, 1551360]'

pedir() {
  local nombre="$1" metodo="$2" ruta="$3" cuerpo="${4:-}"
  local archivo="$TMP/$nombre.json"
  local args=(-sS -o "$archivo" -w '%{http_code}' --max-time 25 -X "$metodo"
              "https://api.isthereanydeal.com${ruta}")
  if [[ -n "$cuerpo" ]]; then
    args+=(-H 'Content-Type: application/json' -d "$cuerpo")
  fi

  local codigo
  codigo="$(curl "${args[@]}" 2>/dev/null || echo 000)"
  printf '\n=== %s  (HTTP %s, %s bytes)\n' "$nombre" "$codigo" "$(wc -c < "$archivo" | tr -d ' ')"
  python3 -m json.tool "$archivo" 2>/dev/null | head -60 || head -c 400 "$archivo"
}

echo "→ Explorando IsThereAnyDeal (pais=$PAIS)"

pedir "lookup-por-appid" GET "/games/lookup/v1?key=$CLAVE&appid=268910"
pedir "lookup-por-titulo" GET "/games/lookup/v1?key=$CLAVE&title=Cuphead"

# El id de ITAD sale del lookup; se toma el del primero para las consultas
# siguientes.
ID="$(python3 -c "
import json
d = json.load(open('$TMP/lookup-por-appid.json'))
print(d.get('game', {}).get('id', ''))
" 2>/dev/null)"

if [[ -n "$ID" ]]; then
  pedir "precios-lote" POST "/games/prices/v3?key=$CLAVE&country=$PAIS" "[\"$ID\"]"
  pedir "minimo-historico" POST "/games/historylow/v1?key=$CLAVE&country=$PAIS" "[\"$ID\"]"
  pedir "info-juego" GET "/games/info/v2?key=$CLAVE&id=$ID"
fi

pedir "lookup-lote" POST "/lookup/id/shop/61/v1?key=$CLAVE" "$APPIDS"

echo
echo "→ Respuestas guardadas en: $TMP"
echo "$TMP" > /tmp/itad-ultimo-tmp
