/*
THERAPYFLEX — MODELO FÍSICO PARA MICROSOFT SQL SERVER
Destino: SQL Server 2016 o posterior / SQL Server Management Studio (SSMS).
Fecha: 2026-10-02. Archivo UTF-8.

INSTRUCCIONES
1. Conectarse a una instancia de SQL Server desde SSMS.
2. Abrir este archivo y ejecutarlo COMPLETO (F5).
3. Actualizar Bases de datos > therapyflex_crm > Tablas.
   Se crean nueve tablas dbo.* y sus relaciones.

Requiere permiso para crear la base si no existe y para crear tablas.
GO es un separador de lotes de SSMS/sqlcmd, no una instrucción del motor.
Si la base existe, no se elimina; si existe alguna tabla del modelo, se
aborta la creación. Es una instalación nueva, NO una migración ni un importador
de datos desde Supabase. No contiene DROP TABLE ni DROP DATABASE.

ADAPTACIÓN DEL MODELO
- public -> dbo; auth.users -> dbo.users (tabla local de referencia).
- uuid -> uniqueidentifier; gen_random_uuid() -> NEWID().
- text -> nvarchar(max); boolean -> bit; integer -> int.
- timestamptz -> datetimeoffset(6), conservando un desplazamiento horario.
- Fechas por defecto: fecha/hora y zona del servidor SQL Server.
- Columnas únicas de texto: nvarchar(100) para invoice_number y
  nvarchar(450) para google_review_id (hasta 900 bytes de clave).
- Citas: patient_id NOT NULL. Pacientes: created_by NULL.
- No se trasladan Auth, RLS, políticas, Storage ni sesiones de Supabase.
  dbo.users no autentica usuarios ni almacena contraseñas.
- Todas las FK usan NO ACTION. Se evitan rutas múltiples de cascada y
  borrados implícitos; deben resolverse los dependientes antes de borrar.
- updated_at requiere actualización desde la aplicación; no hay triggers.
- No se agrega Servicios ni una relación pago-factura.
*/

USE [master];
GO

IF DB_ID(N'therapyflex_crm') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [therapyflex_crm];');
END;
GO

