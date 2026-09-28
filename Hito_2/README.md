# DIGITAL CAFÉ LUNA — HITO 2: ARQUITECTURA Y MIGRACIÓN
## BLUEPRINT DE ARQUITECTURA CLOUD, ESTRATEGIA DE MIGRACIÓN Y GUÍA DE DEFENSA TÉCNICA

---

| Campo | Detalle |
| :--- | :--- |
| **Asignatura** | Computación en Nube (2026-2) — EAFIT |
| **Proyecto** | Digital Café Luna — Hito 2: Arquitectura y Migración |
| **Equipo** | Grupo 1 |
| **Integrantes y Roles** | - **Paulina Velásquez Londoño**: Arquitecta de Soluciones<br>- **Luis Alejandro Castrillón Pulgarín**: Cloud / IaC Engineer<br>- **Martín Valencia Vallejo**: Security / CloudOps Engineer<br>- **Alberto Cervantes Forero**: FinOps & Documentación |
| **Versión** | 2.0 (Blueprint Definitivo) |

---

## 1. INTRODUCCIÓN

El presente documento constituye el **Blueprint Arquitectónico y Estrategia de Migración** para la modernización del canal digital de **Digital Café Luna**, correspondiente al **Hito 2** de la asignatura Computación en Nube (EAFIT 2026-2). 

Digital Café Luna es una empresa en crecimiento que comercializa productos de café a través de puntos físicos y su canal digital. Actualmente, la operación digital enfrenta severas limitaciones debido a una arquitectura monolítica alojada en infraestructura tradicional on-premise, con despliegues manuales, escasa visibilidad de seguridad, falta de observabilidad y ausencia de control de costos.

El Hito 2 transforma las necesidades del negocio definidas en el Hito 1 en una arquitectura nativa de nube **defendible, trazable, segura y costeable**, estableciendo la estrategia de migración desde el estado actual on-premise hacia una plataforma moderna en Amazon Web Services (AWS), sin comprometer la portabilidad ni incurrir en complejidad innecesaria.

---

## 2. CONTEXTO DEL HITO 1

La definición estratégica del proyecto se sustenta en el **Project Charter** acordado en el Hito 1 por el Grupo 1:

### 2.1 Resumen del Project Charter
*   **Problema del Negocio:** La operación monolítica on-premise dificulta la agilidad, impide responder a picos de demanda, genera altos tiempos de inactividad durante despliegues manuales y no ofrece visibilidad sobre costos ni seguridad.
*   **Objetivo General:** Diseñar e implementar progresivamente una primera solución cloud que modernice el canal digital aplicando principios de arquitectura cloud-native, automatización de infraestructura como código (IaC), seguridad de mínimo privilegio, observabilidad y gobierno financiero (FinOps).
*   **Alcance Inicial del Proyecto:** Arquitectura agnóstica y su mapeo en AWS (red, cómputo, almacenamiento, persistencia, mensajería/desacoplamiento), seguridad IAM mínimo privilegio, observabilidad básica (logs, métricas, al menos una alarma), y plantillas de automatización IaC con Terraform.
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

**Consecuencias Directas:**
1. Pérdida de ventas en el canal digital durante promociones o horas pico.
2. Tiempos prolongados de despliegue y riesgo constante de caídas del sistema en producción.
3. Imposibilidad de imputar costos por servicio o componente de negocio.

---

## 4. OBJETIVO DEL HITO 2

Responder formalmente a las 11 preguntas fundamentales de arquitectura planteadas en la metodología del curso:

1. **¿Qué arquitectura necesita Digital Café Luna?** Una arquitectura cloud-native de 3 capas (Red segmentada, Cómputo contenedorizado desacoplado, Persistencia relacional administrada y Mensajería asíncrona).
2. **¿Por qué?** Porque resuelve los cuellos de botella de escalabilidad, garantiza la persistencia independiente de los datos (RF-4) y elimina despliegues manuales (RF-1).
3. **¿Qué alternativas fueron consideradas?** On-premise, Nube Híbrida permanente, VM-monolito (EC2 puro), Serverless total (Lambda+DynamoDB), y Contenedores orquestados (ECS/Fargate).
4. **¿Por qué se seleccionó la alternativa final?** ECS Fargate + RDS PostgreSQL + S3 + SQS en AWS equilibra agilidad, bajo costo operacional, desacoplamiento y portabilidad basada en Docker (RNF-5).
5. **¿Por qué AWS?** Por la madurez de sus servicios administrados, ecosistema de integración, compatibilidad total con Terraform y amplia adopción académica y profesional.
6. **¿Qué parte es agnóstica?** El diseño de topología de red de 3 capas, el empaquetado en contenedores Docker, la cola de mensajes estándar y la persistencia SQL.
7. **¿Qué parte depende de AWS?** Las implementaciones específicas de los servicios administrados (AWS ECS, RDS, S3, SQS, ALB, CloudWatch, IAM).
8. **¿Qué componentes deben migrarse?** La base de datos transaccional (catálogo y pedidos), las imágenes/activos estáticos de productos y la lógica de la aplicación web/API.
9. **¿Cómo se migrarán?** Mediante una migración progresiva en fases (Estrategia Rehost + Replatform / Containerize) con corte programado (*cutover*).
10. **¿Qué riesgos existen?** Inconsistencia de datos durante migración, sobrecostos por recursos mal dimensionados y *vendor lock-in* por servicios propietarios.
11. **¿Cómo se validará posteriormente?** A través de los Laboratorios Prácticos 1, 2, 3 y pruebas de falla/reemplazo controladas.

---

## 5. REQUERIMIENTOS DEL HITO 1 (FUENTE DE VERDAD)

Los requerimientos definidos formalmente por el Grupo 1 en el Hito 1 se mantienen intactos como la fuente inmutable de validación:

