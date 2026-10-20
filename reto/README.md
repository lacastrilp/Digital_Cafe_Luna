# Reto Terraform — Digital Café Luna

Curso: Computación en Nube · EAFIT · S15 · Peso 5 %
Entorno: AWS Academy Learner Lab · Región `us-east-1`

Este README explica **qué hace cada archivo, qué hace cada comando y por qué se hace así**.

---

## 1. ¿Qué se despliega?

| Recurso | Nombre | ¿Lo administra Terraform? | Para qué sirve |
|---|---|---|---|
| EC2 Ubuntu 20.04 `t3.micro` | `reto-tf-ec2` | Sí | Recurso de cómputo del workload |
| Security Group | `reto-tf-sg` | Sí | Firewall: controla quién entra y sale de la EC2 |
| Cola SQS Standard | `reto-tf-queue` | Sí | Recurso dependiente real (mensajería de pedidos) |
| VPC `dcl-dev-vpc` y subnet pública | existentes | **No** (solo se leen) | Red donde corre la EC2 |
| `LabInstanceProfile` | existente | **No** (solo se referencia) | Permisos IAM de la EC2 |
| AMI Ubuntu (Canonical) | pública | **No** (solo se lee) | Imagen del sistema operativo |

**Por qué así:** el reto exige que `terraform destroy` elimine solo lo creado por el reto y que no se afecte la solución base de S16. Todo lo que Terraform *lee* (con `data`) nunca se destruye. Todo lo que *crea* lleva el prefijo `reto-tf`.

---

## 2. Archivos del proyecto y qué hace cada uno

| Archivo | Contenido | Por qué existe |
|---|---|---|
| `main.tf` | Provider, data sources y recursos | Es la definición de la infraestructura |
| `variables.tf` | Parámetros de entrada | Evita valores fijos en el código (subnet, IP, prefijo) |
| `outputs.tf` | Valores de salida | Permiten localizar y probar lo desplegado |
| `terraform.tfvars.example` | Ejemplo de valores | Plantilla sin datos sensibles que sí se versiona |
| `terraform.tfvars` | Tus valores reales | **No se versiona** (está en `.gitignore`) |
| `.gitignore` | Archivos excluidos de Git | Evita subir state, credenciales y la carpeta `.terraform/` |
| `README.md` | Este documento | Instrucciones para reproducir el ciclo |

### Qué hay dentro de `main.tf`

1. **Bloque `terraform`**: fija la versión mínima de Terraform (`>= 1.3`) y la del provider AWS (`~> 5.0`). *Por qué:* para que cualquier integrante obtenga el mismo comportamiento.
2. **Bloque `provider "aws"`**: solo define la región. *Por qué sin credenciales:* el reto prohíbe credenciales en el código, y el provider las toma solo de variables de entorno.
3. **`data "aws_subnet"`**: lee la subnet existente por su ID y de ahí se obtiene la VPC. *Por qué:* reutilizar la red sin administrarla.
4. **`data "aws_ami"`**: busca la AMI más reciente de Ubuntu 20.04 publicada por Canonical. *Por qué:* un ID de AMI fijo se rompe entre regiones o con el tiempo.
5. **`aws_security_group`**: permite SSH (22) solo desde tu IP y todo el tráfico de salida. *Por qué:* control mínimo y defendible; no se abre `0.0.0.0/0` de entrada.
6. **`aws_sqs_queue`**: cola Standard con prefijo del reto. *Por qué:* es el recurso dependiente que pide el reto y permite una prueba funcional simple.
7. **`aws_instance`**: la EC2, con su subnet, su Security Group y el Instance Profile. *Por qué:* es el recurso de cómputo.

---

## 3. Prerrequisitos

