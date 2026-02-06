FROM gradle:jdk21 AS build
WORKDIR /app
COPY gradle/ gradle/
COPY gradlew build.gradle.kts ./
COPY src/ src/
RUN ./gradlew build --no-daemon

FROM aquasec/trivy:0.69.1 AS sbom
WORKDIR /app
COPY --from=build /app/build/libs/*-all.jar app.jar
RUN trivy fs --format spdx-json --output /app/sbom.spdx.json /app/app.jar

FROM bitnami/cosign:3.0.4 AS cosign
WORKDIR /app
COPY --from=build /app/build/libs/*-all.jar app.jar
COPY --from=sbom /app/sbom.spdx.json /app/sbom.spdx.json
ARG COSIGN_KEY
ARG COSIGN_PASSWORD
ENV COSIGN_PASSWORD=${COSIGN_PASSWORD}
RUN test -n "$COSIGN_KEY" || (echo "ERROR: COSIGN_KEY is required" && exit 1) && \
    test -n "$COSIGN_PASSWORD" || (echo "ERROR: COSIGN_PASSWORD is required" && exit 1)
RUN echo "$COSIGN_KEY" > /tmp/cosign.key && \
    cosign sign-blob --yes \
      --key /tmp/cosign.key \
      --output-signature=app.jar.sig \
      app.jar && \
    rm -f /tmp/cosign.key

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=cosign /app/app.jar app.jar
COPY --from=cosign /app/app.jar.sig app.jar.sig
COPY --from=sbom /app/sbom.spdx.json /app/sbom.spdx.json
RUN groupadd -r Kepler && useradd -r -g Kepler Kepler
RUN chown -R Kepler:Kepler /app
USER Kepler
ENTRYPOINT ["java", "-jar", "app.jar"]
