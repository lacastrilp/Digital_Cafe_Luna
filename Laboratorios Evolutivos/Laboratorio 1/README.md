Sí. Revisé el **Laboratorio Evolutivo 01**, que es el que contiene exactamente esas preguntas y la evidencia mínima solicitada. El laboratorio pide una VPC `10.20.0.0/16`, cuatro subredes en dos AZ, un Internet Gateway y tablas de rutas separadas para público/privado. 

## 1. Respuestas técnicas

### ¿Qué cambiaría para que un recurso de una subred privada pudiera salir a Internet sin recibir conexiones iniciadas desde Internet?

**Respuesta:**

Se agregaría un **NAT Gateway** en una subred pública y se modificaría la tabla de rutas de la subred privada para que la ruta `0.0.0.0/0` apunte al NAT Gateway.

De esta manera:

```text
Recurso privado
      |
      v
Tabla de rutas privada
0.0.0.0/0 → NAT Gateway
      |
      v
NAT Gateway (subred pública)
      |
      v
Internet Gateway
      |
      v
Internet
```

El NAT Gateway permite que los recursos privados **inicien conexiones hacia Internet**, pero evita que Internet pueda iniciar directamente una conexión hacia esos recursos privados.

**Importante para este laboratorio:** no se debe crear el NAT Gateway, porque explícitamente está fuera del alcance del Lab 01 y genera cargos. El laboratorio indica que las subredes privadas deben conservar únicamente la ruta local. 

---

### ¿Qué elemento determina realmente que una subred sea pública?

**Respuesta:**

Lo determina **su tabla de rutas**, no el nombre de la subred.

Una subred es pública cuando su tabla de rutas tiene una ruta:

```text
0.0.0.0/0 → Internet Gateway
```

Una subred privada **no tiene una ruta directa hacia el Internet Gateway**.

Por eso, aunque la subred se llame `private-a`, lo que realmente define su carácter es el **enrutamiento asociado**. El propio laboratorio lo recalca explícitamente. 

---

### ¿Por qué dos subredes en la misma AZ no ofrecen tolerancia ante la falla de esa AZ?

**Respuesta:**

Porque una **Availability Zone es un límite de fallo**. Si ambas subredes están dentro de la misma AZ y esa AZ falla, las dos subredes quedan afectadas simultáneamente.

Para obtener redundancia frente a una falla de AZ, los recursos deben distribuirse entre **dos o más Availability Zones diferentes** dentro de la misma Región.

Ejemplo:

```text
Región us-east-1
│
├── AZ A
│   ├── subnet pública A
│   └── subnet privada A
│
└── AZ B
    ├── subnet pública B
    └── subnet privada B
```

El laboratorio precisamente plantea distribuir las cuatro subredes entre dos AZ para reducir la dependencia de una única ubicación. 

---

### ¿Qué responsabilidad conserva Digital Café Luna aunque AWS administre la infraestructura física?

**Respuesta:**

Digital Café Luna conserva la responsabilidad de **configurar, proteger y administrar correctamente sus recursos dentro de AWS**.

Esto incluye, entre otros:

* Configuración de la VPC y subredes.
* Tablas de rutas y conectividad.
* Reglas de seguridad y acceso.
* Configuración de los recursos desplegados.
* Control de las identidades y permisos.
* Protección de los datos y de las aplicaciones.

AWS administra la **infraestructura física subyacente**, pero eso no significa que AWS sea responsable de toda la configuración y seguridad de los recursos que Digital Café Luna despliega.

> **Respuesta corta para entregar:**
> *Digital Café Luna conserva la responsabilidad sobre la configuración, seguridad, acceso y protección de los recursos y datos que despliega en AWS, mientras AWS administra la infraestructura física subyacente.*

---

# 2. Comandos AWS CLI para la evidencia mínima

Aquí hay una pequeña particularidad: el documento tiene **tres consultas principales de infraestructura**, aunque antes muestra dos comandos adicionales para comprobar sesión y región.

## Comando 1 — Verificar la VPC

Este es el comando que pide el laboratorio para consultar la VPC del proyecto:

```bash
aws ec2 describe-vpcs \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'Vpcs[].{Name:Tags[?Key==`Name`]|[0].Value,CIDR:CidrBlock,State:State}' \
--output table
```

