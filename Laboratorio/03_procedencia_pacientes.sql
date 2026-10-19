/*
THERAPYFLEX — CONSULTAS DE NEGOCIO

Uso en SSMS:
1. Ejecuta este archivo completo con F5 para obtener este análisis.
2. Este archivo es independiente e incluye su base y parámetros.
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

