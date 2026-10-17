#!/usr/bin/env bash
# Fecha: 2026-10-16
# Ruta: marca/aplicar-marca.sh
# Convierte el codigo de RustDesk en OberDesk justo antes de compilar.
#
# Por que es un script y no commits sueltos sobre el codigo: asi cada version
# nueva del motor se trae con un "git merge" limpio y la marca se vuelve a
# aplicar encima sin conflictos. Lo que se toca son nombres, iconos, textos y
# el servidor al que se conecta el programa; la logica del motor no se toca.
#
# REGLA: si un texto que hay que cambiar ya no esta donde se espera, el script
# PARA. Un sed que no encuentra nada no da error y dejaria salir un programa
# con el nombre y el servidor de otros, que es justo lo que no queremos.
#
#   bash marca/aplicar-marca.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source marca/marca.conf

cambiados=0

# Cambia un texto en un fichero y se asegura de que estaba. $1 fichero, $2 texto, $3 nuevo
cambiar() {
    local fichero="$1" viejo="$2" nuevo="$3"
    if [ ! -f "$fichero" ]; then
        echo "PARO: no existe $fichero (el motor ha cambiado de sitio los ficheros)" >&2
        exit 1
    fi
    if ! grep -qF -- "$viejo" "$fichero"; then
        echo "PARO: en $fichero no aparece: $viejo" >&2
        echo "      Lo habra cambiado una version nueva del motor. Revisar antes de compilar." >&2
        exit 1
    fi
    python - "$fichero" "$viejo" "$nuevo" <<'PY'
import sys
fichero, viejo, nuevo = sys.argv[1], sys.argv[2], sys.argv[3]
with open(fichero, encoding='utf-8') as f:
    texto = f.read()
with open(fichero, 'w', encoding='utf-8', newline='') as f:
    f.write(texto.replace(viejo, nuevo))
PY
    cambiados=$((cambiados + 1))
}

echo "== Servidor y clave =="
# Aqui es donde OberDesk deja de ser RustDesk: el programa ya no habla con los
# servidores publicos del proyecto, solo con el nuestro.
CFG=libs/hbb_common/src/config.rs
if [ ! -f "$CFG" ]; then
    echo "PARO: falta $CFG. Es un submodulo: clonar con 'git submodule update --init --recursive'." >&2
    exit 1
fi
cambiar "$CFG" 'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];' \
                "pub const RENDEZVOUS_SERVERS: &[&str] = &[\"${SERVIDOR}\"];"
cambiar "$CFG" 'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";' \
                "pub const RS_PUB_KEY: &str = \"${CLAVE}\";"
# Ademas hay que decirle que nuestro servidor es "el suyo", no uno publico.
# Si esto se queda vacio, el motor se cree que anda en los servidores abiertos
# del proyecto: ensena el aviso de "configure su propio servidor" y activa
# apanos pensados para ellos.
cambiar "$CFG" 'pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new("".to_owned());' \
                "pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new(\"${SERVIDOR}\".to_owned());"

echo "== Nombre en Windows =="
cambiar Cargo.toml 'description = "RustDesk Remote Desktop"' "description = \"${NOMBRE}\""
cambiar Cargo.toml 'ProductName = "RustDesk"'                "ProductName = \"${NOMBRE}\""
cambiar Cargo.toml 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"${NOMBRE}\""
cambiar Cargo.toml 'OriginalFilename = "rustdesk.exe"'       "OriginalFilename = \"${EJECUTABLE}.exe\""
cambiar Cargo.toml 'Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved.' \
                   "Copyright © 2026 ${EMPRESA}"
cambiar Cargo.toml 'name = "RustDesk"'                       "name = \"${NOMBRE}\""

cambiar libs/portable/Cargo.toml 'ProductName = "RustDesk"'  "ProductName = \"${NOMBRE}\""
cambiar libs/portable/Cargo.toml 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"${NOMBRE}\""
cambiar libs/portable/Cargo.toml 'OriginalFilename = "rustdesk.exe"' "OriginalFilename = \"${EJECUTABLE}.exe\""
cambiar libs/portable/src/main.rs 'const APP_PREFIX: &str = "rustdesk";' \
                                  "const APP_PREFIX: &str = \"${EJECUTABLE}\";"

