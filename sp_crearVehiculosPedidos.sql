USE terminal_automotriz;

DELIMITER //
CREATE PROCEDURE sp_crearVehiculosPedidos(
	IN p_id_pedido INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
	DECLARE fin BOOL DEFAULT FALSE;
    DECLARE v_id_modelo INT;
    DECLARE v_cantidad INT;
    DECLARE v_chasis VARCHAR(17);
    
    -- Cursor para recorrer las filas del detalle pedido
	DECLARE cur CURSOR FOR 
    SELECT id_modelo, cantidad 
    FROM detalle_pedido_vehiculo
    WHERE id_pedido = p_id_pedido;
    
    -- Declarar el NOT FOUND (EOF) handler
    DECLARE CONTINUE HANDLER
    FOR NOT FOUND SET fin = TRUE;
    
    SET nResultado = 0;
    SET cMensaje = '';
    
    -- Validamos el pedido
    IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
		SET nResultado = -1;
        SET cMensaje = 'El pedido especificado no existe.';
	ELSE    
		-- Abrir el cursor
		OPEN cur;
    
		insertar_vehiculos: LOOP
			FETCH cur INTO v_id_modelo, v_cantidad;
        
			-- Condición de salida del loop
			IF fin THEN
				LEAVE insertar_vehiculos;
			END IF;
			
			-- Bucle para crear la cantidad especifica de un modelo
			WHILE v_cantidad > 0 DO
				
				-- Número de chasis aleatorio (simil VIN)
				REPEAT
						SET v_chasis = UPPER(LEFT(MD5(RAND()), 17));
					UNTIL NOT EXISTS (SELECT 1 FROM vehiculo WHERE num_chasis = v_chasis)
				END REPEAT;
				
				-- Insertar vehiculo
				INSERT INTO vehiculo(num_chasis, id_modelo, fecha_inicio, fecha_fin)
				VALUES (v_chasis, v_id_modelo, NOW(), NULL);
				
				SET v_cantidad = v_cantidad - 1;
				
			END WHILE;
        
		END LOOP insertar_vehiculos;
    
		CLOSE cur;
    
		SET cMensaje = 'Vehiculos creados exitosamente.';
    END IF;
END//

DELIMITER ;