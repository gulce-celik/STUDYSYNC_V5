# ---- Build Stage ----
# JDK 21 ile Maven build (proje JDK 21 kullanıyor)
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app

# Önce bağımlılıkları çöz (Docker cache optimizasyonu)
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw dependency:resolve -B

# Kaynak kodu kopyala ve derle
COPY src/ src/
RUN ./mvnw clean package -DskipTests -B

# ---- Runtime Stage ----
# Sadece JRE ile hafif bir image (JDK'ya gerek yok)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
