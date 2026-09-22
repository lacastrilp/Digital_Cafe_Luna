# 1. Propósito del laboratorio

El objetivo es evolucionar el baseline de S06 para separar el ciclo de vida del **cómputo** del ciclo de vida del **estado persistente**.

La arquitectura debe conservar:

- Application Load Balancer.
- Target Group.
- Launch Template.
- Auto Scaling Group.
- VPC y red del baseline.

Y agregar:

- Bucket S3 privado.
- Objeto `state/dcl-state.json`.
- IAM Policy de mínimo privilegio.
- IAM Role para EC2.
- Instance Profile.
- Nueva versión del Launch Template que use el role y lea el objeto desde S3.

La demostración principal consiste en terminar una instancia administrada por el ASG, esperar que aparezca otra y comprobar:

```text
Instance ID          → cambia
Estado local         → cambia
Boot time            → cambia
Estado en S3         → permanece igual
```

## Pregunta rectora

> **¿Qué debe ocurrir con los datos cuando una instancia desaparece y otra toma su lugar?**

**Respuesta:**

Los datos que representan estado persistente deben sobrevivir al reemplazo de la instancia. En esta práctica, el estado compartido se almacena en `state/dcl-state.json` dentro de un bucket privado de S3. La nueva instancia lo recupera mediante un IAM Role, mientras que el estado local de la instancia cambia porque el cómputo es reemplazable.

---

# 2. Arquitectura final

```text
                           INTERNET
                               │
                               ▼
                     ┌──────────────────┐
                     │  Application     │
                     │  Load Balancer   │
                     │  dcl-dev-alb     │
                     └────────┬─────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
                 ▼                         ▼
        ┌─────────────────┐       ┌─────────────────┐
        │ EC2 / ASG       │       │ EC2 / ASG       │
        │ AZ A            │       │ AZ B            │
        │ Instance A      │       │ Instance B      │
        └────────┬────────┘       └────────┬────────┘
                 │                         │
                 └───────────┬─────────────┘
                             │
                         IAM Role
                             │
                             ▼
                    ┌─────────────────┐
                    │   S3 PRIVADO    │
                    │                 │
                    │ state/          │
                    │ dcl-state.json  │
                    └─────────────────┘
```

## Separación de responsabilidades

| Componente | Responsabilidad |
|---|---|
| ALB | Punto único de entrada HTTP |
| Target Group | Registra y verifica instancias |
| ASG | Mantiene la capacidad deseada y reemplaza instancias |
| EC2 | Cómputo reemplazable |
| Launch Template | Define cómo nace una instancia |
| IAM Role | Entrega permisos temporales a EC2 |
| IAM Policy | Define el permiso mínimo |
| S3 | Almacena el estado persistente |
| `local-state.txt` | Estado efímero de una instancia concreta |

---

# 3. Convenciones

## Región

```text
us-east-1
```



## Recursos que deben reutilizarse

```text
dcl-dev-vpc
dcl-dev-alb
dcl-dev-tg-web
dcl-dev-lt-web
dcl-dev-asg-web
```

## Recursos nuevos

```text
dcl-dev-state-<account-id>-team-XX
dcl-dev-policy-s3-state
dcl-dev-role-web
```

Objeto:

```text
state/dcl-state.json
```

## Configuración del ASG

Durante la preparación:

```text
Min     = 0
Desired = 0
Max     = 4
```

Durante la validación:

```text
Min     = 2
Desired = 2
Max     = 4
```

---

# 4. Reglas importantes del laboratorio

1. No reconstruir recursos del baseline que ya existan.
2. No crear NAT Gateway.
3. No crear S3 VPC Endpoint.
4. Las instancias permanecen en las subnets públicas del baseline.
5. No se utiliza SSH en esta práctica.
6. No se crean access keys para la aplicación.
7. El bucket S3 debe permanecer privado.
8. La policy debe permitir solamente `s3:GetObject`.
9. El permiso debe apuntar específicamente a `state/dcl-state.json`.
10. La nueva configuración debe quedar en el Launch Template, no aplicarse manualmente a una instancia.
11. Al finalizar, conservar los recursos indicados para continuidad hacia S08.
12. Eliminar recursos de costo continuo, especialmente el ALB, según el cleanup del laboratorio.

---

# 5. Variables de trabajo

Primero obtenemos el Account ID:

```bash
aws sts get-caller-identity \
  --query Account \
  --output text
```

Crear variables en CloudShell:

```bash
REGION="us-east-1"
ASG="dcl-dev-asg-web"
LT="dcl-dev-lt-web"
ALB="dcl-dev-alb"
TG="dcl-dev-tg-web"
ROLE="dcl-dev-role-web"
POLICY_NAME="dcl-dev-policy-s3-state"
```

