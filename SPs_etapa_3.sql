USE terminal_automotriz;
DROP PROCEDURE IF EXISTS sp_crearVehiculosPedidos;
DROP PROCEDURE IF EXISTS sp_iniciarMontajeVehiculo;
DROP PROCEDURE IF EXISTS sp_avanzarVehiculoEstacion;

DELIMITER //
-- =========== PUNTO 3(a) =========== --
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

-- =========== PUNTO 3(b) =========== --

CREATE PROCEDURE sp_iniciarMontajeVehiculo(
    IN p_num_chasis VARCHAR(17),
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256),
    OUT p_chasis_ocupante VARCHAR(17)
)
BEGIN
    DECLARE v_id_modelo INT;
    DECLARE v_id_linea INT;
    DECLARE v_id_estacion_1 INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET nResultado = -1;
        SET cMensaje = 'Error inesperado al iniciar el montaje del vehículo.';
    END;

    SET nResultado = 0;
    SET cMensaje = '';
    SET p_chasis_ocupante = '';

    -- 1. Validaciones previas
    IF NOT EXISTS (SELECT 1 FROM vehiculo WHERE num_chasis = p_num_chasis) THEN
        SET nResultado = -2;
        SET cMensaje = 'El vehículo especificado no existe.';
    ELSEIF EXISTS (SELECT 1 FROM vehiculo WHERE num_chasis = p_num_chasis AND fecha_fin IS NOT NULL) THEN
        SET nResultado = -3;
        SET cMensaje = 'El vehículo ya completó previamente su proceso de fabricación.';
    ELSEIF EXISTS (SELECT 1 FROM registro_vehiculo_estacion WHERE num_chasis = p_num_chasis AND fecha_hora_egreso IS NULL) THEN
        SET nResultado = -4;
        SET cMensaje = 'El vehículo ya se encuentra ingresado en una estación de montaje activa.';
    ELSE
        -- 2. Obtener el modelo y la línea de montaje asociada
        SELECT v.id_modelo, l.id_linea 
        INTO v_id_modelo, v_id_linea
        FROM vehiculo v
        INNER JOIN linea_montaje l ON v.id_modelo = l.id_modelo
        WHERE v.num_chasis = p_num_chasis;

        -- 3. Obtener el id_estacion correspondiente a orden = 1
        SELECT id_estacion INTO v_id_estacion_1
        FROM estacion_trabajo
        WHERE id_linea = v_id_linea AND orden = 1
        LIMIT 1;

        IF v_id_estacion_1 IS NULL THEN
            SET nResultado = -5;
            SET cMensaje = 'No se encontró la estación inicial (orden 1) para la línea de montaje de este vehículo.';
        -- 4. Validar si la estación 1 está ocupada por otro vehículo
        ELSEIF EXISTS (SELECT 1 FROM registro_vehiculo_estacion WHERE id_estacion = v_id_estacion_1 AND fecha_hora_egreso IS NULL) THEN
            -- Informar el chasis del vehículo que ocupa la estación de trabajo
            SELECT num_chasis INTO p_chasis_ocupante
            FROM registro_vehiculo_estacion
            WHERE id_estacion = v_id_estacion_1 AND fecha_hora_egreso IS NULL
            LIMIT 1;

            SET nResultado = -6;
            SET cMensaje = CONCAT('La estación inicial (1) de la línea de montaje se encuentra ocupada por el vehículo ', COALESCE(p_chasis_ocupante, ''), '.');
        ELSE
            -- 5. Insertar el inicio del recorrido
            START TRANSACTION;

            INSERT INTO registro_vehiculo_estacion (num_chasis, id_estacion, fecha_hora_ingreso)
            VALUES (p_num_chasis, v_id_estacion_1, NOW());

            COMMIT;

            SET cMensaje = 'Vehículo ingresado a la estación inicial (1) de montaje exitosamente.';
        END IF;
    END IF;
END//

-- =========== PUNTO 3(c) =========== --

