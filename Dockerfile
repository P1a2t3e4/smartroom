FROM ghcr.io/cirruslabs/flutter:3.29.3 AS builder

# Create non-root user
RUN useradd -m flutteruser && \
    mkdir -p /home/flutteruser/app && \
    chown -R flutteruser:flutteruser /home/flutteruser

WORKDIR /home/flutteruser/app

# Install JDK 17 as root user
USER root
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# Fix the Git ownership issue
RUN git config --global --add safe.directory /sdks/flutter

# Switch to flutteruser
USER flutteruser

# Copy pubspec files first
COPY --chown=flutteruser:flutteruser pubspec.yaml ./
COPY --chown=flutteruser:flutteruser pubspec.lock* ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY --chown=flutteruser:flutteruser . .

# Build APK
RUN flutter build apk --release

FROM alpine:latest
COPY --from=builder /home/flutteruser/app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
CMD ["echo", "Build complete"]