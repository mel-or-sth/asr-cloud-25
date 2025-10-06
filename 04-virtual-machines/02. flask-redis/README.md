### Introducción

En el siguiente ejemplo vamos a profundizar un poco más en la automatización de los
despliegues de aplicaciones (interconectadas) mediante `gcloud`. En este proceso de
automatización vamos a introducir también algunos de los 12-factores (12F) que deben
componer una aplicación *nativa cloud* (*cloud native* en inglés), e.g., 
vamos a introducir la praxis de explicitar la configuración de la aplicación en un
fichero de parametrización, en este caso en concreto será [config.txt](config.ini), 
así como declarar todas las dependencias en un manifiesto, en nuestro caso será
[requirements.txt](requirements.txt). 

### Previo

- Instalar docker
  ```bash
    #!/bin/bash
    # ===============================
    # Script de instalación de Docker Engine en WSL2 (Ubuntu)
    # ===============================
    
    set -e
    
    echo "[1/7] Actualizando paquetes..."
    sudo apt update && sudo apt upgrade -y
    
    echo "[2/7] Instalando dependencias..."
    sudo apt install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    echo "[3/7] Configurando clave GPG de Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo "[4/7] Agregando repositorio oficial de Docker..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    echo "[5/7] Instalando Docker Engine..."
    sudo apt update
    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-compose-plugin
    
    echo "[6/7] Configurando permisos para el usuario actual..."
    sudo usermod -aG docker $USER
    
    echo "[7/7] Instalación finalizada."
    echo "⚠️ IMPORTANTE: Cierra y vuelve a abrir tu terminal o ejecuta 'newgrp docker' para aplicar los permisos."
    
    echo
    echo "Prueba la instalación ejecutando:"
    echo "   docker run hello-world"
  ```

### La aplicación

Se trata de una aplicación sencilla escrita
en `python` (con `Flask`) la cual actúa como interfaz de comunicación con una 
base de datos `Redis`, ambos dos servicios desplegados en GCP. La idea es que la
aplicación `Flask` exponga:

- Métodp `POST` en el path `/`, que admita cargas `JSON` del tipo `{"name": "myName"}`
  que serán guardadas como entradas en la base de datos
    
- Método `GET` en el path `/`, que mostrará todos los registros guardados en la base
  de datos
    
- Método `POST` en el path `/reset`, que borrará la base da datos y mostrará 
  el índice a posteriori (que estará en blanco)
  

El código de la App está compuesto por los ficheros:

- [app.py](app.py): Código Python de la aplicación

- [requirements.txt](requirements.txt): Manifiesto de las dependencias necesarias

- [Dockerfile](Dockerfile): Fichero Docker donde se procede a la contenerización de la aplicación

Los pasos necesarios son (ver [deployment.sh](deployment.sh)):

1. Desplegar una VM en GCP con la imagen de Redis, la cual estará sirviendo a través del puerto
  (TCP) `6379`:
   
   ```shell
   set -o allexport
   source config.ini
   set +o allexport

   gcloud compute instances create-with-container $redis_server \
      --machine-type="$machine_type" \
      --container-image="$redis_image" \
      --zone=europe-west1-b \
      --quiet
   ```
   Las opciones de configuración de la máquina y de la imagen vienen dadas en el fichero
   [config.txt](config.ini)


2. Definir una variable de entorno adicional `app_image_uri` se define como `app_image_uri="eu.gcr.io/$PROJECT/$app_img"`, siendo
  `$PROJECT` el UUID de nuestro proyecto, y `$app_img` el nombre de la imagen de nuestra
  aplicación, que viene explicitado en el archivo de configuración de despliegue [config.txt](config.ini)

   
3. Contenerizar la aplicación (haciendo `docker build`), pasándole como argumento de construcción
  la IP reservada para Redis, de manera que la App pueda establecer la conexión con ésta:
  ```shell
  docker build --tag $app_image_uri . 
  
  ```
  
  Antes de subir la imagen al registry de Google, vamos a probar que nuestra imagen corra correctamente con docker.
  ```shell
  docker run $app_image_uri
  ```
  ![alt text](images/error_environ.png)
  
  ¿Qué error da? ¿Por qué puede ser este error? ¿Cómo habría que corregirlo?


  ```
  docker run -p 6379:6379 redis

  docker build -t asr-flask:v.0.0.1 .
  docker run -e REDIS_IP_GCP=host.docker.internal -p 5000:5000 --add-host=host.docker.internal:host-gateway asr-flask:v.0.0.1

  #Comprobar elementos
  curl localhost:5000 
  # Insertando primer elemento en el redis
  curl --header "Content-Type: application/json" \
  --request POST \  
  --data '{"name":"paco"}' \
  "http://localhost:5000/?name=paco"
  # Vaciando la lista
  curl localhost:5000/reset
  ```


  
  
4. Publicar la imagen de la aplicación en nuestro `Container Registry` asociado al proyecto GCP:
  ```shell
  docker push "$app_image_uri"

  docker push europe-west1-docker.pkg.dev/manifest-access-473306-h4/asr-registry/asr-flask:v.0.0.1
  ```
  
  Si falla este paso, probablemente haya que lanzar el siguiente comando para conectar nuestra instalación docker con el registry de Google
  ```shell
  gcloud auth configure-docker
  ```

5. Desplegar una VM en GCP con la imagen de la aplicación:
   ```shell
    gcloud compute instances create-with-container $app_name \
    --machine-type=$machine_type \
    --container-image=$app_image_uri \
    --tags=app-server \
    --zone=europe-west1-b \
    --container-env=REDIS_IP_GCP=$REDIS_VM_IP
   ```

6. Crear regla de `firewall` para permitir tráfico de entrada en los puerto `5000` que es la que sirve el trafico (app.py)
  y `6379` (redis):
    ```shell
    gcloud compute firewall-rules create "default-allow-onlymyip-$app_port" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:"$app_port" \
    --source-ranges=$(curl ifconfig.me) \
    --target-tags=app-server
    ```
  
Todo ello se podría haber ejecutado de forma automatica agregando todos los pasos en el siguiente script:
```shell
chmod a+x deployment.sh && ./deployment.sh
```
Esta podría ser nuestra primera infraestructura como código, pero veremos métodos más avanzados de hacer esto.

### Liberación de los recursos 
Para evitar incurrir en gastos innecesarios que acabarían con nuestros créditos
gratuitos, podemos proceder a la limpieza del proyecto ejecutando el script [clean.sh](clean-all.sh):

```shell
chmod a+x clean.sh && ./clean.sh
```

#### 🔹 Ejemplos con `curl`


```bash
#Añadir estudiante:
curl -X POST http://localhost:8080/ \
     -H "Content-Type: application/json" \
     -d '{"name": "Alice"}'

#Añadir otro estudiante:
curl -X POST http://localhost:8080/ \
     -H "Content-Type: application/json" \
     -d '{"name": "Bob"}'

#Listar estudiantes:
curl http://localhost:8080/

#Resetear lista de estudiantes:
curl -X POST http://localhost:8080/reset

#Resetear lista y añadir estudiante en un solo paso:
curl -X POST http://localhost:8080/reset \
     -H "Content-Type: application/json" \
     -d '{"name": "Charlie"}'
```