- Terraform >= 1.3 (`terraform version`)
- AWS CLI (`aws --version`)
- Learner Lab de AWS Academy **iniciado** (círculo verde)
- ID de una subnet **pública** de `dcl-dev-vpc`
- Tu IP pública (búscala en https://checkip.amazonaws.com)

---

## 4. Paso a paso

### Paso 1 · Preparar tus variables

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```
Abre `terraform.tfvars` y completa:

```hcl
subnet_id = "subnet-xxxxxxxxxxxxxxxxx"   # subnet pública de dcl-dev-vpc
ssh_cidr  = "TU.IP.PUBLICA/32"           # el /32 significa "solo esa IP"
```

**Por qué:** el código no tiene datos fijos; cada integrante pone los suyos. Este archivo no se sube a Git.

### Paso 2 · Cargar las credenciales del lab

En AWS Academy: *AWS Details → Show* y copia los tres valores. En PowerShell, en **la misma terminal** donde correrás Terraform:

```powershell
$env:AWS_ACCESS_KEY_ID     = "..."
$env:AWS_SECRET_ACCESS_KEY = "..."
$env:AWS_SESSION_TOKEN     = "..."
$env:AWS_DEFAULT_REGION    = "us-east-1"
```

**Por qué así:** Terraform y la AWS CLI leen estas variables automáticamente, así que no hace falta ponerlas en el código. El `SESSION_TOKEN` es obligatorio en Learner Lab y las tres credenciales cambian en cada sesión, por lo que hay que repetir este paso cada vez.

Comprueba que funcionan:
```powershell
aws sts get-caller-identity
```
*Qué hace:* pregunta a AWS quién eres. Si responde con una cuenta y un ARN, las credenciales sirven. Si da error, la sesión expiró o copiaste mal alguna.

### Paso 3 · `terraform init`

```powershell
terraform init
```
*Qué hace:* descarga el provider de AWS y prepara la carpeta `.terraform/`.
*Por qué primero:* sin esto ningún otro comando funciona.
*Resultado esperado:* `Terraform has been successfully initialized!`

### Paso 4 · `terraform validate`

```powershell
terraform validate
```
*Qué hace:* revisa sintaxis y referencias entre recursos, **sin conectarse a AWS**.
*Por qué:* detecta errores tontos (variables no declaradas, llaves mal cerradas) antes de gastar tiempo en el plan.
*Resultado esperado:* `Success! The configuration is valid.`

### Paso 5 · `terraform plan`

```powershell
terraform plan -out=tfplan
```
*Qué hace:* compara el código con lo que existe en AWS y muestra qué va a crear, cambiar o destruir. No modifica nada.
*Por qué `-out=tfplan`:* guarda el plan exacto para aplicarlo tal cual.
*Qué revisar:* debe decir `Plan: 3 to add, 0 to change, 0 to destroy.` (EC2, Security Group y SQS). Si aparece algo de VPC o subnet, **detente**: algo está mal.

### Paso 6 · `terraform apply`

```powershell
terraform apply tfplan
```
*Qué hace:* crea los recursos en AWS.
*Por qué con `tfplan`:* aplica exactamente lo que revisaste en el paso anterior.
*Resultado esperado:* `Apply complete! Resources: 3 added, 0 changed, 0 destroyed.`

### Paso 7 · Ver los outputs

```powershell
terraform output
```
*Qué hace:* muestra `instance_id`, `instance_public_ip`, `instance_private_ip` y `queue_url`.
*Por qué:* son los datos que necesitas para probar lo desplegado.

### Paso 8 · Functional check (prueba real)

**a) La EC2 está corriendo**
```powershell
aws ec2 describe-instances --instance-ids (terraform output -raw instance_id) `
  --query "Reservations[].Instances[].State.Name" --output text
```
*Qué hace:* consulta el estado de la instancia. Esperado: `running`.

**b) La cola funciona**
```powershell
$Q = terraform output -raw queue_url
aws sqs send-message --queue-url $Q --message-body "hola reto terraform"
aws sqs receive-message --queue-url $Q
```
*Qué hace:* guarda la URL en una variable, envía un mensaje y lo recibe.
*Esperado:* el segundo comando devuelve un mensaje con el cuerpo `hola reto terraform`.
*Por qué:* el reto dice que entregar solo `.tf` sin prueba funcional no cumple. Esto demuestra que lo creado realmente funciona.

### Paso 9 · Cleanup

```powershell
terraform state list
```
*Qué hace:* lista lo que Terraform administra. Debe mostrar **solo** `aws_instance.reto`, `aws_security_group.reto` y `aws_sqs_queue.reto`. Los `data.*` pueden aparecer, pero no se destruyen.
*Por qué antes de destruir:* el reto dice que un cleanup que afecte la solución base incumple el contrato.

```powershell
terraform destroy
```
*Qué hace:* elimina los recursos del state. Escribe `yes` para confirmar.
*Esperado:* `Destroy complete! Resources: 3 destroyed.`

---

## 5. Registro de ejecución (llenar con tus capturas)

| Gate | Resultado | Evidencia |
|---|---|---|
| terraform init | PASS / FAIL | `evidencias/01-init.png` |
| terraform validate | PASS / FAIL | `evidencias/02-validate.png` |
| terraform plan | PASS / FAIL | `evidencias/03-plan.png` |
| terraform apply | PASS / FAIL | `evidencias/04-apply.png` |
| functional check | PASS / FAIL | `evidencias/05-functional.png` |
| terraform destroy | PASS / FAIL | `evidencias/06-destroy.png` |

