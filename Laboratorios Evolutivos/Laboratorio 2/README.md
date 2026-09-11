Sí. Para el **Laboratorio 2 — Diseño para fallos**, el objetivo es demostrar **redundancia entre dos AZ**, pero también dejar claro que todavía **no existe failover automático**. El documento indica que A y B deben estar en AZ distintas, responder por HTTP antes de la falla y que, al detener A, B continúe disponible mientras A deja de responder. 

## 1. Comando principal: estado de las dos instancias

Este es el comando que te sirve para obtener la evidencia de **Name, estado, AZ e IP pública**:

```bash
aws ec2 describe-instances \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,AZ:Placement.AvailabilityZone,PublicIP:PublicIpAddress}' \
--output table
```

El resultado debería mostrar algo parecido a:

```text
-------------------------------------------------------------
|                         DescribeInstances                  |
+----------------+---------+-------------+------------------+
| Name           | State   | AZ          | PublicIP         |
+----------------+---------+-------------+------------------+
| dcl-dev-web-a  | running | us-east-1a | xx.xx.xx.xx      |
| dcl-dev-web-b  | running | us-east-1b | yy.yy.yy.yy      |
+----------------+---------+-------------+------------------+
```

**Evidencia:** captura esa tabla cuando ambas estén `running`.

El laboratorio espera **una instancia por subred pública y por AZ**. 

---

# 2. Verificar Security Group

El segundo comando que entrega el laboratorio es:

```bash
aws ec2 describe-security-groups \
--filters 'Name=group-name,Values=dcl-dev-sg-web' \
--query 'SecurityGroups[].{Name:GroupName,Inbound:IpPermissions}' \
--output json
```

Aquí debes comprobar principalmente que:

* **TCP/80 (HTTP)** esté permitido.
* **SSH/22 no esté expuesto**, según los criterios del laboratorio. 

---

# 3. Prueba HTTP antes de la falla

Primero ejecuta el comando de arriba para obtener las IP públicas.

Supongamos:

```text
A = 3.90.10.20
B = 18.220.30.40
```

Desde CloudShell puedes probar:

```bash
curl -i http://3.90.10.20
```

y:

```bash
curl -i http://18.220.30.40
```

También puedes hacer una prueba más sencilla:

```bash
curl http://3.90.10.20
```

```bash
curl http://18.220.30.40
```

### Resultado esperado

Ambas deben responder con algo similar a:

```html
<h1>Digital Cafe Luna</h1>
<p>Servidor: ...</p>
<p>Availability Zone: ...</p>
```

El `user data` del laboratorio instala Apache y genera una página que identifica el servidor y su Availability Zone. 

**Evidencia que debes guardar:**

```text
Prueba HTTP A → responde correctamente
Prueba HTTP B → responde correctamente
```

El documento pide específicamente probar las dos IPv4 públicas antes de realizar la falla. 

---

# 4. Simular la falla de A

Ahora detén:

```text
dcl-dev-web-a
```

En la consola:

**EC2 → Instances → dcl-dev-web-a → Instance state → Stop instance**

El laboratorio indica expresamente que después hay que comprobar nuevamente A y B y **no reiniciar A todavía**. 

Después puedes verificar el estado con:

```bash
aws ec2 describe-instances \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,AZ:Placement.AvailabilityZone,PublicIP:PublicIpAddress}' \
--output table
```

Deberías ver:

```text
dcl-dev-web-a    stopped
dcl-dev-web-b    running
```

---

# 5. Probar que B continúa disponible

Prueba nuevamente B:

```bash
curl -i http://IP-B
```

**Resultado esperado:**

```text
HTTP/1.1 200 OK
```

y aparece:

```html
Digital Cafe Luna
```

Mientras tanto, prueba A:

```bash
curl -i http://IP-A
```

A debería dejar de responder correctamente porque la instancia está detenida.

La evidencia fundamental es:

| Prueba                 | Resultado               |
| ---------------------- | ----------------------- |
| HTTP A antes de falla  | ✅ Responde              |
| HTTP B antes de falla  | ✅ Responde              |
| A después de detenerla | ❌ No responde           |
| B después de detener A | ✅ Continúa respondiendo |

Esto demuestra **redundancia**, pero no todavía failover. El propio laboratorio señala que B continúa disponible, pero los usuarios que tenían el endpoint de A **no son redirigidos automáticamente**. 

---

# 6. Análisis técnico del fallo

La explicación que puedes dar es:

