# Use Google's Dart image
FROM dart:stable AS build

# Set working directory
WORKDIR /app

# 1. Copy the SERVER pubspec specifically (ignores the Flutter one)
COPY server/pubspec.* ./
RUN dart pub get

# 2. Copy the rest of the SERVER code
COPY server/ .

# 3. Compile the server
RUN dart compile exe bin/server.dart -o bin/server

# Build the minimal runtime image
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

# Expose port
EXPOSE 8080

# Start server
CMD ["/app/bin/server"]