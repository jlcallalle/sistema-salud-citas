# Caso propuesto: Centro de Fisioterapia TherapyFlex

## 1. Contexto y objetivo

TherapyFlex necesita organizar la información de sus pacientes, la programación de citas, el seguimiento clínico y los registros económicos. El proyecto representa estas necesidades mediante un modelo entidad–relación (ER), un modelo lógico y un modelo físico para Microsoft SQL Server.

El objetivo es relacionar la información de cada paciente con sus citas, sesiones, archivos clínicos, pagos y facturas, e identificar a los usuarios que registran información. También se contempla un módulo independiente de reseñas de Google.

Este documento describe los archivos disponibles en «Proyecto Modelado Jorge». La referencia para los tipos de datos, la obligatoriedad y las restricciones implementadas es el script `Modelo Físico/scrip_creacion_db_tablas.sql`, que define la base `therapyflex_crm`. No se ha verificado una instancia de base de datos en ejecución.

Los diagramas lógicos conservan nombres y tipos del origen PostgreSQL/Supabase. Su correspondencia con SQL Server y las diferencias entre diagramas se explican en las secciones 6 y 9.

## 2. Alcance

El modelo comprende nueve entidades:

| Entidad | Tabla física | Función |
|---|---|---|
| Usuario | `dbo.users` | Referencia del usuario que registra información. |
| Paciente | `dbo.patients` | Datos personales, de contacto y clínicos generales. |
| Cita | `dbo.appointments` | Programación de atención y agrupación de citas en paquetes. |
| Sesión clínica | `dbo.sessions` | Tratamiento, evolución y dolor por sesión. |
| Archivo clínico | `dbo.session_files` | Metadatos y rutas de archivos de sesiones. |
| Pago | `dbo.payments` | Pagos por paciente, con cita opcional. |
| Factura | `dbo.invoices` | Cabecera de facturación por paciente. |
| Detalle de factura | `dbo.invoice_items` | Conceptos facturados, cantidades e importes. |
| Reseña de Google | `dbo.google_reviews` | Valoraciones, comentarios y respuestas externas. |

No se implementan tablas independientes de fisioterapeutas, paquetes o servicios. Tampoco se implementan autenticación, roles, almacenamiento del contenido de archivos ni sincronización automática con Google. El modelo físico no migra usuarios o datos desde Supabase ni cambia la conexión de una aplicación existente.

## 3. Información de las entidades

### 3.1. Pacientes

`patients` registra `id`, `full_name`, `dni`, `phone`, `email`, `birth_date`, `address`, `antecedents`, `occupation`, `diagnosis`, `eva`, `from_website`, `status`, `created_by` y `created_at`.

El nombre es obligatorio. La escala de dolor `eva` admite valores de 0 a 10 y tiene valor inicial 0. `from_website` indica si el registro procede de la web y tiene valor inicial 0. El estado tiene valor predeterminado `Consulta`, pero admite NULL y no tiene un catálogo de estados restringido mediante CHECK.

El DNI es opcional y no tiene restricción de unicidad ni validación de ocho dígitos; `varchar(8)` limita su longitud máxima. El usuario creador también es opcional y referencia `users.id`.

Un paciente puede tener cero o varias citas, sesiones, archivos, pagos y facturas.

### 3.2. Citas y agrupación en paquetes

`appointments` contiene `id`, `patient_id`, `appointment_date`, `physiotherapist`, `reason`, `appointment_package_id`, `session_number`, `package_total_sessions`, `status`, `notes` y `created_at`.

Toda cita requiere un paciente y una fecha y hora. El fisioterapeuta se guarda como texto; no referencia a `users` ni a una tabla de profesionales. El estado inicial es `programado`, aunque la columna admite NULL y no tiene CHECK de estados.

Las citas de un paquete comparten `appointment_package_id`. Los campos `session_number` y `package_total_sessions` describen su posición y cantidad prevista. Son opcionales. El identificador del paquete no es una clave foránea y los índices del paquete no impiden duplicados de número de sesión.

El modelo no define duración o fecha de fin de la cita ni una regla de base de datos que evite superposición de horarios.

### 3.3. Sesiones clínicas

`sessions` contiene `id`, `patient_id`, `session_date`, `evolution`, `pain_eva`, `treatment`, `observations`, `created_by`, `created_at` y `updated_at`.

Cada sesión requiere un paciente, fecha, evolución y tratamiento. `pain_eva` admite valores de 0 a 10. El usuario creador es opcional.