CREATE PROCEDURE sp_avanzarVehiculoEstacion(
    IN p_num_chasis VARCHAR(17),
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    DECLARE v_id_estacion_actual INT;
    DECLARE v_orden_actual INT;
    DECLARE v_id_linea INT;
    DECLARE v_id_siguiente_estacion INT;
    DECLARE v_chasis_ocupante VARCHAR(17);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET nResultado = -1;
        SET cMensaje = 'Error inesperado al avanzar el vehículo de estación.';
    END;

    SET nResultado = 0;
    SET cMensaje = '';

    -- 1. Validar existencia del vehículo
    IF NOT EXISTS (SELECT 1 FROM vehiculo WHERE num_chasis = p_num_chasis) THEN
        SET nResultado = -2;
        SET cMensaje = 'El vehículo especificado no existe.';
    ELSE
        -- 2. Obtener la estación activa actual del vehículo
       SELECT 
    r.id_estacion, e.orden, e.id_linea
INTO v_id_estacion_actual , v_orden_actual , v_id_linea FROM
    registro_vehiculo_estacion r
        INNER JOIN
    estacion_trabajo e ON r.id_estacion = e.id_estacion
WHERE
    r.num_chasis = p_num_chasis
        AND r.fecha_hora_egreso IS NULL
LIMIT 1;

        IF v_id_estacion_actual IS NULL THEN
            SET nResultado = -3;
            SET cMensaje = 'El vehículo no se encuentra activo en ninguna estación (debe iniciar montaje o ya finalizó).';
        ELSE
            -- 3. Buscar la siguiente estación en la secuencia de la línea
            SELECT id_estacion INTO v_id_siguiente_estacion
            FROM estacion_trabajo
            WHERE id_linea = v_id_linea AND orden = v_orden_actual + 1
            LIMIT 1;

            -- 4. Evaluar si existe una siguiente estación o si era la última
            IF v_id_siguiente_estacion IS NOT NULL THEN
                -- Validar si la siguiente estación está ocupada por otro vehículo
                IF EXISTS (SELECT 1 FROM registro_vehiculo_estacion WHERE id_estacion = v_id_siguiente_estacion AND fecha_hora_egreso IS NULL) THEN
                    -- Informar el chasis del vehículo que ocupa la estación de trabajo
                    SELECT num_chasis INTO v_chasis_ocupante
                    FROM registro_vehiculo_estacion
                    WHERE id_estacion = v_id_siguiente_estacion AND fecha_hora_egreso IS NULL
                    LIMIT 1;

                    SET nResultado = -4;
                    SET cMensaje = CONCAT('No se puede avanzar: la estación ', v_orden_actual + 1, ' se encuentra ocupada por el vehículo ', COALESCE(v_chasis_ocupante, ''), '.');
                ELSE
                    START TRANSACTION;

                    -- Egreso de la estación actual
                    UPDATE registro_vehiculo_estacion
                    SET fecha_hora_egreso = NOW()
                    WHERE num_chasis = p_num_chasis AND id_estacion = v_id_estacion_actual AND fecha_hora_egreso IS NULL;

                    -- Ingreso a la siguiente estación
                    INSERT INTO registro_vehiculo_estacion (num_chasis, id_estacion, fecha_hora_ingreso)
                    VALUES (p_num_chasis, v_id_siguiente_estacion, NOW());

                    COMMIT;

                    SET cMensaje = CONCAT('Vehículo avanzado con éxito a la estación de orden ', v_orden_actual + 1, '.');
                END IF;
            ELSE
                -- Era la última estación: finalizar fabricación del vehículo
                START TRANSACTION;

                -- Egreso de la última estación
                UPDATE registro_vehiculo_estacion
                SET fecha_hora_egreso = NOW()
                WHERE num_chasis = p_num_chasis AND id_estacion = v_id_estacion_actual AND fecha_hora_egreso IS NULL;

                -- Registro de fecha de finalización en el vehículo
                UPDATE vehiculo
                SET fecha_fin = NOW()
                WHERE num_chasis = p_num_chasis;

                COMMIT;

                SET cMensaje = 'El vehículo completó la última estación de la línea y finalizó su proceso de fabricación.';
            END IF;
        END IF;
    END IF;
END//

DELIMITER ;


-- ============================================================
-- CASOS DE PRUEBA: sp_crearVehiculosPedidos
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


-- ============================================================================
-- CASOS DE PRUEBA: sp_iniciarMontajeVehiculo
-- ============================================================================

-- A) Seleccionar un chasis nuevo que NO haya ingresado a montaje todavía
SELECT num_chasis INTO @chasis_1
FROM vehiculo v
WHERE NOT EXISTS (
    SELECT 1 FROM registro_vehiculo_estacion r WHERE r.num_chasis = v.num_chasis
) AND v.fecha_fin IS NULL
LIMIT 1;

