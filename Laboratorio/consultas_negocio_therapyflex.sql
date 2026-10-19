/*
THERAPYFLEX — CONSULTAS DE NEGOCIO

Uso en SSMS:
1. Ejecuta el archivo completo para obtener todos los resultados.
2. Para ejecutar una consulta por separado, incluye primero USE y DECLARE.
3. Cambia las fechas del bloque de parámetros si deseas limitar el período.

Definiciones para interpretar los resultados:
- Se adopta payments.amount como importe del pago y paid_at como fecha.
  Confirma esta elección con el uso real de la aplicación antes de reportar.
  No se suman amount y total_amount: podrían representar el mismo concepto.
- No se calcula rentabilidad: el modelo no tiene costos asociados.
- created_by identifica al usuario que registró el pago, no necesariamente
  al fisioterapeuta ni al responsable comercial de generar el ingreso.
- Servicio = descripción de una línea de factura. No existe catálogo.
  Solo se normalizan espacios exteriores y mayúsculas; no se unen sinónimos.
- from_website distingue registro web de registro no marcado como web.
  No identifica Google, redes sociales, referidos ni procedencia geográfica.
- Las facturas canceladas se excluyen del análisis de servicios y saldos.
- Pagos y facturas se analizan por separado: no existe FK entre ambos.
- No se presupone moneda: las tablas económicas no guardan ese dato.
- El archivo solo lee datos. No crea tablas ni carga datos de prueba.
*/

USE [Pdan8_Academico];
GO
SET NOCOUNT ON;

-- NULL significa sin límite. FechaHasta incluye todo ese día.
DECLARE @FechaDesde date = NULL; -- Ejemplo: '2026-01-01'
DECLARE @FechaHasta date = NULL; -- Ejemplo: '2026-12-31'

IF DB_NAME() <> N'Pdan8_Academico'
    THROW 50001, N'Seleccione la base Pdan8_Academico antes de ejecutar.', 1;

IF @FechaDesde > @FechaHasta
    THROW 50002, N'FechaDesde no puede ser posterior a FechaHasta.', 1;

/* 1. ¿QUÉ USUARIO REGISTRÓ EL MAYOR IMPORTE DE PAGOS?
Resultado: ranking por importe, cantidad de pagos, pacientes atendidos
en esos pagos y participación en el importe total del período.
La primera posición es el mayor importe registrado, no mayor rentabilidad.
Se incluye el grupo sin usuario para no perder pagos al calcular el total.
Los usuarios sin pagos no aparecen. Los empates comparten posición.
*/
PRINT N'1. Pagos registrados por usuario';
;WITH pagos_usuario AS (
    SELECT created_by AS usuario_id,
           COUNT(*) AS cantidad_pagos,
           COUNT(DISTINCT patient_id) AS pacientes_con_pagos,
           SUM(amount) AS importe_pagos
    FROM dbo.payments
    WHERE (@FechaDesde IS NULL OR paid_at >= @FechaDesde)
      AND (@FechaHasta IS NULL OR paid_at <= @FechaHasta)
    GROUP BY created_by
)
SELECT DENSE_RANK() OVER (ORDER BY pu.importe_pagos DESC) AS posicion,
       pu.usuario_id,
       CASE WHEN pu.usuario_id IS NULL THEN N'Sin usuario registrado'
            ELSE COALESCE(NULLIF(u.email, N''), N'Usuario sin correo') END AS usuario,
       pu.cantidad_pagos,
       pu.pacientes_con_pagos,
       pu.importe_pagos,
       CAST(pu.importe_pagos / NULLIF(SUM(pu.importe_pagos) OVER (), 0)
            * 100.0 AS decimal(12,2)) AS participacion_porcentaje
FROM pagos_usuario AS pu
LEFT JOIN dbo.users AS u ON u.id = pu.usuario_id
ORDER BY posicion, pu.usuario_id;

