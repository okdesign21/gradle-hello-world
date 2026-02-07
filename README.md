# Gradle Hello World

This repository contains a simple Java "Hello World" application using Gradle as the build tool.

## Project Structure

- `src/main/java/com/ido/HelloWorld.java`: Main Java source file.
- `build.gradle.kts`: Gradle build configuration (Kotlin DSL).
- `Dockerfile`: Containerization setup for the app.
- `.github/workflows/ci.yml`: GitHub Actions CI workflow.
- `.github/dependabot.yaml`: GitHub Dependabot.
- `.mega-linter.yml`: MegaLinter configuration file.
- `.actrc`: Act configuration for secrets.
- `.cspell.json`: for CSpeel in MegaLinter.

## Docker

Multi-stage build with:

- Build stage: Compiles app and bumps patch version.
- SBOM stage: Generates SPDX Bill of Materials using Trivy.
- Cosign stage: Signs JAR with Cosign key and password.
- Final stage: Runs app as non-root `Kepler` user on JRE 21.

## CI

The CI pipeline is managed with GitHub Actions (`.github/workflows/ci.yml`). It runs on pull requests, pushes to master, and can be manually triggered.

### Workflow Steps

**All Branches (PR/Push):**

- Runs MegaLinter for code quality and style checks.
- Performs security scans (Trivy, TruffleHog) and uploads reports.
- Executes unit tests using Gradle.

**Master Branch Only:**

- Builds the Docker image.
- Extracts and uploads build artifacts: `app.jar`, `app.jar.bundle`, `sbom.spdx.json`, and the Docker image as tar.
- Runs Trivy scan on the built image.
- Publishes the Docker image to DockerHub with multiple tags (latest, version, commit SHA).
- Signs the Docker image with Cosign for authenticity and integrity.
- Bumps the project version in `build.gradle.kts` and commits it.
- Calls home by running the built container and validating its output.
- Creates a GitHub Release with all artifacts attached.

### Build Artifacts

The following are produced during the build and included in the release:

- `app.jar`: The compiled Java application.
- `app.jar.bundle`: Signed JAR bundle (signed with Cosign).
- `sbom.spdx.json`: Software Bill of Materials for security/compliance.
- Security reports: Trivy and TruffleHog scan outputs.

