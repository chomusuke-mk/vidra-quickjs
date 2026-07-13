FROM debian:bookworm-slim

# Instalar dependencias para C/C++, Make, MinGW (Windows) y herramientas de red
RUN apt-get update && apt-get install -y \
    git curl wget python3 cmake ninja-build \
    build-essential pkg-config unzip clang lld llvm \
    gcc-mingw-w64-x86-64-win32 \
    && rm -rf /var/lib/apt/lists/*

# Descargar e instalar el Android NDK
ARG NDK_VERSION=r27d
WORKDIR /opt
RUN wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip \
    && unzip -q android-ndk-${NDK_VERSION}-linux.zip \
    && mv android-ndk-${NDK_VERSION} android-ndk-linux \
    && rm android-ndk-${NDK_VERSION}-linux.zip

ENV ANDROID_NDK_HOME=/opt/android-ndk-linux
ENV NDK_HOME=/opt/android-ndk-linux

WORKDIR /app
COPY config.sh /app/config.sh
COPY compile.sh /app/compile.sh
RUN chmod +x /app/config.sh /app/compile.sh

ENTRYPOINT ["/app/compile.sh"]