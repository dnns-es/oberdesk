# Fecha: 2026-10-17
# Ruta: marca/generar-icono.py
# Dibuja marca/icono.png (1024x1024) a partir de marca/icono.svg.
#
# No se convierte el SVG con una libreria: eso obligaria a instalar Cairo, que
# en Windows no viene y da mas guerra que dibujarlo. Aqui se repite el mismo
# dibujo con Pillow, que ya hace falta para los tamanos del instalador.
#
# Si se cambian los colores del SVG, se ejecuta esto y se vuelve a compilar:
#   python marca/generar-icono.py

import re
from PIL import Image, ImageDraw

ESCALA = 2                      # el SVG mide 512; se dibuja al doble y queda fino
LADO = 512 * ESCALA


def colores_del_svg(ruta='marca/icono.svg'):
    """Saca los tres colores del degradado de fondo, en orden."""
    with open(ruta, encoding='utf-8') as f:
        svg = f.read()
    fondo = svg.split('id="fondo"')[1].split('</linearGradient>')[0]
    tonos = re.findall(r'stop-color="(#[0-9a-fA-F]{6})"', fondo)
    if len(tonos) != 3:
        raise SystemExit('El degradado de fondo del SVG ya no tiene tres colores')
    return [tuple(int(t[i:i + 2], 16) for i in (1, 3, 5)) for t in tonos]


def mezclar(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def degradado_diagonal(lado, tonos):
    """Degradado en diagonal, como el x1=0,y1=0 -> x2=1,y2=1 del SVG."""
    img = Image.new('RGB', (lado, lado))
    pix = img.load()
    for y in range(lado):
        for x in range(lado):
            t = (x + y) / (2 * (lado - 1))
            if t < 0.55:
                pix[x, y] = mezclar(tonos[0], tonos[1], t / 0.55)
            else:
                pix[x, y] = mezclar(tonos[1], tonos[2], (t - 0.55) / 0.45)
    return img


def e(v):
    return v * ESCALA


tonos = colores_del_svg()
fondo = degradado_diagonal(LADO, tonos)

# Esquinas redondeadas: se recorta con una mascara.
mascara = Image.new('L', (LADO, LADO), 0)
ImageDraw.Draw(mascara).rounded_rectangle([0, 0, LADO - 1, LADO - 1], radius=e(112), fill=255)

icono = Image.new('RGBA', (LADO, LADO), (0, 0, 0, 0))
icono.paste(fondo, (0, 0), mascara)

# Brillo de la mitad de arriba.
brillo = Image.new('RGBA', (LADO, LADO), (0, 0, 0, 0))
bd = ImageDraw.Draw(brillo)
alto = LADO // 2
for y in range(alto):
    bd.line([(0, y), (LADO, y)], fill=(255, 255, 255, round(56 * (1 - y / alto))))
recorte = Image.new('RGBA', (LADO, LADO), (0, 0, 0, 0))
recorte.paste(brillo, (0, 0), mascara)
icono = Image.alpha_composite(icono, recorte)

d = ImageDraw.Draw(icono)
grosor = e(26)
blanco = (255, 255, 255, 255)

# La pantalla.
d.rounded_rectangle([e(96), e(128), e(96 + 320), e(128 + 214)],
                    radius=e(30), outline=blanco, width=grosor)
# El pie.
d.line([e(208), e(384), e(304), e(384)], fill=blanco, width=grosor, joint='curve')
d.line([e(256), e(342), e(256), e(384)], fill=blanco, width=grosor)
# El puntero dentro de la pantalla.
d.polygon([(e(222), e(184)), (e(318), e(232)), (e(276), e(247)), (e(261), e(289))], fill=blanco)

icono.resize((1024, 1024), Image.LANCZOS).save('marca/icono.png')

# El mismo dibujo pero solo el trazo blanco, sin fondo. Hace falta para el icono
# de Android (que pone el fondo por su cuenta) y para el aviso de la barra de
# estado, que Android pinta de un solo color.
glifo = Image.new('RGBA', (LADO, LADO), (0, 0, 0, 0))
g = ImageDraw.Draw(glifo)
g.rounded_rectangle([e(96), e(128), e(96 + 320), e(128 + 214)],
                    radius=e(30), outline=blanco, width=grosor)
g.line([e(208), e(384), e(304), e(384)], fill=blanco, width=grosor, joint='curve')
g.line([e(256), e(342), e(256), e(384)], fill=blanco, width=grosor)
g.polygon([(e(222), e(184)), (e(318), e(232)), (e(276), e(247)), (e(261), e(289))], fill=blanco)
glifo.resize((1024, 1024), Image.LANCZOS).save('marca/glifo.png')

print('marca/icono.png y marca/glifo.png generados con los colores del SVG')