| ID | Tipo | Requerimiento | Criterio de Aceptación y Verificación | Responsable |
| :--- | :--- | :--- | :--- | :--- |
| **RF-1** | Funcional | El entorno de nube debe permitir la provisión y modificación de infraestructura mediante código para erradicar procesos manuales. | Mediante la ejecución exitosa de los comandos de despliegue automatizado (`terraform apply`), sin requerir clics en la consola web. | Luis Castrillón |
| **RF-2** | Funcional | El sistema del canal digital debe contar con un mecanismo de integración o mensajería para lograr el desacoplamiento de componentes. | A través de una prueba de comunicación asíncrona enviando y consumiendo mensajes desde una cola o bus de eventos. | Paulina Velásquez |
| **RF-3** | Funcional | La plataforma requiere un modelo de almacenamiento centralizado (archivos, objetos o bloques) para alojar la persistencia de datos. | Subiendo un recurso (ej. imagen de producto) y validando su acceso seguro en el repositorio de almacenamiento cloud. | Luis Castrillón |
| **RF-4** | Funcional | El sistema debe abstraer y separar el almacenamiento de datos (catálogo y pedidos) de los recursos de cómputo, permitiendo escalar ambos de forma independiente. | Apagando o destruyendo una unidad de cómputo y verificando que los datos de la base de datos persisten intactos. | Paulina Velásquez |
| **RF-5** | Funcional | El equipo de ingeniería debe contar con un sistema de control de versiones que almacene las plantillas de infraestructura como código (IaC). | Revisando el historial de commits en Git y validando que un cambio de infraestructura puede rastrearse hasta un autor específico. | Luis Castrillón |
| **RNF-1** | No Funcional | La topología de red y los servicios de cómputo deben estar segmentados para separar el tráfico público del privado. | Inspeccionando las tablas de ruteo y la configuración de subredes públicas y privadas en la nube. | Luis Castrillón |
| **RNF-2** | No Funcional | Los accesos y permisos a la infraestructura deben estar acotados siguiendo el principio de mínimo privilegio. | Mediante una auditoría de las políticas IAM (Identity and Access Management) asignadas a roles específicos. | Martín Valencia |
| **RNF-3** | No Funcional | El entorno operativo debe notificar anomalías basadas en umbrales de rendimiento. | Simulando una carga de trabajo alta o error que logre disparar de manera efectiva al menos una alarma configurada. | Martín Valencia |
| **RNF-4** | No Funcional | Todos los componentes aprovisionados deben contar con etiquetas (*tags*) para viabilizar el control y análisis financiero de la nube. | Revisando que los recursos desplegados tengan aplicadas etiquetas de categorización e identificando los *cost drivers*. | Alberto Cervantes |
| **RNF-5** | No Funcional | El diseño de la arquitectura debe priorizar el uso de tecnologías y contenedores estándar que faciliten la portabilidad de las cargas de trabajo (mitigando *vendor lock-in*). | Evaluando las decisiones de diseño mediante un análisis de trade-offs que justifique cómo se facilita la migración a otra plataforma. | Paulina Velásquez |
| **RNF-6** | No Funcional | Toda la información transaccional y de usuarios del canal digital debe estar protegida mediante cifrado, tanto en tránsito como en reposo. | Verificando que las conexiones exigen protocolos seguros (HTTPS/TLS) y que las bases de datos/almacenamiento tienen cifrado activado por defecto. | Martín Valencia |

---

## 6. CONTEXTO ACADÉMICO Y ALINEACIÓN CURRICULAR

El diseño del Hito 2 se fundamenta conceptualmente en las Unidades 1 y 2 del Plan Maestro del curso:

```
UNIDAD 1: Fundamentos y Arquitecturas Cloud
  ├── Cap 1: Fundamentos, modelos y gobierno (Analizado en Hito 2)
  └── Cap 2: Fundamentos de arquitectura cloud-native (Analizado en Hito 2)

UNIDAD 2: Infraestructura y Plataformas como Servicio
  ├── Cap 3: Cómputo y orquestación (Diseñado en Hito 2)
  ├── Cap 4: Almacenamiento, redes y conectividad (Diseñado en Hito 2)
  ├── Cap 5: Datos, integración y mensajería (Diseñado en Hito 2)
  └── Cap 6: Nube privada, híbrida y portabilidad (Analizado en Hito 2)

UNIDAD 3: Gestión y Optimización (Preparado arquitectónicamente)
  ├── Cap 7: Seguridad, identidad, gobierno (Mínimo privilegio conceptual en Hito 2 → Implementación Lab 3)
  ├── Cap 8: Observabilidad, rendimiento y FinOps (Métricas/Tags conceptuales en Hito 2 → Implementación Lab 3)
  └── Cap 9: Automatización, IaC y multi-cloud (Convenciones IaC en Hito 2 → Reto Terraform)
```

---

## 7. REGLA DE MADUREZ DEL HITO 2

Para garantizar el rigor académico y no presentar componentes teóricos como implementaciones realizadas, se aplica la siguiente clasificación explícita:

*   **[A] DECIDIDO EN HITO 2:** Selección de modelo de nube (100% Public Cloud AWS), topología de red de 3 capas, estrategia de contenedorización Docker, separación de persistencia RDS PostgreSQL, uso de SQS para desacoplamiento y modelo de migración por fases.
*   **[B] DISEÑADO PERO PENDIENTE DE IMPLEMENTACIÓN:** Parámetros exactos de VPC (`10.0.0.0/16`), Subnets públicas/privadas, ALB Target Groups, ECS Task Definitions, políticas IAM y alarmas CloudWatch.
*   **[C] PENDIENTE DE VALIDACIÓN:** Tasa exacta de transacciones por segundo (TPS), tamaño definitivo de la base de datos de producción, latencia de red bajo carga real.
*   **[D] RESERVADO PARA HITO 3 / HITO 4 / LABORATORIOS:** 
    *   *Laboratorio 1:* Aprovisionamiento de red (VPC, IGW, Subnets, Route Tables, Security Groups).
    *   *Laboratorio 2:* Despliegue de aplicación contenedorizada, ALB, Auto Scaling y SQS.
    *   *Laboratorio 3:* Gobierno de identidad (IAM), Cifrado KMS, métricas y alarmas CloudWatch.
    *   *Reto Terraform:* Codificación IaC modular de toda la infraestructura.
*   **[E] FUERA DE ALCANCE:** Procesamiento real de tarjetas de crédito/pagos PCI-DSS, arquitectura multi-región activo-activo, despliegue simultáneo multi-cloud en tiempo de ejecución.

---

## 8. CAPÍTULO 1 — ANÁLISIS DEL MODELO CLOUD

### 8.1 Comparación de Modelos de Servicio

| Modelo | Definición para Digital Café Luna | Evaluación de Ajuste al Proyecto | Decisión |
| :--- | :--- | :--- | :--- |
| **IaaS (Infrastructure as a Service)** | Aprovisionar Servidores Virtuales (EC2) y gestionar SO, parches y redes manualmente. | Exige alta carga operacional de mantenimiento para el equipo (parcheo de SO, configuración de clustering). | Usado únicamente para red base; descartado para base de datos y orquestación pura. |
| **PaaS / Serverless Containers** | Desplegar la aplicación en contenedores sobre una plataforma administrada (AWS ECS Fargate) y DB administrada (RDS). | **Ajuste Perfecto:** El equipo se enfoca en el código de la aplicación y la arquitectura, delegando la gestión del servidor físico y SO al proveedor cloud. | **SELECCIONADO** |
| **SaaS (Software as a Service)** | Consumir software listo (ej. Shopify). | No permite personalizar la lógica de negocio única de Café Luna ni cumple los objetivos académicos del curso. | Descartado. |
| **FaaS (Function as a Service)** | Refactorizar todo el monolito en funciones serverless (AWS Lambda). | Requiere reestructurar completamente el código del monolito actual, incrementando drásticamente el riesgo y tiempo de migración. | Descartado para el MVP. |

