FROM debian:bookworm-slim

# Instalar dependencias para C/C++, Make, MinGW (Windows) y herramientas de red
RUN apt-get update && apt-get install -y \
    git curl wget python3 cmake ninja-build \
    build-essential pkg-config unzip clang lld llvm \
    gcc-mingw-w64-x86-64-win32 \
    && rm -rf /var/lib/apt/lists/*

# Descargar e instalar el Android NDK
WORKDIR /opt
RUN wget -q https://dl.google.com/android/repository/android-ndk-r27b-linux.zip \
    && unzip -q android-ndk-r27b-linux.zip \
    && rm android-ndk-r27b-linux.zip

ENV ANDROID_NDK_HOME=/opt/android-ndk-r27b
ENV NDK_HOME=/opt/android-ndk-r27b

WORKDIR /app
COPY compile.sh /app/compile.sh
RUN chmod +x /app/compile.sh

ENTRYPOINT ["/app/compile.sh"]