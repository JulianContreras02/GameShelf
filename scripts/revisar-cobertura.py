#!/usr/bin/env python3
"""Revisa la cobertura de pruebas de las capas de servicios y modelos.

Se ejecuta despues de `xcodebuild test`, sobre el .xcresult que deja:

    python3 scripts/revisar-cobertura.py Pruebas.xcresult

Falla si alguna de las dos capas queda por debajo del minimo (70 % por
defecto). Las vistas y los ViewModels no cuentan: las vistas de SwiftUI no
llevan prueba unitaria (ver CONTRIBUTING.md), y lo que aca se vigila es la
logica que mas se puede romper.

Tambien acepta el JSON de `xcrun xccov view --report --json` ya guardado, en
vez del .xcresult, para poder revisarlo sin volver a correr las pruebas.

Si corre en GitHub Actions, deja ademas la tabla en el resumen del trabajo.
"""
import argparse
import json
import os
import subprocess
import sys

# Que carpeta es cada capa. Se busca el fragmento dentro de la ruta absoluta
# que da xccov, asi que no importa donde se haya clonado el repo.
CAPAS = {
  "Servicios": "/GameShelf/Services/",
  "Modelos": "/GameShelf/Models/",
}


def main() -> int:
  argumentos = leer_argumentos()
  reporte = cargar_reporte(argumentos.resultado)
  archivos = list(archivos_de_la_app(reporte))

  filas = []
  problemas = []

  for capa, fragmento in CAPAS.items():
    de_la_capa = [a for a in archivos if fragmento in a["ruta"]]
    if not de_la_capa:
      # Sin archivos no hay nada que medir: casi seguro la cobertura no se
      # activo en el scheme. Fallar es mejor que dar un 0 % o un 100 % falso.
      problemas.append(f"{capa}: no aparece ningun archivo. Esta activada la cobertura en el scheme?")
      continue

    cubiertas = sum(a["cubiertas"] for a in de_la_capa)
    ejecutables = sum(a["ejecutables"] for a in de_la_capa)
    porcentaje = 100 * cubiertas / ejecutables if ejecutables else 100.0
    filas.append((capa, cubiertas, ejecutables, porcentaje, de_la_capa, fragmento))

    if porcentaje < argumentos.minimo:
      problemas.append(f"{capa}: {porcentaje:.1f} %, por debajo del {argumentos.minimo:.0f} %")

  texto = resumen(filas, argumentos.minimo, argumentos.peores)
  print(texto)

  resumen_de_actions = os.environ.get("GITHUB_STEP_SUMMARY")
  if resumen_de_actions:
    with open(resumen_de_actions, "a", encoding="utf-8") as salida:
      salida.write(texto + "\n")

  if problemas:
    print("\nNo alcanza:")
    for problema in problemas:
      print("  -", problema)
    return 1

  print(f"\nLas dos capas pasan del {argumentos.minimo:.0f} %.")
  return 0


def leer_argumentos():
  parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
  parser.add_argument("resultado", help="El .xcresult de xcodebuild test, o el JSON de xccov")
  parser.add_argument("--minimo", type=float, default=70, help="Porcentaje minimo por capa (70)")
  parser.add_argument("--peores", type=int, default=8, help="Cuantos archivos ensenar por capa (8)")
  return parser.parse_args()


def cargar_reporte(ruta):
  if ruta.endswith(".json"):
    with open(ruta, encoding="utf-8") as archivo:
      return json.load(archivo)

  salida = subprocess.run(
    ["xcrun", "xccov", "view", "--report", "--json", ruta],
    check=True, capture_output=True, text=True,
  )
  return json.loads(salida.stdout)


def archivos_de_la_app(reporte):
  """Los archivos de la app, sin los de las pruebas.

  El scheme ya pide cobertura solo de la app, pero se filtra igual: si un dia
  se cuela el target de pruebas, sus archivos (casi todos al 100 %) inflarian
  el resultado.
  """
  for target in reporte.get("targets", []):
    if "Tests" in target.get("name", ""):
      continue
    for archivo in target.get("files", []):
      yield {
        "ruta": archivo.get("path", ""),
        "nombre": archivo.get("name") or os.path.basename(archivo.get("path", "")),
        "cubiertas": archivo.get("coveredLines", 0),
        "ejecutables": archivo.get("executableLines", 0),
      }


def resumen(filas, minimo, peores):
  lineas = [
    "## Cobertura de pruebas",
    "",
    f"Minimo por capa: {minimo:.0f} %",
    "",
    "| Capa | Lineas cubiertas | Porcentaje |",
    "| --- | --- | --- |",
  ]
  for capa, cubiertas, ejecutables, porcentaje, _, _ in filas:
    marca = "✅" if porcentaje >= minimo else "❌"
    lineas.append(f"| {capa} | {cubiertas} de {ejecutables} | {marca} {porcentaje:.1f} % |")

  for capa, _, _, _, archivos, fragmento in filas:
    con_codigo = [a for a in archivos if a["ejecutables"] > 0]
    con_codigo.sort(key=lambda a: (a["cubiertas"] / a["ejecutables"], -a["ejecutables"]))
    lineas += ["", f"### {capa}: archivos con menos cobertura", ""]
    lineas += ["| Archivo | Lineas | Porcentaje |", "| --- | --- | --- |"]
    for archivo in con_codigo[:peores]:
      porcentaje = 100 * archivo["cubiertas"] / archivo["ejecutables"]
      relativa = archivo["ruta"].split(fragmento, 1)[-1]
      lineas.append(f"| `{relativa}` | {archivo['cubiertas']} de {archivo['ejecutables']} | {porcentaje:.1f} % |")

  return "\n".join(lineas)


if __name__ == "__main__":
  sys.exit(main())
