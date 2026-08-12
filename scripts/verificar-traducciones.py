#!/usr/bin/env python3
"""Revisa que el String Catalog no tenga huecos.

Se ejecuta a mano o desde CI:

    python3 scripts/verificar-traducciones.py

Falla si alguna clave visible no esta traducida al ingles, o si quedaron
entradas marcadas como obsoletas. No lo cubre una prueba unitaria porque el
idioma base no genera tabla: para el espanol la clave *es* el valor, asi que
dentro de la app no hay contra que comparar.
"""
import json
import pathlib
import sys

CATALOGO = pathlib.Path(__file__).parent.parent / "GameShelf/Resources/Localizable.xcstrings"
IDIOMAS = ["en"]


def main() -> int:
  catalogo = json.loads(CATALOGO.read_text())
  strings = catalogo["strings"]
  problemas = []

  if catalogo.get("sourceLanguage") != "es":
    problemas.append(f"El idioma base deberia ser 'es' y es {catalogo.get('sourceLanguage')!r}")

  for clave, entrada in sorted(strings.items()):
    # Las cadenas de puro formato ("%@: %@", "·") no se traducen a proposito.
    if entrada.get("shouldTranslate") is False:
      continue

    if entrada.get("extractionState") == "stale":
      problemas.append(f"Sobra (ya no se usa en el codigo): {clave!r}")
      continue

    localizaciones = entrada.get("localizations", {})
    for idioma in IDIOMAS:
      if idioma not in localizaciones:
        problemas.append(f"Falta {idioma}: {clave!r}")
        continue

      unidades = list(recorrer(localizaciones[idioma]))
      if not unidades:
        problemas.append(f"{idioma} sin texto: {clave!r}")
      for estado, valor in unidades:
        if not valor.strip():
          problemas.append(f"{idioma} vacio: {clave!r}")
        elif estado in ("new", "needs_review"):
          problemas.append(f"{idioma} sin revisar ({estado}): {clave!r}")

  traducidas = sum(1 for e in strings.values() if e.get("shouldTranslate") is not False)
  print(f"{len(strings)} claves ({traducidas} traducibles)")

  if problemas:
    print(f"\n{len(problemas)} problemas:")
    for p in problemas:
      print("  -", p)
    return 1

  print("Todo traducido.")
  return 0


def recorrer(nodo):
  """Saca (estado, valor) de una localizacion, entre o no en variantes."""
  if "stringUnit" in nodo:
    unidad = nodo["stringUnit"]
    yield unidad.get("state", ""), unidad.get("value", "")
  for variantes in nodo.get("variations", {}).values():
    for rama in variantes.values():
      yield from recorrer(rama)
  for sustitucion in nodo.get("substitutions", {}).values():
    yield from recorrer(sustitucion)


if __name__ == "__main__":
  sys.exit(main())