Después de conocer el Account ID:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEAM="team-XX"
BUCKET="dcl-dev-state-${ACCOUNT_ID}-${TEAM}"

echo "$BUCKET"
```

> Sustituir `team-XX` por el equipo real.

---

# 6. FASE 0 — Descubrir y verificar el baseline

La práctica comienza con:

```text
descubrir → verificar → reutilizar → extender → validar
```

No debemos crear recursos duplicados.

## 6.1 Ver VPC

```bash
aws ec2 describe-vpcs \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=dcl-dev-vpc" \
  --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock,Default:IsDefault,State:State,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

## 6.2 Ver subnets

```bash
aws ec2 describe-subnets \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=$(aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=dcl-dev-vpc --query 'Vpcs[0].VpcId' --output text)" \
  --query 'Subnets[].{ID:SubnetId,Name:Tags[?Key==`Name`]|[0].Value,CIDR:CidrBlock,AZ:AvailabilityZone,PublicIP:MapPublicIpOnLaunch}' \
  --output table
```

## 6.3 Ver ALB

```bash
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --names dcl-dev-alb \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,State:State.Code,VPC:VpcId,Type:Type}' \
  --output table
```

## 6.4 Ver Target Group

```bash
aws elbv2 describe-target-groups \
  --region us-east-1 \
  --names dcl-dev-tg-web \
  --query 'TargetGroups[].{Name:TargetGroupName,ARN:TargetGroupArn,Port:Port,Protocol:Protocol,VPC:VpcId}' \
  --output table
```

## 6.5 Ver Launch Template

```bash
aws ec2 describe-launch-templates \
  --region us-east-1 \
  --launch-template-names dcl-dev-lt-web \
  --query 'LaunchTemplates[].{Name:LaunchTemplateName,ID:LaunchTemplateId,DefaultVersion:DefaultVersionNumber,LatestVersion:LatestVersionNumber}' \
  --output table
```

## 6.6 Ver ASG

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{Name:AutoScalingGroupName,Min:MinSize,Desired:DesiredCapacity,Max:MaxSize,LT:LaunchTemplate}' \
  --output table
```

## 6.7 Poner ASG en cero

```bash
aws autoscaling update-auto-scaling-group \
  --region us-east-1 \
  --auto-scaling-group-name dcl-dev-asg-web \
  --min-size 0 \
  --desired-capacity 0 \
  --max-size 4
```

Verificación:

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{Min:MinSize,Desired:DesiredCapacity,Max:MaxSize,Instances:Instances[].{ID:InstanceId,State:LifecycleState}}' \
  --output json
```

### Evidencia ANTES

Guardar captura de:

- VPC.
- ALB.
- Target Group.
- Launch Template.
- ASG con `Desired=0`.
- Ausencia de instancias gestionadas activas.

---

# 7. FASE 1 — Crear bucket S3 privado

## 7.1 Crear bucket

```bash
aws s3api create-bucket \
  --region us-east-1 \
  --bucket "$BUCKET"
```

Para `us-east-1` no se agrega `--create-bucket-configuration`.

## 7.2 Bloquear acceso público

```bash
aws s3api put-public-access-block \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

## 7.3 Etiquetas

```bash
aws s3api put-bucket-tagging \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --tagging 'TagSet=[
    {Key=dcl:project,Value=digital-cafe-luna},
    {Key=dcl:environment,Value=dev},
    {Key=dcl:owner-team,Value=team-XX},
    {Key=dcl:managed-by,Value=console}
  ]'
```

Cambiar `team-XX` por el equipo real.

## 7.4 Crear objeto

```bash
cat > dcl-state.json <<'EOF'
{
  "project": "Digital Cafe Luna",
  "environment": "dev",
  "message": "Estado persistente almacenado fuera de EC2",
  "version": 1
}
EOF
```

Ver contenido:

```bash
cat dcl-state.json
```

## 7.5 Subir a S3

```bash
aws s3 cp dcl-state.json \
  "s3://${BUCKET}/state/dcl-state.json" \
  --region us-east-1
```

## 7.6 Evidencias S3

Existencia del objeto:

```bash
aws s3api head-object \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --key state/dcl-state.json
```

Listado:

```bash
aws s3api list-objects-v2 \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --query 'Contents[].{Key:Key,Size:Size,LastModified:LastModified}' \
  --output table
