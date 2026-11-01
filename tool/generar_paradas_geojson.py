"""Genera assets/data/stops.geojson desde un GTFS (zip).

Cada parada lleva las líneas que pasan por ella (de stop_times + trips +
routes), para mostrarlas al tocarla en el mapa aunque no haya datos en vivo.

Uso:
    python tool/generar_paradas_geojson.py C:/Users/felix/otp/mvd.gtfs.zip
"""

import collections
import csv
import io
import json
import re
import sys
import zipfile


def main(ruta_gtfs: str, salida: str = "assets/data/stops.geojson") -> None:
    z = zipfile.ZipFile(ruta_gtfs)

    def filas(nombre):
        return csv.DictReader(io.TextIOWrapper(z.open(nombre), encoding="utf-8-sig"))

    rutas = {r["route_id"]: r["route_short_name"] for r in filas("routes.txt")}
    linea_de_viaje = {t["trip_id"]: rutas.get(t["route_id"]) for t in filas("trips.txt")}
    lineas = collections.defaultdict(set)
    for st in filas("stop_times.txt"):
        linea = linea_de_viaje.get(st["trip_id"])
        if linea:
            lineas[st["stop_id"]].add(linea)

    def orden(linea):
        m = re.match(r"(\d+)(.*)", linea)
        return (0, int(m.group(1)), m.group(2)) if m else (1, 0, linea)

    features = []
    for s in filas("stops.txt"):
        ls = sorted(lineas.get(s["stop_id"], []), key=orden)
        if not ls:
            continue  # paradas sin servicio
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [round(float(s["stop_lon"]), 6), round(float(s["stop_lat"]), 6)],
            },
            "properties": {"stop_id": s["stop_id"], "stop_name": s["stop_name"].strip(), "lines": ls},
        })
    with open(salida, "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": features}, f,
                  ensure_ascii=False, separators=(",", ":"))
    print(f"{len(features)} paradas -> {salida}")


if __name__ == "__main__":
    main(*sys.argv[1:])