-- B) Seleccionar un SEGUNDO chasis del MISMO modelo para la prueba de estación ocupada
SELECT num_chasis INTO @chasis_2
FROM vehiculo v
WHERE v.id_modelo = (SELECT id_modelo FROM vehiculo WHERE num_chasis = @chasis_1)
  AND v.num_chasis <> @chasis_1
  AND NOT EXISTS (
      SELECT 1 FROM registro_vehiculo_estacion r WHERE r.num_chasis = v.num_chasis
  ) AND v.fecha_fin IS NULL
LIMIT 1;

-- C) Seleccionar (si existe) un chasis ya finalizado
SELECT num_chasis INTO @chasis_finalizado
FROM vehiculo
WHERE fecha_fin IS NOT NULL
LIMIT 1;


-- ----------------------------------------------------------------------------
-- PRUEBA 1: Éxito - Ingreso correcto a la Estación 1 (Esperado: Resultado = 0)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

SET @ocupa = '';
CALL sp_iniciarMontajeVehiculo(@chasis_1, @res, @msj, @ocupa);
SELECT 'Prueba 1 (Éxito)' AS Test, @chasis_1 AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

-- Verificación del registro generado
SELECT * FROM registro_vehiculo_estacion 
WHERE num_chasis = @chasis_1 AND fecha_hora_egreso IS NULL;


-- ----------------------------------------------------------------------------
-- PRUEBA 2: Error - Vehículo Inexistente (Esperado: Resultado = -2)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

SET @ocupa = '';
CALL sp_iniciarMontajeVehiculo('INEXISTENTE', @res, @msj, @ocupa);
SELECT 'Prueba 2 (Inexistente)' AS Test, 'INEXISTENTE' AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;


-- ----------------------------------------------------------------------------
-- PRUEBA 3: Error - Vehículo ya Finalizado (Esperado: Resultado = -3)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

SET @ocupa = '';
CALL sp_iniciarMontajeVehiculo(@chasis_finalizado, @res, @msj, @ocupa);
SELECT 'Prueba 3 (Finalizado)' AS Test, @chasis_finalizado AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;


-- ----------------------------------------------------------------------------
-- PRUEBA 4: Error - Vehículo ya Activo en Montaje (Esperado: Resultado = -4)
-- ----------------------------------------------------------------------------
-- Intentamos ingresar de nuevo @chasis_1 que ingresó en la Prueba 1
SET @res = 0; SET @msj = '';

SET @ocupa = '';
CALL sp_iniciarMontajeVehiculo(@chasis_1, @res, @msj, @ocupa);
SELECT 'Prueba 4 (Ya Activo)' AS Test, @chasis_1 AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;


-- ----------------------------------------------------------------------------
-- PRUEBA 5: Error - Estación 1 Ocupada por Otro Auto (Esperado: Resultado = -6)
-- ----------------------------------------------------------------------------
-- Intentamos ingresar @chasis_2 mientras @chasis_1 sigue ocupando la Estación 1
SET @res = 0; SET @msj = '';

SET @ocupa = '';
CALL sp_iniciarMontajeVehiculo(@chasis_2, @res, @msj, @ocupa);
SELECT 'Prueba 5 (Estación Ocupada)' AS Test, @chasis_2 AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje, @ocupa AS Chasis_Ocupante;