> **La falla de A afecta únicamente a la instancia A porque A y B están distribuidas en Availability Zones diferentes. B continúa funcionando porque pertenece a otro dominio de fallo. Sin embargo, el usuario que accede directamente a la IP pública de A no es enviado automáticamente a B. Por eso la arquitectura tiene redundancia, pero todavía no tiene failover automático.**

Esto es exactamente lo que busca demostrar la práctica: **A deja de responder y B sigue disponible**, pero no existe redirección automática. 

---

# 7. Diagrama v2: qué debes marcar

En tu diagrama marca algo así:

```text
                    Internet
                       |
             +---------+---------+
             |                   |
          AZ-A                AZ-B
             |                   |
     Public Subnet A      Public Subnet B
             |                   |
       dcl-dev-web-a       dcl-dev-web-b
             |                   |
          ❌ FALLA              ✅ OK
          STOPPED              RUNNING
             |                   |
        HTTP falla          HTTP funciona
```

### Radio de impacto

Marca el radio de impacto **solo sobre A**:

```text
Falla:
dcl-dev-web-a
     ↓
Instancia A no disponible
     ↓
IP pública de A no responde

NO afecta:
dcl-dev-web-b
     ↓
B continúa disponible
```

**Importante:** la falla simulada es de la instancia A, no de toda la AZ. La distribución entre AZ demuestra que una falla localizada no elimina ambas unidades de cómputo.

---

# 8. Pregunta técnica: ¿qué falta para un único endpoint con health checks y failover automático?

### Respuesta corta para entregar

> **Falta un Application Load Balancer (ALB), un Target Group con health checks y la configuración de los targets para que el tráfico se envíe únicamente a instancias saludables. De esta forma, el usuario utilizaría un único endpoint DNS y el ALB podría dejar de enviar tráfico a una instancia que falle.**

Pero hay una precisión importante: **Auto Scaling Group, Launch Template y políticas de escalado tampoco forman parte de este laboratorio**; el documento indica que esos mecanismos se incorporan en la siguiente iteración S06. 

Por tanto, para responder **exactamente lo que pregunta el laboratorio**, los componentes principales que faltan son:

```text
ALB
 ↓
Target Group
 ↓
Health Checks
 ↓
Instancia A + Instancia B
```

En lugar de:

```text
Usuario
  ├──→ IP pública A
  └──→ IP pública B
```

tendríamos:

```text
             Usuario
                |
                ↓
         Único endpoint
          DNS del ALB
                |
                ↓
        Application Load
           Balancer
                |
          +-----+-----+
          |           |
       Target A    Target B
       healthy      healthy
```

Si A falla:

```text
             Usuario
                |
                ↓
             ALB
                |
          +-----+-----+
          |           |
       A ❌          B ✅
                    ↑
              recibe tráfico
```

---

## 9. Comandos que yo usaría como evidencia

### A. Instancias

```bash
aws ec2 describe-instances \
--filters 'Name=tag:dcl:project,Values=digital-cafe-luna' \
--query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,AZ:Placement.AvailabilityZone,PublicIP:PublicIpAddress}' \
--output table
```

### B. Security Group

```bash
aws ec2 describe-security-groups \
--filters 'Name=group-name,Values=dcl-dev-sg-web' \
--query 'SecurityGroups[].{Name:GroupName,Inbound:IpPermissions}' \
--output json
```

Ambos comandos son los que proporciona directamente el Laboratorio 2. 

### C. Prueba HTTP A

```bash
curl -i http://IP-PUBLICA-A
```

### D. Prueba HTTP B

```bash
curl -i http://IP-PUBLICA-B
```

### E. Después de detener A

```bash
curl -i http://IP-PUBLICA-A
```

```bash
curl -i http://IP-PUBLICA-B
```

---

## 10. Resumen de evidencias que debes entregar

| Evidencia                | Qué debe demostrar                        |
| ------------------------ | ----------------------------------------- |
| **1. Tabla EC2**         | Name, State, AZ, Public IP de A y B       |
| **2. HTTP A**            | A responde antes de la falla              |
| **3. HTTP B**            | B responde antes de la falla              |
| **4. A detenida**        | A pasa a `stopped` y deja de responder    |
| **5. HTTP B después**    | B sigue respondiendo                      |
| **6. Diagrama v2**       | A marcada como fallida y radio de impacto |
| **7. Análisis**          | Redundancia ≠ failover automático         |
| **8. Respuesta técnica** | Faltan ALB + Target Group + Health Checks |

El criterio de aceptación del laboratorio confirma precisamente: **ambos endpoints funcionan antes de la simulación; al detener A, B continúa; no hay redirección automática**. 

**¿Quieres que sigamos con la parte de *paso a paso en AWS Console* o con *qué debes pegar exactamente en el informe*?**
