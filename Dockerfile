# Use Google's Dart image
FROM dart:stable AS build

# Set working directory
WORKDIR /app

# Copy pubspec and resolve dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy app source code
COPY . .

# Compile the server
RUN dart compile exe bin/server.dart -o bin/server

# Build the runtime image
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

# Expose port
EXPOSE 8080

# Start server
CMD ["/app/bin/server"]