RC=flutter/windows/runner/Runner.rc
cambiar "$RC" 'VALUE "CompanyName", "Purslane Tech Pte. Ltd." "\0"' "VALUE \"CompanyName\", \"${EMPRESA}\" \"\\0\""
cambiar "$RC" 'VALUE "FileDescription", "RustDesk Remote Desktop" "\0"' "VALUE \"FileDescription\", \"${NOMBRE}\" \"\\0\""
cambiar "$RC" 'VALUE "InternalName", "rustdesk" "\0"'       "VALUE \"InternalName\", \"${EJECUTABLE}\" \"\\0\""
cambiar "$RC" 'VALUE "LegalCopyright", "Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved." "\0"' \
              "VALUE \"LegalCopyright\", \"Copyright © 2026 ${EMPRESA}\" \"\\0\""
cambiar "$RC" 'VALUE "OriginalFilename", "rustdesk.exe" "\0"' "VALUE \"OriginalFilename\", \"${EJECUTABLE}.exe\" \"\\0\""
cambiar "$RC" 'VALUE "ProductName", "RustDesk" "\0"'        "VALUE \"ProductName\", \"${NOMBRE}\" \"\\0\""

echo "== Nombre en Android =="
cambiar flutter/android/app/build.gradle 'applicationId "com.carriez.flutter_hbb"' \
                                         "applicationId \"es.dnns.oberdesk\""

echo "== Nombre en Mac =="
cambiar Cargo.toml 'identifier = "com.carriez.rustdesk"' 'identifier = "es.dnns.oberdesk"'

echo "== Colores =="
# El motor es azul de arriba abajo. Aqui se cambia por el morado del icono, que
# es lo que hace que al abrirlo no parezca el programa de otra gente.
COMUN=flutter/lib/common.dart
INICIO=flutter/lib/desktop/pages/desktop_home_page.dart
cambiar "$COMUN" '0xFF0071FF' "0xFF${COLOR_PRINCIPAL}"      # acento
cambiar "$COMUN" '0x770071FF' "0x77${COLOR_PRINCIPAL}"      # acento a media tinta
cambiar "$COMUN" '0xAA0071FF' "0xAA${COLOR_PRINCIPAL}"
cambiar "$COMUN" '0xFF2C8CFF' "0xFF${COLOR_BOTON}"          # botones y avisos
cambiar "$COMUN" '0xFF00B6F0' "0xFF${COLOR_OSCURO}"         # el numero de ID
cambiar "$INICIO" '0xFF2F65BA' "0xFF${COLOR_OSCURO}"        # borde de la ventana

# El color "primary" del tema se queda en el azul de serie de Flutter aunque se
# cambie el acento: hay que decirselo en los dos temas, claro y oscuro.
cambiar "$COMUN" 'primary: Colors.blue, secondary: accent, background: grayBg' \
                 "primary: Color(0xFF${COLOR_PRINCIPAL}), secondary: accent, background: grayBg"
cambiar "$COMUN" '      primary: Colors.blue,
      secondary: accent,' \
                 "      primary: Color(0xFF${COLOR_PRINCIPAL}),
      secondary: accent,"

# La franja de aviso de la pantalla principal es rosa chicle en el motor.
cambiar "$INICIO" '                  Color.fromARGB(255, 226, 66, 188),
                  Color.fromARGB(255, 244, 114, 124),' \
                  "                  Color(0xFF${COLOR_OSCURO}),
                  Color(0xFF${COLOR_BOTON}),"

# Esquinas mas redondeadas que las del motor. Es un detalle pequeno, pero es de
# lo primero que distingue una aplicacion de otra sin leer nada.
cambiar "$COMUN" '  // ListTile
  static const ListTileThemeData listTileTheme = ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(5),' \
                 '  // ListTile
  static const ListTileThemeData listTileTheme = ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(12),'
