# 1. First ensure you're in the correct directory
cd C:\Users\USER\Development\projects\smartroom\smartroom

# 2. Create a new Dockerfile with this exact content:
@"
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS builder

# Set working directory
WORKDIR /app

# Install JDK as root
USER root
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m flutteruser && chown -R flutteruser /app
USER flutteruser

# Copy SPECIFIC files with Windows path fix
COPY ["./pubspec.yaml", "./pubspec.lock", "./"]
RUN flutter pub get

# Copy remaining files
COPY . .
RUN flutter build apk --release

# Final image
FROM alpine:latest
COPY --from=builder /app/build/app/outputs/flutter-apk/app-release.apk /app/
CMD ["echo", "Build complete"]
"@ > Dockerfile.fixed