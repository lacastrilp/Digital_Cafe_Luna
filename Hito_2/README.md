# DIGITAL CAFÉ LUNA — HITO 2: ARQUITECTURA Y MIGRACIÓN
## BLUEPRINT DE ARQUITECTURA CLOUD, ESTRATEGIA DE MIGRACIÓN Y GUÍA DE DEFENSA TÉCNICA

---

| Campo | Detalle |
| :--- | :--- |
| **Asignatura** | Computación en Nube (2026-2) — EAFIT |
| **Proyecto** | Digital Café Luna — Hito 2: Arquitectura y Migración |
| **Equipo** | Grupo 1 |
| **Integrantes y Roles** | - **Paulina Velásquez Londoño**: Arquitecta de Soluciones<br>- **Luis Alejandro Castrillón Pulgarín**: Cloud / IaC Engineer<br>- **Martín Valencia Vallejo**: Security / CloudOps Engineer<br>- **Alberto Cervantes Forero**: FinOps & Documentación |
| **Versión** | 3.0 (Enfoque IaaS con Terraform + RDS & S3 Justificados) |

---

## 1. INTRODUCCIÓN

El presente documento constituye el **Blueprint Arquitectónico y Estrategia de Migración** para la modernización del canal digital de **Digital Café Luna**, correspondiente al **Hito 2** de la asignatura Computación en Nube (EAFIT 2026-2). 

Digital Café Luna es una empresa en crecimiento que comercializa productos de café a través de puntos físicos y su canal digital. Actualmente, la operación digital enfrenta severas limitaciones debido a una arquitectura monolítica alojada en infraestructura tradicional on-premise, con despliegues manuales, escasa visibilidad de seguridad, falta de observabilidad y ausencia de control de costos.

El Hito 2 transforma las necesidades del negocio definidas en el Hito 1 en una arquitectura nativa de nube **defendible, trazable, segura y costeable**, basada en el modelo **IaaS (Infrastructure as a Service)** mediante **AWS EC2 y Auto Scaling Groups** aprovisionados 100% con Infraestructura como Código (**Terraform IaC**), complementada con servicios administrados de persistencia (**AWS RDS PostgreSQL**) y almacenamiento de objetos (**AWS S3**).

---

## 2. CONTEXTO DEL HITO 1

La definición estratégica del proyecto se sustenta en el **Project Charter** acordado en el Hito 1 por el Grupo 1:

### 2.1 Resumen del Project Charter
*   **Problema del Negocio:** La operación monolítica on-premise dificulta la agilidad, impide responder a picos de demanda, genera altos tiempos de inactividad durante despliegues manuales y no ofrece visibilidad sobre costos ni seguridad.
*   **Objetivo General:** Diseñar e implementar progresivamente una primera solución cloud que modernice el canal digital aplicando principios de arquitectura cloud-native, automatización de infraestructura como código (IaC), seguridad de mínimo privilegio, observabilidad y gobierno financiero (FinOps).
*   **Alcance Inicial del Proyecto:** Arquitectura agnóstica y su mapeo en AWS (red IaaS, cómputo IaaS EC2/ASG, almacenamiento S3, persistencia RDS PostgreSQL, mensajería SQS), seguridad IAM mínimo privilegio, observabilidad básica (logs, métricas, al menos una alarma), y plantillas de automatización IaC con Terraform.
*   **Fuera de Alcance:** Procesamiento real de pagos (pasarela de pagos externa), disponibilidad empresarial multi-región, entornos multi-cloud simultáneos en runtime, y reprogramación completa de la aplicación desde cero.
*   **Stakeholders:** Gerencia de Digital Café Luna, Clientes del canal digital, Personal operativo de tiendas y logística, Equipo de Transformación Cloud (Grupo 1).

---

## 3. PROBLEMA DEL NEGOCIO Y TÉCNICO

La cadena de dolor actual de Digital Café Luna se sintetiza en la siguiente secuencia:

```
Despliegues Manuales (Riesgo de Error)
       ↓
Monolito Acoplado (Bases de datos y cómputo compartidos)
       ↓
Cuellos de Botella en Picos de Venta (Falta de escalabilidad)
       ↓
Infraestructura On-Premise Rígida (Capacidad ociosa o insuficiente)
       ↓
Cero Visibilidad Operativa y de Costos (Sin logs centralizados ni alarmas)
```

