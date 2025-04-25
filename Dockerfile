# Multi-stage build
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS builder

# 1. First install JDK as root (before user switch)
RUN apt-get update && \
    apt-get install -y --no-install-recommends openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# 2. Then create and switch to non-root user
RUN useradd -m flutteruser && \
    mkdir -p /home/flutteruser/app && \
    chown -R flutteruser:flutteruser /home/flutteruser

WORKDIR /home/flutteruser/app
USER flutteruser

# 3. Fix Flutter SDK permissions
RUN git config --global --add safe.directory /sdks/flutter

# 4. Copy and build application
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build apk --release

# Final minimal image
FROM alpine:latest
COPY --from=builder /home/flutteruser/app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
CMD ["echo", "Build complete. APK available at /app-release.apk"]