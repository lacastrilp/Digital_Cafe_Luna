¡Perfecto! Ya estamos en las **Fases 4, 5 y 6**, que son prácticamente la validación final del Lab 04. Como ya configuraste S3 + IAM + Launch Template v2, ahora vamos a comprobar que **el ASG puede reemplazar una EC2 y recuperar el mismo estado desde S3**.

> **Importante:** antes de terminar una instancia, debemos asegurarnos de que el ASG esté usando la **versión 2** del Launch Template. Si todavía aparece `$Default` y el default sigue siendo la versión 1, la nueva instancia podría nacer sin el IAM Role.

---

# Fase 4 — Recuperar capacidad y validar S3

## 4.1 Configurar el ASG

En AWS Console:

**EC2 → Auto Scaling Groups → `dcl-dev-asg-web`**

Entra a:

**Details → Group size**

Configura:

| Parámetro                | Valor |
| ------------------------ | ----: |
| Minimum desired capacity |   `2` |
| Desired capacity         |   `2` |
| Maximum desired capacity |   `4` |

Guarda con **Update**.

---

## 4.2 Verificar el Launch Template del ASG

En el mismo ASG busca:

**Launch template**

Queremos que aparezca:

```text
dcl-dev-lt-web
Version: 2
```

### ⚠️ Si aparece `$Default`

No terminemos ninguna instancia todavía.

Puedes comprobar desde CloudShell:

```bash id="2xj8bv"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[0].LaunchTemplate' \
  --output json
```

Si devuelve algo como:

```json
{
    "LaunchTemplateId": "lt-0a7428f20a910ee4e",
    "LaunchTemplateName": "dcl-dev-lt-web",
    "Version": "$Default"
}
```

hay que cambiar el ASG para que use la **versión 2**.

### Desde la consola

En:

**Auto Scaling Groups → dcl-dev-asg-web → Details**

busca **Launch template** → **Edit**.

Selecciona:

```text
Launch template: dcl-dev-lt-web
Version: 2
```

Guarda.

---

# 4.3 Verificar las instancias

En CloudShell ejecuta:

```bash id="5j0wzv"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{Min:MinSize,Desired:DesiredCapacity,Max:MaxSize,LaunchTemplate:LaunchTemplate,Instances:Instances[].{Id:InstanceId,State:LifecycleState,Health:HealthStatus}}' \
  --output json
```

Queremos ver:

```text
Min:     2
Desired: 2
Max:     4
```

y:

```text
InService
Healthy
```

para **dos instancias**.

---

# 4.4 Verificar los targets del ALB

Usa el ARN que ya tenemos:

```bash id="hpkh8e"
aws elbv2 describe-target-health \
  --target-group-arn "arn:aws:elasticloadbalancing:us-east-2:381492258467:targetgroup/dcl-dev-tg-web/0af899d3839483e1" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table
```

Queremos que las **dos instancias actuales del ASG** aparezcan:

```text
State: healthy
```

⚠️ Recuerda que actualmente existe esta instancia antigua:

```text
i-0550a71f689e6ed56
```

Esa **no es la que queremos usar como referencia del reemplazo**, porque pertenece al laboratorio anterior y no al ASG.

---

# 4.5 Verificar distribución entre AZ

Ejecuta:

```bash id="tr1o4d"
aws ec2 describe-instances \
  --instance-ids i-0a10e00bb6957c811 i-0dadd084bed622e6e \
  --query 'Reservations[].Instances[].{ID:InstanceId,AZ:Placement.AvailabilityZone,Subnet:SubnetId,State:State.Name}' \
  --output table
```

Esperamos algo similar a:

```text
----------------------------------------
| ID                 | AZ       | State |
----------------------------------------
| i-0a10...          | us-east-2a| running |
| i-0dadd...         | us-east-2b| running |
----------------------------------------
```

Esto demuestra que tenemos capacidad distribuida entre las dos AZ del baseline.

---

# Fase 4 — Prueba desde el navegador

Ahora abre:

```text
dcl-dev-alb-1671105139.us-east-2.elb.amazonaws.com
```

