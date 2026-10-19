# Diccionario de datos — TherapyFlex

Fuente: metadatos de localhost/therapyflex_crm consultados el 19/10/2026. Tipos, nulabilidad y valores predeterminados extraídos del servidor. Las reglas y relaciones se detallan en [Caso propuesto](Caso%20Propuesto/README.md) y [DDL](DDL/create_database.sql).

Granularidad: un usuario, paciente, cita, sesión, archivo, pago, factura, línea de factura o reseña por fila, según tabla. Todos los id son PK; las relaciones no eliminan en cascada. Los datos clínicos y de contacto son sensibles; esta entrega solo incluye datos ficticios.

## dbo.appointments

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| patient_id | uniqueidentifier | False |  |
| appointment_date | datetimeoffset(6) | False |  |
| physiotherapist | nvarchar(max) | True |  |
| reason | nvarchar(max) | True |  |
| appointment_package_id | uniqueidentifier | True |  |
| session_number | int | True |  |
| package_total_sessions | int | True |  |
| status | nvarchar(max) | True | ('programado') |
| notes | nvarchar(max) | True |  |
| created_at | datetimeoffset(6) | True | (sysdatetimeoffset()) |

## dbo.google_reviews

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| google_review_id | nvarchar(450) | False |  |
| google_review_name | nvarchar(max) | True |  |
| reviewer_name | nvarchar(max) | False | ('Usuario de Google') |
| reviewer_photo_url | nvarchar(max) | True |  |
| star_rating | int | False | ((5)) |
| comment | nvarchar(max) | True |  |
| reply | nvarchar(max) | True |  |
| review_created_at | datetimeoffset(6) | True |  |
| review_updated_at | datetimeoffset(6) | True |  |
| reply_updated_at | datetimeoffset(6) | True |  |
| source | nvarchar(max) | False | ('google-places-api') |
| synced_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |
| created_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |
| updated_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |

## dbo.invoice_items

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| invoice_id | uniqueidentifier | False |  |
| service_date | date | False | (CONVERT([date],sysdatetimeoffset())) |
| description | nvarchar(max) | False |  |
| quantity | decimal(10,2) | False | ((1)) |
| unit_price | decimal(10,2) | False | ((0)) |
| total | decimal(10,2) | False | ((0)) |
| created_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |

## dbo.invoices

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| invoice_number | nvarchar(100) | False |  |
| patient_id | uniqueidentifier | False |  |
| period_start | date | True |  |
| period_end | date | True |  |
| issue_date | date | False | (CONVERT([date],sysdatetimeoffset())) |
| status | nvarchar(max) | False | ('pendiente') |
| subtotal | decimal(10,2) | False | ((0)) |
| discount_percent | decimal(5,2) | False | ((0)) |
| discount_amount | decimal(10,2) | False | ((0)) |
| total | decimal(10,2) | False | ((0)) |
| paid_amount | decimal(10,2) | False | ((0)) |
| notes | nvarchar(max) | True |  |
| created_by | uniqueidentifier | True |  |
| created_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |
| updated_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |

## dbo.patients

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| full_name | nvarchar(max) | False |  |
| dni | varchar(8) | True |  |
| phone | varchar(20) | True |  |
| email | nvarchar(max) | True |  |
| birth_date | date | True |  |
| address | nvarchar(max) | True |  |
| antecedents | nvarchar(max) | True |  |
| occupation | nvarchar(max) | True |  |
| diagnosis | nvarchar(max) | True |  |
| eva | int | False | ((0)) |
| from_website | bit | False | ((0)) |
| status | nvarchar(max) | True | ('Consulta') |
| created_by | uniqueidentifier | True |  |
| created_at | datetimeoffset(6) | True | (sysdatetimeoffset()) |

## dbo.payments

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| patient_id | uniqueidentifier | False |  |
| appointment_id | uniqueidentifier | True |  |
| paid_at | date | False | (CONVERT([date],sysdatetimeoffset())) |
| payment_date | date | True | (CONVERT([date],sysdatetimeoffset())) |
| amount | decimal(10,2) | False | ((0)) |
| sessions_count | int | False | ((1)) |
| amount_per_session | decimal(10,2) | False | ((0)) |
| total_amount | decimal(10,2) | False | ((0)) |
| payment_method | nvarchar(max) | False | ('efectivo') |
| notes | nvarchar(max) | True |  |
| created_by | uniqueidentifier | True |  |
| created_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |
| updated_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |

## dbo.session_files

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| session_id | uniqueidentifier | False |  |
| patient_id | uniqueidentifier | False |  |
| file_name | nvarchar(max) | False |  |
| file_path | nvarchar(max) | False |  |
| file_type | nvarchar(max) | False |  |
| mime_type | nvarchar(max) | True |  |
| size_bytes | bigint | True |  |
| created_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |

## dbo.sessions

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| patient_id | uniqueidentifier | False |  |
| session_date | datetimeoffset(6) | False | (sysdatetimeoffset()) |
| evolution | nvarchar(max) | False |  |
| pain_eva | int | False | ((0)) |
| treatment | nvarchar(max) | False |  |
| observations | nvarchar(max) | True |  |
| created_by | uniqueidentifier | True |  |
| created_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |
| updated_at | datetimeoffset(6) | False | (sysdatetimeoffset()) |

## dbo.users

| Columna | Tipo | Admite NULL | DEFAULT |
|---|---|---|---|
| id | uniqueidentifier | False | (newid()) |
| email | nvarchar(320) | True |  |
