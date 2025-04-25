FROM ghcr.io/cirruslabs/flutter:3.29.3 AS builder

# Create non-root user
RUN useradd -m flutteruser && \
    mkdir -p /home/flutteruser/app && \
    chown -R flutteruser:flutteruser /home/flutteruser

WORKDIR /home/flutteruser/app

# Install JDK 17 as root user
# This is the critical change - we need to install packages as root
USER root
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# Switch back to non-root user for Flutter operations
USER flutteruser

# Rest of your Dockerfile remains the same
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build apk --release

FROM alpine:latest
COPY --from=builder /home/flutteruser/app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
CMD ["echo", "Build complete"]