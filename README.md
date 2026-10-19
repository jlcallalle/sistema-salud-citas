# TherapyFlex — Proyecto final de modelamiento de datos

Autor: Jorge. Motor: Microsoft SQL Server. Fecha de preparación: 19/10/2026.

Sistema de gestión de pacientes, citas, sesiones clínicas, archivos, pagos, facturas y reseñas. Se adopta la organización académica de la guía del profesor (caso, diccionario, DDL, DML y laboratorio) y el contexto de TherapyFlex. No se trasladan entidades bancarias ni se presenta recaudación como rentabilidad.

## Contenido

| Recurso | Finalidad |
|---|---|
| [Caso propuesto](Caso%20Propuesto/README.md) | Alcance, entidades, cardinalidades, reglas y diferencias entre modelos |
| [Diccionario](diccionario.md) | Todas las columnas, tipos, nulabilidad y valores predeterminados del servidor |
| Modelo Entidad Relacion / Modelo Lógico / Modelo Físico | Diagramas originales de TherapyFlex; consultar diferencias documentadas |
| [DDL](DDL/create_database.sql) | Instalación del modelo original: 9 tablas, 12 FK, 17 índices explícitos |
| [DDL de demostración](DDL/create_database_demo.sql) | Mismo esquema en therapyflex_academico_demo |
| [DML](DML/insert_data.sql) | Datos ficticios, exclusivamente en la base de demostración vacía |
| Consultas de Negocio | Once consultas individuales y un consolidado de ocho consultas |
| [Laboratorio](laboratorio/README.md) | Función, procedimiento, vista y ejercicios adaptados |
| [Validación y pendientes](validacion/PENDIENTES.md) | Evidencia de servidor, limitaciones y pasos de cierre |

## Ejecución

En SSMS ejecutar archivos completos, respetando GO.

1. Para una instalación académica reproducible: ejecutar DDL/create_database_demo.sql y luego DML/insert_data.sql. No requiere copiar datos de pacientes reales.
2. Ejecutar laboratorio/objetos_demo.sql y validacion/pruebas_demo.sql sobre la base de demostración.
3. Para aplicar las consultas de negocio a la demostración, cambiar solamente USE [therapyflex_crm] y la comprobación DB_NAME() a therapyflex_academico_demo en una copia. Los archivos originales consultan la base existente.
4. Para tu base actual: no volver a ejecutar el DDL ni el DML. Ejecutar únicamente las consultas de lectura y validacion/inspeccionar_base.sql.

El DDL original se conserva para recrear la estructura en una instancia sin esas tablas; no es una actualización. El DML aborta si encuentra datos y no contiene limpieza ni borrados.

## Definiciones de los indicadores

Pagos = SUM(payments.amount), con fecha paid_at. Confirmar esa semántica con la aplicación. No sumar amount y total_amount. Saldo de factura = total - paid_amount; no existe conciliación automática con payments. Servicios = texto de invoice_items.description. Procedencia web = patients.from_website; no representa canal comercial detallado. Usuario creador no equivale a fisioterapeuta. El modelo no contiene costos ni moneda: no permite calcular rentabilidad ni afirmar moneda sin información adicional.

La guía del profesor no incluye aquí una rúbrica de evaluación comprobada. La carpeta cubre sus categorías de archivos, pero no implica que el profesor exija cada uno de sus ejercicios bancarios.
Para ejecutar las once consultas sobre datos ficticios sin editar archivos, usar [consultas_demo.sql](laboratorio/consultas_demo.sql).