/* 2. ¿QUÉ SERVICIO SE FACTURA CON MAYOR FRECUENCIA?
Frecuencia = número de líneas de factura con esa descripción.
También se muestran unidades facturadas y número de facturas distintas.
Una línea con cantidad 10 cuenta como 1 aparición y 10 unidades.
Importe de líneas no equivale a dinero cobrado ni incorpora necesariamente
el descuento de la cabecera. El filtro usa invoice_items.service_date.
*/
PRINT N'2. Servicios facturados con mayor frecuencia';
;WITH servicios AS (
    SELECT COALESCE(NULLIF(UPPER(LTRIM(RTRIM(d.description))), N''),
                    N'SIN DESCRIPCIÓN') AS servicio,
           d.invoice_id, d.quantity, d.total
    FROM dbo.invoice_items AS d
    INNER JOIN dbo.invoices AS f ON f.id = d.invoice_id
    WHERE f.status <> N'cancelada'
      AND (@FechaDesde IS NULL OR d.service_date >= @FechaDesde)
      AND (@FechaHasta IS NULL OR d.service_date <= @FechaHasta)
)
SELECT servicio,
       COUNT(*) AS frecuencia_lineas,
       COUNT(DISTINCT invoice_id) AS cantidad_facturas,
       SUM(quantity) AS unidades_facturadas,
       SUM(total) AS importe_lineas
FROM servicios
GROUP BY servicio
ORDER BY frecuencia_lineas DESC, unidades_facturadas DESC, servicio;

/* 3. ¿DE DÓNDE PROVIENE EL REGISTRO DE LOS PACIENTES?
Clasificación disponible: web / no marcado como web.
El filtro usa la fecha de creación del paciente, según su fecha local
almacenada en datetimeoffset. No corresponde al canal de captación.
*/
PRINT N'3. Procedencia del registro de pacientes';
SELECT CASE WHEN from_website = 1 THEN N'Registro web'
            ELSE N'No marcado como web' END AS origen_registro,
       COUNT(*) AS cantidad_pacientes,
       CAST(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0)
            AS decimal(6,2)) AS participacion_porcentaje
FROM dbo.patients
WHERE (@FechaDesde IS NULL OR CAST(created_at AS date) >= @FechaDesde)
  AND (@FechaHasta IS NULL OR CAST(created_at AS date) <= @FechaHasta)
GROUP BY from_website
ORDER BY cantidad_pacientes DESC;

/* 4. ¿CUÁNTO SE REGISTRA EN PAGOS SEGÚN EL ORIGEN DEL PACIENTE?
El período se aplica al pago, no al alta del paciente. Incluye pacientes
creados antes del período que pagaron dentro de él. Se usa la marca actual
from_website; no existe historial de cambios de procedencia.
*/
PRINT N'4. Pagos por procedencia del registro del paciente';
SELECT CASE WHEN p.from_website = 1 THEN N'Registro web'
            ELSE N'No marcado como web' END AS origen_registro,
       COUNT(DISTINCT p.id) AS pacientes_con_pagos,
       COUNT(*) AS cantidad_pagos,
       SUM(pg.amount) AS importe_pagos,
       CAST(SUM(pg.amount) / NULLIF(COUNT(DISTINCT p.id), 0)
            AS decimal(18,2)) AS importe_promedio_por_paciente
FROM dbo.payments AS pg
INNER JOIN dbo.patients AS p ON p.id = pg.patient_id
WHERE (@FechaDesde IS NULL OR pg.paid_at >= @FechaDesde)
  AND (@FechaHasta IS NULL OR pg.paid_at <= @FechaHasta)
GROUP BY p.from_website
ORDER BY importe_pagos DESC;

/* 5. ¿CÓMO EVOLUCIONA EL IMPORTE DE PAGOS MES A MES?
No suma facturas: evita contar la facturación y el cobro como dos ingresos.
Solo aparecen meses con pagos registrados, no meses vacíos.
*/
PRINT N'5. Evolución mensual de pagos';
SELECT YEAR(paid_at) AS anio,
       MONTH(paid_at) AS mes,
       COUNT(*) AS cantidad_pagos,
       COUNT(DISTINCT patient_id) AS pacientes_con_pagos,
       SUM(amount) AS importe_pagos,
       CAST(AVG(amount) AS decimal(18,2)) AS importe_promedio_por_pago
FROM dbo.payments
WHERE (@FechaDesde IS NULL OR paid_at >= @FechaDesde)
  AND (@FechaHasta IS NULL OR paid_at <= @FechaHasta)
GROUP BY YEAR(paid_at), MONTH(paid_at)
ORDER BY anio, mes;

