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

# Set Java home path for Gradle
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Switch to flutteruser
USER flutteruser

# Copy pubspec files first
COPY --chown=flutteruser:flutteruser pubspec.yaml ./
COPY --chown=flutteruser:flutteruser pubspec.lock* ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application (excluding properties files we'll create)
COPY --chown=flutteruser:flutteruser . .

# Create proper Linux path configuration files
RUN mkdir -p android && \
    # Create local.properties with Linux paths
    echo "sdk.dir=/opt/android-sdk-linux" > android/local.properties && \
    echo "flutter.sdk=/sdks/flutter" >> android/local.properties && \
    echo "flutter.buildMode=release" >> android/local.properties && \
    echo "flutter.versionName=1.0.0" >> android/local.properties && \
    echo "flutter.versionCode=1" >> android/local.properties && \
    # Create gradle.properties with Linux paths
    echo "org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError" > android/gradle.properties && \
    echo "android.useAndroidX=true" >> android/gradle.properties && \
    echo "android.enableJetifier=true" >> android/gradle.properties && \
    echo "org.gradle.java.home=/usr/lib/jvm/java-17-openjdk-amd64" >> android/gradle.properties && \
    echo "org.gradle.parallel=true" >> android/gradle.properties && \
    echo "org.gradle.daemon=true" >> android/gradle.properties && \
    echo "org.gradle.configureondemand=true" >> android/gradle.properties

# Build APK
RUN flutter build apk --release

FROM alpine:latest
COPY --from=builder /home/flutteruser/app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
CMD ["echo", "Build complete"]