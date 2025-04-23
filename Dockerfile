# Use official Ubuntu base image
FROM ubuntu:20.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    libglu1-mesa \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create a flutter user and set up proper permissions
RUN useradd -ms /bin/bash flutter && \
    mkdir -p /home/flutter && \
    chown -R flutter:flutter /home/flutter

# Install Flutter SDK
ARG FLUTTER_VERSION=3.13.0
RUN mkdir -p /sdks && cd /sdks && \
    curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    rm flutter_linux_${FLUTTER_VERSION}-stable.tar.xz && \
    chown -R flutter:flutter /sdks/flutter

# Set up environment variables
ENV PATH="${PATH}:/sdks/flutter/bin:/sdks/flutter/bin/cache/dart-sdk/bin"
ENV PUB_CACHE="/home/flutter/.pub-cache"
ENV PATH="${PATH}:${PUB_CACHE}/bin"

# Fix git safe directory issue and set up pub cache
USER flutter
WORKDIR /home/flutter
RUN git config --global --add safe.directory /sdks/flutter && \
    mkdir -p ${PUB_CACHE} && \
    flutter config --no-analytics && \
    flutter doctor -v

# Set working directory and copy app files
WORKDIR /app
COPY --chown=flutter:flutter . .

# Get dependencies
RUN flutter pub get

# Build the app (uncomment when ready)
# RUN flutter build <your-platform>

# Expose ports if needed (for web server, etc.)
# EXPOSE 5000

# Set the default command to run your app
# CMD ["flutter", "run"]