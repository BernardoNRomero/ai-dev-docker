# AI Dev Docker

Entorno para escribir PHP, HTML, CSS, JavaScript y PL/SQL con un agente local, y para correr comandos y SSH desde el mismo contenedor.

La imagen es siempre la misma. Al ejecutar `./bin/up.sh` el script lee la RAM de esa PC y ajusta modelo, contexto y topes de memoria. No hay que reconstruir nada para pasar de una notebook de 8 GB a un equipo de 16 GB o mas.

## Que incluye

- Agente [Aider](https://aider.chat/) con reglas de codigo en [workstation/CODING.md](workstation/CODING.md)
- Ollama, con un modelo de codigo elegido segun la RAM
- PHP 8.3, Apache, Composer, PHPStan y PHP-CS-Fixer
- Node.js 22, Prettier y ESLint
- Cliente SSH y herramientas de consola (`git`, `curl`, `jq`, `rg`)
- Runner `plsql` contra Oracle, sin Instant Client
- Oracle Free 23 opcional, apagado por defecto
- Open WebUI opcional, solo si la RAM alcanza

## Estructura de archivos y donde se guardan los datos

```text
ai-dev-docker/
├── bin/                      # Comandos para iniciar, detener y entrar a los servicios
│   ├── up.sh                 # Detecta RAM, genera .env.runtime y levanta el entorno
│   ├── down.sh               # Detiene servicios; con -v tambien borra volumenes
│   ├── ai.sh                 # Ejecuta Aider dentro del contenedor
│   ├── shell.sh              # Abre una shell en workstation
│   └── plsql.sh              # Ejecuta scripts SQL/PLSQL en workstation
├── workstation/              # Archivos para construir la imagen de desarrollo
│   ├── Dockerfile            # PHP, Node, Composer, Aider, Oracle driver y utilidades
│   ├── CODING.md             # Reglas e instrucciones que lee el agente
│   ├── ai.sh                 # Entrada al agente desde dentro del contenedor
│   ├── entrypoint.sh         # Prepara Aider y arranca Apache
│   ├── plsql.py              # Runner SQL/PLSQL con python-oracledb
│   ├── apache-workspace.conf # Apache publica /workspace
│   ├── dev.ini               # Configuracion PHP de desarrollo
│   ├── phpstan.neon          # Nivel y rutas de PHPStan
│   ├── .prettierrc.json      # Preferencias de formato
│   ├── ssh_config            # Configuracion SSH del contenedor
│   └── .dockerignore         # Excluye .git del contexto de construccion
├── workspace/                # Tu codigo fuente; persistente en una carpeta del host
│   ├── index.php             # Pagina PHP inicial de ejemplo
│   └── assets/styles.css     # CSS de la pagina inicial
├── ssh/                      # Claves SSH locales; ignoradas por Git
├── docker-compose.yml        # Servicios, redes, puertos, limites y volumenes
├── docker-compose.gpu.yml    # Reserva GPU NVIDIA opcional
├── .env.example              # Plantilla versionable de configuracion
├── .env                      # Configuracion y secretos locales; no versionar
├── .env.runtime              # Perfil calculado por up.sh; generado y no versionar
├── .gitignore                # Excluye secretos, claves y archivos de trabajo
└── README.md                 # Esta guia
```

### Persistencia

- **Codigo y proyectos:** guarda tus archivos en `workspace/`. Esta carpeta se monta en `/workspace` dentro de `workstation`, por lo que los cambios sobreviven a la recreacion del contenedor y se editan tambien desde el host. Apache sirve esa misma carpeta.
- **Claves SSH:** guarda solo las identidades que necesites en `ssh/`. Se montan como solo lectura en `/root/.ssh`. La carpeta se excluye de Git; los permisos de las claves privadas deben ser restrictivos.
- **Modelos descargados:** Ollama los almacena en el volumen Docker `ollama-data`, no dentro de `workspace/` ni en la imagen de desarrollo. Cambiar el modelo no borra automaticamente los anteriores.
- **Base Oracle:** si activas el perfil Oracle, sus archivos de datos persisten en el volumen `oracle-data`.
- **Conversaciones y ajustes de Open WebUI:** si activas el perfil web, persisten en `open-webui`.
- **Configuracion local:** `.env` guarda opciones y posibles secretos que completas tu; `.env.runtime` lo genera `bin/up.sh` con el modelo y limites efectivos. Ambos estan ignorados por Git. No los compartas ni los agregues a una imagen publica.
- **Contenedores e imagen:** el contenedor `workstation` se puede reconstruir; no es donde se deben guardar proyectos o datos persistentes. La configuracion reproducible esta en `workstation/` y `docker-compose.yml`.

`./bin/down.sh` detiene el stack y conserva los volumenes. `./bin/down.sh -v` los elimina junto con los datos de modelos, Oracle y Open WebUI; respalda primero lo que quieras conservar. Para ver los volumenes Docker existentes usa `docker volume ls`.

## Limite honesto de los 8 GB

En esta PC hay unos 7,5 GB. El perfil local usa `qwen2.5-coder:3b`. Sirve para borradores, HTML/CSS, funciones PHP y scripts chicos. No equivale a un modelo de frontera.

| RAM de la PC | Modelo | Contexto | Chat web | Calidad esperable |
| --- | --- | --- | --- | --- |
| menos de 12 GB | `qwen2.5-coder:3b` | 4096 | no | asistencia corta |
| 12 a 23 GB | `qwen2.5-coder:7b` | 8192 | si | bastante mejor en PHP y JS |
| 24 a 39 GB | `qwen2.5-coder:14b` | 16384 | si | codigo mas solido |
| 40 GB o mas | `qwen3-coder:30b` | 32768 | si | el salto grande, sin cambiar la imagen |

Si queres calidad alta en 8 GB, no corras el modelo aca. Apunta el mismo contenedor a una API:

```bash
# en .env
AI_BACKEND=openai
OPENAI_API_BASE=https://api.openai.com/v1
OPENAI_API_KEY=sk-...
AI_MODEL=gpt-4.1
```

```bash
./bin/up.sh --api
```

`OPENAI_API_BASE` tambien puede ser Ollama de otra PC con mas RAM, LM Studio u OpenRouter. El codigo, PHP y `plsql` siguen en este contenedor.

## Arranque

Hace falta Docker. Cerra el navegador si vas a usar el modelo local: ahora mismo esta PC tiene poca RAM libre.

```bash
cd ai-dev-docker
cp .env.example .env
./bin/up.sh
```

La primera vez descarga la imagen y el modelo (el de 3B pesa cerca de 2 GB). Despues:

- Preview: http://127.0.0.1:8086
- Agente: `./bin/ai.sh "crea un alta de clientes en PHP con validacion"`
- Shell del contenedor: `./bin/shell.sh`
- Apagar: `./bin/down.sh`

El agente pide confirmacion antes de editar o ejecutar comandos. No aplica cambios a ciegas.

## PHP, HTML, CSS y JavaScript

El codigo va en [workspace/](workspace). Apache publica esa carpeta.

Dentro del contenedor:

```bash
php -l archivo.php
phpstan analyse --memory-limit=256M -c /opt/ai/phpstan.neon archivo.php
php-cs-fixer fix archivo.php
prettier --write archivo.js archivo.css
node archivo.js
composer require ...
```

## PL/SQL

El runner usa el driver thin de `python-oracledb`. No hace falta Instant Client. Los bloques conviene terminarlos con `/` en una linea sola.

```bash
./bin/plsql.sh script.sql
```

Para una base en este Docker, solo en una PC que tenga RAM de sobra:

```bash
# en .env, cambia las dos claves
./bin/up.sh --oracle
```

En menos de 12 GB, Oracle no se levanta junto con el modelo local. En 16 GB o mas, el mismo comando alcanza. El DSN por defecto es `oracle:1521/FREEPDB1`.

Tambien podes apuntar `ORACLE_DSN` a un Oracle que ya tengas, sin levantar el perfil `oracle`.

## SSH y comandos

El contenedor tiene cliente OpenSSH. Copia tus claves a [ssh/](ssh), dale `chmod 600` a cada clave (esa carpeta no se versiona) y entra con:

```bash
./bin/shell.sh
ssh -o StrictHostKeyChecking=accept-new usuario@servidor
```

El agente puede usar `ssh`, `php`, `node`, `composer`, `git` y `plsql`. No desactives la verificacion de host para forzar una conexion.

## Pasar el mismo entorno a otra PC

1. Copia esta carpeta completa, incluido `workstation/` y los scripts de `bin/`. No hace falta exportar la imagen: `./bin/up.sh` la construye en la PC de destino.
2. En la PC nueva, con Docker instalado, corre `./bin/up.sh`.
3. No edites el Dockerfile ni el compose para "darle mas RAM". El script vuelve a medir la memoria y, si hay 16 GB o mas, sube solo el modelo, el contexto y los `mem_limit`.

Para forzar un modelo sin tocar archivos:

```bash
AI_MODEL=qwen2.5-coder:7b ./bin/up.sh
```

Si esa PC tiene GPU NVIDIA y el toolkit de Docker, `./bin/up.sh` agrega [docker-compose.gpu.yml](docker-compose.gpu.yml). Si no hay GPU, sigue en CPU.

Los modelos quedan en el volumen `ollama-data`. Cambiar de perfil descarga el modelo nuevo la primera vez y no borra el anterior.

## Variables utiles

Estan documentadas en [.env.example](.env.example). Lo que calcula el script queda en `.env.runtime` (no se versiona). Una variable definida en `.env` pisa el valor automatico.

## Uso comercial y licencias

Este repositorio es un **entorno de desarrollo**, no una imagen lista para publicar como parte de un sistema comercial ni una configuracion endurecida para produccion. Puedes usarlo para desarrollar software comercial, pero revisa por separado las licencias y condiciones de cada componente antes de redistribuir contenedores, modelos o servicios a clientes. Esta informacion es orientativa, no asesoramiento legal.

- **Modelos Qwen:** las versiones Qwen2.5-Coder y Qwen3-Coder indicadas arriba se publican bajo Apache 2.0. Esa licencia permite uso comercial; si redistribuyes pesos o una imagen que los incluya, conserva los avisos y cumple las condiciones aplicables de la licencia. Verifica la ficha y licencia de la version/tag concreto que descargues: [Qwen2.5-Coder](https://huggingface.co/Qwen/Qwen2.5-Coder-32B-Instruct) y [Qwen3-Coder](https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct).
- **Codigo generado:** el uso de estas herramientas no convierte por si solo tu aplicacion en software de codigo abierto. Tampoco garantiza que cada salida sea original, libre de derechos de terceros o apta para produccion: revisa, prueba y somete los cambios a tu proceso habitual de licencias y calidad.
- **Proveedor de API:** con `--api`, el codigo y las instrucciones enviados al modelo salen a la API configurada. Revisa sus precios, terminos, retencion, ubicacion y uso de datos; no envies secretos, datos personales ni codigo confidencial sin autorizacion. El costo de inferencia no esta incluido en Docker.
- **Oracle Database Free:** esta configuracion es para desarrollo/pruebas. Oracle permite ciertos usos internos comerciales bajo sus Free Use Terms, pero la redistribucion y el cobro tienen condiciones; ademas, la edicion Free no recibe soporte ni parches de seguridad. La imagen `gvenzl/oracle-free` es un empaquetado de terceros y no sustituye la licencia de Oracle. Antes de distribuir Oracle junto con un producto, ofrecerlo a clientes o usarlo en produccion, revisa la [licencia Oracle Free](https://www.oracle.com/downloads/licenses/oracle-free-license.html), las condiciones vigentes de la imagen y consulta a tu responsable legal/licenciamiento. Para produccion, utiliza una edicion/servicio Oracle con soporte adecuado.
- **Open WebUI:** es opcional y tiene licencia propia con condiciones sobre conservar su marca, segun el tipo y escala de despliegue. Consulta su [licencia vigente](https://github.com/open-webui/open-webui/blob/main/LICENSE) antes de redistribuirlo o ofrecerlo a usuarios.
- **Demas herramientas:** PHP, Apache, Node.js, Aider, Ollama y las utilidades tienen licencias individuales. Si distribuyes la imagen, conserva sus avisos y revisa las licencias de la version concreta y sus dependencias.

## Despliegue seguro y operacion

Para desplegar **este entorno de desarrollo** en otra maquina:

1. Instala Docker Engine y el plugin Docker Compose, copia la carpeta completa y entra en ella.
2. Ejecuta `cp .env.example .env`, configura solo los servicios que usaras y protege el archivo: `chmod 600 .env`. No guardes `.env`, `.env.runtime`, claves SSH ni contrasenas en Git.
3. Ejecuta `./bin/up.sh`. La primera construccion descarga dependencias e imagenes, y el primer arranque local descarga el modelo. Hace falta Internet en esa primera ejecucion; reserva disco para imagenes, modelos y volumenes persistentes.
4. Comprueba `docker compose ps` y `docker compose logs -f workstation ollama` (si usas Ollama). `./bin/down.sh` detiene los servicios sin borrar los volumenes.

Consideraciones importantes antes de exponer algo fuera de la PC:

- Los puertos de preview, Ollama, Open WebUI y Oracle se enlazan a `127.0.0.1`; asi quedan disponibles solo desde el host por defecto. No cambies ese enlace a `0.0.0.0` ni los publiques en Internet sin autenticacion, TLS, firewall y una revision de seguridad.
- Open WebUI esta configurado con `WEBUI_AUTH=false` para uso local. No lo expongas en una red compartida o publica con esa configuracion.
- `.env` y `.env.runtime` contienen credenciales en texto plano. Usa contrasenas unicas, no reutilices credenciales de produccion y considera un gestor de secretos si automatizas despliegues.
- Las claves SSH se montan de solo lectura, pero el proceso del contenedor puede usarlas. Monta solo las identidades necesarias, con permisos restrictivos, y no incluyas la carpeta `ssh/` en respaldos o imagenes publicas.
- `workspace/` se monta desde el host y es donde se guardan los cambios. Los modelos, datos de Oracle y datos de Open WebUI persisten en volumenes Docker. Respalda por separado el codigo y los volumenes que necesites; `./bin/down.sh -v` elimina volumenes y sus datos.
- El compose utiliza algunas etiquetas mutables (`latest` y `main`). Para un despliegue repetible, fija versiones o digests de imagen, conserva la version del modelo y prueba las actualizaciones antes de adoptarlas.
- El stack no incorpora HTTPS, autenticacion de usuarios, monitoreo, alta disponibilidad ni estrategia de respaldo/restauracion. No lo uses como sustituto de la arquitectura, controles y soporte requeridos por una aplicacion de produccion.
