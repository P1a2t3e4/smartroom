# Use a Flutter image with a newer SDK version
FROM ghcr.io/cirruslabs/flutter:3.19.3

# Fix permissions for the Flutter SDK
RUN git config --global --add safe.directory /sdks/flutter

# Set working directory
WORKDIR /app

# Copy project files
COPY pubspec.yaml pubspec.lock ./

# Install dependencies
RUN flutter pub get

# Copy the rest of the project files
COPY . .

# Build your project for Android
RUN flutter build apk --release

# Command to run your app
CMD ["flutter", "run", "--release"]
