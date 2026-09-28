# DIGITAL CAFÉ LUNA — HITO 2: ARQUITECTURA Y MIGRACIÓN
## ARTEFACTO DEL ESTUDIANTE · v01 (ENTREGABLE FORMAL)

---

| Campo | Detalle |
| :--- | :--- |
| **Asignatura** | Computación en Nube (2026-2) — EAFIT |
| **Evaluativo** | Hito 2 — Arquitectura y migración (Peso: 5 %) |
| **Fecha de Entrega** | 29 de septiembre de 2026 |
| **Modalidad** | Equipos permanentes de 4 (Grupo 1) |
| **Integrantes y Roles Rotados** | - **Paulina Velásquez Londoño**: Arquitecta de Soluciones<br>- **Luis Alejandro Castrillón Pulgarín**: Cloud / IaC Engineer<br>- **Martín Valencia Vallejo**: Security / CloudOps Engineer<br>- **Alberto Cervantes Forero**: FinOps & Documentación |

---

## 1. RESUMEN DE LA ENTREGA ESPERADA

*   **Arquitectura revisada:** Diseño objetivo de 3 capas en AWS (Red segmentada, Cómputo contenedorizado inmutable en ECS Fargate, Persistencia administrada en RDS Multi-AZ y Mensajería SQS).
*   **Decisiones y Trade-offs:** Evaluación justificada de cómputo, base de datos, red, automatización IaC y modelo cloud objetivo.
*   **Plan de migración progresiva:** Estrategia en 5 etapas secuenciales desde la red base hasta el cutover definitivo sin pérdida de datos.
*   **Convivencia híbrida:** Limitada estrictamente a la fase de transición (migración de datos y pruebas), con retiro total tras la estabilización.
*   **Riesgos y mitigaciones:** Identificación de riesgos de inconsistencia de datos, sobrecostos y conectividad con sus correspondientes controles.
*   **Roles y contribuciones:** Distribución explícita del trabajo práctico y teórico por integrante.

---

## 2. TRAZABILIDAD DESDE HITO 1

*No se reescribe el Hito 1. Esta tabla evidencia la continuidad estricta: Requerimiento / Pendiente → Decisión revisada → Consecuencia.*