Las sesiones clínicas y las citas son registros independientes vinculados al paciente: no existe una clave foránea entre `sessions` y `appointments`. Una sesión clínica no debe confundirse con el número de cita dentro de un paquete.

La tabla incluye una restricción UNIQUE sobre `(id, patient_id)` para que los archivos puedan referenciar conjuntamente la sesión y su paciente.

### 3.4. Archivos clínicos

`session_files` contiene `id`, `session_id`, `patient_id`, `file_name`, `file_path`, `file_type`, `mime_type`, `size_bytes` y `created_at`.

Todo archivo requiere una sesión, un paciente, nombre, ruta y tipo. Los tipos admitidos son `foto`, `resonancia`, `rayos_x` y `otro`.

La clave foránea compuesta `(session_id, patient_id)` referencia `sessions(id, patient_id)`. Por tanto, el script de SQL Server sí garantiza que el paciente del archivo sea el mismo que el de la sesión. Además, `patient_id` referencia directamente a `patients.id`.

`file_path` guarda una ruta: el script no almacena, copia ni elimina el contenido del archivo. `size_bytes` es opcional y no tiene CHECK para impedir valores negativos.

### 3.5. Pagos

`payments` contiene `id`, `patient_id`, `appointment_id`, `paid_at`, `payment_date`, `amount`, `sessions_count`, `amount_per_session`, `total_amount`, `payment_method`, `notes`, `created_by`, `created_at` y `updated_at`.

Cada pago requiere un paciente. La cita y el usuario creador son opcionales. Una cita puede tener cero o varios pagos.

El script exige `sessions_count > 0`, `amount_per_session >= 0` y `total_amount >= 0`. `amount` no tiene CHECK de no negatividad. El método de pago tiene valor inicial `efectivo`, pero no se restringe a una lista de métodos.

`paid_at` es obligatorio y `payment_date` es opcional. El modelo conserva ambos campos, así como `amount` y `total_amount`; no define una regla de igualdad entre ellos ni una fórmula automática para el total. Antes de analizar pagos debe establecerse qué campo representa el importe y la fecha que se desean medir, sin sumar estas columnas como pagos independientes.

La FK de la cita comprueba que esta exista, pero no garantiza que pertenezca al paciente del pago. No existe relación directa entre pagos y facturas.

### 3.6. Facturas

`invoices` contiene `id`, `invoice_number`, `patient_id`, `period_start`, `period_end`, `issue_date`, `status`, `subtotal`, `discount_percent`, `discount_amount`, `total`, `paid_amount`, `notes`, `created_by`, `created_at` y `updated_at`.

Cada factura requiere un paciente y un número único. El usuario creador y las fechas del período son opcionales. Los estados permitidos son `pendiente`, `pagada` y `cancelada`.

Los importes se almacenan directamente. El script no calcula el total desde sus detalles, no valida la coherencia entre subtotal, descuento y total, ni limita el porcentaje de descuento a 0–100. Tampoco valida el orden de las fechas del período.

`paid_amount` registra un importe, pero no crea una relación con `payments` ni demuestra una conciliación automática.

### 3.7. Detalles de factura

`invoice_items` contiene `id`, `invoice_id`, `service_date`, `description`, `quantity`, `unit_price`, `total` y `created_at`.

Cada detalle pertenece obligatoriamente a una factura. Una factura puede tener cero o varios detalles: la FK no obliga a registrar al menos uno.

El concepto se describe mediante texto y no referencia un catálogo de servicios, citas o sesiones. El script no impone positividad de cantidades o precios ni calcula automáticamente `total = quantity × unit_price`.

### 3.8. Usuarios de registro

`users` contiene únicamente `id` y `email`; el correo es opcional y no está declarado como único. Es una tabla local de referencia, no un sistema de autenticación ni una tabla de fisioterapeutas.

Las columnas `created_by` de pacientes, sesiones, pagos y facturas referencian `users.id` y admiten NULL. Permiten identificar al usuario creador cuando se proporciona el dato. No hay columna de rol ni contraseñas en el modelo físico.

### 3.9. Reseñas de Google

`google_reviews` contiene `id`, `google_review_id`, `google_review_name`, `reviewer_name`, `reviewer_photo_url`, `star_rating`, `comment`, `reply`, `review_created_at`, `review_updated_at`, `reply_updated_at`, `source`, `synced_at`, `created_at` y `updated_at`.

El identificador externo `google_review_id` es único. La puntuación admite valores de 1 a 5. Los orígenes permitidos son `google-business-api`, `google-places-api` y `manual`.

