# Botica MARFARMA — Sistema de Gestión & Data Warehouse (Desafío DataSalud)

![SQL Server](https://img.shields.io/badge/SQL%20Server-2019%2B-CC292B?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-Database%20Engine-0078D4?style=for-the-badge)
![Modelado](https://img.shields.io/badge/Architecture-Kimball%20Star%20Schema-green?style=for-the-badge)
![Compliance](https://img.shields.io/badge/Compliance-Ley%20N.%C2%BA%2029733%20(Per%C3%BA)-blue?style=for-the-badge)

---

## Descripción del Proyecto

Este repositorio contiene la arquitectura, diseño dimensional y scripts de implementación para la base de datos de **Botica MARFARMA**, desarrollado en el marco del **Desafío DataSalud** como proyecto integrador.

El sistema está diseñado para resolver la necesidad de consolidación, integridad analítica y monitoreo transaccional en farmacias/boticas comerciales, integrando:
1. **Modelado Dimensional para BI:** Esquema en Estrella (*Star Schema*) basado en la metodología **Kimball (Bottom-Up)** para explotación en tableros de Business Intelligence y reportería de morbilidad.
2. **Seguridad y Trazabilidad:** Cumplimiento de la **Ley N.º 29733 (Ley de Protección de Datos Personales del Perú)** con segregación estricta de funciones y auditoría automática de transacciones.
3. **Automatización y Reglas de Negocio:** Procedimientos almacenados robustos con transaccionalidad ACID (`TRY/CATCH`), triggers de auditoría DML, disparadores de integridad temporal y funciones de clasificación de riesgos para salud pública.

---

## 📐 Modelo Dimensional (Esquema Estrella - Metodología Kimball)

El repositorio implementa un modelo en estrella optimizado para consultas analíticas de alto rendimiento, análisis de morbilidad por grupo etario y métricas financieras de venta y servicios (e.g., transacciones de Agente BCP vs. Medicamentos).

```
                      +-------------------+
                      |    Dim_Tiempo     |
                      +-------------------+
                      | PK  DateKey       |
                      |     Fecha         |
                      |     Anio          |
                      |     Mes           |
                      |     Dia           |
                      |     NombreMes     |
                      +---------+---------+
                                |
                                | 1:N
                                v
+------------------+  1:N   +---------------------------+   N:1   +--------------------+
|   Dim_Cliente    +------->+     Fact_Transacciones    +<--------+    Dim_Producto    |
+------------------+        +---------------------------+         +--------------------+
| PK  ClienteKey   |        | PK  TransaccionKey        |         | PK  ProductoKey    |
|     Nombre_Comp. |        |     ID_Transaccion_Orig.  |         |     Nombre_Producto|
|     Grupo_Etario |        | FK  DateKey               |         |     Tipo_Producto  |
+------------------+        | FK  ClienteKey            |         |     Es_Medicamento |
                            | FK  ProductoKey           |         |     Es_Agente_BCP  |
                            | FK  SedeKey               |         +--------------------+
                            |     Cantidad              |
                            |     Monto_Estimado        |
                            +-------------+-------------+
                                          ^
                                          | 1:N
                                          |
                                +---------+---------+
                                |     Dim_Sede      |
                                +-------------------+
                                | PK  SedeKey       |
                                |     Nombre_Sede   |
                                +-------------------+
```

---

## Diccionario de Datos

### 1. Dimensiones

| Tabla | Atributo | Tipo de Dato | Clave / Restricción | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| **`Dim_Tiempo`** | `DateKey` | `INT` | **PK** | Llave subrogada de fecha en formato numérico (e.g., `YYYYMMDD`). |
| | `Fecha` | `DATE` | NOT NULL | Fecha calendaria de la transacción. |
| | `Anio` | `INT` | NOT NULL | Año de la operación. |
| | `Mes` | `INT` | NOT NULL | Mes numérico (1 - 12). |
| | `Dia` | `INT` | NOT NULL | Día del mes (1 - 31). |
| | `NombreMes`| `VARCHAR(20)` | NOT NULL | Nombre legible del mes en español. |
| **`Dim_Cliente`**| `ClienteKey` | `INT` | **PK (IDENTITY)** | Identificador único dimensional del cliente. |
| | `Nombre_Completo` | `VARCHAR(150)` | NOT NULL | Nombres y apellidos anonimizados / registrados. |
| | `Grupo_Etario` | `VARCHAR(50)` | NULL | Clasificación poblacional (e.g., `Niño (0-11)`, `Adulto Mayor (60+)`). |
| **`Dim_Producto`**| `ProductoKey` | `INT` | **PK (IDENTITY)** | Identificador único del catálogo. |
| | `Nombre_Producto` | `VARCHAR(150)` | NOT NULL | Denominación comercial o genérica del ítem. |
| | `Tipo_Producto` | `VARCHAR(50)` | NOT NULL | Clasificación operativa (Farmacia, Cuidado personal, Servicio). |
| | `Es_Medicamento` | `VARCHAR(2)` | `SI` / `NO` | Indicador de control para auditoría farmacológica. |
| | `Es_Agente_BCP` | `VARCHAR(2)` | `SI` / `NO` | Indicador si la operación corresponde a transacciones de agente bancario. |
| **`Dim_Sede`** | `SedeKey` | `INT` | **PK (IDENTITY)** | Identificador único del establecimiento físico. |
| | `Nombre_Sede` | `VARCHAR(100)` | NOT NULL | Nombre comercial o ubicación de la botica. |

### 2. Tabla de Hechos (`Fact_Transacciones`)

| Atributo | Tipo de Dato | Rol | Descripción |
| :--- | :--- | :--- | :--- |
| `TransaccionKey` | `INT` | **PK (IDENTITY)** | Identificador sustituto propio del Data Warehouse. |
| `ID_Transaccion_Original` | `VARCHAR(20)` | Atributo Degenerado | Código original del ticket/boleta del sistema OLTP transaccional. |
| `DateKey` | `INT` | **FK** | Referencia a `Dim_Tiempo(DateKey)`. |
| `ClienteKey` | `INT` | **FK** | Referencia a `Dim_Cliente(ClienteKey)`. |
| `ProductoKey` | `INT` | **FK** | Referencia a `Dim_Producto(ProductoKey)`. |
| `SedeKey` | `INT` | **FK** | Referencia a `Dim_Sede(SedeKey)`. |
| `Cantidad` | `INT` | Métrica Aditiva | Número de unidades vendidas u operaciones procesadas (default `1`). |
| `Monto_Estimado` | `DECIMAL(10,2)` | Métrica Aditiva | Importe monetario de la operación para reportería financiera. |

### 3. Tabla de Auditoría (`Auditoria_Log`)

| Atributo | Tipo de Dato | Descripción |
| :--- | :--- | :--- |
| `ID_Log` | `INT` (PK, IDENTITY) | Secuencial único del registro de auditoría. |
| `Tabla_Afectada` | `VARCHAR(50)` | Nombre de la entidad donde se realizó la operación o se originó el evento. |
| `Accion` | `VARCHAR(50)` | Operación efectuada (`INSERT`, `UPDATE`, `DELETE`, `ERROR_SP`). |
| `Usuario_DB` | `VARCHAR(100)` | Cuenta de base de datos o sistema que ejecutó la instrucción (`SYSTEM_USER`). |
| `Fecha_Hora` | `DATETIME` | Timestamp del evento en el servidor (`GETDATE()`). |
| `Detalles` | `NVARCHAR(MAX)` | Descripción del cambio o mensaje capturado en el bloque `CATCH`. |

---

## Seguridad y Cumplimiento Normativo (Ley N.º 29733)

El diseño incorpora medidas de seguridad lógica exigidas por la **Ley N.º 29733** (Ley de Protección de Datos Personales en el Perú) y las directivas del sector salud:

1. **Segregación de Roles (Principle of Least Privilege):**
   * `Rol_Administrador_Datos`: Gestión DDL/DML total de la infraestructura de base de datos.
   * `Rol_Analista_BI`: Acceso restringido de solo lectura (`SELECT`) a las vistas y dimensiones analíticas sin privilegios de modificación sobre datos sensibles.
   * `Rol_Auditor_Seguridad`: Supervisión exclusiva de los registros de `Auditoria_Log` y verificación de integridad.
2. **Trazabilidad y No Repudio:** Cada alteración DML sobre la tabla de hechos queda registrada de forma inmutable a través de triggers del motor.
3. **Manejo Seguro de Excepciones:** Los procedimientos almacenados capturan los fallos en tiempo de ejecución, evitando la exposición de cadenas de error sensibles y persistiendo los logs de falla con severidad controlada.

---

## ⚙️ Componentes de Lógica de Negocio (T-SQL)

### 1. Funciones Escalares
* **`fn_EsGrupoRiesgo(@GrupoEtario)`**: Evalúa y retorna un valor booleano (`1` o `0`) determinando si el cliente pertenece a una población vulnerable (`Niño (0-11)` o `Adulto Mayor (60+)`), facilitando el análisis epidemiológico y focalización de programas de salud.

### 2. Procedimientos Almacenados
* **`sp_IngestarNuevaTransaccion`**: Orquesta la carga de operaciones transaccionales garantizando atomicidad y consistencia (ACID). Incorpora validación de existencia de clientes y registro automático en el log de auditoría en caso de aborto transaccional (`ROLLBACK`).
* **`sp_LimpiarNulosGrupoEtario`**: Procedimiento de calidad de datos (ETL/Data Cleansing). Estandariza valores huérfanos, nulos o cadenas vacías/`'nan'` hacia el valor canónico `'No Especificado'`.

### 3. Triggers Automatizados
* **`trg_AuditarTransacciones` (AFTER INSERT, UPDATE)**: Disparador DML acoplado a `Fact_Transacciones` que registra automáticamente el usuario autenticado, tipo de acción y la clave del registro afectado.
* **`trg_IntegridadFecha` (INSTEAD OF INSERT)**: Disparador de integridad temporal sobre `Dim_Tiempo` que intercepta e impide la inserción de registros con fechas futuras (`Fecha > GETDATE()`), evitando corrupción de series temporales.

---

## Despliegue e Instalación

### Requisitos Previos
* **Motor de Base de Datos:** Microsoft SQL Server 2016 o superior / Azure SQL Database.
* **Herramienta de Gestión:** SQL Server Management Studio (SSMS) v18+ o Azure Data Studio.

### Instrucciones de Ejecución
1. **Clonar o descargar el repositorio:**
   ```bash
   git clone https://github.com/tu-usuario/DB-MARFARMA.git
   cd DB-MARFARMA
   ```
2. **Abrir el script principal:**
   Abra el archivo `SQLQuery1.sql` en SQL Server Management Studio.
3. **Ejecutar el script completo:**
   Presione `F5` o haga clic en **Execute** para crear la base de datos `MarfarmaDB`, los esquemas relacionales, roles de seguridad, funciones, procedimientos almacenados y disparadores.
4. **Verificación rápida:**
   ```sql
   USE MarfarmaDB;
   
   -- Verificar tablas creadas
   SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;
   
   -- Probar función de grupo de riesgo
   SELECT dbo.fn_EsGrupoRiesgo('Adulto Mayor (60+)') AS EsRiesgo;
   ```

---

## Estructura del Repositorio

```text
DB-MARFARMA/
├── .gitattributes      # Configuración de normalización de saltos de línea Git
├── .gitignore          # Exclusiones de archivos temporales de SSMS y logs
├── SQLQuery1.sql       # Script T-SQL integral (DDL, Roles, Funciones, SPs, Triggers)
└── README.md           # Documentación técnica del proyecto
```

---

## Autor y Créditos
* **Proyecto:** Integrador Botica Marfarma — Desafío DataSalud
* **Entorno:** SQL Server Management Studio & T-SQL
