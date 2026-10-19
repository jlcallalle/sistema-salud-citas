/*
THERAPYFLEX — CONSULTAS DE NEGOCIO
Listar 5 pacientes más rentables 
*/

USE therapyflex_crm;
GO

SELECT TOP (5)
    p.full_name AS paciente,
    SUM(pg.amount) AS total_pagos
FROM dbo.patients AS p
INNER JOIN dbo.payments AS pg
    ON pg.patient_id = p.id
GROUP BY p.id, p.full_name
ORDER BY total_pagos DESC, p.id;