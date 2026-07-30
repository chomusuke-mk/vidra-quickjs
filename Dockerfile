FROM debian:bookworm-slim

# Instalar dependencias para C/C++, Make, MinGW (Windows) y herramientas de red
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl wget python3 cmake ninja-build ca-certificates \
    build-essential pkg-config unzip clang lld llvm \
    gcc-mingw-w64-x86-64-win32 \
    && rm -rf /var/lib/apt/lists/*

# Instalar Android NDK
RUN wget https://dl.google.com/android/repository/android-ndk-r27d-linux.zip -O /tmp/android-ndk-linux.zip \
    && mkdir -p /tmp/android-ndk-linux /opt/android-ndk-linux \
    && unzip /tmp/android-ndk-linux.zip -d /tmp/android-ndk-linux \
    && mv /tmp/android-ndk-linux/*/* /opt/android-ndk-linux \
    && rm -rf /tmp/android-ndk-linux.zip /tmp/android-ndk-linux
ENV ANDROID_NDK_HOME=/opt/android-ndk-linux

WORKDIR /vidra
