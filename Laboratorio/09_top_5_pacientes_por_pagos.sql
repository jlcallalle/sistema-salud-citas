/*
EJERCICIO BÁSICO — LOS 5 PACIENTES CON MAYOR IMPORTE DE PAGOS

Objetivo: mostrar los cinco pacientes que suman más dinero en pagos
registrados, considerando todo el historial.

Se utiliza payments.amount como importe del pago.
No es rentabilidad neta: para calcularla también necesitaríamos costos.
No se suma total_amount para evitar contar el mismo concepto dos veces.

Pasos:
1. Relacionar pacientes con sus pagos mediante INNER JOIN.
2. Agrupar los pagos de cada paciente mediante GROUP BY.
3. Sumar sus importes mediante SUM.
4. Ordenar de mayor a menor y mostrar TOP (5).
*/

USE [Pdan8_Academico];
GO

SELECT TOP (5)
    p.id AS paciente_id,
    p.full_name AS paciente,
    COUNT(*) AS cantidad_pagos,
    SUM(pg.amount) AS total_pagos
FROM dbo.patients AS p
INNER JOIN dbo.payments AS pg
    ON pg.patient_id = p.id
GROUP BY p.id, p.full_name
ORDER BY total_pagos DESC, p.id;

-- Se agrupa por ID y nombre para no mezclar pacientes que se llamen igual.
-- Si hay empate en importe, se utiliza el ID para elegir el orden.
-- Solo aparecen pacientes con pagos; si hay menos de cinco, salen los disponibles.
