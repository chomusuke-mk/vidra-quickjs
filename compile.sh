#!/bin/bash
set -euo pipefail

# --- Captura de Parámetros ---
TARGET_OS=${1:-"all"}
TARGET_ARCH=${2:-"all"}

# shellcheck disable=SC1091
source /config.sh
API_LEVEL=24
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

echo "=== Preparando el entorno ==="
echo "Descargando código fuente de QuickJS (versión: $QUICKJS_VERSION)..."
TAR_URL="https://github.com/${QUICKJS_REPO}/archive/${QUICKJS_VERSION}.tar.gz"

VIDRA_QUICKJS_DIR="/vidra/quickjs"
VIDRA_TEMP="/vidra-tmp"
VIDRA_BUILD_DIR="/dist"
rm -rf "$VIDRA_QUICKJS_DIR" "$VIDRA_TEMP"
mkdir -p "$VIDRA_QUICKJS_DIR" "$VIDRA_TEMP"
cd "$VIDRA_QUICKJS_DIR"

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
	echo " Compilando Linux (x86_64) "
	echo "=================================================="

	local QUICKJS_DIR="$VIDRA_TEMP/linux-x86_64"
	local BUILD_DIR="$VIDRA_BUILD_DIR/linux-x86_64"
	
	rm -rf "$QUICKJS_DIR" "$BUILD_DIR" && mkdir -p "$QUICKJS_DIR" "$BUILD_DIR" "$QUICKJS_DIR/vidra-build"
	cp -r "$VIDRA_QUICKJS_DIR"/* "$QUICKJS_DIR"

	pushd "$QUICKJS_DIR/vidra-build" >/dev/null

	cmake .. -DCMAKE_BUILD_TYPE=Release -DQJS_BUILD_CLI_STATIC=ON
	cmake --build . -j"$(nproc)"
	strip qjs
	cp qjs "$BUILD_DIR/quickjs"

	popd >/dev/null
	echo "QuickJS compilado y almacenado en: $BUILD_DIR"
	echo "============= Compilación completada - Linux (x86_64) ============="
}

build_windows() {
	echo "=================================================="
	echo " Compilando Windows (x86_64-mingw32) "
	echo "=================================================="

	local QUICKJS_DIR="$VIDRA_TEMP/windows-x86_64"
	local BUILD_DIR="$VIDRA_BUILD_DIR/windows-x86_64"
	rm -rf "$QUICKJS_DIR" "$BUILD_DIR" && mkdir -p "$QUICKJS_DIR" "$BUILD_DIR" "$QUICKJS_DIR/vidra-build"
	cp -r "$VIDRA_QUICKJS_DIR"/* "$QUICKJS_DIR"

	pushd "$QUICKJS_DIR/vidra-build" >/dev/null

	cmake .. \
		-DCMAKE_SYSTEM_NAME=Windows \
		-DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
		-DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
		-DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
		-DQJS_BUILD_CLI_STATIC=ON \
		-DCMAKE_BUILD_TYPE=Release
	cmake --build . -j"$(nproc)"
	x86_64-w64-mingw32-strip qjs.exe
	cp qjs.exe "$BUILD_DIR/quickjs.exe"

	popd >/dev/null
	echo "QuickJS compilado y almacenado en: $BUILD_DIR"
	echo "============= Compilación completada - Windows (x86_64) ============="
}

build_android() {
	local -x TARGET_ARCH=$1
	echo "=================================================="
	echo " Compilando Android: $TARGET_ARCH "
	echo "=================================================="

	local QUICKJS_DIR="$VIDRA_TEMP/android-$TARGET_ARCH"
	local BUILD_DIR="$VIDRA_BUILD_DIR/android-$TARGET_ARCH"
	rm -rf "$QUICKJS_DIR" "$BUILD_DIR" && mkdir -p "$QUICKJS_DIR" "$BUILD_DIR" "$QUICKJS_DIR/vidra-build"
	cp -r "$VIDRA_QUICKJS_DIR"/* "$QUICKJS_DIR"

	local -x HOST
	case "$TARGET_ARCH" in
	arm64-v8a) HOST="aarch64-linux-android" ;;
	armeabi-v7a) HOST="armv7a-linux-androideabi" ;;
	x86) HOST="i686-linux-android" ;;
	x86_64) HOST="x86_64-linux-android" ;;
	esac

	pushd "$QUICKJS_DIR/vidra-build" >/dev/null

	cmake .. \
		-DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
		-DANDROID_ABI="$TARGET_ARCH" \
		-DANDROID_PLATFORM=android-$API_LEVEL \
		-DCMAKE_BUILD_TYPE=Release

	cmake --build . -j"$(nproc)"
	"$TOOLCHAIN/bin/llvm-strip" qjs
	cp qjs "$BUILD_DIR/quickjs"

	popd >/dev/null
	echo "QuickJS compilado y almacenado en: $BUILD_DIR"
	echo "============= Compilación completada - Android ($TARGET_ARCH) ============="
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
		build_android "arm64-v8a"
		build_android "armeabi-v7a"
		build_android "x86"
		build_android "x86_64"
	else
		case "$TARGET_ARCH" in
		arm64-v8a) build_android "arm64-v8a" ;;
		armeabi-v7a) build_android "armeabi-v7a" ;;
		x86) build_android "x86" ;;
		x86_64) build_android "x86_64" ;;
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
	build_android "arm64-v8a"
	build_android "armeabi-v7a"
	build_android "x86"
	build_android "x86_64"
	;;
*)
	echo "❌ Sistema operativo no válido: $TARGET_OS"
	exit 1
	;;
esac

echo "=== Proceso completado exitosamente ==="
echo "Los binarios están listos en $VIDRA_BUILD_DIR"