### 8.2 Comparación On-Premise vs. Híbrido vs. Public Cloud

```
+-----------------------------------------------------------------------------------+
|                     EVALUACIÓN DE MODELOS DE DESPLIEGUE                           |
+-----------------------------------------------------------------------------------+
| Criterio          | On-Premise (Actual)    | Nube Híbrida          | Public Cloud (AWS)   |
+-------------------+------------------------+-----------------------+----------------------+
| Costo Capital     | Alto (CAPEX elevado)   | Medio (CAPEX+OPEX)    | Bajo (100% OPEX)     |
| Escalabilidad     | Lenta (Semanas/Meses)  | Compleja de orquestar | Inmediata / Elástica |
| Operación         | Manual (Alto riesgo)   | Doble complejidad     | Automatizada (IaC)   |
| Mantenimiento HW  | Responsabilidad Luna   | Compartida            | Delegado a AWS       |
| Tiempo de Salida  | Lento                  | Medio                 | Rápido               |
+-----------------------------------------------------------------------------------+
```

---

## 9. CAPÍTULO 2 — EVALUACIÓN CLOUD-NATIVE Y ARQUITECTURA DE CÓMPUTO

### 9.1 Alternativas de Cómputo Analizadas

1.  **Máquina Virtual Pura (EC2 + Auto Scaling):**
    *   *Ventajas:* Migración inicial muy rápida (Rehost direct).
    *   *Desventajas:* Mantenimiento de imágenes AMI, parcheo de SO, arranque lento de instancias durante eventos de auto-scaling.
2.  **Contenedores Orquestados (AWS ECS + Fargate / Docker):**
    *   *Ventajas:* Despliegues estandarizados e inmutables, arranque en segundos, portabilidad total (RNF-5), cero gestión de servidores subyacentes.
    *   *Desventajas:* Ligera curva de aprendizaje en empaquetado Docker.
3.  **Kubernetes Administrado (AWS EKS):**
    *   *Ventajas:* Estándar de la industria para microservicios masivos.
    *   *Desventajas:* Alta complejidad operacional, plano de control costoso para un MVP de canal digital pequeño.
4.  **Serverless Functions (AWS Lambda):**
    *   *Ventajas:* Escala a cero, pago estricto por ejecución.
    *   *Desventajas:* Requiere reescritura del monolito, límites de tiempo de ejecución, riesgo de *cold starts*.

### 9.2 Matriz de Selección de Cómputo

| Criterio | EC2 + ASG | ECS Fargate | AWS EKS | AWS Lambda |
| :--- | :--- | :--- | :--- | :--- |
| **Complejidad Operativa** | Media | **Baja** | Muy Alta | Media (Reescritura) |
| **Portabilidad (RNF-5)** | Baja (AMIs) | **Alta (Docker)** | Alta (K8s) | Muy Baja (Vendor lock-in) |
| **Esfuerzo de Migración** | Bajo | **Medio-Bajo** | Alto | Muy Alto |
| **Costo Base MVP** | Medio | **Bajo (Pago por recurso usado)** | Alto ($0.10/hr solo cluster) | Muy Bajo |
| **Decisión Final** | Alternativa de Respaldo | **SELECCIONADO (Principal)** | Descartado | Descartado |

---

## 10. CAPÍTULO 4 — ARQUITECTURA DE RED Y SEGMENTACIÓN

El diseño de red garantiza la estricta separación de dominios de tráfico requerida por el **RNF-1**:

```
+--------------------------------------------------------------------------------------------------------+
|                                        AWS CLOUD (REGION)                                              |
|                                                                                                        |
|  VPC: 10.0.0.0/16                                                                                      |
|  +--------------------------------------------------------------------------------------------------+  |
|  |                                  INTERNET GATEWAY (IGW)                                          |  |
|  +--------------------------------------------------------------------------------------------------+  |
|                                                  |                                                     |
|                  +-------------------------------+-------------------------------+                     |
|                  |                                                               |                     |
|                  v                                                               v                     |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|  | AVAILABILITY ZONE A (us-east-1a)              |   | AVAILABILITY ZONE B (us-east-1b)              | |
|  |                                               |   |                                               | |
|  | [SUBNET PÚBLICA 1] (10.0.1.0/24)              |   | [SUBNET PÚBLICA 2] (10.0.2.0/24)              | |
|  |  - Application Load Balancer (ALB Node A)     |   |  - Application Load Balancer (ALB Node B)     | |
|  |  - NAT Gateway A                              |   |  - NAT Gateway B                              | |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|                  |                                                               |                     |
|                  v                                                               v                     |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|  | [SUBNET PRIVADA CÓMPUTO 1] (10.0.10.0/24)     |   | [SUBNET PRIVADA CÓMPUTO 2] (10.0.20.0/24)     | |
|  |  - ECS Tasks / App Containers                 |   |  - ECS Tasks / App Containers                 | |
|  |  - Worker Consumers (SQS)                     |   |  - Worker Consumers (SQS)                     | |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|                  |                                                               |                     |
|                  v                                                               v                     |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|  | [SUBNET PRIVADA DATOS 1] (10.0.100.0/24)      |   | [SUBNET PRIVADA DATOS 2] (10.0.200.0/24)      | |
|  |  - RDS PostgreSQL Primary                     |   |  - RDS PostgreSQL Standby (Multi-AZ)          | |
|  +-----------------------------------------------+   +-----------------------------------------------+ |
|                                                                                                        |
+--------------------------------------------------------------------------------------------------------+
```

### 10.1 Descripción de Componentes de Red
*   **VPC (Virtual Private Cloud):** Rango `10.0.0.0/16` (65,536 IP privadas disponibles).
*   **Zonas de Disponibilidad (AZs):** Implementación Multi-AZ en 2 zonas (`us-east-1a` y `us-east-1b`) para garantizar tolerancia a fallos a nivel de datacenter local.
*   **Subnets Públicas (`10.0.1.0/24` y `10.0.2.0/24`):** Albergan únicamente el Application Load Balancer (ALB) y los NAT Gateways. Tienen ruta directa al Internet Gateway (IGW).
*   **Subnets Privadas de Cómputo (`10.0.10.0/24` y `10.0.20.0/24`):** Albergan los contenedores de la aplicación (ECS Fargate). Sin direcciones IP públicas; el tráfico saliente a Internet (ej. para actualizar dependencias) pasa exclusivamente a través del NAT Gateway.
*   **Subnets Privadas de Datos (`10.0.100.0/24` y `10.0.200.0/24`):** Aislamiento total. Sin acceso directo a Internet ni rutas hacia el NAT Gateway. Accesibles exclusivamente desde la capa de cómputo privada vía Security Groups.

