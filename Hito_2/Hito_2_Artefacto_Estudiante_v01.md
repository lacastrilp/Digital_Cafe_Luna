# DIGITAL CAFÉ LUNA — HITO 2: ARQUITECTURA Y MIGRACIÓN
## ARTEFACTO DEL ESTUDIANTE · v01 (ENTREGABLE FORMAL CON ENFOQUE IAAS + RDS + S3)

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

*   **Arquitectura revisada:** Diseño objetivo de 3 capas en AWS bajo modelo **IaaS (Infrastructure as a Service)** utilizando **AWS EC2 en Auto Scaling Groups (ASG)** con provisión 100% en **Terraform IaC**, complementada con persistencia administrada en **AWS RDS PostgreSQL Multi-AZ** y almacenamiento de objetos en **AWS S3**.
*   **Decisiones y Trade-offs:** Justificación del cómputo IaaS (con PaaS como alternativa inicial/prototipado), red VPC segmentada, base de datos RDS PostgreSQL y almacenamiento de objetos S3.
*   **Justificación de RDS PostgreSQL y S3:** Explicación detallada de por qué se necesitan ambos servicios (datos estructurados transaccionales vs. objetos estáticos), junto con sus ventajas y desventajas.
*   **Plan de migración progresiva:** Estrategia en 5 etapas secuenciales desde la red base hasta el cutover definitivo sin pérdida de datos.
*   **Convivencia híbrida:** Limitada estrictamente a la fase de transición (migración de datos y pruebas), con retiro total tras la estabilización.
*   **Riesgos y mitigaciones:** Identificación de riesgos de inconsistencia de datos, sobrecostos y conectividad con sus correspondientes controles.

---

## 2. TRAZABILIDAD DESDE HITO 1

| Elemento de Hito 1 | Se mantiene / cambia | Decisión o cambio en Hito 2 | Justificación |
| :--- | :--- | :--- | :--- |
| **Monolito con despliegues manuales y poca visibilidad (Problema Hito 1)** | **Se mantiene** (problema origen), **Cambia** la solución. | Migración progresiva a AWS IaaS administrando instancias **AWS EC2 con Auto Scaling Group** y contenedores Docker provistos 100% mediante plantillas Terraform IaC. | Convierte el objetivo en una secuencia donde la capacidad de cómputo se gestiona mediante infraestructura como código con reemplazo automático ante fallas. |
| **RF-1: Provisión mediante código (IaC)** | **Se mantiene** (se profundiza) | Definición estandarizada de plantillas Terraform para la VPC, Subnets, Security Groups, Launch Templates de EC2, ASG, RDS y S3. | Garantiza el aprovisionamiento IaaS reproducible por código, erradicando clics manuales en la consola web. |
| **RF-2: Mecanismo de integración / mensajería** | **Se mantiene** | Incorporación de **AWS SQS** como bus de colas para desacoplar las notificaciones/workers del proceso principal de pedidos. | Evita cuellos de botella en horas pico de ventas de café. |
| **RF-3: Almacenamiento centralizado de objetos** | **Se mantiene** | Adopción de **AWS S3 Bucket** para alojar activos estáticos e imágenes del catálogo de productos. | Almacena archivos estáticos no estructurados fuera de las instancias EC2 y de la base de datos SQL. |
| **RF-4: Separación de datos del cómputo** | **Cambia** (se profundiza) | La base de datos relacional se despliega en **AWS RDS PostgreSQL Multi-AZ** (primaria en AZ A, standby síncrona en AZ B con failover automático), separada de las instancias EC2 del Auto Scaling Group. | Desacopla la persistencia transaccional de las instancias de cómputo EC2. Si una EC2 se destruye, el Auto Scaling Group recrea la VM y los datos en RDS permanecen intactos. |
| **RF-5: Control de versiones de IaC** | **Se mantiene** | Código Terraform versionado en Git con seguimiento de commits por autor. | Asegura auditabilidad de los cambios de infraestructura. |
| **RNF-1: Segmentación de red** | **Cambia** (se profundiza) | Topología **VPC 3-Capas** (Subnets Públicas para ALB/NAT, Privadas para EC2 ASG, Aisladas para RDS). | Aísla completamente la base de datos de Internet; el tráfico web solo entra por el ALB. |
| **RNF-2: Mínimo privilegio (IAM)** | **Se mantiene** | IAM Roles acotados asignados a las instancias EC2 para leer S3 y escribir en SQS. | Erradica el uso de credenciales estáticas en el código de la aplicación. |
| **RNF-3 / RNF-3 v03: Notificación de anomalías** | **Cambia** (se profundiza) | Alarmas **CloudWatch** configuradas para notificar ante CPU >75% en las EC2 o mensajes acumulados en la DLQ de SQS. | Notifica oportunamente al equipo antes de impactar al usuario. |
| **RNF-4: Etiquetado financiero (FinOps)** | **Se mantiene** | **Cost Allocation Tags** obligatorios y alerta de presupuesto en **AWS Budgets** a $20 USD. | Permite identificar los *cost drivers* reales y mantener control del gasto. |
| **RNF-5: Portabilidad y mitigar Lock-in** | **Se mantiene** | Cómputo IaaS basado en **contenedores Docker sobre Linux EC2** y motor **PostgreSQL**. | Permite migrar el cómputo y la BD a cualquier servidor virtual en otra nube u on-premise. |
| **RNF-6: Cifrado en tránsito y reposo** | **Se mantiene** | **HTTPS (TLS 1.3)** en ALB y cifrado **AWS KMS** por defecto en RDS y S3. | Garantiza la protección de la información del canal digital. |