| Elemento de Hito 1 | Se mantiene / cambia | Decisión o cambio en Hito 2 | Justificación |
| :--- | :--- | :--- | :--- |
| **Monolito con despliegues manuales y poca visibilidad (Problema Hito 1)** | **Se mantiene** (el problema de origen), **Cambia** la estrategia de solución. | Migración progresiva por 5 etapas verificables a AWS, contenerizando la aplicación (Docker sobre ECS Fargate), definiendo la infraestructura en Terraform y ejecutando un cutover gradual con plan de rollback. | El problema del negocio y el objetivo estratégico siguen siendo los mismos. El Hito 2 convierte el objetivo en una secuencia operativa donde cada etapa tiene un criterio de salida claro y el **RF-3** / **RF-4** se protegen durante el corte. |
| **RF-1: Provisión mediante código (IaC)** | **Se mantiene** (se profundiza) | Definición estandarizada de plantillas Terraform para la VPC, Subnets, Security Groups, ECS, RDS y S3 (B07). | Garantiza la eliminación absoluta de clics manuales en la consola web de AWS y asegura entornos reproducibles. |
| **RF-2: Mecanismo de integración / mensajería** | **Se mantiene** (se activa) | Incorporación de **AWS SQS (Simple Queue Service)** como bus de colas para desacoplar el procesamiento de pedidos de los workers de notificaciones/inventario (B04). | Evita cuellos de botella en horas pico de ventas y absorbe picos de demanda sin degradar la respuesta a los clientes digitales. |
| **RF-3: Almacenamiento centralizado de objetos** | **Se mantiene** | Adopción de **AWS S3 Bucket** con cifrado SSE-S3 por defecto para alojar activos estáticos, imágenes de catálogo y respaldos. | Separa los activos del sistema de archivos local de los servidores de cómputo. |
| **RF-4: Separación de datos del cómputo** | **Cambia** (se profundiza) | La base de datos se despliega en **AWS RDS PostgreSQL Multi-AZ** (primaria en AZ A, standby síncrona en AZ B con failover automático), separada de los contenedores ECS Fargate. | Separar los datos del cómputo no basta si la BD no es altamente disponible. Multi-AZ evita que un fallo de instancia o de AZ deje caídos los pedidos (failover automático en 1-2 min). |
| **RF-5: Control de versiones de IaC** | **Se mantiene** | Estructuración del código Terraform en repositorio Git con seguimiento estricto de commits por autor. | Cumple la auditabilidad de cambios de infraestructura requerida por el equipo de ingeniería. |
| **RNF-1: Segmentación de red** | **Cambia** (se profundiza) | Rediseño a topología **VPC de 3 capas** (Public Subnets para ALB/NAT, Private Subnets para ECS, Isolated Subnets para RDS). | Aísla completamente la base de datos de Internet; el tráfico web solo entra por el ALB en subnets públicas. |
| **RNF-2: Mínimo privilegio (IAM)** | **Se mantiene** (se profundiza) | Definición de **IAM Task Roles** específicos para contenedores ECS con permisos de lectura/escritura limitados a S3 y SQS. | Erradica el uso de credenciales fijas o permisos globales `AdministratorAccess`. |
| **RNF-3 / RNF-3 v03: Notificación de anomalías** | **Cambia** (se profundiza) | Configuración de **AWS CloudWatch Alarms** vinculadas a métricas de CPU (>75%) y mensajes en la Dead Letter Queue (DLQ) de SQS. | Asegura que el equipo operativo sea notificado inmediatamente antes de que una anomalía afecte al usuario final. |
| **RNF-4: Etiquetado financiero (FinOps)** | **Se mantiene** | Aplicación obligatoria de **Cost Allocation Tags** en Terraform (`Project`, `Owner`, `Environment`) y alerta de presupuesto **AWS Budgets** a $20 USD. | Permite identificar los *cost drivers* reales y mantener la disciplina financiera en la nube. |
| **RNF-5: Portabilidad y mitigar Lock-in** | **Se mantiene** | Uso estricto de **contenedores Docker** y motor **PostgreSQL**, evitando APIs propietarias en el núcleo de la aplicación. | Permite ejecutar el contenedor y migrar los datos a cualquier otro proveedor cloud o entorno local si fuera necesario. |
| **RNF-6: Cifrado en tránsito y reposo** | **Se mantiene** | Enforzamiento de **HTTPS (TLS 1.3)** en el ALB y activación de cifrado **AWS KMS** por defecto en RDS y S3. | Garantiza la protección de la información transaccional y de los usuarios. |
| **B10 (Estrategia de Migración de Datos) y B02 (Diseño Arquitectónico)** | **Cambia** (B10 se activa y B02 se actualiza) | B10: La Etapa 3 del plan migra los datos a RDS Multi-AZ con comprobación de conteos, checksums y snapshot previo al cutover.<br>B02: Diagrama revisado en AWS con la capa de datos profundizada. | La migración de datos es el mayor riesgo del plan. El snapshot sirve de punto de rollback. El diagrama responde a las observaciones de disponibilidad. |

---

## 3. ARQUITECTURA REVISADA

### 3.1 Diagrama de la Arquitectura Objetivo Revisada (AWS 3-Capas)