```

Bloqueo público:

```bash
aws s3api get-public-access-block \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --output json
```

Tags:

```bash
aws s3api get-bucket-tagging \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --output table
```

### Evidencia DURANTE

Capturar:

1. Bucket.
2. Block Public Access.
3. Objeto `state/dcl-state.json`.
4. Contenido del JSON.

---

# 8. FASE 2 — IAM Policy de mínimo privilegio

La policy debe permitir exclusivamente:

```text
Action:
    s3:GetObject

Resource:
    arn:aws:s3:::BUCKET/state/dcl-state.json
```

## 8.1 Crear documento

```bash
cat > policy-s3-state.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadPersistentStateObject",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET}/state/dcl-state.json"
    }
  ]
}
EOF
```

Ver:

```bash
cat policy-s3-state.json
```

## 8.2 Crear policy

```bash
aws iam create-policy \
  --policy-name dcl-dev-policy-s3-state \
  --policy-document file://policy-s3-state.json
```

## 8.3 Obtener ARN

```bash
POLICY_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='dcl-dev-policy-s3-state'].Arn" \
  --output text)

echo "$POLICY_ARN"
```

## 8.4 Ver policy

```bash
aws iam get-policy \
  --policy-arn "$POLICY_ARN" \
  --output table
```

Contenido:

```bash
aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id v1 \
  --query 'PolicyVersion.Document' \
  --output json
```

---

# 9. FASE 2.1 — IAM Role para EC2

## 9.1 Trust policy

```bash
cat > trust-ec2.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

## 9.2 Crear role

```bash
aws iam create-role \
  --role-name dcl-dev-role-web \
  --assume-role-policy-document file://trust-ec2.json
```

## 9.3 Adjuntar policy

```bash
aws iam attach-role-policy \
  --role-name dcl-dev-role-web \
  --policy-arn "$POLICY_ARN"
```

## 9.4 Crear instance profile

```bash
aws iam create-instance-profile \
  --instance-profile-name dcl-dev-role-web
```

Agregar role:

```bash
aws iam add-role-to-instance-profile \
  --instance-profile-name dcl-dev-role-web \
  --role-name dcl-dev-role-web
```

Esperar propagación:

```bash
sleep 10
```

## 9.5 Evidencias IAM

Role:

```bash
aws iam get-role \
  --role-name dcl-dev-role-web \
  --query 'Role.{Name:RoleName,Arn:Arn}' \
  --output table
```

Policy asociada:

```bash
aws iam list-attached-role-policies \
  --role-name dcl-dev-role-web \
  --output table
```

Instance Profile:

```bash
aws iam get-instance-profile \
  --instance-profile-name dcl-dev-role-web \
  --query 'InstanceProfile.{Name:InstanceProfileName,Arn:Arn,Roles:Roles[].RoleName}' \
  --output json
```

Trust policy:

```bash
aws iam get-role \
  --role-name dcl-dev-role-web \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

### Evidencia DURANTE

Capturar:

- Role `dcl-dev-role-web`.
- Policy `dcl-dev-policy-s3-state`.
- Permiso `s3:GetObject`.
- Recurso exacto `state/dcl-state.json`.
- Trust hacia EC2.
- Instance Profile.

**No deben aparecer access keys de la aplicación.**

---

# 10. FASE 3 — Nueva versión del Launch Template

El cambio debe quedar en la plantilla de lanzamiento.

## 10.1 Inspeccionar versión actual

```bash
aws ec2 describe-launch-template-versions \
  --region us-east-1 \
  --launch-template-name dcl-dev-lt-web \
  --versions '$Default' \
  --query 'LaunchTemplateVersions[].{
    Version:VersionNumber,
    ImageId:LaunchTemplateData.ImageId,
    InstanceType:LaunchTemplateData.InstanceType,
    IamInstanceProfile:LaunchTemplateData.IamInstanceProfile,
    SecurityGroups:LaunchTemplateData.SecurityGroupIds,
    UserData:LaunchTemplateData.UserData
  }' \
  --output json
```

Conservar la configuración existente de:

- AMI.
- Tipo de instancia.
- Security Group.
- IMDSv2.
- Configuración de red.

## 10.2 User Data requerido

El User Data debe instalar Apache, obtener Instance ID y AZ mediante IMDSv2, crear el estado local y copiar el estado persistente desde S3.

```bash
#!/bin/bash
set -e

dnf install -y httpd
systemctl enable --now httpd

