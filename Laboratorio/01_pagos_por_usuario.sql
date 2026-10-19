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

/* 2. DETALLE POR PACIENTE Y USUARIO
El resumen anterior agrupa varios pacientes en una sola fila por usuario.
Este segundo resultado muestra una fila por paciente y usuario registrador.
El mismo paciente puede aparecer con distintos usuarios si estos registraron
sus pagos. Se agrupa por ID para no mezclar pacientes con el mismo nombre.
La participación se calcula sobre todos los pagos del período seleccionado.
Se usan los mismos parámetros de fecha del primer resultado.
*/
PRINT N'2. Nombre del paciente y pagos por usuario';
;WITH pagos_por_paciente_usuario AS (
    SELECT patient_id AS paciente_id,
           created_by AS usuario_id,
           COUNT(*) AS cantidad_pagos,
           SUM(amount) AS importe_pagos
    FROM dbo.payments
    WHERE (@FechaDesde IS NULL OR paid_at >= @FechaDesde)
      AND (@FechaHasta IS NULL OR paid_at <= @FechaHasta)
    GROUP BY patient_id, created_by
)
SELECT DENSE_RANK() OVER (ORDER BY pp.importe_pagos DESC) AS posicion,
       pp.paciente_id,
       p.full_name AS nombre_paciente,
       pp.usuario_id,
       CASE WHEN pp.usuario_id IS NULL THEN N'Sin usuario registrado'
            ELSE COALESCE(NULLIF(u.email, N''), N'Usuario sin correo') END AS usuario,
       pp.cantidad_pagos,
       pp.importe_pagos,
       CAST(pp.importe_pagos / NULLIF(SUM(pp.importe_pagos) OVER (), 0)
            * 100.0 AS decimal(12,2)) AS participacion_porcentaje
FROM pagos_por_paciente_usuario AS pp
INNER JOIN dbo.patients AS p ON p.id = pp.paciente_id
LEFT JOIN dbo.users AS u ON u.id = pp.usuario_id
ORDER BY posicion, p.full_name, pp.paciente_id, pp.usuario_id;