### 10.2 Distinción Clara entre Capas de Red
1.  **Routing (Tablas de Ruteo):** Define las vías de transporte IP (Subnet Pública → IGW; Subnet Privada → NAT Gateway; Subnet Datos → Tráfico Local VPC únicamente).
2.  **Seguridad Stateful (Security Groups):** Actúan como firewalls virtuales a nivel de instancia/ENI.
    *   `SG-ALB`: Permite HTTP (80) y HTTPS (443) desde `0.0.0.0/0`.
    *   `SG-App`: Permite tráfico en el puerto de la aplicación (ej. 8080) únicamente si proviene de `SG-ALB`.
    *   `SG-DB`: Permite tráfico en el puerto de PostgreSQL (5432) únicamente si proviene de `SG-App`.
3.  **Seguridad Stateless (NACL - Network Access Control Lists):** Actúan a nivel de frontera de subred como segunda línea de defensa en profundidad.
4.  **Subnetting:** Segmentación de bloques CIDR para impedir colisiones y limitar el dominio de broadcast.

---

## 11. CAPÍTULO 5 — CAPA DE DATOS Y MENSAJERÍA

### 11.1 Estrategia de Persistencia y Separación de Cómputo (RF-3, RF-4, RNF-6)

La persistencia se desacopla completamente del cómputo para cumplir con el **RF-4** (destrucción inofensiva de instancias de cómputo):

```
                                  +-----------------------+
                                  |     S3 BUCKET         |
                                  | Activos Estáticos e   |
                                  | Imágenes de Productos |
                                  +-----------------------+
                                              ^
                                              | (Archivos/Objetos - RF-3)
                                              |
+----------------------+         +-----------------------+         +-----------------------+
|  CAPA DE CÓMPUTO     |         |  CAPA DE PERSISTENCIA |         |   CAPA DE MENSAJERÍA  |
|  (ECS Fargate Tasks) |  -----> |  (RDS PostgreSQL)     |  -----> |   (AWS SQS Queue)     |
|  Sin estado local    |         |  Catálogo y Pedidos   |         |   Procesamiento       |
+----------------------+         +-----------------------+         |   Asíncrono           |
                                 - Multi-AZ              |         +-----------------------+
                                 - Encrypted at Rest     |
                                 - Subnet Privada Datos  |
                                 +-----------------------+
```

| Tipo de Dato | Servicio AWS | Justificación Técnica | Criterio de Selección |
| :--- | :--- | :--- | :--- |
| **Datos Transaccionales** (Catálogo, Pedidos, Usuarios) | **AWS RDS PostgreSQL** | Garantiza propiedades ACID, relaciones complejas entre tablas de pedidos y clientes, respaldos automáticos y cifrado KMS (RNF-6). | Separa los datos del cómputo (**RF-4**). |
| **Almacenamiento de Objetos** (Imágenes de productos, facturas PDF) | **AWS S3 (Simple Storage Service)** | Almacenamiento centralizado, altísima durabilidad (99.999999999%), costo extremadamente bajo por GB y soporte de cifrado SSE-S3. | Cumple el **RF-3**. |
| **Caché Temporal** *(Fase Futura)* | AWS ElastiCache (Redis) | Reducción de latencia de lectura en catálogo frecuente. | Reservado para Hito 3/4. |

### 11.2 Arquitectura de Mensajería y Desacoplamiento (RF-2)

Para evitar que un pico de pedidos colapse la aplicación o que fallas en procesos secundarios (ej. envío de correos de confirmación o actualización de inventario) afecten la experiencia del usuario, se implementa el patrón **Productor-Consumidor**:

```
+------------------+             +-------------------+             +-------------------+
|  API / PROCESO   |             |   COLA DE MENSAJES|             | WORKER CONSUMIDOR |
|  DE PEDIDOS      |  ---------> |     AWS SQS       |  ---------> | Procesamiento     |
|  (Productor)     |   Publica   | (Queue Estándar)  |   Consume   | Asíncrono         |
+------------------+   Evento    +-------------------+   Batch     +-------------------+
                                           |                                 |
                                           v (Fallo recurrente)              v
                                 +-------------------+             +-------------------+
                                 | DEAD LETTER QUEUE |             | Actualización BD/ |
                                 |     (DLQ SQS)     |             | Notificación      |
                                 +-------------------+             +-------------------+
```

**Beneficios del Patrón Seleccionado:**
1.  **Desacoplamiento Estructural (RF-2):** El cliente recibe confirmación inmediata de su pedido sin esperar a que se completen las integraciones secundarias.
2.  **Resiliencia ante Picos (Buffering):** Durante horas pico de ventas de café, los mensajes se acumulan en la cola SQS sin perder ningún pedido, permitiendo que los workers consuman al ritmo óptimo.
3.  **Manejo de Errores (DLQ):** Si un mensaje no se puede procesar tras 3 reintentos, se envía a una Dead Letter Queue (DLQ) para análisis posterior sin bloquear la cola principal.

---

## 12. CAPÍTULO 6 — DECISIÓN CLOUD Y ESTRATEGIA TARGET 100% AWS

### 12.1 Evaluación de Alternativas de Plataforma

```
+-------------------------------------------------------------------------------------+
|                     MATRIZ DE SELECCIÓN DE ARQUITECTURA TARGET                      |
+-------------------------------------------------------------------------------------+
| Opción                | Pro / Ventajas                | Contra / Riesgos            |
+-----------------------+-------------------------------+-----------------------------+
| A. On-Premise Final   | Control total físico          | Rigidez, despliegue manual, |
|                       |                               | alto costo fijo             |
| B. Híbrida Permanente | Mantiene inversiones previas  | Complejidad de red y costo  |
|                       |                               | operativo duplicado         |
| C. 100% AWS Cloud     | Escalabilidad total, IaC,     | Vendor lock-in mitigable    |
|    (Seleccionada)     | servicios administrados       | vía contenedores            |
+-------------------------------------------------------------------------------------+
```

### 12.2 Justificación de la Elección 100% AWS Cloud

Se selecciona **100% AWS Cloud** como estado objetivo porque no existe ninguna restricción legal, regulatoria o técnica que obligue a Digital Café Luna a mantener servidores locales. Mantener una infraestructura híbrida permanente añadiría una complejidad inaceptable para el tamaño actual del equipo de ingeniería.

