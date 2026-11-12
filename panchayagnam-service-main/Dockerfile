# Multi-stage Dockerfile for Panchayagnam Core Service
# Stage 1: Build JAR using Maven
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
# Download dependencies offline cache
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime image using Eclipse Temurin JRE 17
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Run as non-root user for security
RUN groupadd -r pyapp && useradd -r -g pyapp -d /app -s /sbin/nologin pyapp
RUN mkdir -p /app/Log && chown -R pyapp:pyapp /app
USER pyapp

COPY --from=builder /app/target/panchayagnam-service-*.jar /app/app.jar

ENV PORT=8083 \
    PAPER_TRADING_ENABLED=true \
    JAVA_OPTS="-Xms64m -Xmx220m -XX:MaxMetaspaceSize=110m -XX:ReservedCodeCacheSize=32m -Xss256k -XX:+UseSerialGC"

EXPOSE 8083

ENTRYPOINT ["sh", "-c", "PROFILE=\"${SPRING_PROFILES_ACTIVE:-}\"; if [ -z \"$PROFILE\" ]; then if [ -n \"${SPRING_DATASOURCE_URL:-${DATABASE_URL:-}}\" ]; then PROFILE=prod; else PROFILE=h2; fi; fi; exec java $JAVA_OPTS -jar /app/app.jar --server.port=${PORT:-8083} --spring.profiles.active=$PROFILE --spring.h2.console.enabled=false --trading.paper-trading.enabled=${PAPER_TRADING_ENABLED:-true} --app.scrip-master.enabled=false"]
