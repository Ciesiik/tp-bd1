USE terminal_automotriz;

DROP PROCEDURE IF EXISTS sp_listarVehiculosPorPedido;

DELIMITER //

CREATE PROCEDURE sp_listarVehiculosPorPedido(IN p_id_pedido INT)
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SELECT 'ERROR: El pedido especificado no existe.' AS mensaje;
    ELSEIF NOT EXISTS (SELECT 1 FROM vehiculo WHERE id_pedido = p_id_pedido) THEN
        SELECT 'ERROR: El pedido existe, pero aún no se generaron los vehículos ' AS mensaje;
    ELSE
		SELECT 
		v.num_chasis AS chasis,
		IF(v.fecha_fin IS NOT NULL, 'SI', 'NO') AS finalizado,
		CASE
			WHEN v.fecha_fin IS NOT NULL THEN 'FINALIZADO'
			WHEN
				EXISTS( SELECT 
						1
					FROM
						registro_vehiculo_estacion r
					WHERE
						r.num_chasis = v.num_chasis
							AND r.fecha_hora_egreso IS NULL)
			THEN
				(SELECT 
						CONCAT('ESTACION ',
									et.orden,
									' - ',
									UPPER(t.tarea))
					FROM
						registro_vehiculo_estacion r
							INNER JOIN
						estacion_trabajo et ON et.id_estacion = r.id_estacion
							INNER JOIN
						tarea t ON t.id_tarea = et.id_tarea
					WHERE
						r.num_chasis = v.num_chasis
							AND r.fecha_hora_egreso IS NULL
					LIMIT 1)
			ELSE 'NO INGRESO A MONTAJE'
		END AS estacion_actual
		FROM vehiculo v
		WHERE v.id_pedido = p_id_pedido
		ORDER BY v.num_chasis;
	END IF;
END//

DELIMITER ;

CALL sp_listarVehiculosPorPedido(2);