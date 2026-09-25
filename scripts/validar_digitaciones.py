#!/usr/bin/env python3
"""validar_digitaciones.py - Verifica que las digitaciones de acordes_html.py sean correctas.

Para cada acorde de la tabla: deriva las notas que suenan al pisar los trastes (afinación
estándar EADGBE), calcula las notas que DEBERÍA tener según el símbolo, y las compara.

Detecta:
    - notas que no pertenecen al acorde
    - acordes a los que les falta la raíz
    - bajo equivocado en los acordes con barra (D/A, E/B, D7/F#...)
    - calidades del símbolo que no existen en CALIDADES

Uso:
    ./scripts/validar_digitaciones.py        (o ./venv/bin/python scripts/validar_digitaciones.py)

Salida: código 0 si todas son válidas, 1 si encontró errores. Corrélo cada vez que agregues
un voicing nuevo a la tabla DIGITACIONES.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from acordes_html import CALIDADES, DIGITACIONES, NOTAS, parsear_acorde  # noqa: E402

CUERDAS = ["E", "A", "D", "G", "B", "E"]   # 6ª grave -> 1ª aguda


def main():
    errores, avisos, ok = [], [], 0

    for simbolo, dig in sorted(DIGITACIONES.items()):
        info = parsear_acorde(simbolo)
        if info is None:
            errores.append(f"{simbolo}: no se puede interpretar el símbolo")
            continue
        raiz, calidad, bajo = info
        intervalos = CALIDADES.get(calidad)
        if intervalos is None:
            errores.append(f"{simbolo}: calidad desconocida '{calidad}' (agregala a CALIDADES)")
            continue

        tonos = {NOTAS[(NOTAS.index(raiz) + i) % 12] for i in intervalos}
        suenan = []
        for i, traste in enumerate(dig):
            if traste == "x" or traste is None:
                continue
            suenan.append(NOTAS[(NOTAS.index(CUERDAS[i]) + int(traste)) % 12])
        if not suenan:
            errores.append(f"{simbolo}: no suena ninguna cuerda")
            continue

        problemas = []
        ajenas = sorted({n for n in suenan if n not in tonos})
        if ajenas:
            problemas.append(f"tiene notas ajenas {ajenas} (esperaba {sorted(tonos)})")
        if raiz not in suenan:
            problemas.append(f"falta la raíz {raiz}")
        if bajo and suenan[0] != bajo:
            problemas.append(f"el bajo debería ser {bajo} y suena {suenan[0]}")

        if problemas:
            cifrado = " ".join(str(x) for x in dig)
            errores.append(f"{simbolo:11s} {cifrado:22s} ->  {'; '.join(problemas)}")
        else:
            ok += 1
            faltantes = sorted(tonos - set(suenan))
            if faltantes:
                avisos.append(f"{simbolo:11s} omite {faltantes} (habitual y válido)")

    print(f"  digitaciones en la tabla : {len(DIGITACIONES)}")
    print(f"  válidas                  : {ok}")
    print(f"  con avisos (leves)       : {len(avisos)}")
    print(f"  ERRORES                  : {len(errores)}")
    if errores:
        print()
        for e in errores:
            print(f"    {e}")
    if avisos:
        print()
        print("  avisos (no son errores):")
        for a in avisos:
            print(f"    {a}")
    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
