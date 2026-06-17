#!/bin/bash
set -e

# --- Captura de Parámetros ---
TARGET_OS=${1:-"all"}
TARGET_ARCH=${2:-"all"}

# Variables globales para QuickJS y Android
QUICKJS_REPO="https://github.com/bellard/quickjs.git"
QJS_VERSION=${QUICKJS_VERSION:-"master"}
API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

echo "=== Preparando el entorno ==="
rm -rf /app/dist/*
mkdir -p /app/dist

git config --global --add safe.directory /app/quickjs >/dev/null 2>&1 || true

# Clonar o actualizar QuickJS (sin depth 1 para poder viajar a cualquier commit o tag)
if [ ! -d "/app/quickjs/.git" ]; then
  echo "Clonando repositorio de QuickJS..."
  git clone -q $QUICKJS_REPO /tmp/qjs-temp >/dev/null 2>&1
  mkdir -p /app/quickjs
  mv /tmp/qjs-temp/* /tmp/qjs-temp/.[!.]* /app/quickjs/ 2>/dev/null || true
  rm -rf /tmp/qjs-temp
fi

cd /app/quickjs
echo "Sincronizando y cambiando a la versión: $QJS_VERSION"
git fetch --all --tags -q >/dev/null 2>&1 || true
git reset --hard HEAD -q >/dev/null 2>&1 || true
git clean -fd -q >/dev/null 2>&1 || true
git checkout "$QJS_VERSION" -q >/dev/null 2>&1 || true
# Hacer pull si es una rama activa; fallará silenciosamente (lo cual es correcto) si es un commit.
git pull origin "$QJS_VERSION" -q >/dev/null 2>&1 || true

# ==========================================
# FUNCIONES DE COMPILACIÓN
# ==========================================

build_linux() {
  echo "=================================================="
  echo " Compilando Linux (x86_64) - Estático"
  echo "=================================================="
  
  make clean
  
  # LDFLAGS="-static" obliga a incluir glibc y dependencias en el binario
  make -j"$(nproc)" LDFLAGS="-static" qjs
  
  # Limpiamos los símbolos para reducir el tamaño del binario nativo
  strip qjs || true
  
  mkdir -p /app/dist/linux-x86_64
  # En Linux generamos el intérprete (qjs)
  cp qjs /app/dist/linux-x86_64/
}

build_windows() {
  echo "=================================================="
  echo " Compilando Windows (x86_64-mingw32) - Estático"
  echo "=================================================="
  
  make clean
  
  # CONFIG_WIN32: Activa los flags de Windows en el Makefile.
  # HOST_CC: Garantiza que el generador de builtins se compile nativamente en el host Linux.
  # LDFLAGS="-static": Obliga a MinGW a embeber libwinpthread-1.dll (y otras libs) dentro del exe.
  make -j"$(nproc)" \
    CROSS_PREFIX=x86_64-w64-mingw32- \
    CONFIG_WIN32=y \
    HOST_CC=gcc \
    LDFLAGS="-static" \
    qjs.exe
  
  # Limpiamos los símbolos para reducir drásticamente el tamaño del .exe
  x86_64-w64-mingw32-strip qjs.exe || true

  mkdir -p /app/dist/windows-x86_64
  cp qjs.exe /app/dist/windows-x86_64/
}

build_android() {
  local ARCH=$1
  local NDK_ARCH_PREFIX=$2

  echo "=================================================="
  echo " Compilando Android: $ARCH - Dinámico PIE (Nativo)"
  echo "=================================================="

  export PATH="$PATH:$TOOLCHAIN/bin"

  # Rutas directas a las herramientas de LLVM/Clang del NDK
  local CC_PATH="$TOOLCHAIN/bin/${NDK_ARCH_PREFIX}${API_LEVEL}-clang"
  local AR_PATH="$TOOLCHAIN/bin/llvm-ar"
  local STRIP_PATH="$TOOLCHAIN/bin/llvm-strip"

  # --- Wrappers Proxy para engañar al Makefile de QuickJS ---
  local WRAPPER_DIR="/tmp/ndk_wrappers_$ARCH"
  rm -rf "$WRAPPER_DIR"
  mkdir -p "$WRAPPER_DIR"
  
  cat <<EOF > "$WRAPPER_DIR/${NDK_ARCH_PREFIX}-gcc"
#!/bin/bash
exec "$CC_PATH" "\$@"
EOF
  chmod +x "$WRAPPER_DIR/${NDK_ARCH_PREFIX}-gcc"

  cat <<EOF > "$WRAPPER_DIR/${NDK_ARCH_PREFIX}-ar"
#!/bin/bash
exec "$AR_PATH" "\$@"
EOF
  chmod +x "$WRAPPER_DIR/${NDK_ARCH_PREFIX}-ar"

  export PATH="$WRAPPER_DIR:$PATH"

  make clean

  # Dejamos que el NDK aplique PIE por defecto.
  # Solo anulamos LIBS para quitar -lpthread y compatibilizar con Bionic.
  make -j"$(nproc)" \
    CROSS_PREFIX="${NDK_ARCH_PREFIX}-" \
    HOST_CC=gcc \
    LIBS="-lm -ldl" \
    LTO=0 \
    qjs

  "$STRIP_PATH" qjs || true

  mkdir -p /app/dist/android-"$ARCH"
  cp qjs /app/dist/android-"$ARCH"/
}

# ==========================================
# ORQUESTADOR (SWITCH DE PARÁMETROS)
# ==========================================

echo ">> Objetivo seleccionado: SO=[$TARGET_OS] | Arquitectura=[$TARGET_ARCH]"

case "$TARGET_OS" in
linux)
  build_linux
  ;;
windows)
  build_windows
  ;;
android)
  if [ "$TARGET_ARCH" == "all" ]; then
    build_android "arm64-v8a" "aarch64-linux-android"
    build_android "armeabi-v7a" "armv7a-linux-androideabi"
    build_android "x86" "i686-linux-android"
    build_android "x86_64" "x86_64-linux-android"
  else
    case "$TARGET_ARCH" in
    arm64-v8a) build_android "arm64-v8a" "aarch64-linux-android" ;;
    armeabi-v7a) build_android "armeabi-v7a" "armv7a-linux-androideabi" ;;
    x86) build_android "x86" "i686-linux-android" ;;
    x86_64) build_android "x86_64" "x86_64-linux-android" ;;
    *)
      echo "❌ Arquitectura de Android no válida: $TARGET_ARCH"
      exit 1
      ;;
    esac
  fi
  ;;
all)
  build_linux
  build_windows
  build_android "arm64-v8a" "aarch64-linux-android"
  build_android "armeabi-v7a" "armv7a-linux-androideabi"
  build_android "x86" "i686-linux-android"
  build_android "x86_64" "x86_64-linux-android"
  ;;
*)
  echo "❌ Sistema operativo no válido: $TARGET_OS"
  exit 1
  ;;
esac

echo "=== Proceso completado exitosamente ==="
echo "Los binarios están listos en /app/dist"