```
[ CLIENTES DIGITALES EN INTERNET ]
               │
               ▼ (HTTPS / 443)
       [ AWS Route 53 ] (DNS / Health Check)
               │
               ▼
+--------------------------------------------------------------------------------------------------------+
|                                        AWS CLOUD (REGION)                                              |
|                                                                                                        |
|  VPC: 10.0.0.0/16                                                                                      |
|  +--------------------------------------------------------------------------------------------------+  |
|  |                                  INTERNET GATEWAY (IGW)                                          |  |
|  +--------------------------------------------------------------------------------------------------+  |
|                                                  │                                                     |
|                  ┌───────────────────────────────┴───────────────────────────────┐                     |
|                  ▼                                                               ▼                     |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|  | AVAILABILITY ZONE A (us-east-1a)              |   | AVAILABILITY ZONE B (us-east-1b)              | |
|  |                                               |   |                                               | |
|  | [SUBNET PÚBLICA 1] (10.0.1.0/24)              |   | [SUBNET PÚBLICA 2] (10.0.2.0/24)              | |
|  |  - Application Load Balancer (ALB Node A)     |   |  - Application Load Balancer (ALB Node B)     | |
|  |  - NAT Gateway A                              |   |  - NAT Gateway B                              | |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|                  │                                                               │                     |
|                  ▼                                                               ▼                     |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|  | [SUBNET PRIVADA CÓMPUTO 1] (10.0.10.0/24)     |   | [SUBNET PRIVADA CÓMPUTO 2] (10.0.20.0/24)     | |
|  |  - ECS Task / App Container (Node A)          |   |  - ECS Task / App Container (Node B)          | |
|  |  - Worker Consumer (SQS)                      |   |  - Worker Consumer (SQS)                      | |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|                  │                                                               │                     |
|                  ├───────────────────────────────┬───────────────────────────────┤                     |
|                  ▼                               ▼                               ▼                     |
|  +-------------------------------+   +-----------------------+   +-----------------------------------+ |
|  | [SUBNET DATOS 1] (10.0.100.0/24)|   | AWS S3 BUCKET         |   | AWS SQS QUEUE                     | |
|  |  - RDS PostgreSQL Primary     |   | Imgs / Objetos (RF-3) |   | Desacoplamiento (RF-2)            | |
|  +-------------------------------+   +-----------------------+   +-----------------------------------+ |
|                  │ (Replicación Síncrona Multi-AZ)                                                     |
|                  ▼                                                                                     |
|  +-------------------------------+                                                                     |
|  | [SUBNET DATOS 2] (10.0.200.0/24)|                                                                     |
|  |  - RDS PostgreSQL Standby     |                                                                     |
|  +-------------------------------+                                                                     |
|                                                                                                        |
+--------------------------------------------------------------------------------------------------------+
```

### 3.2 Justificación de Componentes y Separación de Entornos
*   **Entorno Existente (On-Premise):** Servidor monolítico único con base de datos integrada y almacenamiento local. Durante las etapas 1 a 4 opera de forma independiente mientras se aprovisiona y prueba la nube.
*   **Conectividad de Transición:** Conexión HTTPS/SSL directa enviando datos desde la herramienta de migración local (`pg_dump` / S3 upload) hacia el endpoint seguro de AWS S3 / RDS durante la Etapa 3. No se inventa una red híbrida dedicada permanente (Direct Connect / VPN IPSec) por no estar técnicamente justificada para el volumen del negocio.
*   **Dominio de Cómputo vs. Persistencia:** Los contenedores en **ECS Fargate** no almacenan estado local; la destrucción de cualquiera de ellos no afecta la base de datos en **RDS PostgreSQL** (**RF-4**).

---

## 4. DECISIONES ARQUITECTÓNICAS Y TRADE-OFFS

