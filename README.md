# Multi-Platform QuickJS Builder (Docker & GitHub Actions)

Este proyecto proporciona un entorno automatizado y reproducible basado en Docker para realizar compilación cruzada del motor de JavaScript **QuickJS** (creado por Fabrice Bellard) hacia múltiples sistemas operativos y arquitecturas.

A diferencia del software distribuido por defecto, este generador compila ejecutables altamente optimizados, independientes y listos para producción.

## 🚀 Plataformas Soportadas y Formatos

El proyecto genera los siguientes archivos binarios listos para su ejecución directa:

| Sistema Operativo | Arquitectura / ABI | Tipo de Enlace                  | Nombre del Archivo Generado   |
| :---------------- | :----------------- | :------------------------------ | :---------------------------- |
| 🐧 **Linux**      | x86_64             | 100% Estático (`glibc`)         | `quickjs-linux-x86_64`        |
| 🪟 **Windows**    | x86_64             | Estático (`mingw-w64`)          | `quickjs-windows-x86_64.exe`  |
| 🤖 **Android**    | arm64-v8a          | Dinámico Nativo (PIE - API 24+) | `quickjs-android-arm64-v8a`   |
| 🤖 **Android**    | armeabi-v7a        | Dinámico Nativo (PIE - API 24+) | `quickjs-android-armeabi-v7a` |
| 🤖 **Android**    | x86                | Dinámico Nativo (PIE - API 24+) | `quickjs-android-x86`         |
| 🤖 **Android**    | x86_64             | Dinámico Nativo (PIE - API 24+) | `quickjs-android-x86_64`      |

---

## 🛠️ Requisitos Locales

Para compilar los binarios en tu máquina local, solo necesitas tener instalado:

- **Docker**
- **Docker Compose v2**

---

## 💻 Uso en Entorno Local

Puedes compilar para objetivos específicos o para todas las plataformas simultáneamente pasando los parámetros correspondientes al contenedor. Los ejecutables resultantes aparecerán automáticamente en la carpeta local `./dist/`.

### Compilar para todas las plataformas (Por defecto)

```bash
docker compose run --rm quickjs-builder all
```

### Compilar para Linux x86_64

```bash
docker compose run --rm quickjs-builder linux-x86_64
```

### Compilar para Windows x86_64

```bash
docker compose run --rm quickjs-builder windows-x86_64
```

### Compilar para Android(Todas las arquitecturas)

```bash
docker compose run --rm quickjs-builder android
```

### Compilar para una arquitectura Android específica (Ejemplo: arm64-v8a)

```bash
docker compose run --rm quickjs-builder android arm64-v8a
```

## 🤖 Automatización en CI/CD (Github Actions)

El proyecto incluye un flujo de trabajo automatizado ubicado en `.github/workflows/release.yml`
que puede dispararse de manera manual (`workflow_dispatch`) desde la pestaña Actions de tu repositorio en GitHub.

### Características del Flujo de Trabajo

1. Control de Versión Flexible: Permite ingresar manualmente un branch, tag o ID de commit específico de QuickJS. Si se deja vacío, el sistema consumirá de manera automática el último commit de la rama `master` oficial de QuickJS.

2. Evita Compilaciones Redundantes: El script consulta la API de GitHub; si detecta que la versión solicitada ya dispone de una Release con archivos publicados, detiene el proceso automáticamente para ahorrar tiempo de cómputo.

3. Notas de Lanzamiento Dinámicas: Publica un reporte claro en Markdown que adjunta la fecha exacta de compilación, el commit fuente enlazado y bloques de texto útiles.

4. Firmas de Integridad: Genera automáticamente los archivos de sumas de verificación `SHA2-256SUMS` y `SHA2-512SUMS` para validar que las descargas no estén corruptas.

5. Assets Verificados (Artifact Attestations): Implementa el estándar criptográfico de GitHub a través de Sigstore. Esto garantiza que aparezca una insignia verde de "Verified" al lado de cada binario en la pestaña de lanzamientos, protegiendo a tus usuarios contra ataques de cadena de suministro (Supply Chain Attacks).

## 📄 Licencia

Este entorno de compilación se distribuye bajo la licencia MIT. El motor QuickJS compilado pertenece a sus respectivos autores bajo su propia licencia MIT.