---

## 4. OBJETIVO DEL HITO 2

Responder formalmente a las 11 preguntas fundamentales de arquitectura planteadas en la metodología del curso:

1. **¿Qué arquitectura necesita Digital Café Luna?** Una arquitectura de 3 capas bajo modelo IaaS (Red VPC segmentada, Cómputo elástico en EC2 con Auto Scaling Group, Persistencia relacional RDS PostgreSQL y Almacenamiento S3).
2. **¿Por qué IaaS?** Porque brinda control total de la infraestructura por código (IaC Terraform), gestiona la capacidad virtual explícitamente y permite una transición gradual desde un prototipado inicial PaaS hacia un entorno de infraestructura completamente automatizado.
3. **¿Qué alternativas fueron consideradas?** On-premise, Nube Híbrida permanente, PaaS puro (App Runner / ECS Fargate), Serverless total (Lambda+DynamoDB), y Cómputo IaaS (EC2 + Auto Scaling Group).
4. **¿Por qué se seleccionó IaaS (EC2 + ASG) + RDS + S3?** Ofrece el control requerido de IaC, flexibilidad de SO, escalabilidad elástica y desacoplamiento completo de datos transaccionales (RDS) y archivos estáticos (S3).
5. **¿Por qué AWS?** Por la madurez de su API IaaS, soporte total de Terraform, amplitud de servicios administrados y adopción en el marco del curso.
6. **¿Qué parte es agnóstica?** El diseño de topología de red de 3 capas, las instancias virtuales de cómputo Linux con Docker, la persistencia SQL y el estándar de almacenamiento S3-compatible.
7. **¿Qué parte depende de AWS?** Las implementaciones específicas de AWS EC2 Auto Scaling, RDS PostgreSQL, S3, SQS, ALB, CloudWatch e IAM.
8. **¿Qué componentes deben migrarse?** La base de datos transaccional (catálogo y pedidos), las imágenes/activos estáticos de productos y la aplicación monolítica contenerizada.
9. **¿Cómo se migrarán?** Mediante una migración progresiva en 5 fases (Estrategia Rehost / Replatform - Containerize en EC2) con corte programado (*cutover*).
10. **¿Qué riesgos existen?** Inconsistencia de datos durante la migración, sobrecostos por instancias EC2 encendidas sin Auto Scaling adecuado y errores de configuración en Security Groups.
11. **¿Cómo se validará posteriormente?** A través de los Laboratorios Prácticos 1, 2, 3 y pruebas de falla/reemplazo de instancias en el Auto Scaling Group.

---

## 5. REQUERIMIENTOS DEL HITO 1 (FUENTE DE VERDAD)