**Reconocimiento Explícito de Vendor Lock-in y Mitigación (RNF-5):**
Se reconoce abiertamente que el uso de servicios administrados como AWS RDS, SQS y ALB introduce dependencia del proveedor (*vendor lock-in*). Para mitigar este riesgo sin perder la agilidad de los servicios administrados, se aplican las siguientes reglas de portabilidad:
*   La aplicación corre dentro de contenedores estandarizados **Docker**, ejecutables en cualquier nube o entorno local.
*   La base de datos utiliza el motor SQL estándar **PostgreSQL**, permitiendo la exportación e importación directa a otros proveedores.
*   Toda la infraestructura se define mediante **Terraform**, facilitando la recreación de entornos equivalentes en otras plataformas si fuera necesario.

---

## 13. ARQUITECTURA AGNÓSTICA VS. MAPEO EN AWS

### 13.1 Diagrama 1: Arquitectura Agnóstica del Proveedor

```
[ USUARIOS / CLIENTES DIGITALES ]
               │
               ▼
   [ PUNTO DE ENTRADA / DNS ]
               │
               ▼
    [ BALANCEADOR DE CARGA ]
               │
       ┌───────┴───────┐
       ▼               ▼
[ CAPA DE CÓMPUTO ] [ CAPA DE CÓMPUTO ]  <--- (Escalamiento Horizontal)
  (Instancia A)       (Instancia B)
       │                   │
       ├───────────────────┼───────────────────┐
       ▼                   ▼                   ▼
[ PERSISTENCIA SQL ] [ ARCHIVOS/OBJETOS ] [ COLA DE MENSAJES ]
 (Datos Separados)    (Catálogo/Imágenes)   (Desacoplamiento)
```

### 13.2 Diagrama 2: Mapeo de Servicios Nativos AWS

```
[ USUARIOS DIGITALES EN INTERNET ]
               │
               ▼
       [ AWS Route 53 ]
               │
               ▼
[ AWS Application Load Balancer (ALB) ]
               │
       ┌───────┴───────┐
       ▼               ▼
[ AWS ECS Fargate ] [ AWS ECS Fargate ]  <--- (Auto Scaling Group / Tasks)
  (Task Task-A)       (Task Task-B)
       │                   │
       ├───────────────────┼───────────────────┐
       ▼                   ▼                   ▼
[ AWS RDS PostgreSQL ]  [ AWS S3 Bucket ]   [ AWS SQS Queue ]
 (Multi-AZ Encrypted)   (Cifrado SSE-S3)     (Cola Estándar + DLQ)
```

### 13.3 Tabla de Mapeo Agnóstico a AWS

| Componente Agnóstico | Servicio AWS Seleccionado | Justificación de la Elección | Requerimiento Vinculado |
| :--- | :--- | :--- | :--- |
| Punto de Entrada / DNS | AWS Route 53 | Enrutamiento de alto rendimiento y comprobación de salud. | RNF-1 |
| Balanceador de Carga | AWS Application Load Balancer (ALB) | Soporte L7, integración con Target Groups de ECS y SSL termination. | RNF-1, RNF-6 |
| Cómputo Escalable | AWS ECS con Fargate | Orquestación de contenedores Serverless inmutables. | RNF-5, RF-4 |
| Persistencia Relacional | AWS RDS (PostgreSQL) | Motor relacional administrado, backups, Multi-AZ y cifrado. | RF-4, RNF-6 |
| Almacenamiento Objetos | AWS S3 (Simple Storage) | Repositorio centralizado para activos de productos y respaldos. | RF-3, RNF-6 |
| Cola de Mensajería | AWS SQS (Simple Queue Service) | Mensajería fully-managed para procesamiento asíncrono. | RF-2 |
| Observabilidad | AWS CloudWatch | Captura de logs, métricas y emisión de alarmas de rendimiento. | RNF-3 |
| Gestión de Identidad | AWS IAM (Roles y Políticas) | Control de acceso basado en mínimo privilegio. | RNF-2 |
| Control Financiero | AWS Cost Explorer & Budgets | Etiquetado (*tagging*) e imputación de costos. | RNF-4 |
| Infraestructura Código | HashiCorp Terraform | Plantillas reproducibles y control de versiones. | RF-1, RF-5 |

---

## 14. CORRECCIÓN Y EVOLUCIÓN DEL DIAGRAMA BORRADOR INICIAL

El diagrama preliminar entregado por el equipo contenía inconsistencias conceptuales comunes en etapas tempranas. La siguiente matriz justifica las correcciones aplicadas en el diseño final del Hito 2:

| Componente | Estado en Diagrama Borrador | Corrección Aplicada en Hito 2 | Justificación Técnica | Requerimiento |
| :--- | :--- | :--- | :--- | :--- |
| **ALB** | Dibujado dentro de una sola subnet privada. | Ubicado a través de **dos Subnets Públicas** en AZs distintas. | Un balanceador público debe ser alcanzable desde Internet y distribuir tráfico a múltiples AZs. | RNF-1 |
| **Cómputo** | Dos servidores EC2 estáticos con IPs fijas. | **ECS Fargate Task Set** gestionado por un Auto Scaling Group. | Elimina instancias únicas (*pets*), garantizando reemplazo automático inofensivo. | RF-4, RNF-5 |
| **Persistencia** | Base de datos instalada localmente en la misma EC2. | **AWS RDS PostgreSQL** en subnets de datos privadas aisladas. | Separa la persistencia del cómputo para permitir escalado independiente. | RF-4 |
| **Routing** | Route Table representada como un bloque de aplicación. | Route Table configurada como el **mecanismo de enrutamiento del VPC**. | Aclara que el ruteo es una capacidad de red y no un servicio de software. | RNF-1 |
| **NACL** | Representada como un filtro entre el ALB y la EC2. | Definida como el **firewall de frontera de Subred** (stateless). | Corrección del modelo OSI/Cloud; Security Groups filtran la ENI, NACL filtra la subnet. | RNF-1 |
| **Mensajería** | Ausente en el borrador inicial. | Incorporación de **AWS SQS** entre la API y los Workers de procesamiento. | Permite el desacoplamiento asíncrono solicitado por el negocio. | RF-2 |

---

## 15. CAPÍTULO 7 — PRINCIPIOS DE SEGURIDAD Y CUMPLIMIENTO (CONCEPTUAL)

Aunque la implementación detallada de IAM se ejecutará en el Laboratorio 3, el Hito 2 establece los principios rectores de arquitectura de seguridad:

1.  **Principio de Mínimo Privilegio (RNF-2):**
    *   Ningún componente ni usuario operativo poseerá permisos universales (`AdministratorAccess`).
    *   Los contenedores de ECS asumirán un **IAM Task Role** acotado exclusivamente a leer el S3 Bucket específico del proyecto y escribir mensajes en la cola SQS.
