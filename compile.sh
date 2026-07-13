#!/bin/bash
set -e

# --- Captura de Parámetros ---
TARGET_OS=${1:-"all"}
TARGET_ARCH=${2:-"all"}

# Variables globales para QuickJS y Android
# shellcheck disable=SC1091
source /app/config.sh
API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

echo "=== Preparando el entorno ==="
rm -rf /app/dist/*
mkdir -p /app/dist

echo "Descargando código fuente de QuickJS (versión: $QUICKJS_VERSION)..."
TAR_URL="https://github.com/${QUICKJS_REPO}/archive/${QUICKJS_VERSION}.tar.gz"

mkdir -p /app/quickjs
cd /app/quickjs

curl -sL "$TAR_URL" | tar xz --strip-components=1

if [ ! -f "CMakeLists.txt" ]; then
  echo "❌ Error: No se pudo extraer el código fuente correctamente desde $TAR_URL"
  exit 1
fi

# ==========================================
# FUNCIONES DE COMPILACIÓN
# ==========================================

build_linux() {
  echo "=================================================="
  echo " Compilando Linux (x86_64) - Estático"
  echo "=================================================="
  
  rm -rf build_linux
  cmake -B build_linux -DCMAKE_BUILD_TYPE=Release -DQJS_BUILD_CLI_STATIC=ON
  cmake --build build_linux -j"$(nproc)"
  
  strip build_linux/qjs || true
  
  mkdir -p /app/dist/linux-x86_64
  cp build_linux/qjs /app/dist/linux-x86_64/
}

build_windows() {
  echo "=================================================="
  echo " Compilando Windows (x86_64-mingw32) - Estático"
  echo "=================================================="
  
  rm -rf build_windows
  cmake -B build_windows \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
    -DQJS_BUILD_CLI_STATIC=ON \
    -DCMAKE_BUILD_TYPE=Release
    
  cmake --build build_windows -j"$(nproc)"
  
  x86_64-w64-mingw32-strip build_windows/qjs.exe || true

  mkdir -p /app/dist/windows-x86_64
  cp build_windows/qjs.exe /app/dist/windows-x86_64/
}

build_android() {
  local ARCH=$1

  echo "=================================================="
  echo " Compilando Android: $ARCH - Dinámico PIE (Nativo)"
  echo "=================================================="

  rm -rf "build_android_$ARCH"
  cmake -B "build_android_$ARCH" \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ARCH" \
    -DANDROID_PLATFORM=android-$API_LEVEL \
    -DCMAKE_BUILD_TYPE=Release
    
  cmake --build "build_android_$ARCH" -j"$(nproc)"

  local STRIP_PATH="$TOOLCHAIN/bin/llvm-strip"
  "$STRIP_PATH" "build_android_$ARCH/qjs" || true

  mkdir -p /app/dist/android-"$ARCH"
  cp "build_android_$ARCH/qjs" /app/dist/android-"$ARCH"/
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