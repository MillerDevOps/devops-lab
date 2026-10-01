# DevOps Lab — Preparación para DevOps Engineer

Laboratorio completo para practicar el ciclo DevOps de punta a punta con dos
aplicaciones (Java y Python), CI/CD, Kubernetes, GitOps, IaC, observabilidad y seguridad.

## Arquitectura

```
                 ┌──────────────── GitHub: MillerDevOps/devops-lab ────────────────┐
  git push ───►  │ apps/java-api   ──► Jenkins (Maven, SonarQube, Trivy)           │
                 │ apps/python-api ──► GitHub Actions (Ruff, Pytest, Trivy)        │
                 │        │ ambos publican la imagen en ghcr.io                    │
                 │        └──► actualizan la versión en gitops/<app>/kustomization │
                 └───────────────────────────────┬────────────────────────────────┘
                                                 │ ArgoCD vigila gitops/ (pull)
                                                 ▼
          VPS lab (k3s)  ┌──────────────────────────────────────────────┐
                         │ argocd      → sincroniza Git ↔ cluster       │
                         │ java-api    → 2 pods, Ingress, probes        │
                         │ python-api  → 2 pods, Ingress, probes        │
                         │ monitoring  → Prometheus + Grafana           │
                         └──────────────────────────────────────────────┘
          Terraform instala: namespaces, ArgoCD y el stack de monitoreo
```

| Requisito de la oferta           | Dónde lo practicas                                  |
|----------------------------------|-----------------------------------------------------|
| CI/CD (GitHub Actions, ArgoCD)   | `.github/workflows/`, `apps/java-api/Jenkinsfile`, `argocd/` |
| Docker / Kubernetes              | `apps/*/Dockerfile`, `gitops/`                      |
| Infraestructura como Código      | `terraform/`                                        |
| Monitoreo (Grafana, Prometheus)  | `terraform/values/monitoring.yaml`, `servicemonitor.yaml` |
| DevSecOps                        | Trivy, SonarQube, usuario no-root, `securityContext` |
| Troubleshooting / networking     | Ejercicios del Día 2 y Día 5                        |

URLs de las apps (nip.io resuelve el dominio a la IP, sin configurar DNS):
- http://java.161.97.146.175.nip.io
- http://python.161.97.146.175.nip.io

---

## Día 0 — Preparación (30 min)

1. Crea el repo **público** `MillerDevOps/devops-lab` en GitHub y sube esta carpeta a la rama `main`.
   Público = te sirve como **portafolio** para mostrar en la entrevista.
2. Crea un token (PAT classic) en GitHub con permisos `repo` y `write:packages`.
3. En el VPS del lab, deja el kubeconfig accesible para tu usuario:
   ```bash
   mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && sudo chown $USER ~/.kube/config
   ```
4. Abre el puerto **80** del VPS (Ingress). **No** abras 6443 al mundo: ArgoCD vive dentro del cluster, así que Jenkins ya no necesita acceso a la API de Kubernetes.

---

## Día 1 — Aplicaciones y Docker

**Objetivo:** entender las apps, construir imágenes y dominar el troubleshooting de contenedores.

```bash
# Python
cd apps/python-api
docker build --build-arg APP_VERSION=v1 -t ghcr.io/millerdevops/python-api:v1 .
docker run -d --name py -p 8000:8000 ghcr.io/millerdevops/python-api:v1
curl localhost:8000/api/info ; curl localhost:8000/metrics | head
# Página visual: http://IP_DEL_VPS:8000 en el navegador

# Java (primero se compila el JAR, luego la imagen: "build once")
cd ../java-api
docker run --rm -v "$PWD":/src -w /src maven:3.9-eclipse-temurin-17 mvn -B package
docker build --build-arg APP_VERSION=v1 -t ghcr.io/millerdevops/java-api:v1 .
docker run -d --name java -p 8080:8080 ghcr.io/millerdevops/java-api:v1
curl localhost:8080/actuator/health

# Publicar la versión v1 (la usa Kubernetes el Día 2)
echo TU_TOKEN | docker login ghcr.io -u MillerDevOps --password-stdin
docker push ghcr.io/millerdevops/python-api:v1
docker push ghcr.io/millerdevops/java-api:v1
```
En GitHub → *Packages* → cada paquete → *Package settings* → cambia la visibilidad a **Public**
(así el cluster puede descargar las imágenes sin credenciales).

