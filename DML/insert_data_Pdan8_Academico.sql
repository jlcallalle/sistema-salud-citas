/* Datos de demostración para Pdan8_Academico.
*/
USE [Pdan8_Academico];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
IF DB_NAME() <> N'Pdan8_Academico' THROW 50001,N'Base de destino incorrecta.',1;
IF DB_ID(N'therapyflex_crm') IS NULL THROW 50002,N'No existe la base origen.',1;

DECLARE @Tablas TABLE(orden int PRIMARY KEY,nombre sysname,filas_demo int);
INSERT @Tablas VALUES (1,N'users',1),(2,N'patients',3),(3,N'appointments',3),
 (4,N'sessions',1),(5,N'session_files',1),(6,N'payments',3),
 (7,N'invoices',3),(8,N'invoice_items',3),(9,N'google_reviews',1);
DECLARE @Estado TABLE(nombre sysname,filas bigint);
DECLARE @n int=1,@tabla sysname,@columnas nvarchar(max),@sql nvarchar(max),@filas bigint;
BEGIN TRY
 BEGIN TRANSACTION;
 -- Bloquear el destino durante comprobación y sustitución.
 WHILE @n<=9
 BEGIN
  SELECT @tabla=nombre FROM @Tablas WHERE orden=@n;
  SET @sql=N'SELECT @c=COUNT_BIG(*) FROM dbo.'+QUOTENAME(@tabla)+N' WITH (TABLOCKX,HOLDLOCK);';
  EXEC sys.sp_executesql @sql,N'@c bigint OUTPUT',@c=@filas OUTPUT;
  INSERT @Estado VALUES(@tabla,@filas);
  SET @n+=1;
 END;
 IF EXISTS(SELECT 1 FROM @Estado WHERE filas<>0)
 BEGIN
  IF EXISTS(SELECT 1 FROM @Estado e JOIN @Tablas t ON t.nombre=e.nombre WHERE e.filas<>t.filas_demo)
   OR (SELECT COUNT(*) FROM dbo.patients WHERE full_name IN(N'Paciente ficticio A',N'Paciente ficticio B',N'Paciente ficticio C'))<>3
   OR NOT EXISTS(SELECT 1 FROM dbo.users WHERE email=N'demo@example.invalid')
   OR NOT EXISTS(SELECT 1 FROM dbo.google_reviews WHERE google_review_id=N'demo-review-001')
   OR EXISTS(SELECT 1 FROM dbo.invoices WHERE invoice_number NOT IN(N'DEMO-001',N'DEMO-002',N'DEMO-003'))
   THROW 50003,N'El destino contiene datos distintos de la demostración esperada. No se modifica.',1;
 END;

 -- Comprobar que cada columna de destino existe con el mismo tipo en origen.
 IF EXISTS(
  SELECT t.name,c.name,c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable
  FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
  JOIN sys.columns c ON c.object_id=t.object_id
  WHERE s.name=N'dbo' AND t.name IN(SELECT nombre FROM @Tablas)
  EXCEPT
  SELECT t.name,c.name,c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable
  FROM therapyflex_crm.sys.tables t JOIN therapyflex_crm.sys.schemas s ON s.schema_id=t.schema_id
  JOIN therapyflex_crm.sys.columns c ON c.object_id=t.object_id WHERE s.name=N'dbo'
 ) THROW 50004,N'Las columnas de origen y destino no son compatibles.',1;

 DELETE FROM dbo.invoice_items;
 DELETE FROM dbo.invoices;
 DELETE FROM dbo.payments;
 DELETE FROM dbo.session_files;
 DELETE FROM dbo.sessions;
 DELETE FROM dbo.appointments;
 DELETE FROM dbo.patients;
 DELETE FROM dbo.google_reviews;
 DELETE FROM dbo.users;

 SET @n=1;
 WHILE @n<=9
 BEGIN
  SELECT @tabla=nombre FROM @Tablas WHERE orden=@n;
  SELECT @columnas=STUFF((SELECT N','+QUOTENAME(c.name)
   FROM sys.columns c WHERE c.object_id=OBJECT_ID(N'dbo.'+@tabla)
   ORDER BY c.column_id FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,N'');
  SET @sql=N'INSERT dbo.'+QUOTENAME(@tabla)+N' ('+@columnas+N') SELECT '+@columnas+
   N' FROM therapyflex_crm.dbo.'+QUOTENAME(@tabla)+N' WITH (HOLDLOCK);';
  EXEC sys.sp_executesql @sql;
  SET @sql=N'IF (SELECT COUNT_BIG(*) FROM dbo.'+QUOTENAME(@tabla)+N') <> '+
   N'(SELECT COUNT_BIG(*) FROM therapyflex_crm.dbo.'+QUOTENAME(@tabla)+N') '+
   N'THROW 50005,N''Los conteos no coinciden.'',1;';
  EXEC sys.sp_executesql @sql;
  SET @n+=1;
 END;
 COMMIT;
 PRINT N'Copia completada. Los conteos de las nueve tablas coinciden. Origen sin modificar.';
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO
