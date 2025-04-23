# Use a Flutter image with a newer SDK version
FROM ghcr.io/cirruslabs/flutter:3.19.3

# Create a non-root user
RUN groupadd -r flutter && useradd -r -g flutter flutter
RUN mkdir -p /app && chown -R flutter:flutter /app

# Fix permissions for the Flutter SDK
RUN git config --global --add safe.directory /sdks/flutter
RUN chmod -R 777 /sdks/flutter || true

# Set working directory
WORKDIR /app

# Copy project files with correct ownership
COPY --chown=flutter:flutter pubspec.yaml pubspec.lock ./

# Switch to non-root user
USER flutter

# Install dependencies
RUN flutter pub get

# Copy the rest of the project files
COPY --chown=flutter:flutter . .

# Build your project for Android
RUN flutter build apk --release

# Command to run your app (though typically you'd install the APK on a device)
CMD ["flutter", "run", "--release"]
