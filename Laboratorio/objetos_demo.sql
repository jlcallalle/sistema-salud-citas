USE [therapyflex_academico_demo];
GO
CREATE OR ALTER FUNCTION dbo.fn_total_pagado(@PacienteId uniqueidentifier)
RETURNS decimal(38,2)
AS
BEGIN
 RETURN (SELECT COALESCE(SUM(amount),0) FROM dbo.payments WHERE patient_id=@PacienteId);
END;
GO
CREATE OR ALTER VIEW dbo.vw_pagos_por_paciente
AS
SELECT p.id,p.full_name,COUNT(pg.id) cantidad_pagos,COALESCE(SUM(pg.amount),0) total_pagado
FROM dbo.patients p LEFT JOIN dbo.payments pg ON pg.patient_id=p.id
GROUP BY p.id,p.full_name;
GO
CREATE OR ALTER PROCEDURE dbo.sp_pagos_por_periodo @Desde date=NULL,@Hasta date=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF @Desde>@Hasta THROW 50010,N'Fechas invertidas.',1;
 SELECT patient_id,COUNT(*) cantidad_pagos,SUM(amount) total_pagado
 FROM dbo.payments
 WHERE (@Desde IS NULL OR paid_at>=@Desde) AND (@Hasta IS NULL OR paid_at<=@Hasta)
 GROUP BY patient_id;
END;
GO