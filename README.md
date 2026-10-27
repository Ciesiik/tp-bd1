# Terminal Automotriz - Base de Datos

Este repositorio contiene el trabajo del proyecto de base de datos para una terminal automotriz. El objetivo principal es modelar, crear y mantener la estructura de una base de datos relacional para gestionar concesionarias, modelos, pedidos, proveedores, compras de insumos y producción de vehículos.

## ¿Qué incluye este repositorio?

### 1) Script principal de la base de datos
- `terminal_automotriz.sql`
- Contiene la creación de la base de datos, tablas, relaciones, procedimientos almacenados y ABMs.
- Es el archivo principal para levantar el esquema del sistema.
- Se recomienda usarlo como punto de entrada para reproducir la base de datos en un entorno MySQL.

### 2) Script completo de la etapa 3 del trabajo

- `SPs_etapa_3.sql`
- Reúne la lógica de negocio productiva, transaccional y los casos de prueba de la etapa:

  - **sp_crearVehiculosPedidos**
    - Contiene la lógica para generar vehículos a partir de un pedido registrado.
    - Recorre el detalle del pedido y crea los registros de vehículos según la cantidad indicada.
    - Controla que cada pedido se procese una sola vez para evitar duplicados.
    - Valida que el pedido exista y tenga detalle cargado antes de generar.
    - Ejecuta toda la creación dentro de una transacción atómica.

  - **sp_iniciarMontajeVehiculo**
    - Contiene la lógica para ingresar formalmente un vehículo a la línea de producción.
    - Busca la línea correspondiente según el modelo del auto y lo posiciona en la estación de inicio (orden 1).
    - Valida que el vehículo exista, no haya sido finalizado previamente y no se encuentre activo.
    - Verifica que la Estación 1 esté libre antes de registrar el ingreso.

  - **sp_avanzarVehiculoEstacion**
    - Gestiona el flujo progresivo del vehículo a través de las estaciones de trabajo.
    - Determina la estación consecutiva (`orden + 1`) dentro de su línea.
    - Evalúa que la siguiente estación esté libre antes de avanzar.
    - Detecta la última estación de la línea, registrando el egreso final y la fecha de finalización (`fecha_fin`) en la tabla de vehículos.

### 3) Script completo de la etapa 4 del trabajo

- `SPs_etapa_4.sql`
- Reúne los procedimientos de reporte solicitados para la etapa 4:

  - **sp_listarVehiculosPorPedido**
    - Dado un número de pedido, lista los vehículos indicando su chasis, si se encuentra finalizado (`SI`/`NO`) y, en caso de no estarlo, en qué estación se encuentra (`ESTACION X - TAREA`).
    - Si el vehículo ya fue finalizado, muestra `FINALIZADO`. Si aún no ingresó a montaje, muestra `NO INGRESO A MONTAJE`.
    - Cuenta con validaciones para avisar si el pedido no existe o si aún no se generaron los vehículos.

  - **sp_listarInsumosPorPedido**
    - Dado un número de pedido, lista los insumos necesarios indicando código de insumo (`id_insumo`), descripción y cantidad total requerida para ese pedido.
    - Calcula el total multiplicando la cantidad por vehículo (`insumo_estacion.cantidad`) por la cantidad pedida en el detalle (`detalle_pedido_vehiculo.cantidad`), agrupando por insumo.
    - Incluye una carga mínima de datos en `insumo_estacion` para poder probar correctamente el reporte.

  - **sp_tiempoPromedioPorLinea**
    - Dada una línea de montaje, indica la cantidad de vehículos terminados y el tiempo promedio de construcción en minutos, teniendo en cuenta únicamente los vehículos con `fecha_fin` cargada.
    - Utiliza `TIMESTAMPDIFF(SECOND, fecha_inicio, fecha_fin)` para obtener mayor precisión en el cálculo.

### 4) Modelo conceptual / lógico
- `modelos.mwb`
- Es el archivo del modelo de MySQL Workbench.
- Aquí se define visualmente la estructura de la base de datos.
- Si se trabaja en el diseño, este archivo debe mantenerse sincronizado con los cambios aplicados en los scripts SQL.

### 5) Documentación y entregas del proyecto
- `TP Integrador.pdf`
- Documento del trabajo práctico integrador.
- Sirve como referencia del enunciado, requisitos funcionales y reglas del proyecto.

### 6) Diagrama visual del esquema
- `DER_terminal_automotriz.png`
- Imagen del diagrama entidad-relación generado a partir del modelo.
- Útil para entender rápidamente las tablas y sus relaciones.

---

## Cómo entender el flujo del proyecto

El repositorio se organiza alrededor de un esquema SQL que representa un sistema completo de producción y logística automotriz. La lógica principal se desarrolla en cuatro capas:

- Diseño: `modelos.mwb` y `DER_terminal_automotriz.png`
- Estructura de datos: `terminal_automotriz.sql`
- Lógica de negocio: `SPs_etapa_3.sql` (generación de vehículos, inicio y avance por estaciones de montaje)
- Reportes: `SPs_etapa_4.sql` (listado por pedido, insumos requeridos y tiempo promedio por línea de montaje)

En otras palabras:

- Si querés entender las entidades y relaciones, revisá el modelo y el diagrama.
- Si querés levantar la base de datos desde cero, ejecutá `terminal_automotriz.sql`, luego `SPs_etapa_3.sql` y finalmente `SPs_etapa_4.sql`.
- Si querés revisar una funcionalidad puntual, revisá el stored procedure o el bloque correspondiente dentro del SQL.

---

## Recomendaciones para trabajar con MySQL

1. Crear la base de datos desde el script principal ejecutando `terminal_automotriz.sql`.
2. Ejecutar `SPs_etapa_3.sql` para cargar la lógica de producción y sus casos de prueba.
3. Ejecutar `SPs_etapa_4.sql` para cargar los procedimientos de reporte y la carga mínima de `insumo_estacion`.
4. Revisar el modelo en MySQL Workbench si se necesita cambiar la estructura.
5. Si se modifican tablas o relaciones, actualizar también el script SQL.
6. Probar los procedimientos con datos de ejemplo antes de entregar cambios.
7. Mantener comentarios claros en los scripts para que otros integrantes entiendan el propósito.

---

## Flujo seguro de trabajo con ramas

Para que todos trabajen sin romper el proyecto, la rama principal debe mantenerse estable y los cambios deben hacerse en ramas de trabajo individuales.

### Regla general
- No trabajar directamente sobre `main` ni sobre `master`.
- Cada cambio debe ir en una rama específica.
- Los cambios se integran a la rama principal solo cuando están probados y revisados.

### Convención de nombres de ramas
Usá nombres claros y específicos:

- `feature/modelo-concesionaria`
- `feature/abm-proveedores`
- `fix/sp-crear-vehiculos`
- `docs/readme-proyecto`

### Flujo recomendado

```bash
git checkout main
git pull origin main
git checkout -b feature/nombre-del-cambio
```

Luego hacés tus cambios, probás y hacés commits pequeños y descriptivos:

```bash
git add .
git commit -m "Agrega procedimiento de alta de concesionaria"
```

Cuando estés listo para integrar:

```bash
git push origin feature/nombre-del-cambio
```

Y luego abrir un pull request o merge request para revisión antes de unificar con `main`.

---

## Buenas prácticas para evitar errores

- Hacer `pull` antes de empezar a trabajar.
- No hacer `push --force` salvo que exista un consenso claro y se conozca exactamente el motivo.
- No mezclar cambios no relacionados en un mismo commit.
- Si se trabaja en varias personas, mantener ramas cortas y bien definidas.
- Antes de mergear, revisar que el SQL siga siendo ejecutable y que no haya conflictos con el diseño.
- Si se hace un cambio importante en el esquema, avisar al equipo antes de fusionarlo.

### Recomendación importante
Si la rama principal está protegida, la integración debe pasar por revisión y validación antes del merge. Esto ayuda a evitar que se pierda trabajo o que un cambio de la base de datos rompa el entorno de otros compañeros.

---

## Orden recomendado para trabajar en equipo

1. Actualizar `main`.
2. Crear una rama nueva desde `main`.
3. Trabajar solo en el archivo o módulo asignado.
4. Hacer commits claros y frecuentes.
5. Revisión del cambio antes de mergear.
6. Actualizar la rama local antes de continuar con otra tarea.

---

## Pruebas rápidas (Etapa 4)

Una vez ejecutados los scripts, podés probar los reportes con:

```sql
-- Punto 6 - Listado de vehículos por pedido
CALL sp_listarVehiculosPorPedido(2);

-- Punto 7 - Insumos necesarios por pedido
CALL sp_listarInsumosPorPedido(2);

-- Punto 8 - Tiempo promedio por línea de montaje
CALL sp_tiempoPromedioPorLinea(3);
```

> Nota: Para visualizar correctamente el punto 8 con datos de prueba, puede ser necesario simular una `fecha_fin` distinta a `fecha_inicio` con un `UPDATE`, ya que los tests de la etapa 3 se ejecutan con `NOW()` y la diferencia entre ambas fechas puede resultar menor a 1 minuto.

---

## Resumen rápido

- `terminal_automotriz.sql`: base de datos completa, tablas, relaciones, ABMs y procedimientos iniciales.
- `SPs_etapa_3.sql`: lógica de producción (generación de vehículos, inicio y avance por estaciones de montaje) con casos de prueba.
- `SPs_etapa_4.sql`: procedimientos de reporte (puntos 6, 7 y 8), carga mínima en `insumo_estacion` y llamadas de prueba.
- `modelos.mwb`: diseño visual del esquema.
- `DER_terminal_automotriz.png`: diagrama del sistema.
- `TP Integrador.pdf`: referencia del trabajo práctico.