2.  **Defensa en Profundidad (Segmentación de Red):**
    *   Acceso público limitado al ALB. Las instancias de base de datos no poseen direcciones IP públicas ni rutas de acceso desde Internet.
3.  **Cifrado Ubicuo (RNF-6):**
    *   *En Tránsito:* Todo el tráfico HTTP externo se redirige obligatoriamente a HTTPS (TLS 1.3). La comunicación interna VPC entre ALB y ECS utiliza canales cifrados.
    *   *En Repositorio (At Rest):* Volúmenes RDS PostgreSQL y Buckets S3 cifrados por defecto mediante llaves **AWS KMS (Key Management Service)**.
4.  **Gestión de Secretos:**
    *   Prohibición absoluta de credenciales estáticas o contraseñas en código fuente. Las credenciales de la base de datos se inyectarán en tiempo de ejecución desde **AWS Secrets Manager** o Parameter Store.

---

## 16. CAPÍTULO 8 — OBSERVABILIDAD Y FINOPS (CONCEPTUAL)

### 16.1 Estrategia de Observabilidad (RNF-3)
*   **Logs Centralizados:** Recolección automática de stdout/stderr de los contenedores Docker mediante el driver `awslogs` enviado a **AWS CloudWatch Logs**.
*   **Métricas de Rendimiento:** Monitoreo continuo de uso de CPU, Memoria, recuento de peticiones en el ALB y longitud de mensajes en la cola SQS.
*   **Alarma Configurante (Criterio RNF-3):** Creación de una alarma CloudWatch que notifica cuando la utilización de CPU del grupo de contenedores supera el **75% durante 5 minutos**, o cuando la cantidad de mensajes en la DLQ de SQS sea mayor a 0.

### 16.2 Estrategia FinOps y Gobierno Financiero (RNF-4)
*   **Cost Drivers Identificados:** 
    1. Base de datos administrada (RDS PostgreSQL Multi-AZ).
    2. Cómputo (ECS Fargate vCPU / RAM horas).
    3. Balanceador de Carga (ALB + LCU horas).
*   **Estrategia de Etiquetado Obligatorio (*Tagging Policy*):**
    ```hcl
    tags = {
      Project     = "DigitalCafeLuna"
      Environment = "MVP-Development"
      Owner       = "Grupo1"
      ManagedBy   = "Terraform"
      CostCenter  = "Academico-EAFIT"
    }
    ```
*   **Presupuesto y Alerta de Control:** Configuración de un **AWS Budget** con un umbral de gasto de $20 USD/mes, emitiendo una alerta por correo electrónico si el gasto proyectado supera el 80%.

---

## 17. CAPÍTULO 9 — ESTRATEGIA DE INFRAESTRUCTURA COMO CÓDIGO (IaC)

En cumplimiento de los requerimientos **RF-1** y **RF-5**, se define la estructura estandarizada del código Terraform que se implementará formalmente en las siguientes fases:

### 17.1 Convención de Módulos y Código
```
terraform/
├── main.tf                 # Declaración de proveedores y módulos
├── variables.tf            # Variables globales (region, env, tags)
├── outputs.tf              # Salidas clave (ALB DNS, RDS Endpoint)
├── terraform.tfvars        # Valores de variables por entorno
└── modules/
    ├── vpc/                # Módulo de Red (Subnets, IGW, NAT, Routes)
    ├── security/           # Módulo de Security Groups y NACLs
    ├── compute/            # Módulo ECS Fargate, Task Definitions, ASG
    ├── database/           # Módulo RDS PostgreSQL
    └── storage/            # Módulo S3 y SQS
```

---

## 18. ESTRATEGIA DE MIGRACIÓN

### 18.1 Diagrama del Proceso de Migración

```
+------------------+
|   ESTADO ACTUAL  |
| Monolito On-Prem |
+------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 1: ANÁLISIS E INVENTARIO                                          |
| - Identificación de volumen de datos, esquemas BD y dependencias        |
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 2: PREPARACIÓN Y CONTAINERIZACIÓN                                  |
| - Empaquetado del monolito en imagen Docker                             |
| - Creación de infraestructura AWS vía Terraform (Red, RDS, S3, SQS)     |
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 3: MIGRACIÓN DE DATOS (MIGRACIÓN INICIAL Y PRUEBAS)                |
| - Dump / Restore inicial de base de datos a RDS                         |
| - Sincronización de imágenes de productos a AWS S3                      |
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 4: STAGING Y VALIDACIÓN                                            |
| - Ejecución de pruebas funcionales y de carga en entorno AWS            |
| - Pruebas de persistencia destruyendo tareas ECS (Validación RF-4)      |
+-------------------------------------------------------------------------+
         │
         ▼
+-------------------------------------------------------------------------+
| FASE 5: CUTOVER (CAMBIO DE TRÁFICO PROGRAMADO)                          |
| - Ventana de mantenimiento de bajo tráfico (ej. 02:00 AM)               |
| - Sincronización final de datos delta                                   |
| - Actualización de DNS en Route 53 apuntando al ALB                     |
+-------------------------------------------------------------------------+
         │
         ▼
+------------------+
|  ESTADO OBJETIVO |
| 100% AWS Cloud   |
+------------------+
```

### 18.2 Estrategia de Migración de Datos Paso a Paso

1.  **Inventario y Clasificación:** Identificación de las tablas de base de datos relacional (usuarios, catálogo, pedidos) y archivos estáticos locales.
2.  **Resguardo / Backup Previo:** Generación de una copia de seguridad consistente (`pg_dump`) del motor on-premise antes de cualquier movimiento.
3.  **Copia Inicial y Carga:** Transferencia segura de la imagen del dump hacia AWS S3 y restauración en la instancia RDS PostgreSQL mediante scripts SSL.
4.  **Carga de Objetos:** Sincronización masiva de carpetas de imágenes hacia el Bucket S3 usando AWS CLI (`aws s3 sync`).
5.  **Validación de Integridad:** Verificación del recuento de registros (*row count*) y *checksums* de archivos entre el origen on-premise y el destino en AWS.
6.  **Cutover y Conmutación:** Cambio del apuntamiento DNS.
7.  **Plan de Reversión (Rollback Strategy):** En caso de falla crítica en los primeros 60 minutos del cutover, se revierte el registro DNS al servidor on-premise original, el cual permanece en modo lectura durante la ventana de migración.

---

## 19. MATRIZ DE DECISIONES ARQUITECTÓNICAS (D01 - D14)

