"""Genera los íconos de BondiUY (Android y web) desde el glifo de bus de
Material Icons: blanco sobre el rojo de las líneas, con un degradé sutil.

    python tool/generar_iconos.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
FUENTE = RAIZ.parent / 'bondi-uy-flutter/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf'
BUS = chr(0xF6B1)  # Icons.directions_bus_rounded

ARRIBA = (232, 84, 64)   # rojo de las líneas, un poco más claro arriba
ABAJO = (204, 52, 36)


def degrade(lado):
    img = Image.new('RGB', (lado, lado))
    d = ImageDraw.Draw(img)
    for y in range(lado):
        t = y / (lado - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(ARRIBA, ABAJO))
        d.line([(0, y), (lado, y)], fill=color)
    return img


def icono(lado, *, redondo, glifo=0.58):
    """[redondo]: esquinas redondeadas con transparencia (web, favicon);
    si no, cuadrado lleno (Android recorta solo; maskable)."""
    fondo = degrade(lado).convert('RGBA')
    fuente = ImageFont.truetype(str(FUENTE), round(lado * glifo))
    d = ImageDraw.Draw(fondo)
    caja = d.textbbox((0, 0), BUS, font=fuente)
    w, h = caja[2] - caja[0], caja[3] - caja[1]
    d.text(((lado - w) / 2 - caja[0], (lado - h) / 2 - caja[1]), BUS,
           font=fuente, fill=(255, 255, 255, 255))
    if not redondo:
        return fondo
    mascara = Image.new('L', (lado, lado), 0)
    ImageDraw.Draw(mascara).rounded_rectangle(
        [0, 0, lado - 1, lado - 1], radius=round(lado * 0.225), fill=255)
    fondo.putalpha(mascara)
    return fondo


def guardar(img, ruta):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    img.save(ruta)
    print(ruta.relative_to(RAIZ))


# Android (ícono clásico: el lanzador lo recorta en su forma).
for carpeta, lado in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                      ('xxhdpi', 144), ('xxxhdpi', 192)]:
    grande = icono(lado * 4, redondo=True)
    guardar(grande.resize((lado, lado), Image.LANCZOS),
            RAIZ / f'android/app/src/main/res/mipmap-{carpeta}/ic_launcher.png')

# Web.
for lado in (192, 512):
    guardar(icono(lado * 2, redondo=True).resize((lado, lado), Image.LANCZOS),
            RAIZ / f'web/icons/Icon-{lado}.png')
    # Maskable: lleno y con el glifo dentro de la zona segura (80 %).
    guardar(icono(lado * 2, redondo=False, glifo=0.46).resize((lado, lado), Image.LANCZOS),
            RAIZ / f'web/icons/Icon-maskable-{lado}.png')
guardar(icono(256, redondo=True).resize((64, 64), Image.LANCZOS), RAIZ / 'web/favicon.png')
