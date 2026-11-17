# Multi-stage Dockerfile for Py Broker Microservice
# Stage 1: Build JAR using Maven
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime image using Eclipse Temurin JRE 17
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Run as non-root user for security
RUN groupadd -r pybroker && useradd -r -g pybroker -d /app -s /sbin/nologin pybroker
USER pybroker

COPY --from=builder /app/target/py-broker-service-*.jar /app/app.jar

ENV PORT=8082 \
    TRADING_PAPER_TRADING_ENABLED=false \
    TRADING_LIVE_TRADING_ENABLED=true \
    JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"

EXPOSE 8082

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