USE [therapyflex_crm];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- Si USE falló, impide crear tablas accidentalmente en otra base.
IF DB_NAME() <> N'therapyflex_crm'
    THROW 50001, N'La base activa debe ser therapyflex_crm. Revise los errores anteriores.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
    WHERE s.name = N'dbo'
      AND t.name IN (N'users', N'patients', N'appointments', N'sessions',
                     N'session_files', N'payments', N'invoices',
                     N'invoice_items', N'google_reviews')
)
    THROW 50002, N'Ya existe una tabla del modelo. Este script no modifica tablas existentes.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Usuarios: entidad local que reemplaza la referencia a auth.users.
    CREATE TABLE dbo.users (
        [id] uniqueidentifier NOT NULL
            CONSTRAINT PK_users PRIMARY KEY DEFAULT NEWID(),
        [email] nvarchar(320) NULL
    );

    -- Pacientes
    CREATE TABLE dbo.patients (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_patients PRIMARY KEY default NEWID(),
  [full_name] nvarchar(max) not null,
  [dni] varchar(8) NULL,
  [phone] varchar(20) NULL,
  [email] nvarchar(max) NULL,
  [birth_date] date NULL,
  [address] nvarchar(max) NULL,
  [antecedents] nvarchar(max) NULL,
  [occupation] nvarchar(max) NULL,
  [diagnosis] nvarchar(max) NULL,
  [eva] int not null default 0 check (eva between 0 and 10),
  [from_website] bit not null default 0,
  [status] nvarchar(max) NULL default 'Consulta',
  [created_by] uniqueidentifier NULL REFERENCES dbo.users(id) ON DELETE NO ACTION,
  [created_at] datetimeoffset(6) NULL default SYSDATETIMEOFFSET()
    );

    -- Citas
    CREATE TABLE dbo.appointments (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_appointments PRIMARY KEY default NEWID(),
  [patient_id] uniqueidentifier not null REFERENCES dbo.patients(id) ON DELETE NO ACTION,
  [appointment_date] datetimeoffset(6) not null,
  [physiotherapist] nvarchar(max) NULL,
  [reason] nvarchar(max) NULL,
  [appointment_package_id] uniqueidentifier NULL,
  [session_number] int NULL,
  [package_total_sessions] int NULL,
  [status] nvarchar(max) NULL default 'programado',
  [notes] nvarchar(max) NULL,
  [created_at] datetimeoffset(6) NULL default SYSDATETIMEOFFSET()
    );

    -- Sesiones clínicas
    CREATE TABLE dbo.sessions (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_sessions PRIMARY KEY default NEWID(),
  [patient_id] uniqueidentifier not null REFERENCES dbo.patients(id) ON DELETE NO ACTION,
  [session_date] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  [evolution] nvarchar(max) not null,
  [pain_eva] int not null default 0 check (pain_eva between 0 and 10),
  [treatment] nvarchar(max) not null,
  [observations] nvarchar(max) NULL,
  [created_by] uniqueidentifier NULL REFERENCES dbo.users(id) ON DELETE NO ACTION,
  [created_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  [updated_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  constraint sessions_id_patient_id_key unique (id, patient_id)
    );

    -- Archivos de sesiones
    CREATE TABLE dbo.session_files (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_session_files PRIMARY KEY default NEWID(),
  [session_id] uniqueidentifier not null,
  [patient_id] uniqueidentifier not null REFERENCES dbo.patients(id) ON DELETE NO ACTION,
  [file_name] nvarchar(max) not null,
  [file_path] nvarchar(max) not null,
  [file_type] nvarchar(max) not null check (file_type in ('foto', 'resonancia', 'rayos_x', 'otro')),
  [mime_type] nvarchar(max) NULL,
  [size_bytes] bigint NULL,
  [created_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  constraint session_files_session_patient_fkey
    foreign key (session_id, patient_id)
    REFERENCES dbo.sessions(id, patient_id) ON DELETE NO ACTION
    );

    -- Pagos
    CREATE TABLE dbo.payments (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_payments PRIMARY KEY default NEWID(),
  [patient_id] uniqueidentifier not null REFERENCES dbo.patients(id) ON DELETE NO ACTION,
  [appointment_id] uniqueidentifier NULL REFERENCES dbo.appointments(id) ON DELETE NO ACTION,
  [paid_at] date not null default CONVERT(date, SYSDATETIMEOFFSET()),
  [payment_date] date NULL default CONVERT(date, SYSDATETIMEOFFSET()),
  [amount] decimal(10,2) not null default 0,
  [sessions_count] int not null default 1 check (sessions_count > 0),
  [amount_per_session] decimal(10,2) not null default 0 check (amount_per_session >= 0),
  [total_amount] decimal(10,2) not null default 0 check (total_amount >= 0),
  [payment_method] nvarchar(max) not null default 'efectivo',
  [notes] nvarchar(max) NULL,
  [created_by] uniqueidentifier NULL REFERENCES dbo.users(id) ON DELETE NO ACTION,
  [created_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  [updated_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET()
    );

    -- Facturas
    CREATE TABLE dbo.invoices (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_invoices PRIMARY KEY default NEWID(),
  [invoice_number] nvarchar(100) not null unique,
  [patient_id] uniqueidentifier not null REFERENCES dbo.patients(id) ON DELETE NO ACTION,
  [period_start] date NULL,
  [period_end] date NULL,
  [issue_date] date not null default CONVERT(date, SYSDATETIMEOFFSET()),
  [status] nvarchar(max) not null default 'pendiente' check (status in ('pendiente', 'pagada', 'cancelada')),
  [subtotal] decimal(10,2) not null default 0,
  [discount_percent] decimal(5,2) not null default 0,
  [discount_amount] decimal(10,2) not null default 0,
  [total] decimal(10,2) not null default 0,
  [paid_amount] decimal(10,2) not null default 0,
  [notes] nvarchar(max) NULL,
  [created_by] uniqueidentifier NULL REFERENCES dbo.users(id) ON DELETE NO ACTION,
  [created_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  [updated_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET()
    );

    -- Detalles de factura
    CREATE TABLE dbo.invoice_items (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_invoice_items PRIMARY KEY default NEWID(),
  [invoice_id] uniqueidentifier not null REFERENCES dbo.invoices(id) ON DELETE NO ACTION,
  [service_date] date not null default CONVERT(date, SYSDATETIMEOFFSET()),
  [description] nvarchar(max) not null,
  [quantity] decimal(10,2) not null default 1,
  [unit_price] decimal(10,2) not null default 0,
  [total] decimal(10,2) not null default 0,
  [created_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET()
    );

    -- Reseñas de Google
    CREATE TABLE dbo.google_reviews (
  [id] uniqueidentifier NOT NULL CONSTRAINT PK_google_reviews PRIMARY KEY default NEWID(),
  [google_review_id] nvarchar(450) not null unique,
  [google_review_name] nvarchar(max) NULL,
  [reviewer_name] nvarchar(max) not null default 'Usuario de Google',
  [reviewer_photo_url] nvarchar(max) NULL,
  [star_rating] int not null default 5 check (star_rating between 1 and 5),
  [comment] nvarchar(max) NULL,
  [reply] nvarchar(max) NULL,
  [review_created_at] datetimeoffset(6) NULL,
  [review_updated_at] datetimeoffset(6) NULL,
  [reply_updated_at] datetimeoffset(6) NULL,
  [source] nvarchar(max) not null default 'google-places-api' check (source in ('google-business-api', 'google-places-api', 'manual')),
  [synced_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  [created_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET(),
  [updated_at] datetimeoffset(6) not null default SYSDATETIMEOFFSET()
    );

    -- Índices para las claves foráneas y las consultas habituales.
    CREATE INDEX patients_created_by_idx ON dbo.patients (created_by);
    CREATE INDEX appointments_patient_date_idx ON dbo.appointments (patient_id, appointment_date);
    CREATE INDEX appointments_date_idx ON dbo.appointments (appointment_date);
    CREATE INDEX appointments_package_id_idx ON dbo.appointments (appointment_package_id);
    CREATE INDEX appointments_patient_package_idx
  ON dbo.appointments (patient_id, appointment_package_id, session_number);
    CREATE INDEX sessions_patient_date_idx ON dbo.sessions (patient_id, session_date);
    CREATE INDEX sessions_created_by_idx ON dbo.sessions (created_by);
    CREATE INDEX session_files_session_patient_idx ON dbo.session_files (session_id, patient_id);
    CREATE INDEX session_files_patient_id_idx ON dbo.session_files (patient_id);
    CREATE INDEX payments_patient_id_idx ON dbo.payments (patient_id);
    CREATE INDEX payments_appointment_id_idx ON dbo.payments (appointment_id);
    CREATE INDEX payments_created_by_idx ON dbo.payments (created_by);
    CREATE INDEX payments_paid_at_idx ON dbo.payments (paid_at);
    CREATE INDEX invoices_patient_id_idx ON dbo.invoices (patient_id);
    CREATE INDEX invoices_created_by_idx ON dbo.invoices (created_by);
    CREATE INDEX invoice_items_invoice_id_idx ON dbo.invoice_items (invoice_id);
    CREATE INDEX google_reviews_review_created_at_idx ON dbo.google_reviews (review_created_at DESC);

    COMMIT TRANSACTION;
    PRINT N'Modelo físico creado correctamente: 9 tablas en therapyflex_crm.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Verificación: nueve tablas creadas bajo dbo.
SELECT s.name AS esquema, t.name AS tabla
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'dbo'
  AND t.name IN (N'users', N'patients', N'appointments', N'sessions',
                 N'session_files', N'payments', N'invoices',
                 N'invoice_items', N'google_reviews')
ORDER BY t.name;

-- Verificación: doce FK. La relación archivo-sesión usa dos columnas
-- para impedir que el archivo corresponda a un paciente distinto al de la sesión.
SELECT fk.name AS relacion,
       OBJECT_SCHEMA_NAME(fk.parent_object_id) + N'.' +
       OBJECT_NAME(fk.parent_object_id) AS tabla_hija,
       OBJECT_SCHEMA_NAME(fk.referenced_object_id) + N'.' +
       OBJECT_NAME(fk.referenced_object_id) AS tabla_padre,
       fk.delete_referential_action_desc AS accion_borrado
FROM sys.foreign_keys AS fk
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'dbo'
  AND OBJECT_NAME(fk.parent_object_id) IN
      (N'patients', N'appointments', N'sessions', N'session_files',
       N'payments', N'invoices', N'invoice_items', N'google_reviews')
ORDER BY tabla_hija, relacion;
GO

/*
NOTAS
- Para visualizar relaciones: en SSMS, therapyflex_crm > Diagramas de base
  de datos > Nuevo diagrama. Seleccionar las nueve tablas y guardar.
  La primera vez SSMS puede solicitar instalar los objetos de soporte
  de diagramas; esa operación requiere los permisos correspondientes.
- file_path sigue siendo una ruta. Este script no almacena ni copia archivos.
- appointment_package_id sigue siendo un identificador de grupo, sin FK.
- created_by debe enviarse desde la aplicación; puede quedar NULL.
- payments.appointment_id valida existencia, pero no que la cita corresponda
  al mismo paciente del pago. Esa regla requiere validación adicional.
- El CRM actual utiliza el SDK de Supabase. Crear estas tablas no cambia
  automáticamente su conexión ni migra sus usuarios/datos a SQL Server.
*/