TOKEN=$(curl -sS -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

INSTANCE_ID=$(curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

BOOT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "instance=$INSTANCE_ID boot=$BOOT_TIME" \
  > /var/www/html/local-state.txt

if aws s3 cp s3://BUCKET-NAME/state/dcl-state.json \
  /var/www/html/dcl-state.json; then

  S3_STATE=$(cat /var/www/html/dcl-state.json)

else

  S3_STATE='ERROR: no fue posible leer S3'

fi

cat > /var/www/html/index.html <<EOF
<html><body>
<h1>Digital Cafe Luna</h1>
<p>Instance ID: $INSTANCE_ID</p>
<p>Availability Zone: $AZ</p>

<h2>Estado local efimero</h2>
<pre>$(cat /var/www/html/local-state.txt)</pre>

<h2>Estado persistente en S3</h2>
<pre>$S3_STATE</pre>

</body></html>
EOF
```

Cambiar:

```text
BUCKET-NAME
```

por el bucket real.

## 10.3 Evidencia de Launch Template

Después de crear la nueva versión:

```bash
aws ec2 describe-launch-template-versions \
  --region us-east-1 \
  --launch-template-name dcl-dev-lt-web \
  --query 'LaunchTemplateVersions[].{
    Version:VersionNumber,
    Default:IsDefaultVersion,
    ImageId:LaunchTemplateData.ImageId,
    Type:LaunchTemplateData.InstanceType,
    Profile:LaunchTemplateData.IamInstanceProfile,
    SG:LaunchTemplateData.SecurityGroupIds
  }' \
  --output table
```

Ver la versión usada por el ASG:

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].LaunchTemplate' \
  --output json
```

### Evidencia DURANTE

Capturar:

- Número de nueva versión.
- Instance Profile `dcl-dev-role-web`.
- ASG apuntando a esa versión.

---

# 11. FASE 4 — Recuperar capacidad

Configurar:

```text
Min     = 2
Desired = 2
Max     = 4
```

```bash
aws autoscaling update-auto-scaling-group \
  --region us-east-1 \
  --auto-scaling-group-name dcl-dev-asg-web \
  --min-size 2 \
  --desired-capacity 2 \
  --max-size 4
```

## 11.1 Estado ASG

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{
    Desired:DesiredCapacity,
    Min:MinSize,
    Max:MaxSize,
    Instances:Instances[].{
      ID:InstanceId,
      State:LifecycleState,
      Health:HealthStatus
    }
  }' \
  --output json
```

## 11.2 EC2 activas

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --filters \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{
    ID:InstanceId,
    AZ:Placement.AvailabilityZone,
    Subnet:SubnetId,
    PrivateIP:PrivateIpAddress,
    PublicIP:PublicIpAddress,
    State:State.Name
  }' \
  --output table
```

## 11.3 Targets

Obtener ARN:

```bash
TG_ARN=$(aws elbv2 describe-target-groups \
  --region us-east-1 \
  --names dcl-dev-tg-web \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "$TG_ARN"
```

Health:

```bash
aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{
    InstanceId:Target.Id,
    Port:Target.Port,
    State:TargetHealth.State,
    Reason:TargetHealth.Reason
  }' \
  --output table
```

Resultado esperado:

```text
2 targets
healthy
healthy
```

---

# 12. FASE 5 — Validación desde el ALB

## 12.1 Obtener DNS

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --names dcl-dev-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "$ALB_DNS"
```

## 12.2 Primera prueba

```bash
curl -s "http://$ALB_DNS"
```

La respuesta debe contener:

```text
Digital Cafe Luna
Instance ID
Availability Zone
Estado local efimero
Estado persistente en S3
```

## 12.3 Varias peticiones

```bash
for i in {1..20}; do
  echo "===== REQUEST $i ====="
  curl -s "http://$ALB_DNS" | grep -E "Instance ID|Availability Zone|Estado"
  echo
done
```

También puede guardarse la respuesta completa:

```bash
for i in {1..10}; do
  echo "===== REQUEST $i ====="
  curl -s "http://$ALB_DNS"
  echo
  echo
done
```

## Evidencia ANTES de la prueba de reemplazo

Registrar:

```text
Instance ID A:
Instance ID B:

AZ A:
AZ B:

Contenido S3:
```

Capturas:

- ASG con dos instancias.
- Target Group con dos targets healthy.
- Primera respuesta del ALB.
- Respuesta de otra instancia.
- Contenido idéntico de S3.

---

# 13. FASE 6 — PRUEBA PRINCIPAL: reemplazo de cómputo

Esta es la prueba que demuestra la separación entre estado y cómputo.

## 13.1 Registrar IDs antes

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].Instances[].{
    InstanceId:InstanceId,
    State:LifecycleState,
    Health:HealthStatus
  }' \
  --output table
```

Guardar:

```text
INSTANCE_OLD_1=
INSTANCE_OLD_2=
```

## 13.2 Capturar ALB antes

```bash
curl -s "http://$ALB_DNS"
```

Guardar evidencia de:

```text
Instance ID
AZ
boot
dcl-state.json
```

---

# 14. DURANTE — Terminar una instancia

Seleccionar UNA instancia administrada por el ASG.

```bash
aws ec2 terminate-instances \
  --region us-east-1 \
  --instance-ids INSTANCE-ID
```

Consultar inmediatamente:

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --instance-ids INSTANCE-ID \
  --query 'Reservations[].Instances[].{
    ID:InstanceId,
    State:State.Name
  }' \
  --output table
