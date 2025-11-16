# Imagen base
FROM ubuntu:22.04

# Actualizamos e instalamos ApacheBench
RUN apt-get update && \
    apt-get install -y apache2-utils && \
    apt-get clean

# Establecemos el comando por defecto
ENTRYPOINT ["ab"]