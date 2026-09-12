Sí. Vamos a hacer el **LAB 1 completo**, principalmente desde la **interfaz gráfica de AWS**, y después usaremos CloudShell/Kali para las verificaciones y pruebas.

He revisado el PDF del Lab 1. La evaluación exige una VPC propia, **4 subredes en 2 AZ**, IGW, tablas de rutas separadas, SG, NACL y dos EC2 temporales; además hay que demostrar **permitido → bloqueado → restaurado**. 

> ⚠️ **Importante respecto al Lab 4:** este PDF especifica `us-east-1` (N. Virginia), mientras que tu infraestructura anterior está en `us-east-2` (Ohio). Para este LAB 1 te recomiendo seguir el PDF y trabajar en **us-east-1**, con recursos llamados `dcl-lab1-*`. No reutilices la VPC `dcl-dev-vpc` de Ohio para este laboratorio. El PDF explícitamente pide `us-east-1` y una VPC propia, no la Default VPC. 

---

# 🟢 LAB 1 — Plan completo

La arquitectura será:

```text
                         INTERNET
                            │
                            │
                       ┌────▼────┐
                       │   IGW   │
                       └────┬────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
          Public RT               Private RT
        0.0.0.0/0 → IGW           SOLO local
                 │                     │
        ┌────────┴───────┐      ┌──────┴────────┐
        │                │      │               │
   Public A          Public B  Private A     Private B
 10.20.10.0/24      10.20.20.0/24
 us-east-1a         us-east-1b
        │                           │
        │                           │
   EC2 pública ──── ICMP ───────► EC2 privada
   IPv4 pública                   SIN IPv4 pública
```

El plan de direccionamiento indicado por el laboratorio es: VPC `10.20.0.0/16`, públicas `10.20.10.0/24` y `10.20.20.0/24`, privadas `10.20.110.0/24` y `10.20.120.0/24`, distribuidas entre `us-east-1a` y `us-east-1b`. 

---

# FASE 0 — Plan de red

Antes de crear nada, usa esta tabla en tu informe:

| Recurso   | CIDR             | AZ           | Propósito                     |
| --------- | ---------------- | ------------ | ----------------------------- |
| VPC       | `10.20.0.0/16`   | Regional     | Red de Digital Café Luna      |
| Public A  | `10.20.10.0/24`  | `us-east-1a` | EC2 pública temporal          |
| Public B  | `10.20.20.0/24`  | `us-east-1b` | Capacidad pública/redundancia |
| Private A | `10.20.110.0/24` | `us-east-1a` | Recursos internos             |
| Private B | `10.20.120.0/24` | `us-east-1b` | Recursos internos             |

Esto corresponde directamente al plan de referencia del documento. 

### Respuesta para el diseño

**¿Por qué dividir en públicas y privadas?**

> La segmentación permite separar recursos expuestos de recursos internos. La subnet pública tiene una ruta hacia el Internet Gateway y puede alojar una EC2 con IPv4 pública, mientras que las subnets privadas no tienen una ruta por defecto hacia Internet. La exposición no depende únicamente del nombre de la subnet, sino de direccionamiento, rutas y controles de tráfico. 

---

# FASE 1 — Crear la VPC

En la consola:

**AWS Console → VPC → Your VPCs → Create VPC**

Selecciona:

**VPC only**

Nombre:

```text
dcl-lab1-vpc
```

IPv4 CIDR:

```text
10.20.0.0/16
```

No IPv6.

No necesitas crear NAT Gateway.

Crea la VPC.

El laboratorio pide explícitamente una VPC propia y no utilizar la Default VPC. 

---

# FASE 1.1 — Crear las cuatro subnets

Ve a:

**VPC → Subnets → Create subnet**

Selecciona:

```text
dcl-lab1-vpc
```

## Public A

```text
Name: dcl-lab1-subnet-public-a
AZ: us-east-1a
IPv4 CIDR: 10.20.10.0/24
```

## Private A

```text
Name: dcl-lab1-subnet-private-a
AZ: us-east-1a
IPv4 CIDR: 10.20.110.0/24
```

## Public B

```text
Name: dcl-lab1-subnet-public-b
AZ: us-east-1b
IPv4 CIDR: 10.20.20.0/24
```

## Private B

```text
Name: dcl-lab1-subnet-private-b
AZ: us-east-1b
IPv4 CIDR: 10.20.120.0/24
```