---

## 3. ARQUITECTURA REVISADA (MODELO IAAS AWS)

### 3.1 Diagrama de la Arquitectura Objetivo (IaaS EC2 ASG + RDS Multi-AZ + S3)

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
|  |  - EC2 Instance A (Auto Scaling Group)        |   |  - EC2 Instance B (Auto Scaling Group)        | |
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

---

## 4. JUSTIFICACIÓN PROFUNDA: RDS POSTGRESQL Y AMAZON S3

El proyecto Digital Café Luna requiere obligatoriamente el uso coordinado de **AWS RDS PostgreSQL** y **Amazon S3**.

### 4.1 ¿Por qué se necesitan AMBOS servicios? (Sinergia de Persistencia)

1. **Separación entre Datos Transaccionales (RF-4) y Archivos Estáticos (RF-3):**
   - **RDS PostgreSQL** almacena la información estructurada que requiere transacciones **ACID** (usuarios, catálogo de productos, compras, inventario, pedidos).
   - **Amazon S3** almacena la información no estructurada de gran tamaño (imágenes HD de cafés, archivos de facturas PDF, respaldos).
2. **Prevención del Colapso de la Base de Datos:**
   Guardar archivos de imágenes (BLOBs) dentro de PostgreSQL satura la memoria RAM del servidor SQL, ralentiza los tiempos de respuesta de la base de datos y aumenta exponencialmente los costos de IOPS. Almacenar la imagen en **S3** y guardar solo su referencia URL en **RDS** mantiene la base de datos ligera y veloz.
3. **Compatibilidad con el Cómputo Elástico IaaS (EC2 Auto Scaling):**
   Las instancias EC2 no almacenan imágenes localmente en sus discos. Cuando el Auto Scaling Group crea o destruye servidores EC2 en respuesta al tráfico, todas las instancias leen los datos relacionales desde la misma RDS y sirven los activos estáticos apuntando directamente al Bucket **S3**.

---

### 4.2 Ventajas y Desventajas de AWS RDS PostgreSQL

| Servicio | Ventajas Técnicas | Desventajas / Limitaciones |
| :--- | :--- | :--- |
| **AWS RDS PostgreSQL** | 1. **Réplica Síncrona Multi-AZ:** Alta disponibilidad automática con conmutación en 1-2 minutos en caso de fallo de AZ.<br>2. **Backups Automáticos y PITR:** Cobertura de backups diarios sin intervención manual.<br>3. **Cifrado KMS (RNF-6):** Cifrado por defecto en reposo y conexiones SSL/TLS en tránsito.<br>4. **Cero administración física de SO:** AWS gestiona parches del motor y hardware. | 1. **Costo mensual continuo:** Se paga por la instancia provista 24/7.<br>2. **Sin acceso SSH al SO:** No permite modificaciones en el SO subyacente de la BD.<br>3. **Vendor lock-in de la plataforma:** Dependencia del plano de gestión de AWS (mitigado porque el motor es PostgreSQL estándar). |

