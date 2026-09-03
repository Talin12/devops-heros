# ---- Java Hello World (multi-stage: JDK compiles, JRE runs) ----
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY HelloServer.java .
RUN javac HelloServer.java

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/HelloServer.class .
EXPOSE 8080
CMD ["java", "HelloServer"]
