/*
THERAPYFLEX — CONSULTAS DE NEGOCIO
¿ Cuantos pacientes son registrados desde el sitio web ?
*/

USE therapyflex_crm;
GO

SELECT
    N'Registrados desde la web' AS origen_registro,
    COUNT(*) AS cantidad_pacientes
FROM dbo.patients
WHERE from_website = 1

UNION ALL

SELECT
    N'No marcados como registro web' AS origen_registro,
    COUNT(*) AS cantidad_pacientes
FROM dbo.patients
WHERE from_website = 0;