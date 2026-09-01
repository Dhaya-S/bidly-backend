# -----------------------------------------------------------------
#  Bidly Backend — Production Dockerfile
#  Spring Boot 3.3.4 + Gradle 8.10 + Java 17 + FFmpeg / FFprobe
#  Target: Render (Linux/amd64 container runtime)
# -----------------------------------------------------------------

# =================================================================
#  STAGE 1 — Build
#  Compile the Spring Boot fat-JAR with the Gradle wrapper.
# =================================================================
FROM eclipse-temurin:17-jdk-jammy AS build

WORKDIR /workspace

# -- Dependency cache layer ----------------------------------------
# Copy only the Gradle wrapper + build scripts first so that the
# dependency-download layer is cached and only invalidated when
# build.gradle / settings.gradle actually change.
COPY gradle/             gradle/
COPY gradlew             gradlew
COPY build.gradle        build.gradle
COPY settings.gradle     settings.gradle

# Strip Windows CRLF line endings that Git may have introduced, then make executable
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew

# Warm the Gradle dependency cache (resolves deps without compiling)
RUN ./gradlew dependencies --no-daemon 2>&1 | tail -5 || true

# -- Full source copy + compile ------------------------------------
COPY src/ src/

# Build the production JAR -- skip tests (run them in CI separately)
RUN ./gradlew clean bootJar -x test --no-daemon --stacktrace

# Locate the JAR (handles any version suffix in the filename)
RUN ls -lh build/libs/ && \
    cp $(ls build/libs/*.jar | grep -v plain) /workspace/app.jar

# =================================================================
#  STAGE 2 — Runtime
#  Minimal JRE image + FFmpeg/FFprobe installed from apt.
# =================================================================
FROM eclipse-temurin:17-jre-jammy AS runtime

# -- Install FFmpeg (includes ffprobe) from Ubuntu 22.04 apt ------
# Both 'ffmpeg' and 'ffprobe' binaries end up in /usr/bin/ (on PATH)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# -- Verify FFmpeg & FFprobe are available on PATH -----------------
RUN ffmpeg -version 2>&1 | head -1 && \
    ffprobe -version 2>&1 | head -1

# -- Non-root user (security best-practice) ------------------------
RUN groupadd --gid 1001 appgroup && \
    useradd  --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

# -- Writable temp directory for video transcoding -----------------
RUN mkdir -p /tmp/bidly_media && \
    chown appuser:appgroup /tmp/bidly_media

WORKDIR /app

# -- Copy compiled JAR from build stage ----------------------------
COPY --from=build /workspace/app.jar app.jar
RUN chown appuser:appgroup app.jar

USER appuser

# -- Expose default port (Render overrides via PORT env var) -------
EXPOSE 8081

# -- Runtime entry-point ------------------------------------------
# Render sets $PORT at container start; Spring reads it via
# server.port=${PORT:8081} in application.yml.
# We also force a writable tmp dir for FFmpeg temp files.
ENTRYPOINT ["sh", "-c", \
  "exec java -Djava.io.tmpdir=/tmp/bidly_media -Dserver.port=${PORT:-8081} -jar /app/app.jar"]