**Ejercicios:**
- `docker ps -a`, `docker logs`, `docker inspect java | grep -A5 State`, `docker stats`.
- Provoca un OOM: `docker run --rm -m 64m ghcr.io/millerdevops/java-api:v1` y revisa el código de salida (137).
- Explica en voz alta: imagen vs contenedor, capas, por qué multi-stage, por qué usuario no-root.

---

## Día 2 — Kubernetes a mano y troubleshooting

**Objetivo:** desplegar sin ayuda y diagnosticar los errores típicos de entrevista.

```bash
kubectl apply -k gitops/python-api
kubectl apply -k gitops/java-api
kubectl get pods -A -o wide
curl http://python.161.97.146.175.nip.io/api/info
# Página visual: http://python.161.97.146.175.nip.io en el navegador
```

**Rompe y arregla** (en cada caso: `get pods`, `describe pod`, `logs --previous`, y luego `rollout undo`):

| Error               | Cómo provocarlo |
|---------------------|-----------------|
| `ImagePullBackOff`  | `kubectl -n python-api set image deploy/python-api python-api=ghcr.io/millerdevops/python-api:noexiste` |
| `CrashLoopBackOff`  | `kubectl -n python-api patch deploy python-api --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["sh","-c","exit 1"]}]'` |
| `Pending`           | `kubectl -n python-api set resources deploy/python-api --requests=memory=50Gi` |
| `OOMKilled`         | `kubectl -n java-api set resources deploy/java-api --limits=memory=100Mi` |

Observa algo clave: con `maxUnavailable: 0` los pods viejos **siguen sirviendo** mientras los nuevos fallan. La app nunca se cae.

Comandos para volver al estado sano:
```bash
kubectl -n python-api rollout undo deploy/python-api
kubectl -n python-api rollout history deploy/python-api
```

**Ejercicio de red dentro del cluster:**
```bash
kubectl run tmp --rm -it --image=busybox -- sh
  nslookup python-api.python-api.svc.cluster.local
  wget -qO- http://python-api.python-api/
```
Explica: Pod → Service (ClusterIP) → Ingress (Traefik) → usuario.

---

## Día 3 — Terraform + ArgoCD (IaC y GitOps)

```bash
# Instalar Terraform (Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

cd terraform
cp terraform.tfvars.example terraform.tfvars   # cambia la contraseña
terraform init
terraform fmt && terraform validate
terraform plan        # ¿qué va a crear?
terraform apply
terraform output
```

Registra las apps en ArgoCD:
```bash
kubectl apply -f argocd/applications.yaml
kubectl -n argocd get applications
```

Entra a las consolas **por túnel SSH** (nada expuesto a Internet). Desde tu PC:
```bash
ssh -L 8081:localhost:8081 -L 3000:localhost:3000 usuario@161.97.146.175
# ya dentro del VPS:
kubectl -n argocd port-forward svc/argocd-server 8081:80 &
kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
```
Abre http://localhost:8081 (ArgoCD) y http://localhost:3000 (Grafana).

**Ejercicios:**
- Borra un deployment a mano: `kubectl -n python-api delete deploy python-api`. ArgoCD lo recrea (**selfHeal**).
- Escala a mano a 5 réplicas: ArgoCD lo devuelve a 2. Lección: **Git es la única fuente de verdad**.
- Cambia `replicas: 3` en `gitops/python-api/deployment.yaml`, haz push y mira cómo ArgoCD sincroniza.
- Explica: estado de Terraform (`tfstate`), `plan` vs `apply`, providers, por qué no subir el state a Git.

---

## Día 4 — Pipelines CI/CD de punta a punta

### Python con GitHub Actions
Ya está listo en `.github/workflows/python-api.yml`. Solo haz un cambio en `apps/python-api/app/main.py`
(por ejemplo el texto del saludo), push, y observa:
1. **Actions** corre Lint → Tests → Build → Trivy → Push → Update GitOps.
2. **ArgoCD** detecta el commit y hace el rolling update.
3. La página http://python.161.97.146.175.nip.io muestra la **nueva versión** y **cambia de color**,
   sin recargar: verás cómo los pods viejos se reemplazan por los nuevos en vivo.

### Java con Jenkins
1. En Jenkins crea la credencial `github-creds` (usuario + PAT).
2. Crea un job *Pipeline* → *Pipeline script from SCM* → repo `devops-lab`, rama `main`,
   *Script Path*: `apps/java-api/Jenkinsfile`. Activa *GitHub hook trigger*.
