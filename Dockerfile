# Use a Flutter image with a newer SDK version
FROM ghcr.io/cirruslabs/flutter:3.19.3

# Fix git permissions and set up proper pub cache
RUN git config --global --add safe.directory /sdks/flutter && \
    mkdir -p /home/flutter/.pub-cache && \
    chown -R flutter:flutter /home/flutter/.pub-cache && \
    chmod -R 777 /home/flutter/.pub-cache

# Set pub cache environment variables
ENV PUB_CACHE=/home/flutter/.pub-cache
ENV PATH="$PATH:$PUB_CACHE/bin"

# Set working directory
WORKDIR /app

# Copy project files with proper permissions
COPY --chown=flutter:flutter pubspec.yaml pubspec.lock ./

# Install dependencies
RUN flutter pub get

# Copy the rest of the project files with proper permissions
COPY --chown=flutter:flutter . .

# Build your project for Android
RUN flutter build apk --release

# Command to run your app
CMD ["flutter", "run", "--release"]