```

## Evidencia DURANTE

Capturar:

1. Instance ID que se terminó.
2. Estado `shutting-down` o `terminated`.
3. ASG detectando la pérdida de capacidad.

---

# 15. DURANTE — Observar el reemplazo del ASG

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{
    Desired:DesiredCapacity,
    Instances:Instances[].{
      ID:InstanceId,
      State:LifecycleState,
      Health:HealthStatus
    }
  }' \
  --output table
```

Repetir hasta observar:

```text
Desired = 2

instancia original restante = InService
nueva instancia              = InService
```

---

# 16. DURANTE — Verificar Target Group

```bash
aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].{
    InstanceId:Target.Id,
    State:TargetHealth.State,
    Reason:TargetHealth.Reason
  }' \
  --output table
```

Esperar hasta:

```text
healthy
healthy
```

La nueva instancia debe aparecer como target saludable.

---

# 17. DESPUÉS — Confirmar nuevo Instance ID

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].Instances[].{
    InstanceId:InstanceId,
    State:LifecycleState,
    Health:HealthStatus
  }' \
  --output table
```

Comparación:

```text
ANTES
i-OLD
i-OTHER

DESPUÉS
i-OTHER
i-NEW
```

El ID `i-NEW` demuestra que el cómputo fue reemplazado.

---

# 18. DESPUÉS — Consultar el ALB

```bash
curl -s "http://$ALB_DNS"
```

Repetir:

```bash
for i in {1..20}; do
  echo "===== REQUEST $i ====="
  curl -s "http://$ALB_DNS"
  echo
  echo
done
```

Debe aparecer la nueva instancia.

La comparación esperada:

| Dato | Antes | Después |
|---|---|---|
| Instance ID | ID anterior | ID nuevo |
| Boot time | anterior | nuevo |
| Estado local | propio de instancia anterior | propio de nueva instancia |
| `project` S3 | Digital Cafe Luna | Digital Cafe Luna |
| `environment` | dev | dev |
| `message` | igual | igual |
| `version` | 1 | 1 |

---

# 19. Evidencias organizadas

Crear carpeta:

```bash
mkdir -p evidencias
```

## Evidencias ANTES

```text
01-baseline-vpc
02-baseline-alb
03-baseline-target-group
04-baseline-launch-template
05-asg-zero
06-s3-bucket
07-s3-object
08-iam-role
09-iam-policy
10-launch-template-new-version
11-asg-two-instances
12-targets-healthy
13-alb-response-initial
14-instances-before
```

## Evidencias DURANTE

```text
15-termination
16-asg-detects-failure
17-new-instance-launching
18-target-new-instance
```

## Evidencias DESPUÉS

```text
19-new-instance-inservice
20-targets-healthy-after
21-alb-new-instance
22-s3-object-still-present
23-comparison-before-after
24-asg-final-state
```

---

# 20. Comandos para generar evidencia textual

## Estado completo del ASG

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{
    Name:AutoScalingGroupName,
    Min:MinSize,
    Desired:DesiredCapacity,
    Max:MaxSize,
    LT:LaunchTemplate,
    Instances:Instances[].{
      ID:InstanceId,
      State:LifecycleState,
      Health:HealthStatus
    }
  }' \
  --output json
```

## Instancias

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=instance-state-name,Values=running,pending,stopping,stopped,shutting-down" \
  --query 'Reservations[].Instances[].{
    ID:InstanceId,
    State:State.Name,
    AZ:Placement.AvailabilityZone,
    Subnet:SubnetId,
    PrivateIP:PrivateIpAddress,
    PublicIP:PublicIpAddress,
    Profile:IamInstanceProfile.Arn
  }' \
  --output table
```

## Target Health

```bash
aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn "$TG_ARN" \
  --output table
```

## ALB

```bash
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --names dcl-dev-alb \
  --query 'LoadBalancers[].{
    Name:LoadBalancerName,
    DNS:DNSName,
    State:State.Code,
    VPC:VpcId
  }' \
  --output table
