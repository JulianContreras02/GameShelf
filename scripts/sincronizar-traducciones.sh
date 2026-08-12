#!/usr/bin/env bash
#
# Mete al String Catalog los textos nuevos que haya en el codigo.
#
# Xcode hace esto solo al compilar desde su interfaz, pero `xcodebuild` no: el
# compilador deja los textos en archivos .stringsdata y nadie los junta con el
# catalogo. Este script hace esa union con la herramienta de Xcode.
#
# Uso:  ./scripts/sincronizar-traducciones.sh
#
# Despues hay que escribir las traducciones que falten y comprobar con
# scripts/verificar-traducciones.py.

set -euo pipefail

cd "$(dirname "$0")/.."

ESQUEMA="GameShelf"
DESTINO="platform=iOS Simulator,name=iPhone 17 Pro"
CATALOGO="GameShelf/Resources/Localizable.xcstrings"

echo "==> Compilando para que el compilador extraiga los textos"
xcodebuild -project GameShelf.xcodeproj -scheme "$ESQUEMA" -destination "$DESTINO" \
  | grep -E '^\*\* |error:' || true

echo "==> Buscando los .stringsdata"
CARPETA=$(xcodebuild -project GameShelf.xcodeproj -scheme "$ESQUEMA" -destination "$DESTINO" \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ OBJROOT/{print $2; exit}')

DATOS=$(find "$CARPETA" -name '*.stringsdata' -path '*GameShelf.build*' 2>/dev/null || true)

if [ -z "$DATOS" ]; then
  echo "No se encontro ningun .stringsdata. Revisa que la compilacion haya funcionado." >&2
  exit 1
fi

echo "==> Actualizando $CATALOGO"
# shellcheck disable=SC2086
xcrun xcstringstool sync "$CATALOGO" --stringsdata $DATOS

echo "==> Listo. Ahora revisa que no falten traducciones:"
echo "    python3 scripts/verificar-traducciones.py"