| ID | Tema | Problema | Requerimiento | Alternativas | Decisión Seleccionada | Justificación Técnica | Trade-off / Limitación | Validación Futura |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **D01** | Modelo Cloud | Infraestructura física rígida. | General | On-premise, Híbrido, Public Cloud | **Public Cloud (AWS)** | Máxima agilidad, eliminación de mantenimiento HW y escalabilidad. | Dependencia de conexión a Internet. | Lab 1 |
| **D02** | Proveedor | Necesidad de plataforma madura. | RNF-5 | AWS, Azure, GCP | **AWS** | Amplia adopción, madurez en IaC y encaje curricular. | Introducción de vendor lock-in en servicios administrados. | Reto Terraform |
| **D03** | Cómputo | Despliegue manual e ineficiente. | RF-1, RNF-5 | EC2, ECS Fargate, EKS, Lambda | **ECS Fargate** | Contenedores Serverless inmutables, cero gestión de SO, portabilidad Docker. | Ligera curva de empaquetado inicial. | Lab 2 |
| **D04** | Redes | Tráfico no segmentado. | RNF-1 | Monolítico, Subnets aisladas | **VPC 3-Capas Multi-AZ** | Aislamiento estricto de componentes públicos, cómputo y datos. | Costo adicional de NAT Gateways. | Lab 1 |
| **D05** | Balanceo | Single point of failure de red. | RNF-1 | Sin LB, ALB, NLB | **Application LB (ALB)** | Balanceo L7, enrutamiento por rutas y terminación SSL/TLS. | Costo por LCU procesada. | Lab 2 |
| **D06** | Escalamiento | Caídas en picos de demanda. | RF-4 | Escala Manual, Auto Scaling | **ECS Target Tracking ASG** | Escalamiento dinámico automático basado en CPU/RAM. | Posible tiempo de warm-up de tareas. | Lab 2 |
| **D07** | Persistencia | Base de datos acoplada al cómputo. | RF-4, RNF-6 | BD local en VM, AWS RDS | **AWS RDS PostgreSQL** | Desacoplamiento total, backups automáticos, cifrado KMS, Multi-AZ. | Costo mensual fijo de la instancia RDS. | Pruebas de Apagado Cómputo |
| **D08** | Objetos | Archivos locales no compartidos. | RF-3, RNF-6 | EBS local, EFS, AWS S3 | **AWS S3** | Almacenamiento centralizado ilimitado, durabilidad 99.999999999%. | Consistencia eventual en ciertas operaciones. | Lab 1 / Subida Recurso |
| **D09** | Mensajería | Acoplamiento síncrono de procesos. | RF-2 | REST síncrono, RabbitMQ, SQS | **AWS SQS** | Cola administrada sin servidores, reintentos y Dead Letter Queue. | Procesamiento asíncrono requiere manejo eventual. | Lab 2 / Prueba Mensaje |
| **D10** | Portabilidad | Riesgo de atadura al proveedor. | RNF-5 | Propietario puro, Estándar abierto | **Contenedores Docker + SQL** | Permite migrar las cargas a cualquier otra nube o entorno local. | Ligera pérdida de funciones 100% nativas. | Análisis Trade-offs |
| **D11** | Seguridad | Exposición de permisos globales. | RNF-2 | Credenciales fijas, IAM Roles | **IAM Roles acotados** | Garantiza el principio de mínimo privilegio estricto por componente. | Gestión cuidadosa de políticas JSON. | Lab 3 / Auditoría IAM |
| **D12** | Observabilidad| Cero visibilidad de errores. | RNF-3 | Logs locales, AWS CloudWatch | **CloudWatch Logs & Alarms** | Centralización de métricas y notificaciones automáticas ante anomalías. | Costo de retención de logs a largo plazo. | Lab 3 / Simulación Carga |
| **D13** | FinOps | Descontrol de gastos cloud. | RNF-4 | Sin etiquetas, Tagging Policy | **Tags obligatorios + Budgets** | Permite rastrear *cost drivers* e imputar costos por proyecto. | Disciplina operativa en el código IaC. | Lab 3 / Budget Alert |
| **D14** | IaC | Despliegues manuales por consola. | RF-1, RF-5 | Consola Web, Scripts Bash, Terraform | **HashiCorp Terraform** | Plantillas declarativas, versionables y reproducibles. | Gestión del estado (`terraform.tfstate`). | Reto Terraform |

---

## 20. MATRIZ DE TRAZABILIDAD COMPLETA

```
PROBLEMA DE NEGOCIO (Hito 1)
   │
   ▼
OBJETIVO ESTRATÉGICO
   │
   ▼
REQUERIMIENTO (RF/RNF)
   │
   ▼
DECISIÓN ARQUITECTÓNICA (Hito 2)
   │
   ▼
COMPONENTE AGNÓSTICO
   │
   ▼
SERVICIO AWS SELECCIONADO
   │
   ▼
EVIDENCIA Y VALIDACIÓN FUTURA (Laboratorios)
```

| Problema Hito 1 | Objetivo | Requerimiento | Decisión | Componente Agnóstico | Servicio AWS | Evidencia Futura de Cumplimiento |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Despliegues manuales propenso a errores. | Automatizar la infraestructura. | **RF-1** | D14 (IaC) | Plantillas IaC | Terraform | Ejecución limpia de `terraform apply` sin toques manuales en consola. |
| Acoplamiento síncrono de componentes. | Desacoplar la aplicación. | **RF-2** | D09 (Mensajería) | Cola de Mensajes | AWS SQS | Prueba de envío y consumo asíncrono verificado en la cola. |
| Falta de repositorio de archivos estáticos. | Centralizar almacenamiento. | **RF-3** | D08 (Objetos) | Almacenamiento Objetos | AWS S3 | Carga de archivo a S3 y verificación de URL de acceso seguro. |
| Pérdida de datos al reiniciar cómputo. | Separar datos de cómputo. | **RF-4** | D07 (Persistencia) | Base de Datos Relacional | AWS RDS PostgreSQL | Destrucción de la tarea ECS y comprobación de datos intactos en RDS. |
| Descontrol de cambios de infraestructura. | Versionar arquitectura. | **RF-5** | D14 (IaC) | Control de Versiones | Git + Terraform | Historial de commits auditables vinculados a autores. |
| Tráfico expuesto sin segmentación. | Segmentar la red. | **RNF-1** | D04 (Redes) | Red Segmentada | VPC Subnets Púb/Priv | Inspección de Route Tables y rangos IP en consola o CLI. |
| Accesos globales inseguros. | Mínimo privilegio. | **RNF-2** | D11 (Seguridad) | Gobierno de Identidad | AWS IAM Roles | Auditoría de políticas IAM acotadas asignadas a las tareas. |
| Cero alertas ante caídas. | Notificar anomalías. | **RNF-3** | D12 (Observabilidad)| Alertas de Rendimiento | CloudWatch Alarms | Simulación de carga que dispara una alerta de correo/evento. |
| Imposibilidad de saber los costos. | Gobierno financiero. | **RNF-4** | D13 (FinOps) | Etiquetado Financiero | AWS Cost Allocation Tags | Reporte en Cost Explorer filtrado por las etiquetas obligatorias. |
| Atadura a un único proveedor. | Portabilidad de carga. | **RNF-5** | D03 / D10 | Contenedores Estándar | Docker en ECS | Contenedor ejecutable localmente mediante `docker run`. |
| Tráfico y datos sin encriptar. | Cifrado total. | **RNF-6** | D07 / D08 / D11 | Cifrado en Reposo/Tránsito| TLS 1.3 + AWS KMS | Verificación de HTTPS en navegador y flag `Encrypted: true` en RDS/S3. |