```

## S3

```bash
aws s3api head-object \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --key state/dcl-state.json
```

## IAM

```bash
aws iam list-attached-role-policies \
  --role-name dcl-dev-role-web \
  --output table
```

## Launch Template

```bash
aws ec2 describe-launch-template-versions \
  --region us-east-1 \
  --launch-template-name dcl-dev-lt-web \
  --query 'LaunchTemplateVersions[].{
    Version:VersionNumber,
    Default:IsDefaultVersion,
    ImageId:LaunchTemplateData.ImageId,
    Type:LaunchTemplateData.InstanceType,
    Profile:LaunchTemplateData.IamInstanceProfile
  }' \
  --output table
```

---

# 21. Checklist de aceptación

## S3

- [ ] Bucket creado.
- [ ] Bucket en `us-east-1`.
- [ ] Block Public Access habilitado.
- [ ] Bucket privado.
- [ ] `state/dcl-state.json` existe.
- [ ] JSON contiene los datos solicitados.

## IAM

- [ ] `dcl-dev-policy-s3-state` existe.
- [ ] Solo permite `s3:GetObject`.
- [ ] Resource apunta al objeto concreto.
- [ ] `dcl-dev-role-web` existe.
- [ ] Trusted entity = EC2.
- [ ] Policy asociada al role.
- [ ] Instance Profile disponible.
- [ ] No hay access keys de aplicación.

## Launch Template

- [ ] Existe nueva versión.
- [ ] Usa `dcl-dev-role-web`.
- [ ] Mantiene AMI.
- [ ] Mantiene instance type.
- [ ] Mantiene Security Group.
- [ ] Mantiene IMDSv2.
- [ ] User Data consulta S3.
- [ ] ASG utiliza la nueva versión.

## ASG

- [ ] Min = 2.
- [ ] Desired = 2.
- [ ] Max = 4.
- [ ] Dos instancias InService.
- [ ] Targets healthy.
- [ ] Instancias distribuidas entre baseline/AZ.

## Persistencia

- [ ] ALB responde.
- [ ] Se observan dos Instance IDs.
- [ ] Los estados locales son diferentes.
- [ ] El contenido S3 es igual.
- [ ] Se termina una instancia.
- [ ] ASG crea reemplazo.
- [ ] Aparece nuevo Instance ID.
- [ ] Nuevo target llega a healthy.
- [ ] ALB responde desde la nueva instancia.
- [ ] El contenido S3 permanece igual.

---

# 22. Respuestas técnicas del cierre

## 22.1 ¿Qué cambió entre la instancia terminada y la instancia de reemplazo?

Cambió la identidad del cómputo: el Instance ID es diferente y también cambia el estado local, incluyendo el tiempo de arranque. Esto ocurre porque el ASG crea una nueva instancia a partir de la configuración declarada en el Launch Template.

---

## 22.2 ¿Qué permaneció igual y dónde estaba almacenado?

Permaneció igual el contenido de `state/dcl-state.json`. Ese estado estaba almacenado en el bucket privado de Amazon S3 y no en el disco local de una instancia EC2.

---

## 22.3 ¿Por qué un IAM Role es preferible a guardar access keys en la instancia?

El IAM Role permite que EC2 obtenga credenciales temporales para acceder a AWS sin guardar access keys estáticas dentro del User Data, código o archivos de la instancia. Además, el role puede limitarse mediante una policy de mínimo privilegio.

En esta práctica el permiso requerido es:

```text
s3:GetObject
```

sobre:

```text
arn:aws:s3:::BUCKET/state/dcl-state.json
```

---

## 22.4 ¿Qué resolvería EBS que no resuelve este patrón con S3, y viceversa?

EBS proporciona almacenamiento de bloques asociado a una EC2 dentro de una Availability Zone y es apropiado para el disco de una instancia. S3 proporciona almacenamiento de objetos independiente de una instancia concreta.

En esta práctica S3 es adecuado porque se necesita conservar un objeto de estado simple y desacoplado del ciclo de vida de las EC2.

EBS no proporciona por defecto un estado compartido entre varias instancias de la misma forma que un objeto S3.

---

## 22.5 ¿Cuándo tendría sentido considerar EFS en lugar de S3?

EFS tendría sentido si varias instancias necesitaran acceder simultáneamente a un sistema de archivos compartido con semántica de archivos, por ejemplo archivos creados, modificados y leídos por múltiples servidores.

S3 es más apropiado cuando la aplicación trabaja con objetos mediante una API y no necesita un filesystem montado.

---

# 23. Explicación de la persistencia

La demostración puede expresarse así:

```text
ANTES

