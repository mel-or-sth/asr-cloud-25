# 🧪 Práctica: Pruebas de rendimiento con ApacheBench (ab) en Kubernetes

## 🎯 Objetivo
Montar un **Job de Kubernetes** que ejecute pruebas de rendimiento usando **ApacheBench (ab)**.  
El objetivo es comprender cómo ejecutar tareas **efímeras** en Kubernetes, crear imágenes personalizadas con **Docker** y lanzar cargas controladas sobre un servicio.

---

## 🧱 1. Estructura de los ficheros

Tu entrega deberá contener al menos estos archivos:

```
/mi-practica-ab/
├── Dockerfile
└── job.yaml
```

---

## 🧩 2. Crear la imagen Docker con ApacheBench

Partiremos de una imagen base de **Ubuntu**, sobre la cual instalaremos ApacheBench (`ab`).  
ApacheBench se incluye en el paquete `apache2-utils`, por lo que basta con instalarlo vía `apt`.

Crea un fichero `Dockerfile` con el siguiente contenido:

```dockerfile
# Imagen base
FROM ubuntu:22.04

# Actualizamos e instalamos ApacheBench
RUN apt-get update && \
    apt-get install -y apache2-utils && \
    apt-get clean

# Establecemos el comando por defecto
ENTRYPOINT ["ab"]
```

---

## 🐳 3. Crear y subir la imagen al registry de Google Cloud

1. Compila tu imagen Docker:

   ```bash
   docker build -t gcr.io/$PROJECT/ab:v0.0.1 .
   ```

2. Haz login en tu registro (si es necesario):

   ```bash
   gcloud auth configure-docker
   ```

3. Publica la imagen en tu registry:

   ```bash
   docker push gcr.io/$PROJECT/ab:v0.0.1
   ```

---

## ⚙️ 4. Definir el Job en Kubernetes (`job.yaml`)

Lanzaremos **ApacheBench** como **Job**, para ejecutar la prueba **una sola vez**.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ab-load-test
spec:
  template:
    spec:
      containers:
      - name: ab
        image: gcr.io/myproyecto/ab:v0.0.1
        command: ["ab","-n","10000","-c","10","http://php-apache"]
      restartPolicy: Never
  backoffLimit: 2
```

---

## 🚀 5. Desplegar en Kubernetes

Ejecuta los siguientes comandos en tu terminal:

```bash
kubectl apply -f job.yaml
```

Comprueba que el Job se haya creado:

```bash
kubectl get jobs
```

Verifica los pods generados:

```bash
kubectl get pods
```

---

## 📜 6. Ver los resultados

Para revisar los resultados de la prueba, consulta los logs del pod:

```bash
kubectl logs <nombre-del-pod>
```

(En GCP u otra plataforma gestionada, también puedes ver los logs desde el **visor de logging**).

---

## 🧾 ENTREGA

Debes entregar:

1. Los ficheros:
   - `Dockerfile`
   - `job.yaml`
2. Una captura o fichero de texto con la **salida del test** (logs del pod o del logging del clúster).

El profesor podrá corregir ejecutando:

```bash
docker build .
kubectl apply -f job.yaml
```

💡 *Nota:* En entornos reales, también se podría usar un CronJob para ejecutar la prueba de forma periódica.