Puedes simplemente pegarlo en el navegador.

Refresca varias veces.

La página debería mostrar algo parecido a:

```text
Digital Cafe Luna

Datos de la instancia

Region: us-east-2
Availability Zone: us-east-2a
Instance ID: i-0a10...
```

y:

```text
Estado local de EC2

Instancia: i-0a10...
AZ: us-east-2a
Boot: 2026-...
```

y finalmente:

```text
Estado persistente en S3

{
  "project": "Digital Cafe Luna",
  "environment": "dev",
  "message": "Estado persistente almacenado fuera de EC2",
  "version": 1
}
```

Al refrescar nuevamente, el ALB debería eventualmente enviarte a la otra instancia:

```text
Instance ID: i-0dadd...
```

El **Instance ID y el boot time cambian**, pero:

```text
"project": "Digital Cafe Luna"
"environment": "dev"
"message": "Estado persistente almacenado fuera de EC2"
"version": 1
```

deben ser iguales.

### 📸 Evidencia 4

Toma capturas de **dos respuestas diferentes del ALB**:

**Captura A**

```text
Instance ID: i-0a10...
AZ: us-east-2a
Estado S3: ...
```

**Captura B**

```text
Instance ID: i-0dadd...
AZ: us-east-2b
Estado S3: ...
```

La idea es demostrar:

> Diferente cómputo + mismo estado persistente.

---

# 🚨 Fase 5 — Ahora sí hacemos la prueba principal

Esta es la evidencia más importante del laboratorio.

Primero registra los dos Instance ID que estén actualmente **InService en el ASG**.

Puedes obtenerlos directamente:

```bash id="c2lnfy"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[0].Instances[].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}' \
  --output table
```

Por ejemplo:

```text
i-0a10...   InService   Healthy
i-0dadd...  InService   Healthy
```

---

## 5.1 Captura antes del reemplazo

Antes de terminar nada, abre nuevamente el ALB y consigue una respuesta donde aparezcan:

```text
Instance ID
Availability Zone
Estado local
Estado persistente S3
```

### 📸 Evidencia 5 — ANTES

Esta captura será nuestro **Before**.

---

# 5.2 Terminar una instancia

Ahora sí.

Ve a:

**EC2 → Instances**

Selecciona **una de las dos instancias que pertenecen al ASG**.

⚠️ **NO selecciones:**

```text
i-0550a71f689e6ed56
```

porque esa es la instancia independiente antigua.

Selecciona, por ejemplo:

```text
i-0a10e00bb6957c811
```

si continúa siendo una instancia `InService` del ASG.

Después:

**Instance state → Terminate instance**

Confirma:

**Terminate**

Esto es deliberado. El laboratorio quiere demostrar que el ASG recupera automáticamente la capacidad.

---

# 5.3 Observar el reemplazo

Regresa a:

**EC2 → Auto Scaling Groups → dcl-dev-asg-web → Instances**

Inicialmente podrías ver:

```text
2 → 1
```

y luego AWS lanzará una nueva.

Después aparecerá algo como:

```text
i-0dadd...
i-0xxxxxxxx...
```

La nueva debe pasar por:

```text
Pending
```

y finalmente:

```text
InService
```

---

## 5.4 Comprobar por CLI

Puedes vigilarlo con:

```bash id="z7w6o3"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Instances:Instances[].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}}' \
  --output json
```

Espera hasta que tengas nuevamente:

```text
Desired: 2
```

y dos instancias:

```text
State: InService
Health: Healthy
```

---

# 5.5 Esperar al nuevo target Healthy

Comprueba:

```bash id="knv7ip"
aws elbv2 describe-target-health \
  --target-group-arn "arn:aws:elasticloadbalancing:us-east-2:381492258467:targetgroup/dcl-dev-tg-web/0af899d3839483e1" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table
```

Espera hasta que la **nueva instancia** aparezca:

```text
healthy
```

---

# 5.6 Prueba definitiva

Ahora vuelve al navegador:

```text
dcl-dev-alb-1671105139.us-east-2.elb.amazonaws.com
```