| ID | Tipo | Requerimiento | Criterio de Aceptación y Verificación | Responsable |
| :--- | :--- | :--- | :--- | :--- |
| **RF-1** | Funcional | El entorno de nube debe permitir la provisión y modificación de infraestructura mediante código para erradicar procesos manuales. | Mediante la ejecución exitosa de los comandos de despliegue automatizado (`terraform apply`), sin requerir clics en la consola web. | Luis Castrillón |
| **RF-2** | Funcional | El sistema del canal digital debe contar con un mecanismo de integración o mensajería para lograr el desacoplamiento de componentes. | A través de una prueba de comunicación asíncrona enviando y consumiendo mensajes desde una cola o bus de eventos. | Paulina Velásquez |
| **RF-3** | Funcional | La plataforma requiere un modelo de almacenamiento centralizado (archivos, objetos o bloques) para alojar la persistencia de datos. | Subiendo un recurso (ej. imagen de producto) a S3 y validando su acceso seguro. | Luis Castrillón |
| **RF-4** | Funcional | El sistema debe abstraer y separar el almacenamiento de datos (catálogo y pedidos) de los recursos de cómputo, permitiendo escalar ambos de forma independiente. | Apagando o destruyendo una instancia de cómputo EC2 y verificando que los datos en RDS persisten intactos. | Paulina Velásquez |
| **RF-5** | Funcional | El equipo de ingeniería debe contar con un sistema de control de versiones que almacene las plantillas de infraestructura como código (IaC). | Revisando el historial de commits en Git y validando que un cambio de infraestructura puede rastrearse hasta un autor específico. | Luis Castrillón |
| **RNF-1** | No Funcional | La topología de red y los servicios de cómputo deben estar segmentados para separar el tráfico público del privado. | Inspeccionando las tablas de ruteo y la configuración de subredes públicas y privadas en la nube. | Luis Castrillón |
| **RNF-2** | No Funcional | Los accesos y permisos a la infraestructura deben estar acotados siguiendo el principio de mínimo privilegio. | Mediante una auditoría de las políticas IAM asignadas a roles específicos. | Martín Valencia |
| **RNF-3** | No Funcional | El entorno operativo debe notificar anomalías basadas en umbrales de rendimiento. | Simulando una carga de trabajo alta que logre disparar de manera efectiva al menos una alarma CloudWatch configurada. | Martín Valencia |
| **RNF-4** | No Funcional | Todos los componentes aprovisionados deben contar con etiquetas (*tags*) para viabilizar el control y análisis financiero de la nube. | Revisando que los recursos desplegados tengan aplicadas etiquetas de categorización e identificando los *cost drivers*. | Alberto Cervantes |
| **RNF-5** | No Funcional | El diseño de la arquitectura debe priorizar el uso de tecnologías y contenedores estándar que faciliten la portabilidad de las cargas de trabajo (mitigando *vendor lock-in*). | Evaluando las decisiones de diseño mediante un análisis de trade-offs que justifique cómo se facilita la migración a otra plataforma. | Paulina Velásquez |
| **RNF-6** | No Funcional | Toda la información transaccional y de usuarios del canal digital debe estar protegida mediante cifrado, tanto en tránsito como en reposo. | Verificando que las conexiones exigen HTTPS/TLS y que RDS/S3 tienen cifrado activado por defecto. | Martín Valencia |

---

## 6. CAPÍTULO 1 Y 2 — ANÁLISIS DEL MODELO CLOUD Y CÓMPUTO IAAS VS. PAAS

### 6.1 Justificación del Modelo IaaS (EC2 + Auto Scaling)

El equipo de ingeniería evalúa la evolución del modelo de cómputo entre **PaaS** (Plataforma como Servicio) e **IaaS** (Infraestructura como Servicio):

```
+---------------------------------------------------------------------------------------------------+
|                              EVOLUCIÓN DEL MODELO DE CÓMPUTO                                      |
+---------------------------------------------------------------------------------------------------+
|  FASE INICIAL / PROTOTIPADO (PaaS)         ─►       ESTADO OBJETIVO Y ARQUITECTURA (IaaS + IaC)   |
|  - Despliegue en PaaS (ej. ECS Fargate)             - Instancias virtuales AWS EC2 en Subnets Priv |
|  - Cero gestión de servidor o SO                    - Auto Scaling Group (ASG) elástico dinámico   |
|  - Rápido prototipado de contenedores               - Control total de SO, parches y redes vía IaC |
|                                                     - Provisión 100% automatizada con Terraform    |
+---------------------------------------------------------------------------------------------------+
```

#### ¿Por qué se prefiere IaaS (EC2 + Auto Scaling) para la arquitectura final?
1. **Control Total y Automatización IaC (RF-1, RF-5):** IaaS permite definir exactamente la capacidad de cómputo, las imágenes del sistema operativo (AMI), los scripts de inicialización (`user_data`), y las políticas de Auto Scaling en plantillas **Terraform**, garantizando la máxima profundidad técnica en la gestión de infraestructura como código.
2. **Resiliencia y Reemplazo Automático (RF-4):** El Auto Scaling Group (ASG) distribuye instancias EC2 en múltiples Zonas de Disponibilidad. Si una instancia EC2 se destruye o sufre una falla de hardware, el ASG lanza automáticamente una nueva unidad inmaculada que se conecta a RDS y S3 sin pérdida de datos.
3. **Portabilidad Absoluta (RNF-5):** Ejecutar contenedores Docker sobre instancias EC2 estandarizadas permite mover la carga de trabajo a cualquier servidor virtual en otro proveedor cloud (Azure VM, GCP Compute Engine) o entorno on-premise sin depender de motores PaaS propietarios.