**Sirve para demostrar:**

* Nombre de la VPC.
* CIDR.
* Estado.

El laboratorio indica exactamente esta consulta para verificar la VPC etiquetada como `digital-cafe-luna`. 

---

## Comando 2 — Verificar las subredes

```bash
aws ec2 describe-subnets \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,CIDR:CidrBlock,AZ:AvailabilityZone}' \
--output table
```

**Sirve para demostrar:**

* Nombre de cada subnet.
* CIDR.
* Availability Zone.

Deberías obtener algo conceptualmente parecido a:

```text
------------------------------------------------------------
|                     DescribeSubnets                      |
+----------------------+----------------+------------------+
| Name                 | CIDR           | AZ               |
+----------------------+----------------+------------------+
| dcl-dev-subnet-...   | 10.20.1.0/24  | us-east-1a       |
| dcl-dev-subnet-...   | 10.20.11.0/24 | us-east-1a       |
| dcl-dev-subnet-...   | 10.20.2.0/24  | us-east-1b       |
| dcl-dev-subnet-...   | 10.20.12.0/24 | us-east-1b       |
+----------------------+----------------+------------------+
```

El plan de direccionamiento oficial del laboratorio usa esos cuatro CIDR. 

---

## Comando 3 — Verificar tablas de rutas

Este es **el más importante para responder qué subnet es pública o privada**:

```bash
aws ec2 describe-route-tables \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes[].DestinationCidrBlock,Subnets:Associations[].SubnetId}' \
--output json
```

El laboratorio indica que esta consulta muestra tanto los **destinos de las rutas** como las **subredes asociadas**. 

Para la tabla pública deberías identificar algo equivalente a:

```text
dcl-dev-rt-public
10.20.0.0/16
0.0.0.0/0
```

y para la privada:

```text
dcl-dev-rt-private
10.20.0.0/16
```

La diferencia clave es:

```text
PÚBLICA:
0.0.0.0/0 → Internet Gateway

PRIVADA:
10.20.0.0/16 → local
```

El criterio de aceptación del laboratorio confirma exactamente esta configuración. 

---

# 3. Comandos adicionales: sesión y Región

El documento también proporciona estos dos comandos antes de las tres consultas de infraestructura. Si quieres dejar **evidencia completa**, ejecútalos también.

### Identidad de la sesión

```bash
aws sts get-caller-identity
```

Muestra la cuenta, usuario/rol y ARN de la sesión temporal de CloudShell. 

### Región activa

```bash
aws ec2 describe-availability-zones \
--query 'AvailabilityZones[0].RegionName' \
--output text
```

Debería devolver:

```text
us-east-1
```

si esa es la Región habilitada/acordada en tu Learner Lab. 

---

# 4. Lo mínimo que yo entregaría

Para no llenar la evidencia de capturas innecesarias, dejaría:

**Evidencia CLI:**

```bash
aws ec2 describe-vpcs \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'Vpcs[].{Name:Tags[?Key==`Name`]|[0].Value,CIDR:CidrBlock,State:State}' \
--output table
```

```bash
aws ec2 describe-subnets \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,CIDR:CidrBlock,AZ:AvailabilityZone}' \
--output table
```

```bash
aws ec2 describe-route-tables \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes[].DestinationCidrBlock,Subnets:Associations[].SubnetId}' \
--output json
```

Y como respuestas escritas:

1. **Salida de privada a Internet:** NAT Gateway en subnet pública + `0.0.0.0/0 → NAT Gateway` en la tabla privada.
2. **Qué hace pública una subnet:** su **tabla de rutas**, específicamente una ruta `0.0.0.0/0 → Internet Gateway`.
3. **Dos subnets en la misma AZ:** no hay tolerancia ante la caída de esa AZ porque ambas comparten el mismo límite de fallo.
4. **Responsabilidad de Digital Café Luna:** configurar y proteger sus recursos, accesos, red, datos y aplicaciones; AWS administra la infraestructura física.

Además, el laboratorio especifica que si **CloudShell está restringido por AWS Academy**, no deben crear access keys para solucionarlo; pueden hacer las comprobaciones desde las vistas de VPC y registrar la restricción como evidencia. 

¿Quieres que te lo deje en formato **“copiar y pegar en el informe”** o en formato **“comandos + resultado esperado”**?
