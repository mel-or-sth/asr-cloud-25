# 🧪 Práctica: Pruebas de rendimiento con k6 en Kubernetes

## 🎯 Objetivo
Montar un **Job de Kubernetes** que lance una prueba de rendimiento usando **k6**.  
El escenario de prueba se definirá en un **script de k6 (JavaScript)** que se cargará en el pod mediante un **ConfigMap**.  
Al ejecutar el job, observaremos la salida del test desde los **logs del pod**.

---

## 🧱 1. Estructura de los ficheros

Tu entrega deberá contener al menos estos archivos:

```
/mi-practica-k6/
├── k6-configmap.yaml
├── k6-job.yaml
└── test-script.js
```

---

## 🗂️ 2. Definir el script de prueba (`test-script.js`)

Crea un script simple en **JavaScript**, que será montado en el contenedor k6.

```js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 5,        // Número de usuarios virtuales
  duration: '20s', // Duración de la prueba
};

export default function () {
  const res = http.get('https://test.k6.io');
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
```

---

## 🧩 3. Crear un ConfigMap (`k6-configmap.yaml`)

El ConfigMap contendrá el script anterior, que luego montaremos como un fichero dentro del pod.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: k6-test-script
data:
  test-script.js: |
    import http from 'k6/http';
    import { check, sleep } from 'k6';

    export const options = {
      vus: 5,
      duration: '20s',
    };

    export default function () {
      const res = http.get('https://test.k6.io');
      check(res, { 'status is 200': (r) => r.status === 200 });
      sleep(1);
    }
```

---

## ⚙️ 4. Definir el Job de Kubernetes (`k6-job.yaml`)

Este Job usará la imagen oficial de **Grafana k6**, montará el script desde el ConfigMap y ejecutará el test.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-load-test
spec:
  template:
    spec:
      containers:
        - name: k6
          image: grafana/k6:latest
          command: ["k6", "run", "/test/test-script.js"]
          volumeMounts:
            - name: k6-script
              mountPath: /test
      restartPolicy: Never
      volumes:
        - name: k6-script
          configMap:
            name: k6-test-script
  backoffLimit: 1
```

---

## 🚀 5. Desplegar en Kubernetes

Ejecuta los siguientes comandos en tu terminal:

```bash
kubectl apply -f k6-configmap.yaml
kubectl apply -f k6-job.yaml
```

Comprueba que el job se haya creado:

```bash
kubectl get jobs
```

Verifica los pods generados:

```bash
kubectl get pods
```

---

## 📜 6. Ver los resultados

Cuando el Job haya terminado, muestra los resultados del test:

```bash
kubectl logs <nombre-del-pod>
```

(En GCP u otra plataforma gestionada, también puedes ver los logs desde el **visor de logging**).

---

## 🧾 ENTREGA

Debes entregar:

1. Los ficheros:
   - `k6-configmap.yaml`
   - `k6-job.yaml`
   - `test-script.js`  
2. Una captura o fichero de texto con la **salida del test** (logs del pod o del logging del clúster).

El profesor podrá corregir ejecutando:

```bash
kubectl apply -f <folder_del_alumno>
```