/* 6. ¿QUÉ FISIOTERAPEUTA TIENE MÁS CITAS REGISTRADAS?
Se desglosa por estado sin asumir que todas las citas fueron atendidas.
El nombre es texto libre: variantes del mismo nombre pueden quedar separadas.
El usuario creador de un pago no se usa para identificar al fisioterapeuta.
*/
PRINT N'6. Citas por fisioterapeuta y estado';
;WITH agenda AS (
    SELECT COALESCE(NULLIF(UPPER(LTRIM(RTRIM(physiotherapist))), N''),
                    N'SIN FISIOTERAPEUTA') AS fisioterapeuta,
           COALESCE(NULLIF(LOWER(LTRIM(RTRIM(status))), N''),
                    N'sin estado') AS estado,
           patient_id
    FROM dbo.appointments
    WHERE (@FechaDesde IS NULL OR CAST(appointment_date AS date) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(appointment_date AS date) <= @FechaHasta)
)
SELECT fisioterapeuta, estado,
       COUNT(*) AS cantidad_citas,
       COUNT(DISTINCT patient_id) AS cantidad_pacientes,
       SUM(COUNT(*)) OVER (PARTITION BY fisioterapeuta) AS total_citas_profesional
FROM agenda
GROUP BY fisioterapeuta, estado
ORDER BY total_citas_profesional DESC, fisioterapeuta, cantidad_citas DESC;

/* 7. ¿QUÉ PACIENTES TIENEN MAYOR SALDO REGISTRADO EN FACTURAS?
Saldo = total - paid_amount, según cabecera actual, sin conciliar payments.
Se consideran facturas no canceladas con saldo positivo, incluso si su
estado dice pagada. No se compensan saldos con facturas sobrepagadas.
El filtro selecciona facturas por emisión. No reconstruye deuda histórica
a FechaHasta ni identifica mora, pues no hay fecha de vencimiento.
*/
PRINT N'7. Saldo positivo de facturas por paciente';
SELECT p.id AS paciente_id, p.full_name AS paciente,
       COUNT(*) AS facturas_con_saldo,
       SUM(f.total) AS total_facturas,
       SUM(f.paid_amount) AS importe_pagado_en_cabeceras,
       SUM(f.total - f.paid_amount) AS saldo_registrado
FROM dbo.invoices AS f
INNER JOIN dbo.patients AS p ON p.id = f.patient_id
WHERE f.status <> N'cancelada'
  AND f.total > f.paid_amount
  AND (@FechaDesde IS NULL OR f.issue_date >= @FechaDesde)
  AND (@FechaHasta IS NULL OR f.issue_date <= @FechaHasta)
GROUP BY p.id, p.full_name
ORDER BY saldo_registrado DESC, p.id;

/* 8. ¿QUÉ DATOS CONVIENE REVISAR ANTES DE PRESENTAR RESULTADOS?
Control global, sin filtro de fechas. Los conteos pueden superponerse.
Las diferencias amount/total_amount requieren interpretación de negocio;
no demuestran por sí mismas un error. No se corrigen datos automáticamente.
*/
PRINT N'8. Controles de calidad para interpretar los indicadores';
SELECT N'Pagos sin usuario creador' AS control, COUNT(*) AS cantidad
FROM dbo.payments WHERE created_by IS NULL
UNION ALL
SELECT N'Pagos con amount negativo', COUNT(*)
FROM dbo.payments WHERE amount < 0
UNION ALL
SELECT N'Pagos con amount distinto de total_amount (revisar significado)', COUNT(*)
FROM dbo.payments WHERE amount <> total_amount
UNION ALL
SELECT N'Pagos asociados a una cita de otro paciente', COUNT(*)
FROM dbo.payments AS p
INNER JOIN dbo.appointments AS a ON a.id = p.appointment_id
WHERE p.patient_id <> a.patient_id
UNION ALL
SELECT N'Detalles con cantidad no positiva o precio negativo', COUNT(*)
FROM dbo.invoice_items WHERE quantity <= 0 OR unit_price < 0
UNION ALL
SELECT N'Detalles cuyo total difiere del producto redondeado', COUNT(*)
FROM dbo.invoice_items WHERE total <> ROUND(quantity * unit_price, 2)
UNION ALL
SELECT N'Facturas marcadas pagadas con saldo positivo', COUNT(*)
FROM dbo.invoices WHERE status = N'pagada' AND total > paid_amount
UNION ALL
SELECT N'Pacientes sin fecha de creación', COUNT(*)
FROM dbo.patients WHERE created_at IS NULL;

/*
PARA AMPLIAR EL ANÁLISIS EN EL FUTURO
- Rentabilidad: registrar costos y una regla de atribución de ingresos
  y costos al servicio, período y profesional responsable.
- Servicios: crear un catálogo y relacionarlo con sesiones y facturación.
- Captación: registrar un canal definido (referido, Google, redes, etc.).
Estas ampliaciones no forman parte de las tablas actuales.
*/
