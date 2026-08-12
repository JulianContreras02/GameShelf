#!/usr/bin/env bash
#
# Guarda respuestas reales de Epic como archivos de apoyo para las pruebas.
#
# Lo corre el usuario, no la herramienta: hace falta el codigo de
# autorizacion, que da acceso completo a la cuenta. El script lo pide **sin
# mostrarlo**, no lo guarda y no queda en el historial del terminal.
#
# Antes de guardar nada quita de las respuestas lo que identifique a la cuenta.
#
# Uso:  ./scripts/explorar-api-epic.sh
#
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$RAIZ/GameShelfTests/Fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CLIENT_ID="34a02cf8f4414e29b15921876da36f9a"
CLIENT_SECRET="daafbccc737745039dffe53d94fc76cf"
CODIGO_URL="https://www.epicgames.com/id/api/redirect?clientId=$CLIENT_ID&responseType=code"

echo "Este script necesita un codigo de autorizacion de Epic."
echo
echo "  1. Inicia sesion en https://www.epicgames.com/id/login"
echo "  2. En el mismo navegador abre:"
echo "     $CODIGO_URL"
echo "  3. Copia lo que hay tras \"authorizationCode\", entre comillas"
echo
echo "  Los codigos caducan en segundos: pegalo enseguida."
echo
printf 'Pega el codigo (no se vera al escribir): '
read -rs CODIGO
echo
echo

if [[ -z "$CODIGO" ]]; then
  echo "✘ No se pego ningun codigo."
  exit 1
fi

echo "→ Canjeando el codigo"

RESPUESTA="$(curl -sS --max-time 25 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "code=$CODIGO" \
  --data-urlencode "token_type=eg1" \
  "https://account-public-service-prod.ol.epicgames.com/account/api/oauth/token")"

TOKEN="$(printf '%s' "$RESPUESTA" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)"
CUENTA="$(printf '%s' "$RESPUESTA" | python3 -c "import json,sys; print(json.load(sys.stdin).get('account_id',''))" 2>/dev/null)"

if [[ -z "$TOKEN" ]]; then
  echo "✘ No se pudo obtener el token. Lo mas comun es que el codigo caducara:"
  echo "  recarga la pagina, copia el nuevo y vuelve a intentar."
  exit 1
fi

echo "→ Token obtenido. Pidiendo datos…"

pedir() {
  local nombre="$1" url="$2"
  local codigo
  codigo="$(curl -sS -o "$TMP/$nombre.json" -w '%{http_code}' --max-time 30 \
    -H "Authorization: bearer $TOKEN" "$url")"
  printf '   %-14s HTTP %s  (%s bytes)\n' "$nombre" "$codigo" "$(wc -c < "$TMP/$nombre.json" | tr -d ' ')"
}

# La biblioteca viene paginada: la respuesta trae `nextCursor` cuando falta
# mas. Se siguen las paginas y se juntan, o el resultado queda a medias.
BIBLIOTECA="https://library-service.live.use1a.on.epicgames.com/library/api/public/items"
CURSOR=""
PAGINA=0

while [[ $PAGINA -lt 20 ]]; do
  PAGINA=$((PAGINA + 1))
  URL="$BIBLIOTECA?includeMetadata=true"
  [[ -n "$CURSOR" ]] && URL="$URL&cursor=$CURSOR"

  pedir "pagina$PAGINA" "$URL"

  CURSOR="$(python3 -c "
import json
try:
    print(json.load(open('$TMP/pagina$PAGINA.json')).get('responseMetadata', {}).get('nextCursor') or '')
except Exception:
    print('')
")"
  [[ -z "$CURSOR" ]] && break
done

echo "   (paginas: $PAGINA)"

# Se leen los archivos uno a uno. Un primer intento los concatenaba en un
# .jsonl asumiendo un JSON por linea, y Epic los devuelve formateados en
# varias: el pegado se rompia y se perdia la biblioteca entera.
python3 -c "
import glob
import json
import os

registros = []
for ruta in sorted(glob.glob('$TMP/pagina*.json'), key=lambda r: int(''.join(c for c in os.path.basename(r) if c.isdigit()))):
    registros += json.load(open(ruta)).get('records', [])

json.dump({'records': registros}, open('$TMP/biblioteca.json', 'w'))
print(f'   total de registros: {len(registros)}')
"

pedir "tiempos" \
  "https://library-service.live.use1a.on.epicgames.com/library/api/public/playtime/account/$CUENTA/all"

# La biblioteca devuelve identificadores, no nombres. El catalogo los resuelve,
# pero se pide por namespace: se prueba con el primero para ver la forma.
NS_E_ID="$(python3 -c "
import json
try:
    registros = json.load(open('$TMP/biblioteca.json')).get('records', [])
    if registros:
        print(registros[0].get('namespace',''), registros[0].get('catalogItemId',''))
except Exception:
    pass
" 2>/dev/null)"

read -r NAMESPACE ITEM_ID <<< "$NS_E_ID"

if [[ -n "${NAMESPACE:-}" && -n "${ITEM_ID:-}" ]]; then
  echo "→ Resolviendo el nombre del primer juego"
  pedir "catalogo" \
    "https://catalog-public-service-prod06.ol.epicgames.com/catalog/api/shared/namespace/$NAMESPACE/bulk/items?id=$ITEM_ID&includeDLCDetails=false&includeMainGameDetails=false&country=CO&locale=es"
fi

echo
echo "→ Quitando lo que identifica la cuenta y guardando"

python3 - "$TMP" "$FIXTURES" "$CUENTA" <<'PY'
import json
import sys

tmp, destino, cuenta = sys.argv[1], sys.argv[2], sys.argv[3]

PERSONALES = {"accountId", "acquisitionDate", "entitlementId", "orderId", "userId"}

def limpiar(nodo):
  if isinstance(nodo, dict):
    return {k: limpiar(v) for k, v in nodo.items() if k not in PERSONALES}
  if isinstance(nodo, list):
    return [limpiar(x) for x in nodo]
  if isinstance(nodo, str) and cuenta and cuenta in nodo:
    return nodo.replace(cuenta, "CUENTA_ANONIMA")
  return nodo

for nombre, salida in (
  ("biblioteca", "epic_biblioteca"),
  ("tiempos", "epic_tiempos"),
  ("catalogo", "epic_catalogo"),
):
  try:
    datos = json.load(open(f"{tmp}/{nombre}.json"))
  except Exception as error:
    print(f"   ✘ {nombre}: {error}")
    continue

  limpio = limpiar(datos)
  with open(f"{destino}/{salida}.json", "w") as archivo:
    json.dump(limpio, archivo, indent=2, ensure_ascii=False)
    archivo.write("\n")

  if isinstance(limpio, dict):
    cuantos = len(limpio.get("records") or limpio.get("playtime") or limpio)
  else:
    cuantos = len(limpio)
  print(f"   ✔ {salida}.json  ({cuantos} entradas)")
PY

echo
echo "Listo. Los archivos quedaron en GameShelfTests/Fixtures/"
echo "Revisalos antes de subirlos."
