FROM ghcr.io/cirruslabs/flutter:3.29.3 AS builder

# Create non-root user (no sudo needed here)
RUN useradd -m flutteruser && \
    mkdir -p /home/flutteruser/app && \
    chown -R flutteruser:flutteruser /home/flutteruser

WORKDIR /home/flutteruser/app
USER flutteruser

# Install JDK 17 (fixed version)
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# Rest of your Dockerfile remains the same...
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build apk --release

FROM alpine:latest
COPY --from=builder /home/flutteruser/app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
CMD ["echo", "Build complete"]