EC2 A
 ├── local-state.txt
 └── lee S3/state/dcl-state.json

EC2 B
 ├── local-state.txt
 └── lee S3/state/dcl-state.json


TERMINAMOS EC2 A

EC2 A
 └── desaparece

ASG
 └── crea EC2 C


DESPUÉS

EC2 B
 ├── estado local propio
 └── mismo estado S3

EC2 C
 ├── estado local NUEVO
 └── mismo estado S3
```

Por lo tanto:

```text
Cómputo = reemplazable
Estado  = externo y persistente
```

---

# 24. Evidencia mínima que debe quedar en la entrega

## Antes

1. Baseline existente.
2. ASG `0/0/4`.
3. Bucket privado.
4. Objeto S3.
5. IAM Role.
6. IAM Policy.
7. Launch Template nueva versión.

## Durante

8. Dos instancias iniciales.
9. Dos targets healthy.
10. ALB respondiendo.
11. Instance IDs iniciales.
12. Terminación de una instancia.
13. ASG detectando pérdida.
14. Nueva instancia apareciendo.

## Después

15. Nuevo Instance ID.
16. Nuevo target healthy.
17. ALB respondiendo desde nueva instancia.
18. Estado local diferente.
19. Estado S3 igual.
20. ASG nuevamente en Desired = 2.

---

# 25. Tabla final para documentar la prueba

Completar con los valores reales:

| Elemento | Antes | Después |
|---|---|---|
| Instance ID terminada/reemplazo | `________________` | `________________` |
| Instance ID restante | `________________` | `________________` |
| AZ | `________________` | `________________` |
| Boot time | `________________` | `________________` |
| Estado local | `________________` | `________________` |
| S3 project | `Digital Cafe Luna` | `Digital Cafe Luna` |
| S3 environment | `dev` | `dev` |
| S3 message | `________________` | `________________` |
| S3 version | `1` | `1` |
| ASG Desired | `2` | `2` |
| Target Health | `healthy` | `healthy` |

---

# 26. Comando de diagnóstico general

Si algo falla, ejecutar:

```bash
echo "===== VPC ====="
aws ec2 describe-vpcs \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=dcl-dev-vpc" \
  --output table

echo "===== ASG ====="
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --output json

echo "===== INSTANCES ====="
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=instance-state-name,Values=running,pending,stopping,stopped,shutting-down" \
  --output table

echo "===== TARGET HEALTH ====="
aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn "$TG_ARN" \
  --output table

echo "===== S3 ====="
aws s3api head-object \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --key state/dcl-state.json

echo "===== IAM ====="
aws iam list-attached-role-policies \
  --role-name dcl-dev-role-web \
  --output table

echo "===== LAUNCH TEMPLATE ====="
aws ec2 describe-launch-template-versions \
  --region us-east-1 \
  --launch-template-name dcl-dev-lt-web \
  --output table
```

---

# 27. Errores frecuentes

## Error: S3 AccessDenied

Comprobar:

```bash
aws iam list-attached-role-policies \
  --role-name dcl-dev-role-web
```

Y:

```bash
aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id v1 \
  --query 'PolicyVersion.Document' \
  --output json
```

Revisar que el ARN sea exactamente:

```text
arn:aws:s3:::BUCKET/state/dcl-state.json
```

---

## Error: nueva EC2 no tiene role

Comprobar Launch Template:

```bash
aws ec2 describe-launch-template-versions \
  --region us-east-1 \
  --launch-template-name dcl-dev-lt-web \
  --query 'LaunchTemplateVersions[].{
    Version:VersionNumber,
    Profile:LaunchTemplateData.IamInstanceProfile
  }' \
  --output table
```

Y ASG:

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].LaunchTemplate' \
  --output json
```

---

## Error: Target unhealthy

```bash
aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn "$TG_ARN" \
  --output json
```

Revisar:

- Security Group.
- Puerto 80.
- Apache.
- User Data.
- Health check.
- Estado de la instancia.

---

## Error: ALB no muestra el nuevo Instance ID

Esperar hasta que el target sea:

```text
healthy
```

Después:

```bash
for i in {1..20}; do
  curl -s "http://$ALB_DNS" | grep -E "Instance ID|Availability Zone"
  sleep 2
done
```

---

# 28. Respuesta global para la conclusión

> **¿Qué demuestra el laboratorio?**

