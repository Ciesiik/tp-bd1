USE terminal_automotriz;

DROP PROCEDURE IF EXISTS sp_listarVehiculosPorPedido;
DROP PROCEDURE IF EXISTS sp_listarInsumosPorPedido;
DROP PROCEDURE IF EXISTS sp_tiempoPromedioPorLinea;

DELIMITER //

-- =========== PUNTO 6 =========== --
CREATE PROCEDURE sp_listarVehiculosPorPedido(IN p_id_pedido INT)
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SELECT 'ERROR: El pedido especificado no existe.' AS mensaje;
    ELSEIF NOT EXISTS (SELECT 1 FROM vehiculo WHERE id_pedido = p_id_pedido) THEN
        SELECT 'ERROR: El pedido existe, pero aún no se generaron los vehículos.' AS mensaje;
    ELSE
		SELECT 
			v.num_chasis AS chasis,
			IF(v.fecha_fin IS NOT NULL, 'SI', 'NO') AS finalizado,
			CASE
				WHEN v.fecha_fin IS NOT NULL THEN 'FINALIZADO'
				WHEN EXISTS(
					SELECT 1
					FROM registro_vehiculo_estacion r
					WHERE r.num_chasis = v.num_chasis AND r.fecha_hora_egreso IS NULL
				) THEN (
					SELECT CONCAT('ESTACION ', et.orden,' - ', UPPER(t.tarea))
					FROM registro_vehiculo_estacion r
					INNER JOIN estacion_trabajo et ON et.id_estacion = r.id_estacion
					INNER JOIN tarea t ON t.id_tarea = et.id_tarea
					WHERE r.num_chasis = v.num_chasis AND r.fecha_hora_egreso IS NULL
					LIMIT 1
				)
				ELSE 'NO INGRESO A MONTAJE'
			END AS estacion_actual
		FROM vehiculo v
		WHERE v.id_pedido = p_id_pedido
		ORDER BY v.num_chasis;
	END IF;
END//

DELIMITER ;


-- INSERTS A INSUMO_ESTACION CON CANTIDADES RANDOM PARA PRUEBAS --

-- ORDEN 1 - Ensamblado de chapa
INSERT IGNORE INTO insumo_estacion (id_insumo, id_estacion, cantidad)
SELECT 5, et.id_estacion, FLOOR(RAND()*3)+1
FROM estacion_trabajo et
WHERE et.orden = 1;

-- ORDEN 2 - Pintado de carrocería
INSERT IGNORE INTO insumo_estacion (id_insumo, id_estacion, cantidad)
SELECT 1, et.id_estacion, FLOOR(RAND()*3)+2
FROM estacion_trabajo et
WHERE et.orden = 2;

-- ORDEN 3 - Mecánica motor
INSERT IGNORE INTO insumo_estacion (id_insumo, id_estacion, cantidad)
SELECT 3, et.id_estacion, FLOOR(RAND()*2)+2
FROM estacion_trabajo et
WHERE et.orden = 3;

-- ORDEN 4 - Mecánica rodaje
INSERT IGNORE INTO insumo_estacion (id_insumo, id_estacion, cantidad)
SELECT 2, et.id_estacion, 4
FROM estacion_trabajo et
WHERE et.orden = 4;

-- ORDEN 5 - Electricidad
INSERT IGNORE INTO insumo_estacion (id_insumo, id_estacion, cantidad)
SELECT 3, et.id_estacion, FLOOR(RAND()*3)+4
FROM estacion_trabajo et
WHERE et.orden = 5;

INSERT IGNORE INTO insumo_estacion (id_insumo, id_estacion, cantidad)
SELECT 4, et.id_estacion, 2
FROM estacion_trabajo et
WHERE et.orden = 5;


DELIMITER //
-- =========== PUNTO 7 =========== --

CREATE PROCEDURE sp_listarInsumosPorPedido(IN p_id_pedido INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SELECT 'ERROR: El pedido especificado no existe.' AS mensaje;
    ELSEIF NOT EXISTS (SELECT 1 FROM detalle_pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SELECT 'ERROR: El pedido no tiene detalle cargado.' AS mensaje;
    ELSE
        SELECT 
            ie.id_insumo AS codigo_insumo,
            (SELECT descripcion FROM insumo WHERE insumo.id_insumo = ie.id_insumo) AS descripcion,
            SUM(ie.cantidad * dp.cantidad) AS cantidad_requerida
        FROM detalle_pedido_vehiculo dp
        JOIN linea_montaje lm ON lm.id_modelo = dp.id_modelo
        JOIN estacion_trabajo et ON et.id_linea = lm.id_linea
        JOIN insumo_estacion ie ON ie.id_estacion = et.id_estacion
        WHERE dp.id_pedido = p_id_pedido
        GROUP BY ie.id_insumo
        ORDER BY ie.id_insumo;
    END IF;
END//

-- =========== PUNTO 8 =========== --
CREATE PROCEDURE sp_tiempoPromedioPorLinea(IN p_id_linea INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM linea_montaje WHERE id_linea = p_id_linea) THEN
        SELECT 'ERROR: La línea de montaje especificada no existe.' AS mensaje;
    ELSEIF NOT EXISTS (
        SELECT 1 
        FROM vehiculo v
        JOIN linea_montaje lm ON lm.id_modelo = v.id_modelo
        WHERE lm.id_linea = p_id_linea AND v.fecha_fin IS NOT NULL
    ) THEN
        SELECT 'AVISO: No hay vehículos terminados en esta línea.' AS mensaje;
    ELSE
        SELECT p_id_linea AS id_linea,
            COUNT(*) AS cantidad_terminados,
            ROUND(AVG(TIMESTAMPDIFF(SECOND, v.fecha_inicio, v.fecha_fin) / 60.0), 2) AS promedio_minutos
        FROM vehiculo v
        JOIN linea_montaje lm ON lm.id_modelo = v.id_modelo
        WHERE lm.id_linea = p_id_linea AND v.fecha_fin IS NOT NULL;
    END IF;
END//

DELIMITER ;

CALL sp_listarVehiculosPorPedido(2);
CALL sp_listarInsumosPorPedido(2);
-- Actualizacion del tiempo de finalizacion con fines de prueba mas realistas:
-- los vehiculos terminados pasan a tener un tiempo de construccion de 150 minutos.
-- Se desactiva el modo seguro solo para este UPDATE (el WHERE no usa la clave primaria).
SET SQL_SAFE_UPDATES = 0;
UPDATE vehiculo SET fecha_fin = DATE_ADD(fecha_inicio, INTERVAL 150 MINUTE) WHERE fecha_fin IS NOT NULL;
SET SQL_SAFE_UPDATES = 1;
CALL sp_tiempoPromedioPorLinea(3);