---

## 21. MATRIZ DE RIESGOS Y MITIGACIÓN

| Riesgo Identificado | Impacto | Probabilidad | Estrategia de Mitigación | Evidencia de Validación |
| :--- | :--- | :--- | :--- | :--- |
| **Inconsistencia de datos durante el cutover de migración.** | Alto | Media | Ejecutar respaldos previos, aplicar ventana de mantenimiento nocturna y realizar verificación de *checksums* post-migración. | Reporte de coincidencia de registros (*row count*) origen vs. destino. |
| **Sobrecostos inesperados en AWS por recursos olvidados.** | Medio | Alta | Configurar políticas de etiquetado obligatorio (**RNF-4**), alertas de presupuestos (AWS Budgets) y scripts automáticos de *cleanup*. | Notificación recibida antes de superar los $20 USD de presupuesto. |
| **Dependencia excesiva (*Vendor Lock-in*) de AWS.** | Medio | Media | Priorizar el empaquetado Docker (**RNF-5**) y sintaxis SQL estándar, desacoplando la lógica de negocio de APIs propietarias. | Despliegue funcional de la misma imagen Docker en entorno local. |
| **Falla en el servicio administrado RDS o degradación de AZ.** | Alto | Baja | Configuración Multi-AZ en RDS para conmutación por error (*failover*) automática e ininterrumpida. | Prueba de failover simulado en RDS pasando a la instancia Standby. |
| **Vulnerabilidades por exposición no deseada de puertos de BD.** | Alto | Baja | Isolation total de las subnets de base de datos sin Internet Gateway y Security Groups permitiendo tráfico solo desde `SG-App`. | Test de escaneo de puertos (nmap) confirmando puerto 5432 inaccesible públicamente. |

---

## 22. MATRIZ DE SUPUESTOS

### 22.1 Supuestos Confirmados
*   El equipo cuenta con los accesos requeridos a AWS Academy / AWS Console para desplegar los recursos dentro de los límites asignados.
*   El código de la aplicación monolítica del canal digital es empaquetable mediante un `Dockerfile` estándar.

### 22.2 Supuestos Arquitectónicos
*   Se asume que dos Zonas de Disponibilidad (Multi-AZ local) ofrecen el nivel de disponibilidad exigido para la etapa de MVP.
*   Se asume que la base de datos PostgreSQL soporta la carga esperada del canal digital sin requerir fragmentación (*sharding*).

### 22.3 Pendientes de Validación (No Inventados)
*   *Pendiente de Validación:* El volumen exacto en Gigabytes de la base de datos histórica de producción.
*   *Pendiente de Validación:* El número máximo de usuarios concurrentes en la hora pico de ventas del canal digital.
*   *Pendiente de Validación:* Los requerimientos específicos de latencia (SLA en milisegundos) del cliente final.

---

## 23. RELACIÓN CON LABORATORIOS PRÁCTICOS Y PLAN HITOS 3/4

El Hito 2 sirve como el plano director (*blueprint*) que guía el trabajo práctico futuro del curso:

```
+-----------------------------------------------------------------------------------+
|                        HOJA DE RUTA DE IMPLEMENTACIÓN                             |
+-----------------------------------------------------------------------------------+
| HITO 2: Arquitectura y Migración (Diseño y Blueprint Definitivo - Actual)         |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| LABORATORIO 1: Infraestructura Base (Despliegue de Red y Seguridad)               |
| - Evidencia: VPC, 6 Subnets, IGW, NAT Gateways, Route Tables y Security Groups.   |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| LABORATORIO 2: Aplicación Desacoplada (Despliegue de Cómputo y Persistencia)     |
| - Evidencia: ALB, Target Groups, Cluster ECS Fargate, RDS PostgreSQL y SQS.       |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| LABORATORIO 3: Operación Segura y Observable (Seguridad y Gobierno)               |
| - Evidencia: Roles IAM Mínimo Privilegio, KMS Encryption, CloudWatch Alarms.      |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| RETO TERRAFORM / HITOS 3 y 4: Implementación IaC, Operación y Defensa Final       |
| - Evidencia: Código IaC modular, ejecución `terraform apply/destroy` y sustentación|
+-----------------------------------------------------------------------------------+
```

---

## 24. CONCLUSIONES

1.  **Cadena de Razonamiento Defendible:** El diseño presentado demuestra formalmente que cada componente elegido en AWS responde directamente a un requerimiento de negocio o técnico derivado del Hito 1, erradicando la inclusión arbitraria de tecnologías.
2.  **Modernización Equilibrada:** La adopción de contenedores sobre **AWS ECS Fargate** en combinación con **AWS RDS** ofrece el balance perfecto entre modernización cloud-native, bajo esfuerzo operacional y mitigación del *vendor lock-in* mediante estándares abiertos (Docker, SQL).
3.  **Cumplimiento de Seguridad y Gobierno:** La arquitectura garantiza la segmentación de red en 3 capas (**RNF-1**), el cifrado ubicuo de información (**RNF-6**), la asignación de permisos bajo mínimo privilegio (**RNF-2**) y la observabilidad con gobierno financiero (**RNF-3**, **RNF-4**).

---

## 25. PRÓXIMOS PASOS RECOMENDADOS

1.  **Aprobación del Blueprint:** Presentar esta arquitectura a la dirección técnica y académica para obtener la validación definitiva del Hito 2.
2.  **Construcción del Dockerfile Base:** Empaquetar y probar localmente la aplicación del canal digital para verificar las variables de entorno de conexión a base de datos y SQS.
3.  **Fase Práctica Lab 1:** Iniciar la codificación de las plantillas Terraform para la infraestructura de red en la VPC de AWS.

---
*Fin del Blueprint Hito 2 — Digital Café Luna (Grupo 1)*