Refresca varias veces hasta que aparezca la **nueva Instance ID**.

Por ejemplo, si antes teníamos:

```text
ANTES
Instance ID: i-0a10e00bb6957c811
Boot: 09:10
```

después podríamos tener:

```text
DESPUÉS
Instance ID: i-0123456789abcdef
Boot: 09:18
```

Eso demuestra que es otra máquina.

Pero debe aparecer nuevamente:

```json
{
  "project": "Digital Cafe Luna",
  "environment": "dev",
  "message": "Estado persistente almacenado fuera de EC2",
  "version": 1
}
```

### 📸 Evidencia 6 — DESPUÉS

Esta es probablemente **la captura más importante del Lab 04**:

> Nueva Instance ID + nuevo estado local + mismo estado S3.

---

# 5.7 Verificación final del ASG

Ejecuta:

```bash id="w8g3hs"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{Desired:DesiredCapacity,LaunchTemplate:LaunchTemplate,Instances:Instances[].{Id:InstanceId,State:LifecycleState,Health:HealthStatus}}' \
  --output json
```

La evidencia final debe mostrar:

```text
Desired = 2
```

y:

```text
2 instancias
InService
Healthy
```

---

# Fase 6 — Contraste EBS / S3 / EFS

Esta fase **no requiere crear recursos**.

Puedes responderla así:

### EBS

**EBS** es almacenamiento de bloques asociado a una instancia EC2 en una AZ. Los datos pueden persistir aunque una instancia sea reemplazada, pero el volumen debe gestionarse mediante el ciclo de adjuntar/reasociar y no es almacenamiento compartido multi-instancia por defecto.

### S3

**S3** es independiente de una instancia concreta y almacena objetos accesibles mediante API. Para este laboratorio es adecuado porque `dcl-state.json` es un objeto pequeño de estado que debe ser compartido y sobrevivir al reemplazo de las instancias.

### EFS

**EFS** sería apropiado si varias instancias necesitaran simultáneamente un **filesystem compartido**, con semántica de archivos, mediante NFS.

---

# La respuesta conceptual más importante del Lab 04

Para la pregunta:

> **¿Qué dato sobrevivió al reemplazo y por qué?**

Puedes responder:

> **El contenido de `state/dcl-state.json` sobrevivió porque estaba almacenado en S3, fuera del ciclo de vida de las instancias EC2. La nueva instancia pudo recuperarlo mediante el IAM Role `dcl-dev-role-web`, usando credenciales temporales y el permiso mínimo `s3:GetObject`.**

---

## 📋 Checklist de entrega

Al finalizar deberías tener:

* [x] Bucket S3 privado.
* [x] `state/dcl-state.json` en S3.
* [x] `dcl-dev-policy-s3-state`.
* [x] `dcl-dev-role-web`.
* [x] Trust hacia EC2.
* [x] Sin Access Keys.
* [x] Launch Template versión 2.
* [x] IAM Instance Profile asociado.
* [ ] ASG `min=2`, `desired=2`, `max=4`.
* [ ] Dos instancias `InService`.
* [ ] Dos targets saludables.
* [ ] Instancias distribuidas en `us-east-2a` y `us-east-2b`.
* [ ] ALB mostrando diferentes Instance IDs.
* [ ] Mismo `dcl-state.json` en ambas.
* [ ] Una instancia terminada deliberadamente.
* [ ] ASG creó automáticamente una nueva.
* [ ] Nueva instancia `Healthy`.
* [ ] Nueva Instance ID visible por ALB.
* [ ] Estado local cambió.
* [ ] Estado S3 permaneció igual.
* [ ] Explicación EBS/S3/EFS.

### 🛑 Lo siguiente que quiero que hagas

**No termines todavía ninguna instancia.** Primero verifica que el ASG realmente esté usando **Launch Template versión 2**.

Ejecuta:

```bash id="f8v6hk"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[0].LaunchTemplate' \
  --output json
```

Pásame esa salida. Si aparece `"Version": "2"`, estamos listos para hacer la prueba principal.
