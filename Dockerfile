# Use Flutter 3.29.3 which includes Dart SDK 3.5.4 or higher
FROM ghcr.io/cirruslabs/flutter:3.29.3

# Fix permissions for the Flutter SDK
RUN git config --global --add safe.directory /sdks/flutter

# Install JDK 17 (matches your Android Studio)
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy project files
COPY pubspec.yaml pubspec.lock ./

# Install dependencies
RUN flutter pub get

# Copy the rest of the project files
COPY . .

# Configure Gradle with JDK 17 path
RUN mkdir -p ~/.gradle && \
    echo "org.gradle.java.home=$(dirname $(dirname $(readlink -f $(which javac))))" > ~/.gradle/gradle.properties

# Build your project for Android
RUN flutter build apk --release

# Command to run your app
CMD ["flutter", "run", "--release"]