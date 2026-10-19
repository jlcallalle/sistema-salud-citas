# TherapyFlex — Proyecto final de modelamiento de datos

Autor: Jorge. Motor: Microsoft SQL Server. Fecha de preparación: 19/10/2026.

Sistema de gestión de pacientes, citas, sesiones clínicas, archivos, pagos, facturas y reseñas. Se adopta la organización académica de la guía del profesor (caso, diccionario, DDL, DML y laboratorio) y el contexto de TherapyFlex. No se trasladan entidades bancarias ni se presenta recaudación como rentabilidad.

## Contenido

| Recurso | Finalidad |
|---|---|
| [Caso propuesto](Caso%20Propuesto/README.md) | Alcance, entidades, cardinalidades, reglas y diferencias entre modelos |
| [Diccionario](diccionario.md) | Todas las columnas, tipos, nulabilidad y valores predeterminados del servidor |
| Modelo Entidad Relacion / Modelo Lógico / Modelo Físico | Diagramas originales de TherapyFlex; consultar diferencias documentadas |
| [DDL](DDL/create_database_Pdan8_Academico.sql) | Instalación del modelo original: 9 tablas, 12 FK, 17 índices explícitos |
| [DML](DML/insert_data_Pdan8_Academico.sql) | Datos ficticios, exclusivamente en la base de demostración vacía |
| Consultas de Negocio | Once consultas individuales y un consolidado de ocho consultas |
| [Laboratorio](laboratorio/README.md) | Función, procedimiento, vista y ejercicios adaptados |

## Ejecución

Base de trabajo para consultas y laboratorio: **Pdan8_Academico**. En SSMS ejecutar archivos completos, respetando GO:

1. DDL/create_database_Pdan8_Academico.sql: crea la base y las tablas si aún no están instaladas.
2. DML/insert_data_Pdan8_Academico.sql: carga datos ficticios; requiere tablas vacías. Omitir si ya se cargaron.
3. laboratorio/objetos_demo.sql: crea o actualiza función, vista y procedimiento en Pdan8_Academico.
4. validacion/pruebas_demo.sql: comprueba los resultados esperados de esa carga ficticia.
5. laboratorio/consultas_demo.sql: ejecuta las once consultas; también pueden ejecutarse individualmente desde Consultas de Negocio.

Los nombres de archivo que contienen demo se conservan, pero las consultas, objetos y pruebas ya apuntan a Pdan8_Academico. validacion/inspeccionar_base.sql conserva su destino therapyflex_crm porque documenta la base original. Los resultados guardados previamente corresponden a las bases y ejecuciones indicadas dentro de cada archivo; no son evidencia de ejecución en Pdan8_Academico.

El DDL y DML originales se conservan para sus destinos anteriores. No son scripts de migración.
## Definiciones de los indicadores

Pagos = SUM(payments.amount), con fecha paid_at. Confirmar esa semántica con la aplicación. No sumar amount y total_amount. Saldo de factura = total - paid_amount; no existe conciliación automática con payments. Servicios = texto de invoice_items.description. Procedencia web = patients.from_website; no representa canal comercial detallado. Usuario creador no equivale a fisioterapeuta. El modelo no contiene costos ni moneda: no permite calcular rentabilidad ni afirmar moneda sin información adicional.

La guía del profesor no incluye aquí una rúbrica de evaluación comprobada. La carpeta cubre sus categorías de archivos, pero no implica que el profesor exija cada uno de sus ejercicios bancarios.
Para ejecutar las once consultas sobre datos ficticios sin editar archivos, usar [consultas_demo.sql](laboratorio/consultas_demo.sql).


## Prueba con Pdan8_Academico

Para usar este nombre sin modificar los scripts anteriores, ejecutar completos en SSMS y en este orden:

1. [DDL Pdan8_Academico](DDL/create_database_Pdan8_Academico.sql): crea la base si no existe y las nueve tablas. Se detiene si ya existe alguna tabla del modelo.
2. [DML Pdan8_Academico](DML/insert_data_Pdan8_Academico.sql): carga los datos ficticios en las tablas vacías. No borra datos existentes.

Estos archivos fueron generados cambiando el nombre de destino del esquema y la carga de demostración ya probados. No se ejecutaron sobre Pdan8_Academico al generarlos. Las consultas de negocio, los objetos del laboratorio y validacion/pruebas_demo.sql ya apuntan a Pdan8_Academico. La actualización de referencias se verificó sin ejecutar los scripts en el servidor.

## Estado actual: datos reales

Se sustituyó la demostración de Pdan8_Academico por una copia local de las nueve tablas de therapyflex_crm. Se verificaron conteos iguales durante la transacción: 238 pacientes, 873 citas, 162 pagos, 5 sesiones, 1 archivo, 70 reseñas, 3 usuarios, 0 facturas y 0 detalles. El origen no se modificó. La copia es puntual, no una sincronización automática.

El script utilizado es DML/copiar_datos_reales_Pdan8_Academico.sql. No incluye registros personales literales: lee del servidor local. Solo acepta un destino vacío o la demostración inicial; no sirve para sobrescribir libremente datos reales.

Para trabajar ahora, ejecutar las consultas de negocio o laboratorio/consultas_demo.sql, que ya apuntan a Pdan8_Academico. El nombre demo del archivo no determina los datos consultados. No ejecutar el DML ficticio ni validacion/pruebas_demo.sql: sus valores esperados corresponden exclusivamente a la demostración anterior. Las consultas de facturas y servicios seguirán vacías porque tampoco hay esas filas en el origen. session_files copia metadatos y rutas, no el contenido de los archivos.