-- ============================================================================
-- CASOS DE PRUEBA: sp_avanzarVehiculoEstacion
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CONDICIONES INICIALES DETERMINISTAS
-- ----------------------------------------------------------------------------
-- Estado dejado por los casos de prueba de sp_iniciarMontajeVehiculo:
--   * @chasis_1 quedó ACTIVO en la estación de orden 1.
--   * @chasis_2 nunca ingresó a montaje (su intento fue rechazado con -6).
-- A partir de ahí se fijan todos los escenarios de avance.

-- A) Chasis activo en una estación intermedia -> @chasis_1 (en orden 1)
SET @chasis_intermedio = @chasis_1;

-- B) Chasis que NO ha ingresado a montaje -> @chasis_2
SET @chasis_no_iniciado = @chasis_2;

-- C) Chasis que recorrerá toda la línea hasta la ÚLTIMA estación -> @chasis_1
SET @chasis_ultima_estacion = @chasis_1;

-- D) Chasis para el escenario de bloqueo (mismo modelo -> misma línea):
--    - @chasis_bloqueador: quedará quieto en la estación de orden 2.
--    - @chasis_bloqueado: quedará esperando en la estación de orden 1.
SELECT num_chasis INTO @chasis_bloqueador
FROM vehiculo v
WHERE v.id_modelo = (SELECT id_modelo FROM vehiculo WHERE num_chasis = @chasis_1)
  AND v.num_chasis NOT IN (@chasis_1, @chasis_2)
  AND v.fecha_fin IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM registro_vehiculo_estacion r WHERE r.num_chasis = v.num_chasis
  )
ORDER BY v.num_chasis
LIMIT 1;

SELECT num_chasis INTO @chasis_bloqueado
FROM vehiculo v
WHERE v.id_modelo = (SELECT id_modelo FROM vehiculo WHERE num_chasis = @chasis_1)
  AND v.num_chasis NOT IN (@chasis_1, @chasis_2, @chasis_bloqueador)
  AND v.fecha_fin IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM registro_vehiculo_estacion r WHERE r.num_chasis = v.num_chasis
  )
ORDER BY v.num_chasis
LIMIT 1;


-- ----------------------------------------------------------------------------
-- PRUEBA 1: Éxito - Avanzar a Siguiente Estación (Esperado: Resultado = 0)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

CALL sp_avanzarVehiculoEstacion(@chasis_intermedio, @res, @msj);
SELECT 'Prueba 1 (Avanzar Estación)' AS Test, @chasis_intermedio AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

-- Verificación: Cierre de la estación anterior e ingreso a la nueva
SELECT r.num_chasis, e.orden, r.fecha_hora_ingreso, r.fecha_hora_egreso
FROM registro_vehiculo_estacion r
INNER JOIN estacion_trabajo e ON r.id_estacion = e.id_estacion
WHERE r.num_chasis = @chasis_intermedio
ORDER BY r.fecha_hora_ingreso ASC;


-- ----------------------------------------------------------------------------
-- PRUEBA 2: Error - Vehículo Inexistente (Esperado: Resultado = -2)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

CALL sp_avanzarVehiculoEstacion('INEXISTENTE', @res, @msj);
SELECT 'Prueba 2 (Inexistente)' AS Test, 'INEXISTENTE' AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;


-- ----------------------------------------------------------------------------
-- PRUEBA 3: Error - Vehículo sin Montaje Iniciado (Esperado: Resultado = -3)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

CALL sp_avanzarVehiculoEstacion(@chasis_no_iniciado, @res, @msj);
SELECT 'Prueba 3 (No Iniciado)' AS Test, @chasis_no_iniciado AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;


-- ----------------------------------------------------------------------------
-- CONDICIONES INICIALES - PRUEBA 5: llevar a @chasis_1 a la última estación
-- ----------------------------------------------------------------------------
-- @chasis_1 quedó en la estación de orden 2 (avanzó en la Prueba 1).
-- Se lo mueve paso a paso (2 -> 3 -> 4 -> 5 -> 6) hasta la última estación.
SET @res = 0; SET @msj = '';
CALL sp_avanzarVehiculoEstacion(@chasis_1, @res, @msj);
SELECT 'Setup (a estación 3)' AS Test, @chasis_1 AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