El PDF pide exactamente cuatro subnets distribuidas entre dos AZ. 

---

# FASE 1.2 — Activar IPv4 pública

Para **Public A**:

**Subnet → Actions → Edit subnet settings**

Activa:

```text
Enable auto-assign public IPv4 address
```

Haz lo mismo para **Public B**.

No es necesario habilitarlo en las privadas.

El laboratorio específicamente pide auto-assign público únicamente en las subnets públicas si utilizas esta estrategia. 

---

# 📸 EVIDENCIA 1

Antes de continuar, captura:

**VPC → Subnets**

donde se puedan ver las cuatro:

```text
dcl-lab1-subnet-public-a
dcl-lab1-subnet-public-b
dcl-lab1-subnet-private-a
dcl-lab1-subnet-private-b
```

y sus:

* CIDR
* AZ
* VPC

Esta será la evidencia **1 — Plan de red / subnets**.

---

# FASE 2 — Internet Gateway y Route Tables

## 2.1 Crear IGW

Ve a:

**VPC → Internet Gateways → Create internet gateway**

Nombre:

```text
dcl-lab1-igw
```

Crear.

Luego:

**Actions → Attach to VPC**

Selecciona:

```text
dcl-lab1-vpc
```

---

# 2.2 Crear Route Table pública

Ve a:

**VPC → Route Tables → Create route table**

Nombre:

```text
dcl-lab1-rt-public
```

VPC:

```text
dcl-lab1-vpc
```

Crear.

Después entra a la tabla:

**Routes → Edit routes → Add route**

Pon:

```text
Destination: 0.0.0.0/0
Target: Internet Gateway
dcl-lab1-igw
```

Guarda.

---

# 2.3 Asociar las dos públicas

En la misma route table:

**Subnet associations → Edit subnet associations**

Selecciona:

```text
☑ dcl-lab1-subnet-public-a
☑ dcl-lab1-subnet-public-b
```

Guarda.

---

# 2.4 Crear Route Table privada

Otra vez:

**Route Tables → Create route table**

Nombre:

```text
dcl-lab1-rt-private
```

VPC:

```text
dcl-lab1-vpc
```

Aquí **NO agregues**:

```text
0.0.0.0/0 → IGW
```

Debe quedarse solamente la ruta local de la VPC.

Asocia:

```text
☑ dcl-lab1-subnet-private-a
☑ dcl-lab1-subnet-private-b
```

El documento exige exactamente que las públicas tengan `0.0.0.0/0 → IGW` y que las privadas no tengan ruta por defecto al IGW. 

---

# 📸 EVIDENCIA 2 — Routing

Esta captura es importante.

Puedes mostrar:

### Route table pública

```text
10.20.0.0/16 → local
0.0.0.0/0 → dcl-lab1-igw
```

y las asociaciones:

```text
public-a
public-b
```

Luego una captura de la privada:

```text
10.20.0.0/16 → local
```

sin:

```text
0.0.0.0/0 → IGW
```

Esto demuestra la diferencia de exposición por **routing**.

---

# FASE 3 — Security Groups

Ahora vamos a crear los controles.

## 3.1 SG público

Ve a:

**VPC → Security Groups → Create security group**

Nombre:

```text
dcl-lab1-sg-public
```

Descripción:

```text
Control de acceso para EC2 pública del LAB 1
```

VPC:

```text
dcl-lab1-vpc
```

### Inbound

Agrega:

```text
Type: SSH
Protocol: TCP
Port: 22
Source: My IP
```

AWS debería colocar algo parecido a:

```text
X.X.X.X/32
```

⚠️ **No uses `0.0.0.0/0`.**

El PDF exige SSH únicamente desde la IPv4 pública actual del equipo. 

Para averiguar tu IP desde Kali puedes usar:

```bash id="c81nmx"
curl -4 ifconfig.me
```

Por ejemplo:

```text
181.xxx.xxx.xxx
```

Entonces el SG debe tener:

```text
181.xxx.xxx.xxx/32
```

---

# 3.2 SG privado

Crear otro:

```text
dcl-lab1-sg-private
```

VPC:

```text
dcl-lab1-vpc
```

Inbound:

```text
Type: All ICMP - IPv4
Source: Custom
```

Y selecciona como origen:

```text
dcl-lab1-sg-public
```

Esto es importante: **no pongas `0.0.0.0/0`**.

Queremos:

```text
EC2 pública
   │
   │ ICMP
   ▼
EC2 privada
```

El PDF indica específicamente que el SG privado debe permitir ICMP IPv4 desde `dcl-lab1-sg-public`. 

---

# FASE 3.3 — NACL privada

Ahora:

**VPC → Network ACLs → Create network ACL**

Nombre:

```text
dcl-lab1-nacl-private
```

VPC:

```text
dcl-lab1-vpc
```

---

## Asociar las dos privadas

Entra en la NACL:

**Subnet associations → Edit**

Selecciona:

```text
☑ dcl-lab1-subnet-private-a
☑ dcl-lab1-subnet-private-b
```

---

## Inbound rules

**Inbound rules → Edit inbound rules → Add rule**

Pon:

```text
Rule number: 100
Type: All traffic
Protocol: All
Source: 10.20.0.0/16
Allow
```

## Outbound rules

Agrega:

```text
Rule number: 100
Type: All traffic
Protocol: All
Destination: 10.20.0.0/16
Allow
```

El resto puede quedar con el **deny implícito**.

Esto corresponde al requisito del PDF: permitir tráfico IPv4 dentro del CIDR de la VPC en entrada y salida, manteniendo bloqueado implícitamente lo que venga de otros orígenes. 

---

# 📸 EVIDENCIA 3 — SG + NACL

Captura donde puedas demostrar:

### SG público

```text
SSH TCP 22
Source: TU_IP/32
```

### SG privado

```text
ICMP
Source: dcl-lab1-sg-public
```

### NACL privada

```text
Inbound:
100 → 10.20.0.0/16 → ALLOW

Outbound:
100 → 10.20.0.0/16 → ALLOW
```

Esta evidencia demuestra los controles a nivel de **recurso** y **subnet**. El documento distingue SG como control stateful y NACL como stateless. 

---

# FASE 4 — Crear las dos EC2

Ahora sí creamos las máquinas temporales.

No necesitas instalar Apache ni ningún software adicional. El laboratorio explícitamente dice que esta práctica evalúa red. 

---

## EC2 pública

Ve a:

**EC2 → Instances → Launch instance**

Nombre:

```text
dcl-lab1-ec2-public
```

AMI:

Puedes usar una AMI Linux pequeña disponible, por ejemplo Amazon Linux.

Tipo:

```text
t3.micro
```

o el tipo pequeño que permita tu cuenta.

### Key pair

Selecciona/crea uno temporal.

**No compartas la clave privada.**

### Network settings

VPC:

```text
dcl-lab1-vpc
```

Subnet:

```text
dcl-lab1-subnet-public-a
```

Auto-assign Public IP:

```text
Enable
```

Security Group:

```text
dcl-lab1-sg-public
```

Lanza la instancia.

---

# EC2 privada

Otra:

Nombre:

```text
dcl-lab1-ec2-private
```

Misma AMI.

Mismo tipo.

VPC:

```text
dcl-lab1-vpc
```

Subnet:

```text
dcl-lab1-subnet-private-a
```

Auto-assign Public IP:

```text
Disable
```

Security Group:

```text
dcl-lab1-sg-private
```

Lanza.

---

# FASE 4.1 — Verificación de direccionamiento

En CloudShell:

```bash id="2e4gsl"
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=dcl-lab1-ec2-public,dcl-lab1-ec2-private" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,ID:InstanceId,Subnet:SubnetId,AZ:Placement.AvailabilityZone,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,State:State.Name}' \
  --output table
```

Queremos:

```text
dcl-lab1-ec2-public
PublicIP: X.X.X.X
PrivateIP: 10.20.10.X
```

y:

```text
dcl-lab1-ec2-private
PublicIP: None
PrivateIP: 10.20.110.X
```

### 📸 EVIDENCIA 4

Esta es la evidencia:

> Solo la EC2 pública posee IPv4 pública y ambas están en la subnet correcta.

El documento exige exactamente esa comprobación. 

---

# FASE 5 — Probar conectividad

Aquí viene la parte que más valor tiene en la evaluación.

Obtén las IP:

```bash id="zx1p6n"
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=dcl-lab1-ec2-public,dcl-lab1-ec2-private" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}' \
  --output table
```

