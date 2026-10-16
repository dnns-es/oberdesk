# OberDesk

Programa de asistencia a distancia de DNNS: el cliente lo abre, nos da un número y
una contraseña, y vemos su pantalla para ayudarle. Las conexiones pasan por un
servidor propio de DNNS, no por servidores de terceros.

Ficha y descargas: https://dnns.es/apps.html#oberdesk

## Qué es esto y qué no

Esto es un derivado de [RustDesk](https://github.com/rustdesk/rustdesk), que es el
motor de escritorio remoto: la captura de pantalla, el vídeo, el control del ratón y
el cifrado son suyos. OberDesk le pone la marca, el idioma y, sobre todo, **el
servidor**: estos programas solo hablan con el servidor de DNNS y con ningún otro.

RustDesk se publica con licencia AGPL-3.0, así que este repositorio es público y
cualquiera puede ver qué se ha cambiado. Es la carpeta `marca/`, nada más.

## Cómo se construye

La marca no está esparcida por el código, sino en un script que se aplica justo
antes de compilar. Así, traer una versión nueva del motor es una fusión limpia y la
marca se vuelve a poner encima sin conflictos.

| Fichero | Para qué |
|---|---|
| `marca/marca.conf` | Nombre, empresa, servidor y clave |
| `marca/aplicar-marca.sh` | Cambia nombres, textos, iconos y el servidor del motor |
| `marca/icono.svg` y `marca/icono.png` | El icono; de ahí salen todos los tamaños |
| `.github/actions/marca/` | El paso que ejecuta el script dentro de cada compilación |
| `.github/workflows/oberdesk.yml` | Lanza la compilación de Windows y Android |

Para compilar: pestaña **Actions** → **Compilar OberDesk** → *Run workflow*. Al
acabar, los programas quedan colgados de esa ejecución.

El script **se para** si alguno de los textos que tiene que cambiar ya no está donde
lo espera. Es a propósito: un cambio que no se aplica no da error por su cuenta, y
saldría un programa con el nombre y el servidor de otros.

## Traer una versión nueva del motor

```bash
git fetch upstream --tags
git merge 1.5.1          # la versión que toque
bash marca/aplicar-marca.sh   # comprueba que todo sigue en su sitio
git checkout -- .             # deshacer: la marca se aplica al compilar, no se guarda
```

Si el script se para, hay que mirar qué texto cambió el motor y corregir
`aplicar-marca.sh` antes de publicar nada.