Es una entidad independiente, sin claves foráneas hacia pacientes o usuarios. No se puede atribuir una reseña a un paciente a través de una relación declarada. La presencia de campos de origen y sincronización no implementa por sí misma una integración con Google.

## 4. Relaciones y cardinalidades

Las relaciones tienen cardinalidad máxima 1:N. La tabla siguiente precisa la obligatoriedad según el script físico. En todas ellas, el registro padre puede tener cero o varios registros hijos.

| Padre | Hijo | Referencia en el hijo | Obligatoriedad del padre para cada hijo |
|---|---|---|---|
| `users` | `patients` | `created_by` | Opcional: 0 o 1 usuario. |
| `users` | `sessions` | `created_by` | Opcional: 0 o 1 usuario. |
| `users` | `payments` | `created_by` | Opcional: 0 o 1 usuario. |
| `users` | `invoices` | `created_by` | Opcional: 0 o 1 usuario. |
| `patients` | `appointments` | `patient_id` | Obligatorio: 1 paciente. |
| `patients` | `sessions` | `patient_id` | Obligatorio: 1 paciente. |
| `patients` | `session_files` | `patient_id` | Obligatorio: 1 paciente. |
| `patients` | `payments` | `patient_id` | Obligatorio: 1 paciente. |
| `patients` | `invoices` | `patient_id` | Obligatorio: 1 paciente. |
| `appointments` | `payments` | `appointment_id` | Opcional: 0 o 1 cita. |
| `sessions` | `session_files` | `(session_id, patient_id)` | Obligatorio: 1 sesión del mismo paciente. |
| `invoices` | `invoice_items` | `invoice_id` | Obligatorio: 1 factura. |

Son 12 claves foráneas; la relación archivo–sesión utiliza dos columnas en una sola FK. No hay relaciones directas cita–sesión ni pago–factura, y `google_reviews` permanece independiente.

## 5. Reglas de integridad implementadas

- Las nueve tablas tienen clave primaria `id` de tipo `uniqueidentifier`, con valor predeterminado `NEWID()`.
- Las referencias obligatorias y opcionales se distinguen mediante NOT NULL y NULL, respectivamente.
- Existen restricciones UNIQUE para el número de factura, el identificador externo de reseña y la pareja `(id, patient_id)` de sesiones.
- Los CHECK controlan las escalas de dolor, los tipos de archivo, determinados valores de pagos, los estados de factura, las puntuaciones y los orígenes de reseñas.
- Todas las claves foráneas utilizan `ON DELETE NO ACTION`: una eliminación que deje registros dependientes sin referencia es rechazada. No hay borrado en cascada ni desvinculación automática con SET NULL.
- Las columnas `updated_at` tienen un valor inicial; el script no contiene triggers que las actualicen al modificar una fila. Esa actualización debe gestionarse explícitamente.
- Un valor DEFAULT no impide NULL cuando la columna lo permite.

Las reglas que no están implementadas se describen como limitaciones en la sección 3; no deben presentarse como controles existentes en la base.

## 6. Los tres niveles de modelado

### Modelo entidad–relación

Representa las nueve entidades, sus atributos principales y relaciones de negocio. Los rectángulos representan entidades, los rombos relaciones y los óvalos atributos. La cardinalidad máxima 1:N no determina por sí sola si una referencia es obligatoria; para ello debe consultarse la sección 4.

### Modelo lógico

Organiza las entidades en tablas e identifica atributos, claves primarias, claves foráneas y valores únicos. Los dos diagramas lógicos representan el mismo conjunto de tablas; uno muestra títulos en español.

Estos diagramas conservan tipos y nombres del origen Supabase/PostgreSQL, como `auth.users`, `uuid`, `text` y `timestamptz`. Deben leerse con la siguiente correspondencia hacia el modelo físico entregado:

| Representación de origen | Implementación en SQL Server |
|---|---|
| Esquema `public` | Esquema `dbo` |
| `auth.users` | `dbo.users`, referencia local sin autenticación |
| `uuid` | `uniqueidentifier` |
| Generación de UUID | `NEWID()` |
| `text` | Generalmente `nvarchar(max)`; longitudes acotadas en campos únicos |
| `boolean` | `bit` |
| `integer` | `int` |
| `numeric(p,s)` | `decimal(p,s)` |
| `timestamptz` | `datetimeoffset(6)` |

### Modelo físico

