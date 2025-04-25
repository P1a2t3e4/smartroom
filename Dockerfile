# Multi-stage build for smaller final image
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS builder

# Create non-root user and set up environment
RUN useradd -m flutteruser && \
    mkdir -p /home/flutteruser/app && \
    chown -R flutteruser:flutteruser /home/flutteruser

WORKDIR /home/flutteruser/app
USER flutteruser

# Fix permissions for the Flutter SDK
RUN git config --global --add safe.directory /sdks/flutter

# Install JDK 17 (matches your Android Studio)
RUN sudo apt-get update && \
    sudo apt-get install -y openjdk-17-jdk && \
    sudo rm -rf /var/lib/apt/lists/*

# Copy dependency files first to leverage Docker cache
COPY pubspec.yaml pubspec.lock ./

# Install dependencies
RUN flutter pub get

# Copy the rest of the project files
COPY . .

# Configure Gradle with optimized settings
RUN mkdir -p ~/.gradle && \
    echo "org.gradle.java.home=$(dirname $(dirname $(readlink -f $(which javac))))" > ~/.gradle/gradle.properties && \
    echo "org.gradle.daemon=true" >> ~/.gradle/gradle.properties && \
    echo "org.gradle.parallel=true" >> ~/.gradle/gradle.properties && \
    echo "org.gradle.caching=true" >> ~/.gradle/gradle.properties

# Build release APK
RUN flutter build apk --release

# Final minimal image
FROM alpine:latest

# Copy built APK from builder stage
COPY --from=builder /home/flutteruser/app/build/app/outputs/flutter-apk/app-release.apk /app/app-release.apk

# Command to run your app (if needed)
CMD ["echo", "Build complete. APK available at /app/app-release.apk"]