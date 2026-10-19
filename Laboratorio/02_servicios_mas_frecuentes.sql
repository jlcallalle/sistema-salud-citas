/*
THERAPYFLEX — FRECUENCIA DE TRATAMIENTOS Y SERVICIOS FACTURADOS

Ejecuta todo este archivo con F5. Devuelve tres resultados:
1. Diagnóstico de datos disponibles y filtros.
2. Frecuencia de tratamientos registrados en sesiones clínicas.
3. Frecuencia de conceptos facturados (consulta original).

Son métricas diferentes: un tratamiento registrado no prueba facturación,
y una línea de factura no identifica necesariamente una sesión clínica.
No existe catálogo de servicios. Se agrupan textos completos normalizando
solo mayúsculas y espacios exteriores; no se separan tratamientos combinados.
No se generan datos ni se modifican registros.
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

/* 1. DIAGNÓSTICO
Los primeros conteos muestran el total disponible sin filtrar por fechas.
Los últimos muestran lo que cumple las condiciones de cada análisis.
Si hay detalles pero no son elegibles, revisa las fechas y las facturas.
Los pagos existentes no implican que existan facturas o sesiones clínicas.
*/
PRINT N'1. Diagnóstico de datos disponibles';
SELECT DB_NAME() AS base_actual,
       @FechaDesde AS fecha_desde,
       @FechaHasta AS fecha_hasta,
       (SELECT COUNT(*) FROM dbo.sessions) AS sesiones_totales,
       (SELECT COUNT(*) FROM dbo.invoices) AS facturas_totales,
       (SELECT COUNT(*) FROM dbo.invoice_items) AS detalles_totales,
       (SELECT COUNT(*) FROM dbo.invoice_items AS d
        INNER JOIN dbo.invoices AS f ON f.id = d.invoice_id
        WHERE f.status = N'cancelada') AS detalles_facturas_canceladas,
       (SELECT COUNT(*) FROM dbo.invoice_items AS d
        WHERE NOT EXISTS (SELECT 1 FROM dbo.invoices AS f
                          WHERE f.id = d.invoice_id)) AS detalles_sin_factura,
       (SELECT COUNT(*) FROM dbo.invoice_items AS d
        INNER JOIN dbo.invoices AS f ON f.id = d.invoice_id
        WHERE f.status <> N'cancelada'
          AND (@FechaDesde IS NULL OR d.service_date >= @FechaDesde)
          AND (@FechaHasta IS NULL OR d.service_date <= @FechaHasta))
          AS detalles_elegibles,
       (SELECT COUNT(*) FROM dbo.sessions
        WHERE NULLIF(LTRIM(RTRIM(treatment)), N'') IS NOT NULL
          AND (@FechaDesde IS NULL OR CAST(session_date AS date) >= @FechaDesde)
          AND (@FechaHasta IS NULL OR CAST(session_date AS date) <= @FechaHasta))
          AS sesiones_con_tratamiento_en_periodo;

/* 2. ¿QUÉ TRATAMIENTOS SE REGISTRAN CON MAYOR FRECUENCIA?
Fuente: sessions.treatment. Frecuencia = número de sesiones con ese texto.
Se excluyen tratamientos vacíos. Se cuentan pacientes distintos por texto.
La fecha utilizada es session_date, con la fecha local almacenada.
Este resultado no representa unidades facturadas, cobros o rentabilidad.
*/
PRINT N'2. Tratamientos registrados en sesiones clínicas';
;WITH tratamientos AS (
    SELECT UPPER(LTRIM(RTRIM(treatment))) AS tratamiento,
           patient_id
    FROM dbo.sessions
    WHERE NULLIF(LTRIM(RTRIM(treatment)), N'') IS NOT NULL
      AND (@FechaDesde IS NULL OR CAST(session_date AS date) >= @FechaDesde)
      AND (@FechaHasta IS NULL OR CAST(session_date AS date) <= @FechaHasta)
)
SELECT tratamiento,
       COUNT(*) AS frecuencia_sesiones,
       COUNT(DISTINCT patient_id) AS cantidad_pacientes,
       CAST(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0)
            AS decimal(6,2)) AS participacion_porcentaje
FROM tratamientos
GROUP BY tratamiento
ORDER BY frecuencia_sesiones DESC, tratamiento;

/* 3. ¿QUÉ SERVICIO SE FACTURA CON MAYOR FRECUENCIA?
Frecuencia = número de líneas de factura con esa descripción.
También se muestran unidades facturadas y número de facturas distintas.
Una línea con cantidad 10 cuenta como 1 aparición y 10 unidades.
Importe de líneas no equivale a dinero cobrado ni incorpora necesariamente
el descuento de la cabecera. El filtro usa invoice_items.service_date.
*/
PRINT N'3. Servicios facturados con mayor frecuencia';
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


/* Si ambos rankings están vacíos, usa los conteos del primer resultado
   para comprobar si faltan datos o si las fechas excluyen los registros.
   Mantén ambas fechas en NULL para revisar todo el historial. */