Implementa las nueve tablas en `therapyflex_crm` mediante el script SQL Server. Incluye restricciones, valores predeterminados y 17 índices explícitos para referencias y consultas habituales, además de los asociados a claves primarias y restricciones únicas.

Los valores predeterminados de fecha y hora usan `SYSDATETIMEOFFSET()` y, para columnas `date`, su conversión a fecha. El desplazamiento horario procede del servidor; el script no fija una zona horaria de negocio.

El script crea la base si no existe. Se detiene si ya existe alguna de las tablas del modelo y ejecuta la creación de tablas e índices dentro de una transacción. Es un script de instalación, no de actualización de estructuras existentes ni de carga de datos.

## 7. Preguntas de análisis que permite el modelo

- ¿Cuántos pacientes existen y cuántos fueron registrados desde la web?
- ¿Qué citas tiene cada paciente durante un período?
- ¿Cuántas citas hay por fecha, estado o nombre de fisioterapeuta?
- ¿Qué citas comparten un paquete y qué número de sesión tienen?
- ¿Cómo cambia la escala de dolor entre sesiones de un paciente?
- ¿Qué tratamientos, evoluciones y archivos se registraron?
- ¿Qué pagos tiene cada paciente y cuáles se vinculan a una cita?
- ¿Cuál es el importe de pagos del período, una vez elegido el campo de importe y fecha para el análisis?
- ¿Qué facturas están pendientes, pagadas o canceladas?
- ¿Qué detalles e importes integran cada factura?
- ¿Qué usuario registró pacientes, sesiones, pagos o facturas?
- ¿Cómo se distribuyen las reseñas por puntuación y origen?

Las consultas deben respetar las relaciones existentes. El modelo no permite atribuir directamente pagos a facturas, sesiones a citas o reseñas a pacientes mediante una FK.

## 8. Archivos de la entrega

Los siguientes enlaces apuntan a archivos existentes dentro de «Proyecto Modelado Jorge»:

| Nivel o recurso | Archivo |
|---|---|
| Modelo ER en PNG | [Diagrama ER - Centro-TerapiaFisica.png](../Modelo%20Entidad%20Relacion/Diagrama%20ER%20-%20Centro-TerapiaFisica.png) |
| Modelo ER unificado en SVG | [diagrama_final-completo.svg](../diagrama_final-completo.svg) |
| Representación ER anterior, SVG sin extensión | [Entidad Relacion](../Entidad%20Relacion) |
| Modelo lógico | [modelo-logico.png](../Modelo%20L%C3%B3gico/modelo-logico.png) |
| Modelo lógico con títulos en español | [modelo-logico-centro-terapia.png](../Modelo%20L%C3%B3gico/modelo-logico-centro-terapia.png) |
| Diagrama físico | [modelo-fisico.png](../Modelo%20F%C3%ADsico/modelo-fisico.png) |
| Script de creación de base y tablas | [scrip_creacion_db_tablas.sql](../Modelo%20F%C3%ADsico/scrip_creacion_db_tablas.sql) |
| Nota sobre niveles de modelado | [diagramas.txt](../diagramas.txt) |

## 9. Diferencias pendientes entre los diagramas y el modelo físico

Este README toma el script físico como referencia de implementación. Los diagramas no se modificaron al adaptar el documento, por lo que conservan estas diferencias:

- El ER en PNG muestra el atributo `Rol` del usuario; `dbo.users` solo implementa `id` y `email`.
- Ese ER no representa la autoría de sesiones por usuarios, aunque la FK `sessions.created_by` sí está en el script y en otras representaciones.
- El SVG unificado y los diagramas lógicos conservan referencias a `auth.users` y presentan la autoría de pacientes como propuesta. En el script SQL Server, `patients.created_by` ya está declarada como FK opcional hacia `dbo.users`.
- La representación anterior `Entidad Relacion` usa referencias opcionales al paciente en citas, sesiones y pagos. En el modelo físico esas tres referencias son obligatorias.
- Las notas sobre variaciones de migraciones de Supabase no describen incertidumbre del DDL entregado: en este script `sessions.session_date` es `datetimeoffset(6)` y el paciente de sesiones y pagos es NOT NULL.
- Para la integridad archivo–sesión debe usarse la FK compuesta del script. Los diagramas que solo muestran enlaces simples no expresan completamente esa validación.

Estas diferencias deben tenerse en cuenta al presentar los tres niveles como una misma solución. No se afirma que un servidor desplegado tenga este esquema: el documento describe la implementación declarada en los archivos de la entrega.