---

### 4.3 Ventajas y Desventajas de Amazon S3

| Servicio | Ventajas Técnicas | Desventajas / Limitaciones |
| :--- | :--- | :--- |
| **Amazon S3** | 1. **Durabilidad de 11 Nueves (99.999999999%):** Redundancia física automática en mínimo 3 AZs.<br>2. **Escalabilidad ilimitada:** Almacena desde 1 MB hasta Petabytes sin provisionar discos previamente.<br>3. **Costo por uso extremadamente bajo:** Pago estricto por Gigabytes ocupados.<br>4. **Cifrado SSE-S3 automático (RNF-6).** | 1. **No es un sistema de archivos local POSIX:** Requiere llamadas a API/SDK HTTP en lugar de lecturas de disco local.<br>2. **Mayor latencia que disco EBS:** No apto para bases de datos transaccionales activas.<br>3. **Costos de salida de datos (Egress):** La transferencia masiva a Internet puede generar cargos si no se optimiza. |

---

## 5. DECISIONES ARQUITECTÓNICAS Y TRADE-OFFS

| Decisión | Necesidad / Requerimiento | Alternativas Consideradas | Consecuencia / Trade-off | Justificación |
| :--- | :--- | :--- | :--- | :--- |
| **D1: Cómputo IaaS (AWS EC2 + Auto Scaling Group)** | RF-1 (IaC), RF-5 (Git), RF-4 (Desacoplamiento), RNF-5 (Portabilidad) | PaaS inicial (App Runner / ECS Fargate); Kubernetes (EKS); Serverless Lambda | **Consecuencia:** Exige gestión de scripts de arranque (`user_data`) y AMI en Terraform.<br>**Trade-off:** Control total de SO, parches e infraestructura IaaS por código sin depender de PaaS propietarios. | Se considera PaaS para prototipado rápido inicial, pero se selecciona **IaaS (EC2 + ASG)** como arquitectura final para tener control total de la infraestructura mediante código (**RF-1**). |
| **D2: Base de Datos en AWS RDS PostgreSQL Multi-AZ** | RF-4 (Datos separados), RNF-3 v03 (Disponibilidad), RNF-6 | RDS Single-AZ; BD en EC2 con replicación manual; Multi-región | **Consecuencia:** Duplica el costo mensual de la instancia RDS.<br>**Trade-off:** Single-AZ no tolera caídas de AZ; BD en EC2 aumenta la carga operacional. | Separar los datos del cómputo (RF-4) exige alta disponibilidad. Multi-AZ permite failover automático en 1-2 minutos sin perder transacciones. |
| **D3: Almacenamiento de Objetos en Amazon S3** | RF-3 (Almacenamiento centralizado), RNF-6 | Discos locales EBS en EC2; EFS montado en red | **Consecuencia:** Las aplicaciones deben consumir las imágenes vía URLs o API HTTP.<br>**Trade-off:** Durabilidad de 11 nueves y costo muy bajo sin saturar el almacenamiento de EC2 o RDS. | Separa los archivos no estructurados de la BD relacional y permite que múltiples EC2 compartan las imágenes. |
| **D4: Automatización IaC 100% con Terraform** | RF-1 (Provisión automática), RF-5 (IaC Git), RNF-4 | Configuración manual por Consola AWS; Scripts Bash sueltos | **Consecuencia:** Exige estricta disciplina en el manejo de la sintaxis HCL y del estado `terraform.tfstate`.<br>**Trade-off:** Infraestructura 100% reproducible y auditable. | Es la base del Hito 2 y evita procesos manuales inconsistentes en la nube. |
| **D5: Red VPC 3-Capas con Subnets Privadas** | RNF-1 (Segmentación de red), RNF-6 (Cifrado/Seguridad) | VPC de 1 sola capa pública; Subnets compartidas | **Consecuencia:** Requiere el pago de NAT Gateways para la salida a Internet de las subnets de cómputo EC2.<br>**Trade-off:** Isolation absoluto de la base de datos sin exposición a Internet. | Garantiza la seguridad en profundidad requerida por RNF-1. |
| **D6: Desacoplamiento Asíncrono con AWS SQS** | RF-2 (Mensajería/Desacoplamiento) | REST síncrono puro; RabbitMQ en EC2 | **Consecuencia:** El procesamiento de tareas secundarias requiere manejo eventual de mensajes.<br>**Trade-off:** Cola administrada Serverless sin costo fijo por servidores ociosos. | Permite absorber picos de ventas de café sin ralentizar el checkout del cliente. |