---

## 7. JUSTIFICACIÓN PROFUNDA: AWS RDS POSTGRESQL Y AMAZON S3

Una de las decisiones arquitectónicas fundamentales de Digital Café Luna es la combinación de dos motores de persistencia especializados: **AWS RDS PostgreSQL** (relacional transaccional) y **Amazon S3** (almacenamiento de objetos).

```
                                  +---------------------------------------+
                                  |         AMAZON S3 BUCKET              |
                                  | Almacenamiento de Objetos / Archivos  |
                                  | - Imágenes de productos de café       |
                                  | - Manuales, PDFs de facturas          |
                                  | - Backups y dumps estáticos           |
                                  +---------------------------------------+
                                                      ^
                                                      | (Ruta / URL del recurso)
                                                      |
+----------------------------------+        +---------------------------------------+
|    CAPA DE CÓMPUTO IAAS          |        |        AWS RDS POSTGRESQL             |
|    AWS EC2 (Auto Scaling Group)  | -----> | Base de Datos Relacional Transaccional|
|    Contenedores App / API        |        | - Tablas de usuarios y credenciales  |
|    Sin estado local              |        | - Catálogo de productos y precios     |
+----------------------------------+        | - Pedidos, carrito y transacciones    |
                                            +---------------------------------------+
```

### 7.1 ¿Por qué se necesitan AMBOS servicios? (Sinergia RDS + S3)

1. **Separación de la Naturaleza de los Datos (RF-3 vs RF-4):**
   * **RDS PostgreSQL** está optimizado para datos estructurados con garantías **ACID** (consistencia estricta en transacciones bancarias o de pedidos de café).
   * **Amazon S3** está optimizado para datos NO estructurados de gran tamaño (archivos multimedia, imágenes de gran resolución de productos).
2. **Evitar la Degradación de la Base de Datos:**
   Almacenar archivos binarios pesados (BLOBs) directamente dentro de tablas SQL en PostgreSQL satura la memoria RAM del servidor de base de datos, ralentiza las consultas de catálogo/pedidos y dispara los costos de IOPS. Guardar la imagen en **S3** y únicamente la *URL/string* en **RDS** mantiene la base de datos liviana y veloz.
3. **Persistencia Independiente del Cómputo IaaS (RF-4):**
   Si las instancias EC2 escalan horizontalmente de 2 a 10 unidades durante una promoción de café, todas leen el catálogo relacional desde **RDS** y sirven las imágenes directamente desde **S3**, sin duplicar archivos en discos locales de los servidores.

---

### 7.2 Análisis de Ventajas y Desventajas de AWS RDS PostgreSQL

| Aspecto | Detalles Técnicos |
| :--- | :--- |
| **¿Qué es?** | Servicio de base de datos relacional administrado que ejecuta el motor de código abierto PostgreSQL. |
| **Ventajas** | 1. **Alta Disponibilidad Multi-AZ:** Réplica síncrona automática en una segunda AZ con failover transparente en 1-2 min.<br>2. **Respaldos Automáticos y PITR:** Cobertura de backups diarios y *Point-in-Time Recovery* hasta el segundo exacto.<br>3. **Cifrado KMS Activado (RNF-6):** Cifrado de datos en reposo y conexiones obligatorias SSL/TLS en tránsito.<br>4. **Cero Mantenimiento Físico:** Parcheo de SO y motor delegado a AWS, liberando al equipo de ingeniería. |
| **Desventajas** | 1. **Costo Fijo Mensual:** Pago continuo por la instancia RDS provista, incluso en periodos de bajo tráfico.<br>2. **Menor Control de SO:** No permite acceso root por SSH al servidor subyacente de la BD.<br>3. **Vendor Lock-in del Plano de Control:** La automatización del failover depende de AWS (mitigado porque el motor SQL es 100% estándar PostgreSQL exportable). |

---

### 7.3 Análisis de Ventajas y Desventajas de Amazon S3

