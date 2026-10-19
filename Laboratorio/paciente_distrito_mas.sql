/*
THERAPYFLEX — CONSULTAS DE NEGOCIO
De que ubicación, distrito provienen los pacientes ?
*/

USE therapyflex_crm;
GO

SELECT
    UPPER(LTRIM(RTRIM(address))) AS ubicacion_registrada,
    COUNT(*) AS cantidad_pacientes
FROM dbo.patients
WHERE address IS NOT NULL
  AND LTRIM(RTRIM(address)) <> N''
GROUP BY UPPER(LTRIM(RTRIM(address)))
ORDER BY cantidad_pacientes DESC;