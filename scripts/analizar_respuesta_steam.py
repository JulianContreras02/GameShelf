#!/usr/bin/env python3
"""Compara una respuesta real de GetOwnedGames contra los DTOs del proyecto.

Reporta campos que Steam manda y no modelamos, campos que esperamos y no
llegaron, y valida los supuestos que dimos por ciertos al escribir los DTOs.

No imprime credenciales. La biblioteca del usuario solo se resume; los nombres
de juegos se muestran unicamente en la lista de ejemplo.
"""
import json
import sys
from collections import Counter

# Lo que SteamGameDTO declara en sus CodingKeys
MODELADOS = {"appid", "name", "playtime_forever", "img_icon_url", "rtime_last_played"}

# Campos conocidos que existen pero no nos interesan
IGNORADOS_A_PROPOSITO = {
    "has_community_visible_stats", "playtime_windows_forever",
    "playtime_mac_forever", "playtime_linux_forever", "playtime_deck_forever",
    "playtime_disconnected", "content_descriptorids", "has_leaderboards",
    "capsule_filename", "sort_as", "rtime_last_played_offline",
}


def main(ruta: str) -> int:
    with open(ruta, encoding="utf-8") as f:
        datos = json.load(f)

    print("=" * 68)
    print("ESTRUCTURA DE LA RESPUESTA")
    print("=" * 68)

    if "response" not in datos:
        print("✘ CRITICO: no viene la envoltura 'response'.")
        print(f"  Claves en la raiz: {sorted(datos.keys())}")
        return 1
    print("✔ Viene envuelto en 'response', como asume el DTO")

    payload = datos["response"]
    print(f"  Claves dentro de 'response': {sorted(payload.keys())}")

    if not payload:
        print()
        print("⚠️  'response' llego vacio.")
        print("   Significa perfil privado o biblioteca sin juegos.")
        print("   El DTO lo maneja con isEmpty, asi que esto NO es un fallo.")
        return 0

    juegos = payload.get("games", [])
    print(f"✔ game_count = {payload.get('game_count')}")
    print(f"✔ juegos en la lista = {len(juegos)}")

    if payload.get("game_count") != len(juegos):
        print("  ⚠️  game_count no coincide con la cantidad de juegos")

    if not juegos:
        return 0

    print()
    print("=" * 68)
    print("CAMPOS QUE MANDA STEAM")
    print("=" * 68)

    frecuencia = Counter()
    for j in juegos:
        frecuencia.update(j.keys())

    total = len(juegos)
    for campo, veces in sorted(frecuencia.items(), key=lambda x: -x[1]):
        cobertura = f"{veces}/{total}"
        if campo in MODELADOS:
            marca = "✔ modelado    "
        elif campo in IGNORADOS_A_PROPOSITO:
            marca = "· ignorado    "
        else:
            marca = "⚠️  NO MODELADO"
        print(f"  {marca} {campo:<32} {cobertura}")

    faltantes = MODELADOS - set(frecuencia)
    if faltantes:
        print()
        print(f"⚠️  Campos que el DTO espera y NO llegaron: {sorted(faltantes)}")

    nuevos = set(frecuencia) - MODELADOS - IGNORADOS_A_PROPOSITO
    if nuevos:
        print()
        print(f"⚠️  Campos nuevos no contemplados: {sorted(nuevos)}")

    print()
    print("=" * 68)
    print("SUPUESTOS DEL DTO")
    print("=" * 68)

    sin_nombre = [j for j in juegos if "name" not in j]
    print(f"{'⚠️ ' if sin_nombre else '✔'} juegos sin 'name': {len(sin_nombre)}"
          f"  (el DTO lo trata como opcional)")

    sin_icono = [j for j in juegos if not j.get("img_icon_url")]
    print(f"✔ juegos con 'img_icon_url' vacio o ausente: {len(sin_icono)}"
          f"  (iconURL devuelve nil)")

    nunca = [j for j in juegos if j.get("rtime_last_played", 0) == 0]
    print(f"✔ juegos con rtime_last_played = 0: {len(nunca)}"
          f"  (se traduce a nil, no a 1970)")

    tipos_mal = [j for j in juegos if not isinstance(j.get("appid"), int)]
    print(f"{'✘' if tipos_mal else '✔'} appid siempre entero: "
          f"{'NO' if tipos_mal else 'si'}")

    tipos_mal_pt = [j for j in juegos
                    if "playtime_forever" in j
                    and not isinstance(j["playtime_forever"], int)]
    print(f"{'✘' if tipos_mal_pt else '✔'} playtime_forever siempre entero: "
          f"{'NO' if tipos_mal_pt else 'si'}")

    minutos = sum(j.get("playtime_forever", 0) for j in juegos)
    print(f"✔ tiempo total: {minutos} minutos = {minutos / 60:.1f} horas")

    print()
    print("=" * 68)
    print("MUESTRA (5 juegos con mas horas)")
    print("=" * 68)
    top = sorted(juegos, key=lambda j: j.get("playtime_forever", 0), reverse=True)[:5]
    for j in top:
        horas = j.get("playtime_forever", 0) / 60
        print(f"  {j.get('name', '(sin nombre)')[:40]:<42} {horas:>8.1f} h"
              f"   appid={j.get('appid')}")

    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: analizar_respuesta_steam.py <archivo.json>")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