Antes de capturar, revisa que no se vean credenciales en pantalla.

---

## 6. Seguridad y versionado

`.gitignore` excluye `.terraform/`, `*.tfstate*`, `terraform.tfvars` y `tfplan`.

- El **state** puede contener datos sensibles, por eso no se sube.
- `.terraform/` pesa mucho y se regenera con `init`.
- `terraform.tfvars` contiene tus datos personales (IP, subnet).
- Solo se versiona `terraform.tfvars.example`, con valores de ejemplo.

---

## 7. Errores frecuentes

| Error | Causa | Solución |
|---|---|---|
| `Reference to undeclared input variable` | Se usa `var.algo` sin declararlo | Declarar la variable en `variables.tf` o quitar la referencia |
| `ExpiredToken` / `AuthFailure` / `UnauthorizedOperation` | Sesión del lab expirada o credenciales incompletas | Volver a copiar las tres variables del paso 2 |
| `No value for required variable` | Falta `subnet_id` o `ssh_cidr` | Completar `terraform.tfvars` |
| `instance_public_ip` vacío | La subnet es privada | Usar una subnet pública |
| `iam:CreateRole` denegado | AWS Academy bloquea crear roles | Usar `LabInstanceProfile` existente (ya está así) |
| `QueueAlreadyExists` | Ya hay una cola con ese nombre | Cambiar `prefix` o borrar la cola anterior |

---

## 8. Preguntas y respuestas para la sustentación

**1. ¿Qué es IaC y por qué se usa aquí?**
Definir la infraestructura en código en vez de crearla a mano. Da despliegues repetibles, versionables y auditables, y reduce los errores de los despliegues manuales que el caso identifica como problema.

**2. ¿Qué diferencia hay entre `resource` y `data`?**
`resource` crea y administra. `data` solo consulta algo existente. Lo que sale de un `data` no entra al state como administrado y nunca se destruye.

**3. ¿Por qué no crearon la VPC ni la subnet?**
El reto permite reutilizarlas. Así el `destroy` no puede afectar la solución base de S16.

**4. ¿Cómo garantizan que `destroy` solo borra lo del reto?**
Los recursos creados llevan el prefijo `reto-tf`, y antes de destruir se revisa `terraform state list` y el `plan`.

**5. ¿Qué es el state y por qué no se sube a Git?**
Es donde Terraform guarda qué recursos administra y su estado real. Puede contener datos sensibles.

**6. ¿Cómo manejan las credenciales?**
Por variables de entorno (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`). No están en el código ni en archivos versionados.

**7. ¿Por qué usan `LabInstanceProfile`?**
AWS Academy bloquea `iam:CreateRole`. Se reutiliza el perfil existente, pasado por variable.

**8. ¿Qué permite el Security Group?**
SSH solo desde `ssh_cidr` (tu IP) y toda la salida. No se abre el puerto 22 al mundo.

**9. ¿Para qué sirve el `plan` si ya existe el `apply`?**
Permite revisar los cambios antes de ejecutarlos. Evita crear o destruir algo por accidente.

**10. ¿Qué pasa si corren `apply` dos veces sin cambios?**
Nada. Terraform es idempotente y responde `No changes`.

**11. ¿Qué es el *drift*?**
Cuando alguien cambia un recurso a mano en la consola. El siguiente `plan` lo detecta y propone corregirlo.

**12. ¿Por qué fijan la versión del provider?**
Para que todos los integrantes tengan el mismo comportamiento. `~> 5.0` permite parches y cambios menores, pero no un salto de versión mayor.

**13. ¿Cómo lo reproduce otro integrante?**
Clona el repo, copia `terraform.tfvars.example` a `terraform.tfvars`, completa sus datos, exporta sus credenciales y ejecuta `init`, `validate`, `plan`, `apply`.

**14. ¿Cómo comprobaron que funciona?**
La EC2 queda `running` y un mensaje enviado a la cola se recibe correctamente.

**15. ¿Qué mejorarían con más tiempo?**
Módulos, backend remoto en S3 con bloqueo, workspaces y CI con `validate`/`plan`. El reto aclara que no son necesarios y que la complejidad innecesaria no mejora la nota.

**16. ¿Qué pasa si `destroy` falla a medias?**
Se vuelve a ejecutar. Si queda algo, se revisa con `terraform state list` y solo se borra a mano si lleva el prefijo `reto-tf`.
