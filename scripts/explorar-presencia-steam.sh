#!/usr/bin/env bash
#
# Graba la respuesta REAL de GetPlayerSummaries, para comparar con los archivos
# de apoyo de las pruebas (GameShelfTests/Fixtures/steam_presencia_*.json),
# que se escribieron a mano con la forma que documenta Valve.
#
# Correlo dos veces: una con un juego abierto en Steam y otra sin jugar a nada.
#
# Las credenciales salen de las variables STEAM_API_KEY y STEAM_ID o, si no
# estan, de Config/Secrets.xcconfig. NUNCA se imprimen: la respuesta cruda se
# guarda en un directorio temporal fuera del repositorio, y por pantalla solo
# salen los campos que decide la presencia.
#
# Uso:  STEAM_API_KEY=... STEAM_ID=... ./scripts/explorar-presencia-steam.sh
#
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETOS="$RAIZ/Config/Secrets.xcconfig"
SALIDA="$(mktemp -d)/presencia-steam.json"

leer_clave() {
  [[ -f "$SECRETOS" ]] || return 0
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$SECRETOS" \
    | head -1 | cut -d'=' -f2- | tr -d '[:space:]'
}

API_KEY="${STEAM_API_KEY:-$(leer_clave STEAM_API_KEY)}"
CUENTA="${STEAM_ID:-$(leer_clave STEAM_ID)}"

if [[ -z "$API_KEY" || -z "$CUENTA" ]]; then
  echo "✘ Faltan STEAM_API_KEY y STEAM_ID (variables o Config/Secrets.xcconfig)"
  exit 1
fi

echo "→ Consultando GetPlayerSummaries..."

CODIGO="$(curl -sS -o "$SALIDA" -w '%{http_code}' -G \
  "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/" \
  --data-urlencode "key=$API_KEY" \
  --data-urlencode "steamids=$CUENTA" \
  --data-urlencode "format=json" \
  --max-time 25 2>/dev/null || echo "000")"

# A partir de aca la key ya no se usa
unset API_KEY

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

python3 -I - "$SALIDA" "$CUENTA" <<'PY'
import json
import sys

ruta, cuenta = sys.argv[1], sys.argv[2]
perfiles = json.load(open(ruta)).get("response", {}).get("players", [])
perfil = next((p for p in perfiles if p.get("steamid") == cuenta), None)

if perfil is None:
  print("Steam no devolvio la cuenta: la app lo trata como 'no se sabe'.")
  sys.exit(0)

for campo in ["communityvisibilitystate", "personastate", "gameid", "gameextrainfo"]:
  print(f"  {campo:26} {perfil.get(campo, '(no viene)')}")

print()
if perfil.get("gameid") or perfil.get("gameextrainfo"):
  print("La app lo leeria como: jugando")
elif perfil.get("communityvisibilitystate") == 3:
  print("La app lo leeria como: sin jugar")
else:
  print("La app lo leeria como: no se sabe (perfil no publico)")
PY