| Decisión | Necesidad / Requerimiento | Alternativas Consideradas | Consecuencia / Trade-off | Justificación |
| :--- | :--- | :--- | :--- | :--- |
| **D1: Cómputo en Contenedores Orquestados (AWS ECS Fargate)** | RNF-5 (Portabilidad), RF-1 (IaC), RF-4 (Desacoplamiento) | Lift-and-shift a EC2 puro; Kubernetes (EKS); Serverless Lambda | **Consecuencia:** Exige empaquetado Docker y ligera curva inicial.<br>**Trade-off:** Cero gestión de servidores subyacentes, despliegue inmutable y portabilidad total en contenedores sin pagar el sobrecosto de un cluster EKS. | Es la opción que cumple la portabilidad (RNF-5) sin exigir la reescritura completa del monolito (requerida por Lambda) ni la complejidad operacional de EKS. |
| **D2: Base de Datos en Amazon RDS Multi-AZ** | RF-4 (Datos separados), RNF-3 v03 (Disponibilidad), RF-3 v03 | RDS Single-AZ; BD en EC2 con replicación manual; Multi-región | **Consecuencia:** Duplica aproximadamente el costo mensual de la instancia RDS.<br>**Trade-off:** Single-AZ deja caídos los pedidos ante fallo de AZ; BD en EC2 sube la carga operacional; Multi-región está fuera de alcance por costo y complejidad. | Separar los datos del cómputo (RF-4) exige alta disponibilidad local. Multi-AZ permite failover automático en 1-2 minutos sin perder transacciones. |
| **D3: Migración con Corte Único Programado (Cutover con Rollback)** | RF-3 v03 (Sin interrupciones en operación), RF-4, B10 | Corte directo ("Big Bang") sin pruebas; Replicación síncrona continua híbrida | **Consecuencia:** Requiere ventana de mantenimiento de bajo tráfico (ej. 02:00 AM) y leve ventana de congelamiento de datos de minutos.<br>**Trade-off:** Menor riesgo de caída y punto de retorno claro vía snapshot. | El canal digital no puede interrumpirse durante el día. El snapshot previo de RDS permite volver atrás inmediatamente si la validación falla en producción. |
| **D4: Automatización IaC 100% con Terraform** | RF-1 (Provisión automática), RF-5 (IaC Git), RNF-4, B12 | Configuración manual por Consola AWS; Scripts Bash / AWS CLI sueltos | **Consecuencia:** Exige estricta disciplina en el manejo del estado (`terraform.tfstate`) y sintaxis modular HCL.<br>**Trade-off:** Cambios totalmente trazables, reproducibles y eliminables (`terraform destroy`). | Es la base de todas las etapas del proyecto y evita caer en los procesos manuales e inconsistentes que motivaron la modernización. |
| **D5: Red VPC 3-Capas con Subnets Privadas de Datos** | RNF-1 (Segmentación de red), RNF-6 (Cifrado/Seguridad) | VPC de 1 sola capa pública; Subnets compartidas entre App y BD | **Consecuencia:** Requiere el pago de NAT Gateways para la salida saliente de subnets privadas de cómputo.<br>**Trade-off:** Isolation absoluto de la base de datos sin exposición a Internet. | Garantiza la seguridad en profundidad exigida por RNF-1. La BD no tiene IP pública ni ruta al IGW. |
| **D6: Desacoplamiento Asíncrono con AWS SQS** | RF-2 (Mensajería/Desacoplamiento) | Integración síncrona REST pura; RabbitMQ en EC2 | **Consecuencia:** El procesamiento de tareas secundarias requiere manejo eventual y consumidores workers.<br>**Trade-off:** Cola administrada Serverless sin costo fijo por servidores ociosos. | Permite absorber picos de ventas de café sin ralentizar la respuesta del checkout al cliente. |

---

## 5. PLAN DE MIGRACIÓN PROGRESIVA (5 ETAPAS VERIFICABLES)

