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