El laboratorio demuestra que el ciclo de vida del estado puede separarse del ciclo de vida del cómputo. Las instancias EC2 son reemplazables y el Auto Scaling Group puede crear una nueva instancia cuando una desaparece. La nueva instancia obtiene mediante su IAM Role permiso mínimo para leer `state/dcl-state.json` desde un bucket privado de S3. Por ello cambia la identidad y el estado local de la instancia, mientras que el estado persistente permanece disponible.

---

# 29. Cleanup obligatorio

Primero:

```bash
aws autoscaling update-auto-scaling-group \
  --region us-east-1 \
  --auto-scaling-group-name dcl-dev-asg-web \
  --min-size 0 \
  --desired-capacity 0 \
  --max-size 4
```

Esperar:

```bash
aws autoscaling describe-auto-scaling-groups \
  --region us-east-1 \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].Instances' \
  --output json
```

Después eliminar el ALB:

```text
dcl-dev-alb
```

Verificar:

```bash
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[].LoadBalancerName' \
  --output table
```

## Conservar

```text
dcl-dev-vpc
dcl-dev-lt-web
dcl-dev-asg-web
dcl-dev-tg-web
dcl-dev-role-web
dcl-dev-policy-s3-state
S3 bucket
state/dcl-state.json
Security Groups
subnets
Internet Gateway
route tables
```

## Verificar que no queden EC2 activas

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].{
    ID:InstanceId,
    State:State.Name,
    Name:Tags[?Key==`Name`]|[0].Value
  }' \
  --output table
```

El objetivo es que no queden instancias del laboratorio en estado `Running` o `Stopped`.

---

# 30. Checklist final de entrega

```text
[ ] Región us-east-1
[ ] Baseline reutilizado
[ ] ASG inicial 0/0/4
[ ] S3 privado
[ ] state/dcl-state.json
[ ] Block Public Access
[ ] IAM Policy
[ ] s3:GetObject únicamente
[ ] ARN restringido al objeto
[ ] IAM Role para EC2
[ ] Instance Profile
[ ] Sin access keys
[ ] Nueva versión Launch Template
[ ] Launch Template usa IAM Role
[ ] ASG usa nueva versión
[ ] ASG 2/2/4
[ ] Dos instancias InService
[ ] Dos targets healthy
[ ] ALB responde
[ ] Dos Instance IDs observados
[ ] Evidencia ANTES
[ ] Terminación de una instancia
[ ] Evidencia DURANTE
[ ] ASG crea reemplazo
[ ] Nuevo Instance ID
[ ] Nuevo target healthy
[ ] ALB responde desde reemplazo
[ ] Estado local cambió
[ ] Estado S3 permaneció igual
[ ] Evidencia DESPUÉS
[ ] Respuestas de cierre documentadas
[ ] Cleanup realizado
```

---

# 31. Fuentes oficiales indicadas en el laboratorio

- IAM roles para Amazon EC2:
  `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html`

- IAM role para aplicaciones en EC2:
  `https://docs.aws.amazon.com/autoscaling/ec2/userguide/us-iam-role.html`

- Amazon S3 — Policies and permissions:
  `https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-policy-language-overview.html`

- Amazon S3 — GetObject:
  `https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html`

- Amazon EC2 Auto Scaling — Launch templates:
  `https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-templates.html`

- Amazon Linux 2023 — AWS CLI v2:
  `https://docs.aws.amazon.com/linux/al2023/ug/awscli2.html`

---

# 32. Resumen de la prueba principal

```text
                    ANTES

              ┌──────────────┐
              │     ALB      │
              └──────┬───────┘
                     │
              ┌──────┴──────┐
              │             │
             EC2 A         EC2 B
              │             │
              └──────┬──────┘
                     │
                     ▼
                S3 / state
                     │
                     ▼
             dcl-state.json


                    ↓

              TERMINAMOS A


                    ↓

              ASG CREA C


                    ↓

                    DESPUÉS

              ┌──────────────┐
              │     ALB      │
              └──────┬───────┘
                     │
              ┌──────┴──────┐
              │             │
             EC2 B         EC2 C
              │             │
              └──────┬──────┘
                     │
                     ▼
                S3 / state
                     │
                     ▼
             dcl-state.json
                SIN CAMBIAR
```

## Conclusión

```text
EC2 A desaparece
      ↓
ASG reemplaza EC2 A
      ↓
EC2 C tiene nuevo Instance ID
      ↓
EC2 C tiene nuevo estado local
      ↓
EC2 C utiliza IAM Role
      ↓
IAM autoriza s3:GetObject
      ↓
EC2 C lee S3/state/dcl-state.json
      ↓
El estado persistente sigue disponible
```

**Idea central:**

> **El cómputo puede desaparecer y ser reemplazado; el estado persistente no debe depender de una instancia concreta.**