| Etapa | Objetivo / Cambio / Dependencia Previa | Validación / Criterio de Salida | Riesgo Principal |
| :--- | :--- | :--- | :--- |
| **1. Base de Red e IaC** | **Objetivo:** Aprovisionamiento automatizado de la VPC (`10.0.0.0/16`), subnets públicas/privadas, Internet Gateway, NAT Gateways, tablas de ruteo y Security Groups mediante Terraform.<br>**Dependencia:** Repositorio Git inicial (RF-5) y cuentas AWS creadas. | Ejecución exitosa de `terraform plan` y `terraform apply` sin errores. Inspección de aislamiento de subnets y conectividad básica verificada. | Errores en las reglas de Security Groups o tablas de ruteo que bloqueen el tráfico legítimo o expongan la red privada. |
| **2. Persistencia de Datos (RDS Multi-AZ)** | **Objetivo:** Despliegue de la instancia gestionada Amazon RDS PostgreSQL en subnets privadas con replicación síncrona en AZ secundaria.<br>**Dependencia:** Etapa 1 completada (VPC, Subnets privadas y SG-DB definidos). | Instancia en estado `Available`. Conexión de prueba exitosa desde un contenedor de testeo temporal. Parámetros de cifrado KMS activados (**RNF-6**). | Configuración incorrecta de subredes o credenciales que impidan la réplica síncrona en la AZ B. |
| **3. Migración y Validación de Datos (B10)** | **Objetivo:** Carga inicial de datos (catálogo, usuarios, pedidos) desde el monolito on-premise hacia RDS, comprobaciones de integridad y generación de snapshot de resguardo.<br>**Dependencia:** Etapa 2 completada (RDS Multi-AZ operativo). | Coincidencia exacta en el conteo de registros (*row count*), verificación de *checksums* en tablas principales y generación del snapshot previo al cutover. | Inconsistencia o pérdida de integridad de datos durante el proceso de exportación / importación. |
| **4. Despliegue del Cómputo y ALB** | **Objetivo:** Despliegue del Application Load Balancer (ALB) en subnets públicas y de las tareas de la aplicación contenedorizada (ECS Fargate) en subnets privadas.<br>**Dependencia:** Etapa 3 completada (Datos validados en RDS). | Pruebas de salud (*health checks*) del ALB en estado `Healthy`. Respuesta HTTP 200 OK en las peticiones enviadas al DNS del ALB. | Fallas en el arranque de los contenedores Docker o problemas de resolución de variables de entorno para conectar con RDS. |
| **5. Cutover Final y Estabilización** | **Objetivo:** Redirección del tráfico del canal digital cambiando el registro DNS hacia el ALB. Monitoreo en tiempo real de métricas y cierre gradual del entorno antiguo.<br>**Dependencia:** Etapa 4 completada y pruebas funcionales de extremo a extremo aprobadas. | 100% del tráfico procesado en AWS sin errores 5xx. Métricas CloudWatch en rangos normales y confirmación de persistencia de datos. | Latencia no anticipada o errores no detectados en staging que fuercen la activación del plan de rollback. |

---

## 6. CONVIVENCIA ENTRE ENTORNO EXISTENTE Y CLOUD

| ¿Se requiere convivencia híbrida? | Justificación Técnica | Dependencias / Conectividad durante Transición | Condición para Retirarla o Mantenerla |
| :--- | :--- | :--- | :--- |
| **SÍ (Únicamente como convivencia temporal durante la transición de migración de datos y cutover)**.<br><br>**NO (Como arquitectura final permanente)**. | La convivencia híbrida no se adopta como estado final porque añade costos duplicados y complejidad operacional innecesaria para el canal digital.<br>Sin embargo, durante la **Etapa 3 y 4 del plan de migración**, el entorno on-premise debe convivir temporalmente con AWS para permitir la extracción de datos, la carga inicial a RDS y las pruebas paralelas de validación sin apagar el negocio. | **Conectividad:** Conexión segura punto a punto sobre HTTPS/TLS usando AWS CLI / SSL Client para la transferencia de archivos de dump y sincronización de objetos S3.<br>**Dependencias:** El servidor on-premise permanece activo en modo lectura durante la ventana de corte. | **Condición de Retiro:** Una vez ejecutada exitosamente la Etapa 5 (Cutover), verificado el enrutamiento DNS hacia el ALB y confirmada la estabilidad de la operación en AWS durante 48 horas, se procede al **apagado y retiro definitivo del entorno on-premise**. |

