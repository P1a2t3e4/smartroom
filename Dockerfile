# Use Flutter image
FROM ghcr.io/cirruslabs/flutter:3.29.3

# 1. Fix permissions and setup non-root user FIRST
RUN git config --global --add safe.directory /sdks/flutter && \
    useradd -m flutteruser && \
    mkdir -p /app && \
    chown -R flutteruser:flutteruser /app

# 2. Set working directory and switch user
WORKDIR /app
USER flutteruser

# 3. Set environment variables
ENV PUB_CACHE=/home/flutteruser/.pub-cache
ENV PATH="$PATH:$PUB_CACHE/bin"

# 4. Copy files with correct permissions
COPY --chown=flutteruser:flutteruser pubspec.yaml pubspec.lock ./

# 5. Get dependencies
RUN flutter pub get

# 6. Copy remaining files
COPY --chown=flutteruser:flutteruser . .

# 7. Fix Java compatibility (critical fix)
RUN mkdir -p ~/.gradle && \
    echo "org.gradle.java.home=$(dirname $(dirname $(readlink -f $(which javac))))" > ~/.gradle/gradle.properties && \
    echo "android.recommendedJavaVersion=11" >> ~/.gradle/gradle.properties

# 8. Build with increased memory limits
RUN flutter build apk --release --dart-define=FLUTTER_BUILD_MODE=release \
    --dart-define=FLUTTER_BUILD_DATE=$(date +%Y-%m-%d) \
    -v