# 🧪 Práctica: Pruebas de rendimiento con Locust en Kubernetes

## 🎯 Objetivo
Montar un **cluster de Locust** para ejecutar pruebas de rendimiento en un servicio web.  
El cluster estará compuesto por un **pod Master** (servidor web y orquestador) y varios **pods Worker** (que lanzan la carga).

---

## 🧱 1. Estructura de los ficheros

Tu entrega deberá contener al menos estos archivos:

```
/mi-practica-locust/
├── Dockerfile
├── locustfile.py
├── master-deployment.yaml
└── worker-deployment.yaml
```


---

## 🧩 2. Crear la imagen Docker con Locust

Partiremos de la imagen oficial de Python y instalaremos Locust.  
También incluiremos un **script de prueba básico** (`locustfile.py`) apuntando al path `/` del servicio a testear.

### Dockerfile

```dockerfile
FROM python:3.11-slim

# Instalar Locust
RUN pip install --no-cache-dir locust

# Copiar el script de pruebas
COPY locustfile.py /locustfile.py

# Comando por defecto
ENTRYPOINT ["locust"]
```
## 🗂️ 3. Script de prueba (locustfile.py)

Ejemplo simple:
```python
from locust import HttpUser, task, between

class WebsiteUser(HttpUser):
    wait_time = between(1, 5)

    @task
    def index(self):
        self.client.get("/")

```

## ⚙️ 4. Desplegar Locust en Kubernetes

a) Deployment del Master (master-deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: locust-master
spec:
  replicas: 1
  selector:
    matchLabels:
      app: locust-master
  template:
    metadata:
      labels:
        app: locust-master
    spec:
      containers:
      - name: locust-master
        image: gcr.io/myproyecto/locust:v0.0.1
        args: ["-f", "/locustfile.py", "--master"]
        ports:
        - containerPort: 8089
```

b) Deployment de los Workers (worker-deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: locust-worker
spec:
  replicas: 3
  selector:
    matchLabels:
      app: locust-worker
  template:
    metadata:
      labels:
        app: locust-worker
    spec:
      containers:
      - name: locust-worker
        image: gcr.io/myproyecto/locust:v0.0.1
        args: ["-f", "/locustfile.py", "--worker", "--master-host", "locust-master"]

```

## 🚀 5. Desplegar en Kubernetes

Ejecuta:

```bash
kubectl apply -f master-deployment.yaml
kubectl apply -f worker-deployment.yaml
```

Comprueba los pods:

```bash
kubectl get pods
```

Accede al dashboard de Locust (por defecto puerto 8089 del Master) para iniciar las pruebas.

## 📜 6. Entrega

Debes entregar:

Los ficheros:

- Dockerfile
- locustfile.py
- master-deployment.yaml
- worker-deployment.yaml

Un PDF con pantallazos de la ejecución de Locust, mostrando:

- Pruebas con distintas réplicas de servidor.

- Pruebas con HPA.

El profesor podrá corregir aplicando:

```bash
docker build -t gcr.io/$PROJECT/locust:v0.0.1 .
kubectl apply -f master-deployment.yaml
kubectl apply -f worker-deployment.yaml
```