---

## 7. RIESGOS Y MITIGACIONES

| Riesgo | Impacto | Mitigación / Control | Riesgo Residual o Condición a Vigilante |
| :--- | :--- | :--- | :--- |
| **1. Inconsistencia de datos durante la migración desde On-Premise a RDS (Etapa 3)** | **Alto** | Generar respaldo completo previo, ejecutar validación automatizada de *checksums* y conteo de registros en tablas clave. Generar snapshot de RDS justo antes del cutover. | Diferencia en tipos de datos o caracteres especiales entre motores SQL que requiera ajuste manual en scripts. |
| **2. Sobrecostos inesperados por recursos olvidados o mal dimensionados en AWS** | **Medio** | Etiquetado obligatorio en Terraform (**RNF-4**), presupuestos con alertas **AWS Budgets** a $20 USD y procedimiento claro de `terraform destroy` tras laboratorios. | Costo acumulado por NAT Gateways activos si no se destruyen entornos de prueba. |
| **3. Bloqueo de comunicación entre capas por reglas de Security Groups incorrectas** | **Medio** | Definir Security Groups de forma jerárquica en Terraform (ALB → ECS → RDS) probando conectividad desde la Etapa 1. | Rechazo silencioso de tráfico en puertos específicos (ej. 5432 o 8080) por reglas faltantes. |
| **4. Caída de la base de datos por fallo en una Zona de Disponibilidad** | **Alto** | Configurar RDS en modalidad Multi-AZ con réplica síncrona y conmutación automática de failover (1-2 minutos). | Pequeña ventana de latencia incrementada durante la conmutación al nodo standby. |

---

## 8. ROLES Y CONTRIBUCIONES ROTADOS (GRUPO 1)

| Integrante | Rol Rotativo en Hito 2 | Contribución Concreta en el Hito 2 |
| :--- | :--- | :--- |
| **Paulina Velásquez Londoño** | Arquitectura de Soluciones | Liderar la revisión del diagrama de arquitectura objetivo en AWS (3 capas Multi-AZ), justificar el uso de ECS Fargate frente a alternativas de cómputo y documentar la matriz de decisiones y trade-offs (D1, D2, D3). |
| **Luis Alejandro Castrillón Pulgarín** | Cloud / IaC Engineer | Definir la estructura modular de plantillas Terraform (VPC, Subnets, SG, ECS, RDS), diseñar el plan de migración progresiva en 5 etapas y validar la trazabilidad de los requerimientos de IaC (**RF-1**, **RF-5**). |
| **Martín Valencia Vallejo** | Security / CloudOps Engineer | Establecer el esquema de aislamiento de red (NACLs vs Security Groups), diseñar la política de mínimo privilegio para IAM Task Roles, configurar el cifrado ubiquo (**RNF-6**) y definir los criterios de alerta en CloudWatch (**RNF-3**). |
| **Alberto Cervantes Forero** | FinOps y Documentación | Implementar la estrategia de etiquetado obligatorio (*Cost Allocation Tags*) para cumplimiento del **RNF-4**, configurar el presupuesto de control financiero en AWS Budgets y consolidar el artefacto de trazabilidad e informe final del Hito 2. |

---

## 9. CUMPLIMIENTO DEL CRITERIO EVALUATIVO (NIVEL SOBRESALIENTE)

*   **Evolución clara desde Hito 1:** Demostrada formalmente en la Sección 2 (Trazabilidad) justificando los cambios en base de datos Multi-AZ, IaC y desacoplamiento.
*   **Coherencia y Trazabilidad:** Cada componente de la arquitectura responde directamente a un requerimiento de negocio o a una decisión técnica justificada.
*   **Justificación Técnica de Convivencia Híbrida:** Definida como temporal y estrictamente acotada a la ventana de migración de datos.

---
*Fin del Artefacto del Estudiante v01 — Hito 2 (Digital Café Luna - Grupo 1)*