SET @res = 0; SET @msj = '';
CALL sp_avanzarVehiculoEstacion(@chasis_1, @res, @msj);
SELECT 'Setup (a estación 4)' AS Test, @chasis_1 AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

SET @res = 0; SET @msj = '';
CALL sp_avanzarVehiculoEstacion(@chasis_1, @res, @msj);
SELECT 'Setup (a estación 5)' AS Test, @chasis_1 AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

SET @res = 0; SET @msj = '';
CALL sp_avanzarVehiculoEstacion(@chasis_1, @res, @msj);
SELECT 'Setup (a estación 6)' AS Test, @chasis_1 AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

-- Verificación: @chasis_1 quedó activo en la última estación (orden 6)
SELECT r.num_chasis, e.orden AS estacion_actual
FROM registro_vehiculo_estacion r
INNER JOIN estacion_trabajo e ON r.id_estacion = e.id_estacion
WHERE r.num_chasis = @chasis_ultima_estacion AND r.fecha_hora_egreso IS NULL;


-- ----------------------------------------------------------------------------
-- PRUEBA 5: Éxito - Finalización de Fabricación (Esperado: Resultado = 0)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

CALL sp_avanzarVehiculoEstacion(@chasis_ultima_estacion, @res, @msj);
SELECT 'Prueba 5 (Finalizar Fabricación)' AS Test, @chasis_ultima_estacion AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

-- Verificación: Controlar que fecha_fin se haya poblado en la tabla vehiculo
SELECT num_chasis, id_modelo, fecha_inicio, fecha_fin 
FROM vehiculo 
WHERE num_chasis = @chasis_ultima_estacion;


-- ----------------------------------------------------------------------------
-- CONDICIONES INICIALES - PRUEBA 4: generar el escenario de estación ocupada
-- ----------------------------------------------------------------------------
-- 1) @chasis_bloqueador entra a la línea y se queda quieto en la estación de orden 2.
SET @res = 0; SET @msj = '';
SET @ocupa = '';
CALL sp_iniciarMontajeVehiculo(@chasis_bloqueador, @res, @msj, @ocupa);
SELECT 'Setup (bloqueador en estación 1)' AS Test, @chasis_bloqueador AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

SET @res = 0; SET @msj = '';
CALL sp_avanzarVehiculoEstacion(@chasis_bloqueador, @res, @msj);
SELECT 'Setup (bloqueador a estación 2)' AS Test, @chasis_bloqueador AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

-- 2) @chasis_bloqueado entra a la estación de orden 1 (quedó libre) detrás del bloqueador.
SET @res = 0; SET @msj = '';
SET @ocupa = '';
CALL sp_iniciarMontajeVehiculo(@chasis_bloqueado, @res, @msj, @ocupa);
SELECT 'Setup (bloqueado en estación 1)' AS Test, @chasis_bloqueado AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;


-- ----------------------------------------------------------------------------
-- PRUEBA 4: Error - Siguiente Estación Ocupada (Esperado: Resultado = -4)
-- ----------------------------------------------------------------------------
SET @res = 0; SET @msj = '';

CALL sp_avanzarVehiculoEstacion(@chasis_bloqueado, @res, @msj);
SELECT 'Prueba 4 (Siguiente Ocupada)' AS Test, @chasis_bloqueado AS Chasis_Evaluado, @res AS Resultado, @msj AS Mensaje;

-- Verificación: estado final de las estaciones activas (quedan bloqueado y bloqueador)
SELECT r.num_chasis, e.id_linea, e.orden AS estacion_actual
FROM registro_vehiculo_estacion r
INNER JOIN estacion_trabajo e ON r.id_estacion = e.id_estacion
WHERE r.fecha_hora_egreso IS NULL
ORDER BY e.id_linea, e.orden;