| Aspecto | Detalles Técnicos |
| :--- | :--- |
| **¿Qué es?** | Servicio de almacenamiento de objetos basado en API REST, diseñado para almacenar y recuperar cualquier cantidad de datos desde cualquier lugar. |
| **Ventajas** | 1. **Durabilidad Extrema (99.999999999% - 11 Nueves):** Copia redundante automática a través de mínimo 3 AZs físicas.<br>2. **Escalabilidad ilimitada sin aprovisionamiento:** Crece automáticamente de 1 MB a Petabytes sin definir tamaños de disco previos.<br>3. **Costo Extremadamente Bajo:** Pago estricto por Gigabyte almacenado y peticiones procesadas.<br>4. **Cifrado SSE-S3 por defecto (RNF-6):** Protección automática de objetos en reposo mediante llaves administradas. |
| **Desventajas** | 1. **No es un sistema de archivos local POSIX:** Las aplicaciones no pueden montar S3 como un disco duro tradicional sin latencia (requiere llamadas a API o SDK).<br>2. **Latencia superior a disco de bloque (EBS):** Adecuado para archivos web, pero no para archivos de swapping o bases de datos activas.<br>3. **Costos de Transferencia Saliente:** La descarga masiva hacia fuera de la red de AWS puede generar costos de *Egress* si no se controla. |

---

## 8. CAPÍTULO 4 — ARQUITECTURA DE RED Y SEGMENTACIÓN IAAS

