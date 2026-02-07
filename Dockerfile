FROM gradle:jdk21 AS build
SHELL ["/bin/bash", "-o", "pipefail", "-e", "-c"]
WORKDIR /app
COPY gradle/ gradle/
COPY gradlew build.gradle.kts ./
COPY src/ src/

# Bump version
RUN NEW_VERSION=$(grep '^version\s*=' build.gradle.kts | sed -E 's/.*"(.*)"/\1/' | awk -F. '{print $1"."$2"."$3+1}') && \
    sed -i "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" build.gradle.kts && \
    echo "${NEW_VERSION}" > /app/VERSION.txt

RUN ./gradlew build --no-daemon

FROM aquasec/trivy:0.69.1 AS sbom
WORKDIR /app
COPY --from=build /app/build/libs/*-all.jar app.jar
RUN trivy fs --format spdx-json --output /app/sbom.spdx.json /app/app.jar

FROM bitnami/cosign:latest AS cosign
ARG DEBUG_SECRETS=0
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-e", "-c"]
WORKDIR /app
COPY --from=build /app/build/libs/*-all.jar app.jar
COPY --from=sbom /app/sbom.spdx.json /app/sbom.spdx.json
RUN --mount=type=secret,id=cosign_key \
    --mount=type=secret,id=cosign_password \
    test -s /run/secrets/cosign_key || (echo "ERROR: COSIGN_KEY is required" && exit 1) && \
    test -s /run/secrets/cosign_password || (echo "ERROR: COSIGN_PASSWORD is required" && exit 1) && \
    cat /run/secrets/cosign_key | base64 -d > /tmp/cosign_key.pem && \
    COSIGN_PASSWORD=$(cat /run/secrets/cosign_password) cosign sign-blob --yes \
      --key /tmp/cosign_key.pem \
      --bundle app.jar.bundle \
      app.jar && \
    rm /tmp/cosign_key.pem
USER 1001

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/VERSION.txt VERSION.txt
COPY --from=cosign /app/app.jar app.jar
COPY --from=cosign /app/app.jar.bundle app.jar.bundle
COPY --from=sbom /app/sbom.spdx.json /app/sbom.spdx.json
RUN groupadd -r Kepler && useradd -r -g Kepler Kepler
RUN chown -R Kepler:Kepler /app
USER Kepler
ENTRYPOINT ["java", "-jar", "app.jar"]