---

## 6. PLAN DE MIGRACIÓN PROGRESIVA (5 ETAPAS VERIFICABLES)

| Etapa | Objetivo / Cambio / Dependencia Previa | Validación / Criterio de Salida | Riesgo Principal |
| :--- | :--- | :--- | :--- |
| **1. Base de Red e IaC** | **Objetivo:** Aprovisionamiento de la VPC (`10.0.0.0/16`), subnets públicas/privadas, IGW, NAT Gateways, tablas de ruteo y Security Groups mediante Terraform.<br>**Dependencia:** Repositorio Git inicial (RF-5) y cuenta AWS. | Ejecución exitosa de `terraform apply` sin errores. Verificación de aislamiento de subnets. | Reglas de Security Groups que bloqueen el tráfico legítimo o expongan la red privada. |
| **2. Persistencia de Datos (RDS Multi-AZ + S3)** | **Objetivo:** Despliegue de Amazon RDS PostgreSQL Multi-AZ en subnets privadas y creación del Bucket Amazon S3 cifrado.<br>**Dependencia:** Etapa 1 completada (VPC y Subnets de datos). | RDS en estado `Available` y prueba exitosa de subida de archivo a S3 con cifrado KMS (**RNF-6**). | Configuración de credenciales o subredes que impidan la replicación Multi-AZ. |
| **3. Migración y Validación de Datos (B10)** | **Objetivo:** Carga inicial de datos desde el monolito a RDS PostgreSQL, carga de imágenes a S3, comprobación de checksums y snapshot previo al cutover.<br>**Dependencia:** Etapa 2 completada (RDS y S3 operativos). | Coincidencia exacta de conteo de registros (*row count*), verificación de checksums de datos y generación de snapshot. | Inconsistencia de datos durante la exportación / importación SQL. |
| **4. Despliegue de Cómputo IaaS (EC2 ASG) y ALB** | **Objetivo:** Despliegue del ALB en subnets públicas y de las instancias EC2 en el Auto Scaling Group dentro de subnets privadas.<br>**Dependencia:** Etapa 3 completada (Datos validados en RDS/S3). | Health checks del ALB en estado `Healthy` y respuesta exitosa HTTP 200 al probar el DNS del ALB. | Fallas en scripts de inicialización (`user_data`) o problemas de conexión entre EC2 y RDS. |
| **5. Cutover Final y Estabilización** | **Objetivo:** Cambio de registro DNS en Route 53 hacia el ALB, monitoreo de métricas en tiempo real y cierre del entorno on-premise.<br>**Dependencia:** Etapa 4 completada y pruebas funcionales aprobadas. | 100% de peticiones atendidas en AWS sin errores 5xx. Métricas en rangos normales en CloudWatch. | Latencia no anticipada o errores en producción que fuercen la activación del plan de rollback. |

---

## 7. CONVIVENCIA ENTRE ENTORNO EXISTENTE Y CLOUD

| ¿Se requiere convivencia híbrida? | Justificación Técnica | Dependencias / Conectividad durante Transición | Condición para Retirarla o Mantenerla |
| :--- | :--- | :--- | :--- |
| **SÍ (Únicamente como convivencia temporal durante la transición de migración de datos y cutover)**.<br><br>**NO (Como arquitectura final permanente)**. | La convivencia híbrida no se adopta como estado final porque duplica costos y aumenta la complejidad operacional.<br>Sin embargo, durante las **Etapas 3 y 4**, el entorno on-premise debe convivir temporalmente con AWS para permitir la extracción de datos, la carga inicial a RDS/S3 y las pruebas paralelas sin interrumpir la operación comercial. | **Conectividad:** Conexión segura sobre HTTPS/TLS para la carga del dump hacia RDS y la sincronización de archivos estáticos hacia S3.<br>**Dependencias:** El servidor on-premise permanece activo en modo lectura durante la ventana de corte. | **Condición de Retiro:** Una vez completada la Etapa 5 (Cutover), verificado el DNS apuntando al ALB y confirmada la estabilidad en AWS durante 48 horas, se procede al **apagado y retiro definitivo del servidor on-premise**. |

