#!/usr/bin/env bash
#
# Guarda respuestas reales de PSN como archivos de apoyo para las pruebas.
#
# Lo corre el usuario, no la herramienta: hace falta el codigo NPSSO, que es
# una sesion de la cuenta de Sony. El script lo pide **sin mostrarlo**, no lo
# guarda en ningun lado y no queda en el historial del terminal.
#
# Antes de guardar nada, quita de las respuestas todo lo que identifique a la
# cuenta: accountId, onlineId, avatares y demas. En el repositorio solo quedan
# los nombres de los juegos y el progreso, que es lo que las pruebas necesitan.
#
# Uso:  ./scripts/explorar-api-psn.sh
#
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$RAIZ/GameShelfTests/Fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CLIENT_ID="09515159-7237-4370-9b40-3806e67c0891"
CLIENT_SECRET="ucPjka5tntB2KqsP"
REDIRECT="com.scee.psxandroid.scecompcall://redirect"
SCOPE="psn:mobile.v2.core psn:clientapp"

echo "Este script necesita tu codigo NPSSO."
echo
echo "  1. Inicia sesion en https://www.playstation.com/"
echo "  2. En el mismo navegador abre https://ca.account.sony.com/api/v1/ssocookie"
echo "  3. Copia lo que hay entre comillas"
echo
printf 'Pega el codigo (no se vera al escribir): '
read -rs NPSSO
echo
echo

if [[ -z "$NPSSO" ]]; then
  echo "✘ No se pego ningun codigo."
  exit 1
fi

echo "→ Canjeando el codigo por un token de acceso"

CODIGO="$(curl -sS -o /dev/null -D - --max-time 25 \
  -H "Cookie: npsso=$NPSSO" \
  "https://ca.account.sony.com/api/authz/v3/oauth/authorize?access_type=offline&client_id=$CLIENT_ID&redirect_uri=$REDIRECT&response_type=code&scope=$(printf %s "$SCOPE" | sed 's/ /%20/g')" \
  | grep -i '^location:' | sed -E 's/.*[?&]code=([^&[:space:]]+).*/\1/')"

if [[ -z "$CODIGO" || "$CODIGO" == *"login_required"* ]]; then
  echo "✘ El codigo no sirve o ya caduco. Repite los tres pasos y vuelve a intentar."
  exit 1
fi

TOKEN="$(curl -sS --max-time 25 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  --data-urlencode "code=$CODIGO" \
  --data-urlencode "redirect_uri=$REDIRECT" \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "token_format=jwt" \
  "https://ca.account.sony.com/api/authz/v3/oauth/token" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")"

if [[ -z "$TOKEN" ]]; then
  echo "✘ No se pudo obtener el token de acceso."
  exit 1
fi

echo "→ Token obtenido. Pidiendo datos…"

pedir() {
  local nombre="$1" ruta="$2"
  local codigo
  codigo="$(curl -sS -o "$TMP/$nombre.json" -w '%{http_code}' --max-time 30 \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept-Language: es-CO" \
    "https://m.np.playstation.com/api$ruta")"
  printf '   %-16s HTTP %s  (%s bytes)\n' "$nombre" "$codigo" "$(wc -c < "$TMP/$nombre.json" | tr -d ' ')"
}

pedir "juegos"  "/gamelist/v2/users/me/titles?limit=200"
pedir "trofeos" "/trophy/v1/users/me/trophyTitles?limit=200"

# Los juegos se identifican con titleId (PPSA...) y los trofeos con
# npCommunicationId (NPWR...): no comparten clave. Este endpoint es el que las
# relaciona. Emparejar por nombre no sirve: "Marvel's Spider-Man" y
# "Spider-Man Remastered" son juegos distintos con trofeos distintos.
echo "→ Relacionando juegos con sus trofeos"

IDS="$(python3 -c "
import json
titulos = json.load(open('$TMP/juegos.json')).get('titles', [])
print(','.join(t['titleId'] for t in titulos[:5]))
")"

if [[ -n "$IDS" ]]; then
  pedir "mapa" "/trophy/v1/users/me/titles/trophyTitles?npTitleIds=$IDS"
  echo "   (se piden solo los primeros 5, para ver la forma y el limite)"
fi

echo
echo "→ Quitando lo que identifica la cuenta y guardando"

python3 - "$TMP" "$FIXTURES" <<'PY'
import json
import re
import sys

tmp, destino = sys.argv[1], sys.argv[2]

# Campos que identifican a la persona y no hacen falta para probar el parseo.
PERSONALES = {
  "accountId", "onlineId", "avatarUrl", "avatarUrls", "npId", "personalDetail",
  "profilePictureUrls", "aboutMe", "languages", "isPlus", "isOfficiallyVerified",
}

def limpiar(nodo):
  if isinstance(nodo, dict):
    return {k: limpiar(v) for k, v in nodo.items() if k not in PERSONALES}
  if isinstance(nodo, list):
    return [limpiar(x) for x in nodo]
  if isinstance(nodo, str):
    # Los identificadores largos de cuenta salen tambien dentro de URLs.
    return re.sub(r"\b\d{16,}\b", "0000000000000000", nodo)
  return nodo

for nombre, salida in (("juegos", "psn_juegos"), ("trofeos", "psn_trofeos"), ("mapa", "psn_mapa_trofeos")):
  try:
    datos = json.load(open(f"{tmp}/{nombre}.json"))
  except Exception as error:
    print(f"   ✘ {nombre}: {error}")
    continue

  limpio = limpiar(datos)
  ruta = f"{destino}/{salida}.json"
  with open(ruta, "w") as archivo:
    json.dump(limpio, archivo, indent=2, ensure_ascii=False)
    archivo.write("\n")

  cuantos = len(limpio.get("titles") or limpio.get("trophyTitles") or limpio.get("trophyTitles", []))
  print(f"   ✔ {salida}.json  ({cuantos} entradas)")
PY

echo
echo "Listo. Los archivos quedaron en GameShelfTests/Fixtures/"
echo "Revisalos antes de subirlos: llevan los nombres de tus juegos."
