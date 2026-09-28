USE terminal_automotriz;

DROP PROCEDURE IF EXISTS sp_crearVehiculosPedidos;

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
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin = TRUE;

    -- Cualquier error inesperado dispara el rollback.
    -- Sin esto, un fallo en la mitad del loop dejaria vehiculos ya insertados
    -- y la comprobacion de "ya generado" bloquearia el pedido para siempre.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET nResultado = -4;
        SET cMensaje = 'Error inesperado al crear los vehiculos del pedido.';
    END;

    SET nResultado = 0;
    SET cMensaje = '';

    -- Validamos el pedido
    IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
		SET nResultado = -1;
        SET cMensaje = 'El pedido especificado no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM detalle_pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
		SET nResultado = -2;
        SET cMensaje = 'El pedido no tiene detalle cargado, no se pueden crear vehiculos.';
    -- El pedido ya fue procesado: cada vehiculo guarda a que pedido pertenece,
    -- asi que alcanza con verificar si ya tiene vehiculos asociados.
    ELSEIF EXISTS (SELECT 1 FROM vehiculo WHERE id_pedido = p_id_pedido) THEN
		SET nResultado = -3;
        SET cMensaje = 'Los vehiculos de este pedido ya fueron generados.';
    ELSE
		-- Toda la generacion es atomica: se confirma completa o no queda nada.
		START TRANSACTION;

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
				INSERT INTO vehiculo(num_chasis, id_modelo, id_pedido, fecha_inicio, fecha_fin)
				VALUES (v_chasis, v_id_modelo, p_id_pedido, NOW(), NULL);

				SET v_cantidad = v_cantidad - 1;

			END WHILE;

		END LOOP insertar_vehiculos;

		CLOSE cur;

		COMMIT;

		SET cMensaje = 'Vehiculos creados exitosamente.';
    END IF;
END//

DELIMITER ;


-- ============================================================
-- CASOS DE PRUEBA
-- ============================================================
-- Requisito: ejecutar terminal_automotriz.sql primero, para tener
-- los datos de prueba cargados (concesionarias, modelos y pedidos).

-- --- EJECUCION UNICA DEL SP POR PEDIDO ---

-- Éxito: el pedido 2 pide 10 unidades del modelo 3
CALL sp_crearVehiculosPedidos(2, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Exito_Esperado;

-- Verificación: 10 vehiculos del modelo 3, todos del pedido 2
SELECT id_pedido, id_modelo, COUNT(*) AS generados
FROM vehiculo
GROUP BY id_pedido, id_modelo;

-- Error: segunda ejecución sobre el mismo pedido
CALL sp_crearVehiculosPedidos(2, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Verificación: la segunda llamada no duplicó vehiculos
SELECT COUNT(*) AS vehiculos_del_pedido_2_esperado_10
FROM vehiculo
WHERE id_pedido = 2;


-- --- VALIDACIONES DE ENTRADA ---

-- Error: pedido inexistente
CALL sp_crearVehiculosPedidos(999, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Error: pedido sin detalle cargado
-- Se crea un pedido nuevo (id 6) y se intenta generar sin detalle
CALL sp_altaPedidoVehiculo(1, '2027-01-15', @res, @msj);
SELECT @res AS Resultado, @msj AS Alta_Pedido_Exito;
CALL sp_crearVehiculosPedidos(6, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;


-- --- DETALLE BLOQUEADO UNA VEZ GENERADOS LOS VEHICULOS ---
-- El pedido 2 ya tiene vehiculos, asi que su detalle queda congelado.

-- Error: agregar un modelo a un pedido ya generado
CALL sp_altaDetallePedidoVehiculo(2, 1, 5, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Error: modificar la cantidad de un pedido ya generado
CALL sp_modificacionDetallePedidoVehiculo(2, 3, 20, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Error: eliminar el detalle de un pedido ya generado
CALL sp_bajaDetallePedidoVehiculo(2, 3, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;


-- --- ESTADO FINAL ---
SELECT id_pedido, id_modelo, COUNT(*) AS generados
FROM vehiculo
GROUP BY id_pedido, id_modelo
ORDER BY id_pedido, id_modelo;