```
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

### 8.1 Reglas de Seguridad (Security Groups)
*   `SG-ALB`: Entrada 80/443 desde `0.0.0.0/0`.
*   `SG-EC2-App`: Entrada puerto 8080/80 únicamente desde `SG-ALB`. Salida a Internet vía NAT Gateway.
*   `SG-RDS-DB`: Entrada puerto 5432 únicamente desde `SG-EC2-App`. Cero acceso a Internet.

---

## 9. MATRIZ DE DECISIONES ARQUITECTÓNICAS (D01 - D14)

| ID | Tema | Problema | Requerimiento | Alternativas | Decisión Seleccionada | Justificación Técnica | Trade-off / Limitación | Validación Futura |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **D01** | Modelo Cloud | Infraestructura física rígida. | General | On-premise, Híbrido, Public Cloud | **Public Cloud (AWS)** | Máxima agilidad y eliminación de mantenimiento HW. | Dependencia de red Internet. | Lab 1 |
| **D02** | Proveedor | Plataforma madura requerida. | RNF-5 | AWS, Azure, GCP | **AWS** | Integración total con Terraform y encaje académico. | Vendor lock-in en servicios administrados. | Reto Terraform |
| **D03** | Cómputo | Despliegue manual e ineficiente. | RF-1, RNF-5, RF-4 | PaaS (App Runner / ECS), IaaS (EC2 + ASG) | **IaaS: AWS EC2 + Auto Scaling Group** | Control total de SO, parches y redes en IaC Terraform; resiliencia ante destrucción de instancias. | Requiere mantenimiento de scripts de arranque (`user_data`). | Lab 2 / Prueba ASG |
| **D04** | Redes | Tráfico no segmentado. | RNF-1 | Monolítico, Subnets aisladas | **VPC 3-Capas Multi-AZ** | Aisolation estricto de componentes públicos, cómputo y datos. | Costo adicional de NAT Gateways. | Lab 1 |
| **D05** | Balanceo | Punto único de falla de red. | RNF-1 | Sin LB, ALB, NLB | **Application LB (ALB)** | Balanceo L7, enrutamiento por rutas y terminación SSL/TLS. | Costo por LCU procesada. | Lab 2 |
| **D06** | Escalamiento | Caídas en picos de demanda. | RF-4 | Escala Manual, ASG Dinámico | **EC2 Auto Scaling Group** | Ajuste automático de instancias según uso de CPU/RAM. | Tiempo de inicio de nuevas VMs EC2. | Lab 2 |
| **D07** | Persistencia | BD acoplada al cómputo local. | RF-4, RNF-6 | BD local en EC2, AWS RDS | **AWS RDS PostgreSQL** | Desacoplamiento total, réplica Multi-AZ, backups y cifrado KMS. | Costo mensual fijo de la instancia RDS. | Prueba Apagado EC2 |
| **D08** | Objetos | Archivos estáticos en disco local. | RF-3, RNF-6 | Disco EBS, EFS local, AWS S3 | **AWS S3 Bucket** | Almacenamiento de objetos ilimitado, durabilidad 11 nueves, costo bajo. | Acceso mediante API/URL, no como disco local. | Carga Imagen S3 |
| **D09** | Mensajería | Acoplamiento síncrono. | RF-2 | REST síncrono, RabbitMQ, SQS | **AWS SQS** | Cola administrada para desacoplamiento de tareas asíncronas. | Procesamiento asíncrono eventual. | Lab 2 / Prueba Cola |
| **D10** | Portabilidad | Atadura al proveedor. | RNF-5 | Propietario puro, Estándar abierto | **Contenedores Docker + SQL estándar** | Permite migrar el cómputo y la BD a cualquier servidor o nube. | Pérdida de funciones 100% nativas propietarias. | Análisis Trade-offs |
| **D11** | Seguridad | Permisos globales inseguros. | RNF-2 | Credenciales fijas, IAM Roles | **IAM Roles acotados** | Mínimo privilegio estricto para que la EC2 acceda a S3 y SQS. | Gestión de políticas JSON. | Lab 3 / Auditoría IAM |
| **D12** | Observabilidad| Cero visibilidad de fallas. | RNF-3 | Logs locales, AWS CloudWatch | **CloudWatch Alarms** | Alarma ante CPU >75% o errores en la cola SQS. | Costo de retención de logs. | Lab 3 / Simulación |
| **D13** | FinOps | Descontrol de gastos. | RNF-4 | Sin etiquetas, Tagging Policy | **Tags obligatorios + Budgets** | Rastreo de *cost drivers* e imputación de costos ($20 Budget). | Disciplina operativa IaC. | Lab 3 / Alerta Budget |
| **D14** | IaC | Despliegues por consola web. | RF-1, RF-5 | Consola Web, Scripts Bash, Terraform | **HashiCorp Terraform** | Plantillas declarativas 100% automatizadas y versionables. | Manejo del archivo `terraform.tfstate`. | Reto Terraform |

---

## 10. ESTRATEGIA DE MIGRACIÓN EN 5 ETAPAS (IAAS)

```
+------------------+
|   ESTADO ACTUAL  |
| Monolito On-Prem |
+------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 1: BASE DE RED E IAC (VPC 10.0.0.0/16, Subnets, IGW, NAT, SGs)     |
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 2: PERSISTENCIA DE DATOS (AWS RDS PostgreSQL Multi-AZ + S3 Bucket) |
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 3: MIGRACIÓN Y VALIDACIÓN DE DATOS (Dump/Restore a RDS, Sync S3)   |
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 4: DESPLIEGUE CÓMPUTO IAAS Y ALB (EC2 ASG + ALB en Subnets Privadas)|
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 5: CUTOVER Y ESTABILIZACIÓN (Cambio DNS Route 53 al ALB)           |
+-------------------------------------------------------------------------+
         │
         ▼
+------------------+
|  ESTADO OBJETIVO |
| 100% AWS IaaS    |
+------------------+
```

---

## 11. CONCLUSIONES

1. **Modelo IaaS Robusto y Controlado:** La adopción de **AWS EC2 con Auto Scaling Group** permite demostrar la provisión de infraestructura como código (**RF-1**, **RF-5**) manteniendo control total sobre las instancias y garantizando resiliencia ininterrumpida ante la falla de servidores.
2. **Estrategia Dual de Persistencia (RDS + S3):** La combinación de **RDS PostgreSQL** (para datos relacionales transaccionales) y **Amazon S3** (para objetos estáticos) optimiza el rendimiento, reduce costos y cumple estrictamente con los requerimientos **RF-3** y **RF-4**.
3. **Gobierno y Seguridad Integral:** La solución incluye segmentación de red en 3 capas (**RNF-1**), cifrado de extremo a extremo (**RNF-6**), mínimo privilegio con IAM (**RNF-2**) y gobierno financiero con alertas de presupuesto (**RNF-4**).

---
*Fin del Blueprint Hito 2 v3.0 — Digital Café Luna (Grupo 1)*