Guarda la IP privada de la EC2 privada.

Por ejemplo:

```text
10.20.110.25
```

---

# 5.1 SSH a la pública

Desde tu Kali:

```bash id="em0f89"
ssh -i TU-CLAVE.pem ec2-user@IP_PUBLICA
```

Ejemplo:

```bash
ssh -i lab1.pem ec2-user@54.xxx.xxx.xxx
```

Debe funcionar.

Esto demuestra:

```text
Internet
   ↓
IPv4 pública
   ↓
Public subnet
   ↓
IGW
   ↓
SG público permite TCP/22 desde TU_IP/32
   ↓
EC2 pública
```

El laboratorio pide demostrar acceso SSH únicamente a la EC2 pública. 

---

# 5.2 Ping pública → privada

Una vez dentro de la EC2 pública:

```bash
ping -c 4 IP_PRIVADA
```

Ejemplo:

```bash
ping -c 4 10.20.110.25
```

Esperamos:

```text
64 bytes from 10.20.110.25
64 bytes from 10.20.110.25
64 bytes from 10.20.110.25
64 bytes from 10.20.110.25
```

Esto demuestra comunicación privada entre las dos EC2.

La prueba requerida por el laboratorio es precisamente ping desde la EC2 pública hacia la IP privada de la EC2 privada. 

### 📸 EVIDENCIA 5

Captura del:

```bash
ping -c 4 IP_PRIVADA
```

con respuestas exitosas.

---

# FASE 6 — Permitido → Bloqueado → Restaurado

Esta es **obligatoria**.

Primero tenemos:

```text
SG privado:
ICMP ← SG público
```

y el ping funciona.

---

## 6.1 Estado PERMITIDO

Ejecuta:

```bash id="f9q7qz"
ping -c 4 IP_PRIVADA
```

Debe funcionar.

📸 **Captura A — PERMITIDO**

---

# 6.2 Bloquear ICMP

Ahora en AWS Console:

**VPC → Security Groups → dcl-lab1-sg-private**

Ve a:

**Inbound rules → Edit inbound rules**

Elimina:

```text
All ICMP - IPv4
Source: dcl-lab1-sg-public
```

Guarda.

---

# 6.3 Probar nuevamente

En la EC2 pública:

```bash id="ghqv5m"
ping -c 4 IP_PRIVADA
```

Ahora esperamos:

```text
Request timeout
```

o:

```text
100% packet loss
```

📸 **Captura B — BLOQUEADO**

---

# 6.4 Restaurar

Regresa al SG privado.

Agrega nuevamente:

```text
Type: All ICMP - IPv4
Source: dcl-lab1-sg-public
```

Guarda.

---

# 6.5 Probar nuevamente

```bash id="xdh7co"
ping -c 4 IP_PRIVADA
```

Ahora debe volver a funcionar.

📸 **Captura C — RESTAURADO**

---

# ⭐ La explicación que debes dar al profesor

> **El bloqueo se produjo modificando únicamente el Security Group de la EC2 privada. No fue necesario cambiar las IP, las subnets ni las tablas de rutas. Por eso demostramos que el direccionamiento y el camino de red permanecieron iguales, mientras que el control de tráfico modificó el comportamiento de la comunicación.**

Esto responde directamente al punto 34 del laboratorio. 

---

# 🧠 Respuestas para las preguntas del LAB 1

## Pregunta: ¿Cómo demostramos qué recursos pueden comunicarse, por qué camino y con qué nivel de exposición?

**Respuesta:**

> Lo demostramos combinando direccionamiento, tablas de rutas, Internet Gateway, Security Groups y Network ACLs, y verificando el comportamiento mediante SSH y ping. La EC2 pública tiene IPv4 pública, pertenece a una subnet cuya tabla de rutas contiene `0.0.0.0/0 → IGW` y su Security Group permite SSH desde la IP del equipo. La EC2 privada no tiene IPv4 pública ni ruta por defecto hacia el IGW, pero puede recibir ICMP desde la EC2 pública mediante su Security Group. 

---

## Pregunta de cierre

> **Si Digital Café Luna necesitara conectar una oficina con esta VPC sin publicar la capa privada en Internet, ¿qué aspecto de la arquitectura debería evolucionar y qué debería permanecer igual?**

### Respuesta recomendada:

> **Debería evolucionar la conectividad de red, incorporando un mecanismo de conexión privada entre la oficina y la VPC, mientras deberían permanecer iguales la segmentación pública/privada, el direccionamiento y los controles de acceso de la capa privada. La conexión permitiría que la oficina alcance las redes privadas mediante un camino privado, sin convertirlas en recursos públicos de Internet.**

Una versión más corta para defensa oral:

> **Evolucionaría el camino de conectividad entre la oficina y la VPC, pero conservaría la segmentación, las rutas internas y los controles de seguridad de la capa privada.**

---

# 🧹 FASE 7 — Cleanup

Al terminar las pruebas:

Ve a:

**EC2 → Instances**

Termina:

```text
dcl-lab1-ec2-public
dcl-lab1-ec2-private
```

El PDF exige que las dos EC2 temporales estén terminadas al cierre. 

### Puedes conservar:

```text
dcl-lab1-vpc
dcl-lab1-subnet-public-a
dcl-lab1-subnet-public-b
dcl-lab1-subnet-private-a
dcl-lab1-subnet-private-b
dcl-lab1-igw
dcl-lab1-rt-public
dcl-lab1-rt-private
dcl-lab1-sg-public
dcl-lab1-sg-private
dcl-lab1-nacl-private
```

El documento pide conservar la red base para continuidad. 

Si el Key Pair fue creado **solo** para este laboratorio y no lo necesitas, también puede eliminarse.

---

# 📑 Las 7 evidencias que debes entregar

Te recomiendo organizar el PDF exactamente así:

### Evidencia 1 — Plan de red

Tabla:

```text
VPC 10.20.0.0/16
Public A 10.20.10.0/24 us-east-1a
Public B 10.20.20.0/24 us-east-1b
Private A 10.20.110.0/24 us-east-1a
Private B 10.20.120.0/24 us-east-1b
```

### Evidencia 2 — Routing

Mostrar:

```text
PUBLIC:
0.0.0.0/0 → IGW

PRIVATE:
solo local
```

### Evidencia 3 — Security

Mostrar:

```text
SSH → TU_IP/32
ICMP → SG público
NACL → 10.20.0.0/16
```

### Evidencia 4 — EC2

Mostrar:

```text
Public EC2 → Public IPv4
Private EC2 → No Public IPv4
```

### Evidencia 5 — Conectividad

```text
ping pública → privada
SUCCESS
```

### Evidencia 6 — Control

Tres estados:

```text
PERMITIDO
   ↓
BLOQUEADO
   ↓
RESTAURADO
```

### Evidencia 7 — Cleanup

Mostrar:

```text
dcl-lab1-ec2-public   terminated
dcl-lab1-ec2-private  terminated
```

y la red base conservada.

El PDF define exactamente estas siete evidencias mínimas. 

---

## ⭐ Y estas son las tres afirmaciones que tienes que poder defender

Al final, el profesor debería poder preguntarte y tú responder:

**1. ¿Por qué la EC2 pública es pública?**

> Porque tiene direccionamiento IPv4 público, está en una subnet cuya tabla de rutas tiene `0.0.0.0/0 → IGW` y su Security Group permite el tráfico requerido.

**2. ¿Por qué la privada no está expuesta directamente a Internet?**

> Porque no tiene IPv4 pública y su tabla de rutas no tiene una ruta por defecto hacia el Internet Gateway.

**3. ¿Cómo bloqueaste el ping sin tocar rutas?**

> Eliminando temporalmente la regla ICMP del Security Group privado. Las IP, subnets y rutas permanecieron iguales; solo cambió el control de tráfico.

Estas tres afirmaciones son literalmente el criterio de cierre del laboratorio. 

### Empecemos por la consola

Haz primero **VPC + las 4 subnets** en `us-east-1`. **No crees todavía las EC2.** Cuando tengas las cuatro subnets creadas, ejecuta este comando en CloudShell:

```bash id="jby5kw"
aws ec2 describe-subnets \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=$(aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=dcl-lab1-vpc --query 'Vpcs[0].VpcId' --output text)" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,CIDR:CidrBlock,AZ:AvailabilityZone,ID:SubnetId}' \
  --output table
```

Pásame esa salida y verificamos **CIDR + AZ + nombres** antes de construir el routing. Así evitamos que un error de subnet nos dañe las pruebas posteriores.
