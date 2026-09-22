# Terminal Automotriz - Base de Datos

Este repositorio contiene el trabajo del proyecto de base de datos para una terminal automotriz. El objetivo principal es modelar, crear y mantener la estructura de una base de datos relacional para gestionar concesionarias, modelos, pedidos, proveedores, compras de insumos y producción de vehículos.

## ¿Qué incluye este repositorio?

### 1) Script principal de la base de datos
- `terminal_automotriz.sql`
- Contiene la creación de la base de datos, tablas, relaciones, procedimientos almacenados y ABMs.
- Es el archivo principal para levantar el esquema del sistema.
- Se recomienda usarlo como punto de entrada para reproducir la base de datos en un entorno MySQL.

### 2) Stored procedure de creación de vehículos
- `sp_crearVehiculosPedidos.sql`
- Contiene la lógica para generar vehículos a partir de un pedido registrado.
- Permite recorrer el detalle del pedido y crear registros de vehículos según la cantidad indicada.
- Es un script específico para una funcionalidad de negocio del sistema.

### 3) Modelo conceptual / lógico
- `modelos.mwb`
- Es el archivo del modelo de MySQL Workbench.
- Aquí se define visualmente la estructura de la base de datos.
- Si se trabaja en el diseño, este archivo debe mantenerse sincronizado con los cambios aplicados en los scripts SQL.

### 4) Documentación y entregas del proyecto
- `TP Integrador.pdf`
- Documento del trabajo práctico integrador.
- Sirve como referencia del enunciado, requisitos funcionales y reglas del proyecto.

### 5) Diagrama visual del esquema
- `DER_terminal_automotriz.png`
- Imagen del diagrama entidad-relación generado a partir del modelo.
- Útil para entender rápidamente las tablas y sus relaciones.

---

## Cómo entender el flujo del proyecto

El repositorio se organiza alrededor de un esquema SQL que representa un sistema completo de producción y logística automotriz. La lógica principal se desarrolla en tres capas:

- Diseño: `modelos.mwb` y `DER_terminal_automotriz.png`
- Estructura de datos: `terminal_automotriz.sql`
- Lógica de negocio: `sp_crearVehiculosPedidos.sql` y otros procedimientos dentro del script principal

En otras palabras:

- Si querés entender las entidades y relaciones, revisá el modelo y el diagrama.
- Si querés levantar la base de datos desde cero, ejecutá `terminal_automotriz.sql`.
- Si querés revisar una funcionalidad puntual, revisá el stored procedure o el bloque correspondiente dentro del SQL.

---

## Recomendaciones para trabajar con MySQL

1. Crear la base de datos desde el script principal.
2. Revisar el modelo en MySQL Workbench si se necesita cambiar la estructura.
3. Si se modifican tablas o relaciones, actualizar también el script SQL.
4. Probar los procedimientos con datos de ejemplo antes de entregar cambios.
5. Mantener comentarios claros en los scripts para que otros integrantes entiendan el propósito.

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

## Resumen rápido

- `terminal_automotriz.sql`: base de datos completa y procedimientos.
- `sp_crearVehiculosPedidos.sql`: lógica de generación de vehículos por pedido.
- `modelos.mwb`: diseño visual del esquema.
- `DER_terminal_automotriz.png`: diagrama del sistema.
- `TP Integrador.pdf`: referencia del trabajo práctico.
