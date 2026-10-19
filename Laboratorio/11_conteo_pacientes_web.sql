/*
EJERCICIO BÁSICO — PACIENTES REGISTRADOS DESDE LA WEB

from_website = 1: registrado desde la web.
from_website = 0: no marcado como registro web.

COUNT cuenta los pacientes que cumplen cada condición.
UNION ALL reúne ambos conteos en un solo resultado.
Cada categoría aparece incluso cuando tiene cero pacientes.
Se considera todo el historial. No se modifican datos.

El valor 0 es el predeterminado del modelo: no identifica un canal
específico como presencial, referido o redes sociales.
*/

USE [Pdan8_Academico];
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