cambiar "$COMUN" '  // Checkbox
  static const CheckboxThemeData checkboxTheme = CheckboxThemeData(
    splashRadius: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(5),' \
                 '  // Checkbox
  static const CheckboxThemeData checkboxTheme = CheckboxThemeData(
    splashRadius: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(8),'

echo "== La pantalla de Acerca de =="
AJUSTES=flutter/lib/desktop/pages/desktop_setting_page.dart
cambiar "$AJUSTES" 'Copyright © ${DateTime.now().toString().substring(0, 4)} Purslane Tech Pte. Ltd.\n$license' \
                   "Copyright © \${DateTime.now().toString().substring(0, 4)} ${EMPRESA}\\n\$license"
cambiar "$AJUSTES" "launchUrlString('https://rustdesk.com/privacy.html');" \
                   "launchUrlString('${WEB}');"
cambiar "$AJUSTES" "launchUrlString('https://rustdesk.com');" "launchUrlString('${WEB}');"
cambiar "$AJUSTES" "translate('Slogan_tip')" "'${LEMA}'"
# Este azul va en minusculas y se escapa del cambio de colores de mas arriba.
cambiar "$AJUSTES" '0xFF2c8cff' "0xFF${COLOR_BOTON}"

echo "== Textos que ve el usuario =="
# Los ficheros de idioma son listas de ("clave", "traduccion"). Solo se cambia
# la traduccion: la clave es con lo que el programa busca, y si se le cambia no
# encuentra nada y acaba enseñando la clave en crudo, que es inglés con el
# nombre de otros ("About RustDesk").
for f in src/lang/*.rs; do
    python - "$f" "$NOMBRE" <<'PY'
import re, sys
fichero, nombre = sys.argv[1], sys.argv[2]
with open(fichero, encoding='utf-8') as f:
    texto = f.read()

def una(m):
    return '("%s", "%s")' % (m.group(1), m.group(2).replace('RustDesk', nombre))

# Cada entrada es ("clave", "traduccion"), con comillas escapadas dentro.
texto = re.sub(r'\("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)', una, texto)
with open(fichero, 'w', encoding='utf-8', newline='') as f:
    f.write(texto)
PY
done

# Las claves que YA son una frase en ingles con el nombre dentro ("About
# RustDesk", "Show RustDesk"...) no tienen traduccion al ingles: el programa
# enseña la clave tal cual. Se le añade a en.rs la version con nuestro nombre.
python - "$NOMBRE" <<'PY'
import re, sys
nombre = sys.argv[1]
with open('src/lang/template.rs', encoding='utf-8') as f:
    claves = re.findall(r'\("((?:[^"\\]|\\.)*RustDesk(?:[^"\\]|\\.)*)",', f.read())
with open('src/lang/en.rs', encoding='utf-8') as f:
    en = f.read()
nuevas = [c for c in claves if '("%s",' % c not in en]
if not nuevas:
    raise SystemExit('PARO: en.rs ya trae esas claves; revisar antes de compilar')
linea = max(en.rfind('),\n'), en.rfind(')\n'))
corte = en.index('\n', linea) + 1
anadido = ''.join('        ("%s", "%s"),\n' % (c, c.replace('RustDesk', nombre)) for c in nuevas)
with open('src/lang/en.rs', 'w', encoding='utf-8', newline='') as f:
    f.write(en[:corte] + anadido + en[corte:])
print('   en.rs: %d frases en ingles que llevaban el nombre de otros' % len(nuevas))
PY
echo "   idiomas: $(ls src/lang/*.rs | wc -l) ficheros"

echo "== Iconos =="
# De marca/icono.png salen todos los tamaños, con Python y Pillow.
# No se usa ImageMagick a proposito: en Windows su comando "convert" choca con
# otro de Windows que se llama igual y hace algo muy distinto.
# El icono original del motor se guarda con .orig por si hace falta comparar.
python - "$NOMBRE" <<'PY'
from PIL import Image, ImageDraw
import os, shutil, sys

originales = ['res/icon.png', 'res/icon.ico', 'res/tray-icon.ico', 'res/32x32.png',
              'res/64x64.png', 'res/128x128.png', 'res/128x128@2x.png', 'res/mac-icon.png']
for f in originales:
    if os.path.exists(f) and not os.path.exists(f + '.orig'):
        shutil.copy2(f, f + '.orig')

icono = Image.open('marca/icono.png').convert('RGBA')

def guardar(ruta, lado):
    icono.resize((lado, lado), Image.LANCZOS).save(ruta)

shutil.copy2('marca/icono.png', 'res/icon.png')
# El .ico lleva varios tamaños dentro: Windows coge el que necesita en cada sitio
# (barra de tareas, escritorio, propiedades del archivo).
icono.save('res/icon.ico', sizes=[(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)])
icono.resize((32, 32), Image.LANCZOS).save('res/tray-icon.ico', sizes=[(32, 32)])
guardar('res/32x32.png', 32)
guardar('res/64x64.png', 64)
guardar('res/128x128.png', 128)
guardar('res/128x128@2x.png', 256)
if os.path.exists('res/mac-icon.png.orig'):
    guardar('res/mac-icon.png', 1024)

# Flutter se guarda SU PROPIO icono aparte: este es el de la ventana y el de la
# barra de tareas. Si no se cambia, el programa se llama OberDesk pero en la
# barra sale el circulo azul del motor.
icono.save('flutter/windows/runner/resources/app_icon.ico',
           sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])

# El logotipo que el programa enseña dentro de sus propias pantallas.
shutil.copy2('marca/icono.svg', 'flutter/assets/icon.svg')

# Android. El lanzador usa un icono "adaptativo": el sistema pone el fondo por
# su cuenta y encima coloca solo el dibujo, que tiene que caber en el circulo
# central (de ahi el 60 %). El de la barra de avisos va en blanco y negro.
glifo = Image.open('marca/glifo.png').convert('RGBA')
densidades = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for densidad, lado in densidades.items():
    base = 'flutter/android/app/src/main/res/mipmap-' + densidad
    icono.resize((lado, lado), Image.LANCZOS).save(base + '/ic_launcher.png')
    redondo = icono.resize((lado, lado), Image.LANCZOS)
    mascara = Image.new('L', (lado, lado), 0)
    ImageDraw.Draw(mascara).ellipse([0, 0, lado - 1, lado - 1], fill=255)
    redondo.putalpha(mascara)
    redondo.save(base + '/ic_launcher_round.png')

    frente_lado = round(lado * 2.25)          # el motor los guarda a ese tamaño
    dentro = round(frente_lado * 0.60)
    frente = Image.new('RGBA', (frente_lado, frente_lado), (0, 0, 0, 0))
    hueco = (frente_lado - dentro) // 2
    frente.paste(glifo.resize((dentro, dentro), Image.LANCZOS), (hueco, hueco))
    frente.save(base + '/ic_launcher_foreground.png')

    aviso = round(lado / 2)
    glifo.resize((aviso, aviso), Image.LANCZOS).save(base + '/ic_stat_logo.png')

print('   iconos generados a partir de marca/icono.png')
PY

# El fondo del icono de Android y el color de arranque de la app.
cambiar flutter/android/app/src/main/res/values/ic_launcher_background.xml \
        '<color name="ic_launcher_background">#ffffff</color>' \
        "<color name=\"ic_launcher_background\">#${COLOR_PRINCIPAL}</color>"
cambiar flutter/android/app/src/main/res/values/colors.xml \
        '<color name="primary">#FF0071FF</color>' \
        "<color name=\"primary\">#FF${COLOR_PRINCIPAL}</color>"

echo
echo "Marca aplicada: ${NOMBRE} · servidor ${SERVIDOR} · $cambiados textos cambiados"
