# Caso del proyecto actual
# Centro de Fisioterapia TherapyFlex: Modelo de datos para la gestión de pacientes y citas

El centro de fisioterapia TherapyFlex cuenta con una aplicación que administra pacientes, citas, registros de evolución clínica, archivos de sesiones, pagos y facturas. Su base de datos utiliza PostgreSQL mediante Supabase.

El objetivo del caso es describir cómo el proyecto organiza la información de cada paciente y cómo relaciona su agenda, seguimiento clínico y registros económicos, tomando como referencia las tablas y claves foráneas existentes en los archivos SQL del repositorio.

Para este trabajo se considerará información relacionada con:

- Pacientes.
- Citas y agrupación de citas en paquetes.
- Sesiones de historia clínica.
- Archivos asociados a las sesiones.
- Pagos.
- Facturas.
- Detalles de factura.
- Usuarios que registran sesiones, pagos y facturas.

Se excluyen del modelo las integraciones de analítica web, reseñas y servicios externos. La autenticación y el almacenamiento de archivos se presentan solo en su relación con los registros de negocio.

**Base del documento:** esquema declarado en los scripts del proyecto y uso de las tablas en la aplicación. No se ha consultado el esquema del servidor desplegado. Las diferencias entre versiones de los scripts se explican al final y en el documento del diagrama.

## 1. Pacientes

El centro registra los datos personales, de contacto y clínicos generales de cada paciente en la tabla `patients`.

Para cada paciente se almacena:

- Identificador: `id`.
- Nombre completo: `full_name`.
- DNI: `dni`.
- Teléfono y correo: `phone`, `email`.
- Fecha de nacimiento y dirección: `birth_date`, `address`.
- Antecedentes, ocupación y diagnóstico: `antecedents`, `occupation`, `diagnosis`.
- Escala de dolor: `eva`, con valores de 0 a 10.
- Indicador de registro desde la web: `from_website`.
- Estado y fecha de creación: `status`, `created_at`.

Un paciente puede tener varias citas, sesiones clínicas, archivos, pagos y facturas. El identificador es la clave primaria. El DNI no tiene una restricción UNIQUE declarada en el script base.

## 2. Citas

La tabla `appointments` registra la programación de atención de los pacientes.

Cada cita contiene:

- Identificador: `id`.
- Paciente relacionado: `patient_id`.
- Fecha y hora: `appointment_date`.
- Nombre del fisioterapeuta: `physiotherapist`.
- Motivo: `reason`.
- Identificador de agrupación del paquete: `appointment_package_id`.
- Número de sesión y total de sesiones del paquete: `session_number`, `package_total_sessions`.
- Estado, notas y fecha de creación: `status`, `notes`, `created_at`.

La clave foránea `patient_id` referencia a `patients.id`, aunque el script permite que sea NULL. El estado inicial declarado es `programado` y no se define un CHECK de estados en esta tabla.

El profesional se almacena como texto, sin una tabla de fisioterapeutas. La cita tiene una fecha y hora, pero no columnas separadas de inicio y fin. Los scripts revisados no declaran una restricción para evitar superposición de horarios.

## 3. Agrupación de citas en paquetes

El proyecto permite identificar citas pertenecientes a un mismo paquete mediante campos de `appointments`.

Para esta agrupación se utiliza:

- Un identificador compartido: `appointment_package_id`.
- La posición de la sesión: `session_number`.
- La cantidad total de sesiones: `package_total_sessions`.

Existen índices sobre el identificador del paquete y sobre la combinación de paciente, paquete y número de sesión. Estos índices no son restricciones de unicidad.

No existe una tabla de paquetes declarada en los archivos revisados. Por ello, el paquete se documenta como una agrupación de citas, no como una entidad adicional en el diagrama.

## 4. Sesiones de historia clínica

La tabla `sessions` conserva los registros de evolución y tratamiento de los pacientes.

Cada registro contiene:

- Identificador: `id`.
- Paciente: `patient_id`.
- Fecha de sesión: `session_date`.
- Evolución: `evolution`.
- Escala de dolor de la sesión: `pain_eva`, entre 0 y 10.
- Tratamiento y observaciones: `treatment`, `observations`.
- Usuario que lo registró: `created_by`.
- Fechas de creación y actualización: `created_at`, `updated_at`.

Un paciente puede tener múltiples registros clínicos. La tabla no contiene una clave foránea hacia `appointments`; una cita y una sesión clínica se relacionan con el paciente de forma independiente. Los registros de esta tabla no deben confundirse con las citas numeradas dentro de un paquete.

## 5. Archivos de sesiones

La tabla `session_files` registra los metadatos de documentos e imágenes asociados al seguimiento clínico.

Para cada archivo se almacena:

- Identificador: `id`.
- Sesión y paciente relacionados: `session_id`, `patient_id`.
- Nombre y ruta: `file_name`, `file_path`.
- Tipo: `file_type`.
- Tipo MIME y tamaño en bytes: `mime_type`, `size_bytes`.
- Fecha de creación: `created_at`.

Los tipos permitidos por CHECK son `foto`, `resonancia`, `rayos_x` y `otro`. Cada registro requiere una sesión y un paciente. Una sesión puede tener varios archivos.

Los archivos se gestionan en el bucket `clinical-files` de Supabase Storage; la tabla guarda su ruta, sin una FK a `storage.objects`. Las dos FK no aseguran por sí solas que el paciente del archivo coincida con el paciente de la sesión.

## 6. Pagos

La tabla `payments` permite registrar pagos de pacientes y, opcionalmente, asociarlos a una cita.

Cada pago contiene:

- Identificador: `id`.
- Paciente y cita relacionada: `patient_id`, `appointment_id`.
- Fechas: `paid_at`, `payment_date`.
- Importe: `amount`.
- Cantidad de sesiones: `sessions_count`.
- Importe por sesión y total: `amount_per_session`, `total_amount`.
- Método de pago: `payment_method`.
- Notas: `notes`.
- Usuario de registro: `created_by`.
- Fechas de creación y actualización: `created_at`, `updated_at`.

Una cita puede estar relacionada con varios pagos y un pago puede no tener cita asociada. Los campos de fechas e importes se conservan tal como aparecen en el esquema; no deben sumarse entre sí como si representaran pagos independientes.

La definición nueva del módulo exige sesiones_count mayor que cero e importes por sesión y totales no negativos. No declara una FK hacia facturas ni una restricción que asegure que el paciente del pago coincida con el de su cita.

## 7. Facturas

La tabla `invoices` registra cabeceras de facturación por paciente.

Cada factura almacena:

- Identificador y número único: `id`, `invoice_number`.
- Paciente: `patient_id`.
- Período de inicio y fin: `period_start`, `period_end`.
- Fecha de emisión: `issue_date`.
- Estado: `status`.
- Subtotal: `subtotal`.
- Porcentaje e importe de descuento: `discount_percent`, `discount_amount`.
- Total e importe pagado: `total`, `paid_amount`.
- Notas y usuario de registro: `notes`, `created_by`.
- Fechas de creación y actualización: `created_at`, `updated_at`.

Cada factura requiere un paciente. Un paciente puede tener varias facturas. Los estados restringidos por CHECK son `pendiente`, `pagada` y `cancelada`.

Los importes son columnas almacenadas, no columnas generadas en los scripts revisados. `paid_amount` no crea una relación con la tabla `payments` ni demuestra una conciliación automática entre ambos módulos.

## 8. Detalle de facturas

La tabla `invoice_items` contiene los conceptos de cada factura.

Para cada detalle se registra:

- Identificador: `id`.
- Factura: `invoice_id`.
- Fecha del servicio: `service_date`.
- Descripción: `description`.
- Cantidad: `quantity`.
- Precio unitario: `unit_price`.
- Total: `total`.
- Fecha de creación: `created_at`.

Cada detalle pertenece a una factura. La base permite que una factura tenga cero o muchos detalles; la FK no obliga a crear al menos uno. El detalle describe el servicio mediante texto, sin FK a una cita o catálogo de servicios.

## 9. Usuarios de registro e integridad

Las columnas `created_by` de `sessions`, `payments` e `invoices` referencian `auth.users.id`. Son opcionales y permiten identificar al usuario que creó el registro. No equivalen a la asignación de un fisioterapeuta a una cita.

El esquema declara diferentes acciones de integridad:

- La eliminación de una sesión elimina sus registros de `session_files` mediante CASCADE.
- La eliminación de una factura elimina sus detalles mediante CASCADE.
- La eliminación de una cita deja en NULL la referencia opcional de sus pagos mediante SET NULL.
- Las facturas impiden eliminar al paciente relacionado mediante RESTRICT.
- La eliminación de pacientes tiene efectos distintos según la tabla y la versión del script; consultar el diagrama documentado.

Eliminar metadatos de archivos mediante CASCADE no significa que el SQL elimine automáticamente los objetos de Storage.

## 10. Requerimientos de análisis

A partir de las tablas del proyecto se pueden plantear preguntas como:

- ¿Cuántos pacientes están registrados y cuántos provienen de la web?
- ¿Qué citas tiene un paciente durante un período?
- ¿Cuántas citas hay por fecha, estado y nombre de fisioterapeuta registrado?
- ¿Qué citas pertenecen al mismo paquete y qué número de sesión tienen?
- ¿Cómo evoluciona el dolor registrado en las sesiones clínicas de un paciente?
- ¿Qué tratamientos y archivos se registraron en sus sesiones?
- ¿Qué pagos tiene un paciente y cuáles se asociaron a una cita?
- ¿Cuál es el importe de pagos del período usando el campo contable elegido por la aplicación?
- ¿Qué facturas están pendientes, pagadas o canceladas?
- ¿Qué conceptos e importes componen cada factura?
- ¿Qué usuario creó una sesión, pago o factura?

Los análisis deben respetar las relaciones existentes. No puede atribuirse un pago a una factura mediante una FK inexistente ni identificarse una sesión clínica concreta a partir de una cita sin información adicional.

## Modelo entidad-relación y fuentes

El modelo completo está en [diagrama-entidad-relacion.md](diagrama-entidad-relacion.md), con su fuente editable en [diagrama-entidad-relacion.mmd](diagrama-entidad-relacion.mmd).

Fuentes revisadas:

- `db/script.sql`: esquema base de pacientes, citas, sesiones y pagos.
- `db/appointment_physiotherapist.sql` y `db/appointment_package_fields.sql`: campos de profesional y paquetes en citas.
- `db/patient_clinical_fields.sql`: campos clínicos de pacientes.
- `db/clinical_history.sql`: sesiones clínicas, archivos y almacenamiento.
- `db/payments.sql`: ampliación del módulo de pagos.
- `db/billing.sql` y `db/table_facture.sql`: facturas y detalles.
- `app/pages/`: consultas de los módulos de pacientes, citas, historia clínica, pagos y facturación.

**Diferencias de versión:** los scripts usan CREATE TABLE IF NOT EXISTS y ADD COLUMN IF NOT EXISTS, que no reemplazan definiciones ya existentes. El diagrama toma las definiciones nuevas de los módulos clínico y de pagos. Si se ejecutó primero el script base, pueden variar la nulabilidad de algunas columnas, el tipo de session_date y la acción de eliminación de payments.patient_id. Estas diferencias se detallan en el documento del diagrama y requieren verificar el servidor para determinar su estado efectivo.
