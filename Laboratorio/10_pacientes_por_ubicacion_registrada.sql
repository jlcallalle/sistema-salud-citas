/*
EJERCICIO BÁSICO — UBICACIONES CON MÁS PACIENTES

El modelo tiene address (dirección), pero no una columna distrito.
Esta consulta cuenta pacientes por el texto registrado en address.
Solo representa distritos si ese campo contiene exclusivamente distritos.
Si contiene calles o direcciones completas, el resultado agrupa direcciones:
no permite afirmar cuál es el distrito con más pacientes.

UPPER unifica mayúsculas y LTRIM/RTRIM eliminan espacios exteriores.
No se corrigen abreviaturas, errores de escritura ni se extraen distritos.
Se excluyen direcciones NULL, vacías o compuestas solo por espacios.
El primer resultado muestra todas las ubicaciones de mayor a menor.
El segundo indica cuántos pacientes quedaron sin ubicación utilizable.
*/

USE [Pdan8_Academico];
GO

SELECT
    UPPER(LTRIM(RTRIM(address))) AS ubicacion_registrada,
    COUNT(*) AS cantidad_pacientes
FROM dbo.patients
WHERE address IS NOT NULL
  AND LTRIM(RTRIM(address)) <> N''
GROUP BY UPPER(LTRIM(RTRIM(address)))
ORDER BY cantidad_pacientes DESC, ubicacion_registrada;

SELECT COUNT(*) AS pacientes_sin_ubicacion
FROM dbo.patients
WHERE address IS NULL
   OR LTRIM(RTRIM(address)) = N'';
