USE terminal_automotriz;

-- ============================================================
-- ETAPA 5 - OPTIMIZACION DE REPORTES (PUNTO 9)
-- ============================================================
-- Orden de ejecucion: terminal_automotriz.sql -> SPs_etapa_3.sql -> SPs_etapa_4.sql -> este archivo.
-- Ejecutar una sola vez por base: MySQL no tiene CREATE INDEX IF NOT EXISTS,
-- y repetir el script falla por nombre de indice duplicado.

-- ------------------------------------------------------------
-- INDICE 1: estacion ocupada
-- Consulta que acelera (sp_iniciarMontajeVehiculo y sp_avanzarVehiculoEstacion):
--   SELECT 1 FROM registro_vehiculo_estacion
--   WHERE id_estacion = ? AND fecha_hora_egreso IS NULL;
-- La tabla crece con cada vehiculo que pasa por cada estacion; con el indice
-- se llega directo al unico registro abierto (egreso NULL) de la estacion.
-- ------------------------------------------------------------
CREATE INDEX idx_registro_estacion_egreso
    ON registro_vehiculo_estacion (id_estacion, fecha_hora_egreso) USING BTREE;

-- ------------------------------------------------------------
-- INDICE 2: estacion activa de un vehiculo
-- Consultas que acelera:
--   sp_iniciarMontajeVehiculo y sp_avanzarVehiculoEstacion:
--     WHERE num_chasis = ? AND fecha_hora_egreso IS NULL
--   sp_listarVehiculosPorPedido: el EXISTS y la subconsulta correlacionada
--     se ejecutan UNA VEZ POR CADA vehiculo del pedido.
-- ------------------------------------------------------------
CREATE INDEX idx_registro_chasis_egreso
    ON registro_vehiculo_estacion (num_chasis, fecha_hora_egreso) USING BTREE;

-- ------------------------------------------------------------
-- INDICE 3: vehiculos terminados por modelo (linea de montaje)
-- Consulta que acelera (sp_tiempoPromedioPorLinea):
--   FROM vehiculo v JOIN linea_montaje lm ON lm.id_modelo = v.id_modelo
--   WHERE lm.id_linea = ? AND v.fecha_fin IS NOT NULL
-- El JOIN usa id_modelo (igualdad) y el filtro de terminados usa fecha_fin.
-- ------------------------------------------------------------
CREATE INDEX idx_vehiculo_modelo_fin
    ON vehiculo (id_modelo, fecha_fin) USING BTREE;
