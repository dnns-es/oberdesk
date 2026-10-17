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

echo "== Textos que ve el usuario =="
# Los ficheros de idioma llevan el nombre del programa dentro de frases enteras.
# Se cambia en todos los idiomas, no solo en español: el programa lo elige solo.
for f in src/lang/*.rs; do
    python - "$f" "$NOMBRE" <<'PY'
import sys
fichero, nombre = sys.argv[1], sys.argv[2]
with open(fichero, encoding='utf-8') as f:
    texto = f.read()
with open(fichero, 'w', encoding='utf-8', newline='') as f:
    f.write(texto.replace('RustDesk', nombre))
PY
done
echo "   idiomas: $(ls src/lang/*.rs | wc -l) ficheros"

echo "== Iconos =="
# De marca/icono.png salen todos los tamaños, con Python y Pillow.
# No se usa ImageMagick a proposito: en Windows su comando "convert" choca con
# otro de Windows que se llama igual y hace algo muy distinto.
# El icono original del motor se guarda con .orig por si hace falta comparar.
python - "$NOMBRE" <<'PY'
from PIL import Image
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
print('   iconos generados a partir de marca/icono.png')
PY

echo
echo "Marca aplicada: ${NOMBRE} · servidor ${SERVIDOR} · $cambiados textos cambiados"