3. En GitHub → *Settings → Webhooks* → `https://jenkins.stylopos.com/github-webhook/`.
4. En SonarQube → *Administration → Webhooks* → `https://jenkins.stylopos.com/sonarqube-webhook/`
   (lo necesita la etapa *Quality Gate*).

> Si tu Jenkins corre **dentro de un contenedor**, los `docker run -v $PWD...` montan rutas del host,
> no del contenedor. En ese caso configura Maven como *Tool* de Jenkins o monta el workspace con la misma ruta en el host.

### Rollback estilo GitOps
```bash
git log --oneline gitops/python-api   # busca el commit "deploy(python-api): ..."
git revert <commit> && git push      # ArgoCD vuelve a la versión anterior
```

**Ejercicio de seguridad:** cambia la imagen base de Python a una vieja (`python:3.8-slim`) y mira cómo **Trivy detiene el pipeline**.

---

## Día 5 — Observabilidad, redes y simulacro

### Grafana y PromQL
Genera tráfico:
```bash
for i in $(seq 1 1000); do curl -s http://python.161.97.146.175.nip.io/api/saludo > /dev/null; done
```
Consultas en Grafana → *Explore* (Prometheus):
```promql
sum(rate(http_requests_total{namespace="python-api"}[5m])) by (handler)
sum(rate(http_server_requests_seconds_count{namespace="java-api"}[5m])) by (uri, status)
sum(container_memory_working_set_bytes{namespace="java-api", container!=""}) by (pod)
```
Revisa los dashboards *Kubernetes / Compute Resources / Namespace (Pods)*.

### Redes, DNS y certificados
```bash
dig python.161.97.146.175.nip.io +short
curl -v http://python.161.97.146.175.nip.io/ 2>&1 | head -20
nc -zv 161.97.146.175 80
echo | openssl s_client -connect google.com:443 -servername google.com 2>/dev/null | openssl x509 -noout -subject -dates
```

### Linux (Rocky) y Podman
```bash
docker run -it --rm rockylinux:9 bash
  dnf install -y procps-ng iproute && cat /etc/os-release
```
Repasa: `dnf` vs `apt`, `firewalld` (`firewall-cmd --list-all`), SELinux (`getenforce`).
Podman usa los mismos comandos que Docker (`podman run`, `podman ps`) pero **sin demonio y sin root**.

### Retos extra (si te sobra tiempo)
- Agregar un **HorizontalPodAutoscaler** a python-api (y quitar `replicas` del deployment).
- Agregar **TLS** con cert-manager.
- Mover SonarQube también al workflow de GitHub Actions.

---

## Tu historia para la entrevista

> "Monté un laboratorio con dos microservicios, uno en Java y otro en Python. Java usa Jenkins
> con Maven, SonarQube con quality gate y Trivy; Python usa GitHub Actions. Ambos publican
> imágenes versionadas por commit en GHCR y actualizan un repositorio GitOps. ArgoCD sincroniza
> el cluster k3s con rolling updates sin caída, probes y rollback con git revert. La plataforma
> base — ArgoCD, Prometheus y Grafana — la instalo con Terraform, y monitoreo las apps con
> ServiceMonitors y PromQL. Todo está en mi GitHub."

## Preguntas que debes poder responder
1. ¿Diferencia entre CI, Continuous Delivery y Continuous Deployment?
2. ¿Por qué etiquetar imágenes con el hash del commit y no con `latest`?
3. ¿Qué es GitOps y qué diferencia hay entre modelo push (Jenkins → kubectl) y pull (ArgoCD)?
4. ¿Diferencia entre liveness, readiness y startup probe?
5. ¿Deployment vs StatefulSet? ¿Service ClusterIP vs NodePort vs LoadBalancer vs Ingress?
6. ¿Qué pasa si pierdes el `terraform.tfstate`? ¿Dónde se guarda en equipos reales?
7. ¿Cómo manejas secretos en Kubernetes? (Secrets, Sealed Secrets, Vault)
8. ¿Qué mide cada una de las métricas DORA?
9. ¿Qué harías si un pod está en CrashLoopBackOff? ¿Y en Pending?
10. ¿Qué hace Trivy y qué hace SonarQube? ¿SAST vs DAST?
