# "Build once": el JAR que se probó en el pipeline es el mismo que se empaqueta.
# Antes de construir la imagen se debe ejecutar: mvn package
FROM eclipse-temurin:17-jre-alpine

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# Usuario sin privilegios (buena práctica DevSecOps: nunca correr como root)
RUN addgroup -S app && adduser -S -G app -u 10001 app
WORKDIR /app
COPY target/app.jar app.jar
USER 10001

EXPOSE 8080
# MaxRAMPercentage: la JVM respeta el límite de memoria del contenedor
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
