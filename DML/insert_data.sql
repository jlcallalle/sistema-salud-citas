-- Datos totalmente ficticios. Solo para la base académica vacía.
USE [therapyflex_academico_demo];
GO
SET XACT_ABORT ON;
IF DB_NAME()<>N'therapyflex_academico_demo' THROW 50001,N'Base incorrecta.',1;
IF EXISTS(SELECT 1 FROM dbo.users) OR EXISTS(SELECT 1 FROM dbo.patients)
 OR EXISTS(SELECT 1 FROM dbo.google_reviews)
 THROW 50002,N'La demostración debe estar vacía. No se borran datos.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @u uniqueidentifier=NEWID(),@p1 uniqueidentifier=NEWID(),@p2 uniqueidentifier=NEWID(),@p3 uniqueidentifier=NEWID();
 DECLARE @a1 uniqueidentifier=NEWID(),@s1 uniqueidentifier=NEWID(),@f1 uniqueidentifier=NEWID(),@f2 uniqueidentifier=NEWID(),@f3 uniqueidentifier=NEWID();
 INSERT dbo.users(id,email) VALUES(@u,N'demo@example.invalid');
 INSERT dbo.patients(id,full_name,from_website,created_by,created_at)
 VALUES(@p1,N'Paciente ficticio A',1,@u,'2026-09-01T09:00:00-05:00'),
 (@p2,N'Paciente ficticio B',0,@u,'2026-09-02T09:00:00-05:00'),
 (@p3,N'Paciente ficticio C',1,@u,'2026-10-01T09:00:00-05:00');
 INSERT dbo.appointments(id,patient_id,appointment_date,physiotherapist,status)
 VALUES(@a1,@p1,'2026-09-10T09:00:00-05:00',N'Profesional demo',N'atendido'),
 (NEWID(),@p2,'2026-10-10T10:00:00-05:00',N'Profesional demo',N'programado'),
 (NEWID(),@p3,'2026-10-11T10:00:00-05:00',N'Profesional demo',N'cancelado');
 INSERT dbo.sessions(id,patient_id,session_date,evolution,pain_eva,treatment,created_by)
 VALUES(@s1,@p1,'2026-09-10T09:00:00-05:00',N'Ejemplo académico sin información clínica real',3,N'Tratamiento ficticio',@u);
 INSERT dbo.session_files(session_id,patient_id,file_name,file_path,file_type,size_bytes)
 VALUES(@s1,@p1,N'demo.txt',N'demo/no-existe.txt',N'otro',0);
 INSERT dbo.payments(patient_id,appointment_id,paid_at,payment_date,amount,total_amount,amount_per_session,created_by)
 VALUES(@p1,@a1,'2026-09-10','2026-09-10',100,100,100,@u),
 (@p1,NULL,'2026-10-10','2026-10-10',150,150,150,@u),
 (@p2,NULL,'2026-10-10','2026-10-10',100,100,100,@u);
 INSERT dbo.invoices(id,invoice_number,patient_id,issue_date,status,subtotal,total,paid_amount,created_by)
 VALUES(@f1,N'DEMO-001',@p1,'2026-09-10',N'pagada',250,250,250,@u),
 (@f2,N'DEMO-002',@p2,'2026-10-10',N'pendiente',250,250,100,@u),
 (@f3,N'DEMO-003',@p3,'2026-10-11',N'cancelada',50,50,0,@u);
 INSERT dbo.invoice_items(invoice_id,service_date,description,quantity,unit_price,total)
 VALUES(@f1,'2026-09-10',N'Sesión demostrativa',2,125,250),
 (@f2,'2026-10-10',N'Sesión demostrativa',2,125,250),
 (@f3,'2026-10-11',N'Evaluación demostrativa',1,50,50);
 INSERT dbo.google_reviews(google_review_id,reviewer_name,star_rating,comment,source)
 VALUES(N'demo-review-001',N'Autor ficticio',5,N'Reseña de prueba',N'manual');
 COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
GO