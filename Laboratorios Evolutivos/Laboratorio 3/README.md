Sí. Para el **Laboratorio 3 (S06)** el objetivo es dar el salto de las dos EC2 independientes del Lab 2 a una arquitectura con **un único endpoint (ALB), balanceo, health checks y recuperación de capacidad mediante ASG**. El documento indica explícitamente que el ALB distribuye capacidad existente, mientras que el ASG mantiene la capacidad deseada. 

## 1. Arquitectura que debemos construir

```text
                         Internet
                            |
                            v
                  +-------------------+
                  |       ALB         |
                  |   dcl-dev-alb     |
                  |       :80         |
                  +---------+---------+
                            |
                   Target Group
                  dcl-dev-tg-web
                    /           \
                   v             v
             EC2 Instance A   EC2 Instance B
                AZ 2a            AZ 2b
                   \             /
                    \           /
                     Auto Scaling
                      Group
                  desired = 2
```

La configuración del laboratorio pide:

* **Launch Template:** `dcl-dev-lt-web`
* **Target Group:** `dcl-dev-tg-web`
* **ALB:** `dcl-dev-alb`
* **ASG:** `dcl-dev-asg-web`
* Subnets públicas `a` y `b`
* ASG: **min = 2, desired = 2, max = 4**
* Health checks del ASG: **EC2**, sin habilitar ELB health checks como fuente adicional de reemplazo en este laboratorio. 

> Ojo: en el PDF aparece `max = 4.5`, pero `MaxSize` de un ASG debe ser un entero; probablemente es un error de formato del documento. **No lo cambiaría todavía** sin comprobar la consola/instrucción exacta de tu laboratorio.

---

# 2. Las cuatro preguntas conceptuales

### ¿Qué responsabilidad cumple el ALB que antes recaía en el usuario que elegía una IP?

Antes, el usuario tenía que escoger directamente entre:

```text
http://IP-A
http://IP-B
```

El **ALB elimina esa decisión**. El usuario utiliza un único DNS y el ALB distribuye las solicitudes entre los targets disponibles.

En otras palabras:

> **El ALB abstrae las IP individuales de las instancias y proporciona un único punto de entrada para distribuir el tráfico.**

Esto corresponde al objetivo de la Fase 5: un solo endpoint frente a múltiples instancias. 

---

### ¿Qué determina que un target sea elegible para recibir nuevas solicitudes?

Principalmente, su **estado de salud dentro del Target Group**.

El laboratorio lo expresa directamente: el Target Group determina qué destinos son elegibles para nuevas solicitudes. Si un target falla los health checks y existe otro healthy, el ALB deja de enviarle nuevas solicitudes. 

Respuesta corta para entregar:

> **La elegibilidad depende del estado del target en el Target Group y de los health checks. Un target unhealthy deja de recibir nuevas solicitudes mientras exista otro target healthy.**

---

### ¿Por qué la Prueba A no equivale a la Prueba B?

Porque prueban **dos mecanismos diferentes**.

**Prueba A → Reboot**

La instancia sigue existiendo y permanece `Running`, pero su aplicación puede dejar temporalmente de responder. Se observa principalmente:

```text
EC2
  ↓
Target Group
  ↓
Health Check
  ↓
ALB deja de enviar tráfico al target no saludable
```

El propio laboratorio advierte que el ASG debe observarse y registrarse, **sin asumir previamente que reemplazará la instancia**. 

**Prueba B → Terminate**

La instancia desaparece realmente:

```text
EC2 terminada
      ↓
capacidad real < desired
      ↓
ASG detecta pérdida de capacidad
      ↓
lanza nueva instancia
      ↓
nuevo target
      ↓
healthy
      ↓
desired = 2
```

Esta sí está diseñada para demostrar de forma determinista el **reemplazo de capacidad**. 

---

### ¿Qué significa `desired = 2` cuando una instancia desaparece?

Significa que el ASG tiene como objetivo mantener **2 instancias en funcionamiento como capacidad deseada**.

Por ejemplo:

```text
ANTES

Desired = 2
Running = 2

EC2-A
EC2-B
```

Terminas EC2-A:

```text
DURANTE

Desired = 2
Running = 1
```

El ASG debe lanzar/reponer capacidad:

```text
DESPUÉS

Desired = 2
Running = 2

EC2-B
EC2-C  ← nueva
```

El laboratorio espera precisamente observar la caída temporal de capacidad y posteriormente el lanzamiento de una nueva instancia hasta recuperar `desired = 2`. 

---

# 3. Evidencias que tienes que capturar

Te recomiendo llevarlas en este orden.

### Evidencia 1 — ALB

Ejecuta:

```bash
aws elbv2 describe-load-balancers \
  --names dcl-dev-alb \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' \
  --output table
```

Debes obtener algo equivalente a:

```text
Name          DNS                                      State
dcl-dev-alb   dcl-dev-alb-xxxxx.us-east-2.elb.amazonaws.com  active
```

El laboratorio pide específicamente captura/tabla con **DNS y estado del ALB**. 

---

### Evidencia 2 — Dos respuestas HTTP diferentes

Abre:

```text
http://DNS-DEL-ALB
```

Refresca varias veces.

El laboratorio pide que observes **al menos dos respuestas diferentes**, identificando:

* Region
* Availability Zone
* Instance ID
* Private IP
* Public IP, si aplica. 

Si el navegador reutiliza la respuesta, el propio laboratorio recomienda ventana privada o parámetros como:

```text
http://DNS-DEL-ALB/?v=1
http://DNS-DEL-ALB/?v=2
```

---

# 4. Evidencia del Target Group

Necesitamos obtener primero el ARN:

```bash
aws elbv2 describe-target-groups \
  --names dcl-dev-tg-web \
  --query 'TargetGroups[].{Name:TargetGroupName,ARN:TargetGroupArn,Port:Port,Protocol:Protocol}' \
  --output table
```

Luego:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "ARN_DEL_TARGET_GROUP" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table
```

La evidencia debe mostrar:

### Antes de Prueba A

```text
Target              State
i-xxxxxxxxxxxx      healthy
i-yyyyyyyyyyyy      healthy
```

### Durante Prueba A

Puede aparecer:

```text
Target              State
i-xxxxxxxxxxxx      unhealthy
i-yyyyyyyyyyyy      healthy
```

**Pero no debes fabricar esa transición.**

El documento dice expresamente que si el target se recupera antes de llegar a `unhealthy`, debes registrar lo que realmente observaste. 

La instancia se recupera muy rapido al reiniciar, tanto que no cambia nada en ALB, ASG, Target groups, ni la instancia.

### Después

Esperamos finalmente:

```text
Target              State
i-xxxxxxxxxxxx      healthy
i-yyyyyyyyyyyy      healthy
```

---

# 5. Evidencia del ASG

Ejecuta:

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dcl-dev-asg-web \
  --query 'AutoScalingGroups[].{Min:MinSize,Desired:DesiredCapacity,Max:MaxSize,Instances:Instances[].{Id:InstanceId,State:LifecycleState,Health:HealthStatus}}' \
  --output json
```

El laboratorio proporciona este comando específicamente para verificar el ASG. 

---

# 6. Prueba A — REBOOT
La instancia se recupera muy rapido al reiniciar, tanto que no cambia nada en ALB, ASG, Target groups, ni la instancia.
Primero:

```text
2 targets → healthy
```

Seleccionas **una instancia del ASG** y haces:

**EC2 → Instance state → Reboot instance**

No hagas `Terminate`.

Durante el reboot observa simultáneamente:

1. Estado de EC2.
2. Target Group.
3. ALB.
4. ASG.

El documento indica que durante el reboot la instancia puede permanecer `Running`, mientras los status checks pueden verse afectados temporalmente. 

### Evidencias de Prueba A

Necesitas:

```text
Target Group antes
        ↓
Target Group durante
        ↓
Target Group después
```

Y además:

```text
ASG durante Prueba A
```

**No concluyas automáticamente "el ASG reemplazó la instancia".** El laboratorio explícitamente pide registrar lo observado. 
La instancia se recupera muy rapido al reiniciar, tanto que no cambia nada en ALB, ASG, Target groups, ni la instancia.
---

# 7. Prueba B — TERMINATE

Aquí sí hacemos:

**EC2 → Instance state → Terminate instance**

Primero captura:

```text
Desired = 2
Instance A
Instance B
```

Luego terminas una.

Temporalmente:

```text
Desired = 2
Instances = 1
```

Después espera:

```text
Desired = 2
Instances = 2
```

Y finalmente verifica el Target Group.

Debe aparecer una **nueva Instance ID** en estado:

```text
healthy
```

Eso es una de las evidencias mínimas explícitas del laboratorio. 

---

## 8. Tabla de evidencias para tu informe

Puedes organizarlo así:

| Evidencia | Qué demostrar                                   |
| --------- | ----------------------------------------------- |
| E1        | ALB `dcl-dev-alb` activo + DNS                  |
| E2        | Respuesta HTTP desde instancia 1                |
| E3        | Respuesta HTTP desde instancia 2                |
| E4        | Target Group: 2 targets healthy antes de A      |
| E5        | Target Group durante reboot                     |
| E6        | Target Group después de reboot                  |
| E7        | Estado ASG durante Prueba A                     |
| E8        | ASG antes de Prueba B: desired=2                |
| E9        | ASG después de terminar instancia               |
| E10       | Nueva Instance ID registrada                    |
| E11       | Nueva Instance ID = `healthy`                   |
| E12       | Nueva instancia atendiendo tráfico mediante DNS |

### Y la idea central que debes demostrar

> **ALB = un único endpoint + distribución de tráfico + exclusión de targets no saludables.**
> **ASG = mantenimiento de la capacidad deseada mediante reemplazo de instancias terminadas.**

Eso es exactamente el salto conceptual de S05/Lab 02 a S06: **balanceo + salud + capacidad repetible**. 

**Podemos hacerlo paso a paso en AWS.** El siguiente paso es verificar si ya existen `dcl-dev-alb`, `dcl-dev-tg-web`, `dcl-dev-lt-web` y `dcl-dev-asg-web`, antes de crear nada.
