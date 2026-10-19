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

