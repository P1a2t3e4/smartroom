# Use a Flutter image with a newer SDK version
FROM ghcr.io/cirruslabs/flutter:3.19.3

# Create a non-root user
RUN groupadd -r flutter && useradd -r -g flutter flutter
RUN mkdir -p /app && chown -R flutter:flutter /app

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

# Build your project
RUN flutter build [your-build-target]

# Command to run your app
CMD ["flutter", "run", "--release"]