---

## 8. RIESGOS Y MITIGACIONES

| Riesgo | Impacto | Mitigación / Control | Riesgo Residual o Condición a Vigilar |
| :--- | :--- | :--- | :--- |
| **1. Inconsistencia de datos durante la migración desde On-Premise a RDS/S3 (Etapa 3)** | **Alto** | Respaldo previo, validación automatizada de *checksums* y conteo de registros. Generación de snapshot RDS antes del cutover. | Incompatibilidad menor en tipos de datos entre motores SQL que requiera ajuste en scripts. |
| **2. Sobrecostos en AWS por recursos EC2/NAT olvidados** | **Medio** | Etiquetado obligatorio en Terraform (**RNF-4**), presupuestos **AWS Budgets** a $20 USD y ejecuciones de `terraform destroy` tras laboratorios. | Costo acumulado por NAT Gateways activos si no se destruyen entornos de prueba. |
| **3. Bloqueo de tráfico por Security Groups incorrectos** | **Medio** | Definir Security Groups jerárquicos en Terraform (ALB → EC2 → RDS) y probar conectividad en cada etapa. | Rechazo silencioso de tráfico en puertos específicos (5432 o 8080). |
| **4. Caída de la base de datos por fallo de AZ** | **Alto** | RDS en modalidad Multi-AZ con réplica síncrona y conmutación automática de failover (1-2 min). | Pequeña ventana de latencia durante la conmutación al nodo standby. |

---

## 9. ROLES Y CONTRIBUCIONES ROTADOS (GRUPO 1)

| Integrante | Rol Rotativo en Hito 2 | Contribución Concreta en el Hito 2 |
| :--- | :--- | :--- |
| **Paulina Velásquez Londoño** | Arquitectura de Soluciones | Liderar el diseño de la arquitectura IaaS en AWS (EC2 ASG + RDS + S3), justificar el uso de EC2 frente a PaaS y documentar la justificación profunda y trade-offs de RDS PostgreSQL y Amazon S3. |
| **Luis Alejandro Castrillón Pulgarín** | Cloud / IaC Engineer | Diseñar la estructura modular de Terraform (VPC, Subnets, SG, EC2 ASG, RDS, S3), estructurar las 5 etapas del plan de migración IaaS y garantizar el cumplimiento de **RF-1** y **RF-5**. |
| **Martín Valencia Vallejo** | Security / CloudOps Engineer | Configurar las reglas de aislamiento de red (Security Groups 3-capas), definir las políticas de IAM Roles mínimo privilegio para las instancias EC2, enforzar cifrado KMS/TLS (**RNF-6**) y métricas CloudWatch (**RNF-3**). |
| **Alberto Cervantes Forero** | FinOps y Documentación | Implementar las políticas de etiquetado obligatorio (*Cost Allocation Tags*) para **RNF-4**, configurar el presupuesto de $20 USD en AWS Budgets y consolidar las matrices del entregable final del Hito 2. |

---

## 10. CUMPLIMIENTO DEL CRITERIO EVALUATIVO (NIVEL SOBRESALIENTE)

*   **Evolución clara desde Hito 1:** Demostrada en la Sección 2 (Trazabilidad) justificando la adopción de IaaS con IaC, RDS Multi-AZ y almacenamiento S3.
*   **Coherencia y Trazabilidad:** Cada decisión técnica responde directamente a un requerimiento de negocio o condición técnica.
*   **Justificación de Persistencia y Cómputo:** Explicación técnica sólida sobre IaaS (EC2 ASG) y el uso sinérgico de RDS PostgreSQL y S3 con sus respectivas ventajas y desventajas.

---
*Fin del Artefacto del Estudiante v01 v3.0 — Digital Café Luna (Grupo 1)*
