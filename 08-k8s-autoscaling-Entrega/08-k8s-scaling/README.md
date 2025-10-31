# Autoescalado en Google Kubernetes Engine (GKE)

## Introducción

Google Kubernetes Engine (GKE) ofrece varias herramientas de autoescalado tanto a nivel de **pods** como de **infraestructura**.  
En esta práctica verás cómo:

- Configurar un *Horizontal Pod Autoscaler* (HPA)
- Activar el *Cluster Autoscaler*
- Habilitar *Node Auto Provisioning* (NAP)
- Probar el comportamiento del cluster bajo picos de carga

Trabajaremos de forma **declarativa**, utilizando **ficheros YAML** y comandos `kubectl apply`.

---

## 1️⃣ Preparación del entorno

Primero, configura tu zona de cómputo y crea el clúster GKE:

```bash
ZONE="europe-west1-b"
CLUSTER_NAME="demo-cluster"

gcloud config set compute/zone $ZONE

gcloud container clusters create $CLUSTER_NAME   --num-nodes=3   --enable-vertical-pod-autoscaling   --release-channel=rapid
```

Obtén las credenciales del cluster recién creado:

```bash
gcloud container clusters get-credentials $CLUSTER_NAME
```

---

## 2️⃣ Despliegue de la aplicación PHP-Apache

Crea un fichero llamado `php-apache.yaml` con el siguiente contenido:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  selector:
    matchLabels:
      run: php-apache
  replicas: 3
  template:
    metadata:
      labels:
        run: php-apache
    spec:
      containers:
      - name: php-apache
        image: k8s.gcr.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 500m
          requests:
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
  labels:
    run: php-apache
spec:
  ports:
  - port: 80
  selector:
    run: php-apache
```

Aplica el manifiesto:

```bash
kubectl apply -f php-apache.yaml
```

Verifica el despliegue:

```bash
kubectl get deployments
```

---

## 3️⃣ Autoescalado horizontal (HPA)

Crea un fichero `php-apache-hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

Aplica el HPA:

```bash
kubectl apply -f php-apache-hpa.yaml
```

Comprueba su estado:

```bash
kubectl get hpa
```

Deberías ver algo similar a:

```
NAME             REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache-hpa   Deployment/php-apache   0%/50%          1         10        3          2m
```

---

## 4️⃣ Autoescalado del cluster (Cluster Autoscaler)

Activa el autoescalado del cluster:

```bash
gcloud container clusters update $CLUSTER_NAME   --enable-autoscaling --min-nodes=1 --max-nodes=5
```

Cambia el perfil de autoscaling a uno más agresivo (opcional):

```bash
gcloud beta container clusters update $CLUSTER_NAME   --autoscaling-profile optimize-utilization
```

Verifica los nodos del cluster:

```bash
kubectl get nodes
```

---

## 5️⃣ Node Auto Provisioning (NAP)

Activa el *Node Auto Provisioning* para permitir que GKE cree nuevos node pools automáticamente:

```bash
gcloud container clusters update $CLUSTER_NAME   --enable-autoprovisioning   --min-cpu 1   --min-memory 2   --max-cpu 45   --max-memory 160
```

---

## 6️⃣ Test de carga y observación del escalado

Genera carga simulada sobre el servicio PHP-Apache con el siguiente comando:

```bash
kubectl run -i --tty load-generator --rm   --image=busybox   --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

Mientras tanto, en otra terminal, observa cómo responde el sistema:

```bash
watch kubectl get hpa
```

y también:

```bash
watch kubectl get deployment php-apache
```

Tras unos minutos, deberías ver:

- El número de réplicas del `php-apache` aumenta (HPA activo)
- Nuevos nodos se añaden al cluster (Cluster Autoscaler activo)
- Node pools adicionales creados (NAP activo)

---

## 7️⃣ Liberación de recursos

Cuando termines, borra todos los recursos creados:

```bash
kubectl delete -f php-apache-hpa.yaml
kubectl delete -f php-apache.yaml

gcloud container clusters delete $CLUSTER_NAME --quiet
```

---

## ✅ Resultado esperado

Al final del ejercicio habrás:

- Configurado un clúster GKE con autoescalado horizontal de pods (HPA)
- Activado el autoescalado de nodos (Cluster Autoscaler)
- Habilitado Node Auto Provisioning (NAP)
- Verificado el comportamiento ante picos de carga

Esto demuestra cómo GKE puede adaptarse automáticamente a la carga, optimizando costes y manteniendo la disponibilidad del servicio.
