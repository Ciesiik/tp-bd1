DROP DATABASE terminal_automotriz;
CREATE DATABASE IF NOT EXISTS terminal_automotriz;
USE terminal_automotriz;

CREATE TABLE concesionaria (
  id_concesionaria INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  direccion VARCHAR(100) NOT NULL,
  telefono INT NULL
);

CREATE TABLE modelo (
  id_modelo INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL
);

CREATE TABLE linea_montaje (
  id_linea INT AUTO_INCREMENT PRIMARY KEY,
  id_modelo INT NOT NULL UNIQUE,
  capacidad_mensual INT NOT NULL,
  FOREIGN KEY (id_modelo) REFERENCES modelo(id_modelo)
);

CREATE TABLE tarea (
  id_tarea INT AUTO_INCREMENT PRIMARY KEY,
  tarea VARCHAR(45) NOT NULL
);

CREATE TABLE estacion_trabajo (
  id_estacion INT AUTO_INCREMENT PRIMARY KEY,
  id_linea INT NOT NULL,
  orden INT NOT NULL,
  id_tarea INT NOT NULL,
  FOREIGN KEY (id_linea) REFERENCES linea_montaje(id_linea),
  FOREIGN KEY (id_tarea) REFERENCES tarea(id_tarea)
);

CREATE TABLE vehiculo (
  num_chasis VARCHAR(17) PRIMARY KEY,
  id_modelo INT NOT NULL,
  fecha_inicio DATETIME NOT NULL,
  fecha_fin DATETIME NULL,
  FOREIGN KEY (id_modelo) REFERENCES modelo(id_modelo)
);

CREATE TABLE registro_vehiculo_estacion (
  id_registro INT AUTO_INCREMENT PRIMARY KEY,
  num_chasis VARCHAR(17) NOT NULL,
  id_estacion INT NOT NULL,
  fecha_hora_ingreso DATETIME NOT NULL,
  fecha_hora_egreso DATETIME NULL,
  FOREIGN KEY (num_chasis) REFERENCES vehiculo(num_chasis),
  FOREIGN KEY (id_estacion) REFERENCES estacion_trabajo(id_estacion)
);

CREATE TABLE insumo (
  id_insumo INT AUTO_INCREMENT PRIMARY KEY,
  descripcion VARCHAR(100) NOT NULL
);

CREATE TABLE insumo_estacion (
  id_insumo INT NOT NULL,
  id_estacion INT NOT NULL,
  cantidad INT NOT NULL,
  PRIMARY KEY (id_insumo, id_estacion),
  FOREIGN KEY (id_insumo) REFERENCES insumo(id_insumo),
  FOREIGN KEY (id_estacion) REFERENCES estacion_trabajo(id_estacion)
);

CREATE TABLE pedido_vehiculo (
  id_pedido INT AUTO_INCREMENT PRIMARY KEY,
  id_concesionaria INT NOT NULL,
  fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_entrega_esperada DATE NULL,
  FOREIGN KEY (id_concesionaria) REFERENCES concesionaria(id_concesionaria)
);

CREATE TABLE detalle_pedido_vehiculo (
  id_pedido INT NOT NULL,
  id_modelo INT NOT NULL,
  cantidad INT NOT NULL,
  PRIMARY KEY (id_pedido, id_modelo),
  FOREIGN KEY (id_pedido) REFERENCES pedido_vehiculo(id_pedido),
  FOREIGN KEY (id_modelo) REFERENCES modelo(id_modelo)
);

CREATE TABLE proveedor (
  id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
  razon_social VARCHAR(100) NOT NULL,
  direccion VARCHAR(100) NOT NULL,
  telefono INT NOT NULL
);

CREATE TABLE proveedor_insumo (
  id_proveedor INT NOT NULL,
  id_insumo INT NOT NULL,
  precio FLOAT NOT NULL,
  PRIMARY KEY (id_proveedor, id_insumo),
  FOREIGN KEY (id_proveedor) REFERENCES proveedor(id_proveedor),
  FOREIGN KEY (id_insumo) REFERENCES insumo(id_insumo)
);

CREATE TABLE compra_insumo (
  id_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_proveedor INT NOT NULL,
  fecha_compra DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_proveedor) REFERENCES proveedor(id_proveedor)
);

CREATE TABLE detalle_compra_insumo (
    id_compra INT NOT NULL,
    id_insumo INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario FLOAT NOT NULL,
    PRIMARY KEY (id_compra , id_insumo),
    FOREIGN KEY (id_compra)
        REFERENCES compra_insumo (id_compra),
    FOREIGN KEY (id_insumo)
        REFERENCES insumo (id_insumo)
);

-- ////////////////////////////////////////////////////////////////////////////////////////////////////// --
-- ej. stored procedure
DELIMITER //
CREATE PROCEDURE getModelos()
BEGIN
	SELECT * FROM modelo;
END//

DELIMITER ;

-- === ETAPA 2 - ABMs =========================================

DELIMITER //

-- ============================================================
-- 1. CONCESIONARIA
-- ============================================================

CREATE PROCEDURE sp_altaConcesionaria(
    IN p_nombre VARCHAR(50),
    IN p_direccion VARCHAR(100),
    IN p_telefono INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF EXISTS (SELECT 1 FROM concesionaria WHERE direccion = p_direccion) THEN
        SET nResultado = -1;
        SET cMensaje = 'Ya existe una concesionaria con esa dirección.';
    ELSE
        INSERT INTO concesionaria (nombre, direccion, telefono)
        VALUES (p_nombre, p_direccion, p_telefono);
    END IF;
END//

CREATE PROCEDURE sp_modificacionConcesionaria(
    IN p_id_concesionaria INT,
    IN p_nombre VARCHAR(50),
    IN p_direccion VARCHAR(100),
    IN p_telefono INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM concesionaria WHERE id_concesionaria = p_id_concesionaria) THEN
        SET nResultado = -1;
        SET cMensaje = 'La concesionaria a modificar no existe.';
    ELSE
        UPDATE concesionaria
        SET nombre = p_nombre, direccion = p_direccion, telefono = p_telefono
        WHERE id_concesionaria = p_id_concesionaria;
    END IF;
END//

CREATE PROCEDURE sp_bajaConcesionaria(
    IN p_id_concesionaria INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM concesionaria WHERE id_concesionaria = p_id_concesionaria) THEN
        SET nResultado = -1;
        SET cMensaje = 'La concesionaria a eliminar no existe.';
    ELSEIF EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_concesionaria = p_id_concesionaria) THEN
        SET nResultado = -2;
        SET cMensaje = 'No se puede eliminar la concesionaria porque tiene pedidos asociados.';
    ELSE
        DELETE FROM concesionaria WHERE id_concesionaria = p_id_concesionaria;
    END IF;
END//


-- ============================================================
-- 2. PROVEEDOR
-- ============================================================

CREATE PROCEDURE sp_altaProveedor(
    IN p_razon_social VARCHAR(100),
    IN p_direccion VARCHAR(100),
    IN p_telefono INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF EXISTS (SELECT 1 FROM proveedor WHERE razon_social = p_razon_social) THEN
        SET nResultado = -1;
        SET cMensaje = 'Ya existe un proveedor con esa razón social.';
    ELSE
        INSERT INTO proveedor (razon_social, direccion, telefono)
        VALUES (p_razon_social, p_direccion, p_telefono);
    END IF;
END//

CREATE PROCEDURE sp_modificacionProveedor(
    IN p_id_proveedor INT,
    IN p_razon_social VARCHAR(100),
    IN p_direccion VARCHAR(100),
    IN p_telefono INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM proveedor WHERE id_proveedor = p_id_proveedor) THEN
        SET nResultado = -1;
        SET cMensaje = 'El proveedor a modificar no existe.';
    ELSE
        UPDATE proveedor
        SET razon_social = p_razon_social, direccion = p_direccion, telefono = p_telefono
        WHERE id_proveedor = p_id_proveedor;
    END IF;
END//

CREATE PROCEDURE sp_bajaProveedor(
    IN p_id_proveedor INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM proveedor WHERE id_proveedor = p_id_proveedor) THEN
        SET nResultado = -1;
        SET cMensaje = 'El proveedor a eliminar no existe.';
    ELSEIF EXISTS (SELECT 1 FROM proveedor_insumo WHERE id_proveedor = p_id_proveedor) THEN
        SET nResultado = -2;
        SET cMensaje = 'No se puede eliminar el proveedor porque tiene insumos catalogados.';
    ELSEIF EXISTS (SELECT 1 FROM compra_insumo WHERE id_proveedor = p_id_proveedor) THEN
        SET nResultado = -3;
        SET cMensaje = 'No se puede eliminar el proveedor porque tiene compras asociadas.';
    ELSE
        DELETE FROM proveedor WHERE id_proveedor = p_id_proveedor;
    END IF;
END//


-- ============================================================
-- 3. INSUMO
-- ============================================================

CREATE PROCEDURE sp_altaInsumo(
    IN p_descripcion VARCHAR(100),
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF EXISTS (SELECT 1 FROM insumo WHERE descripcion = p_descripcion) THEN
        SET nResultado = -1;
        SET cMensaje = 'Ya existe un insumo con esa descripción.';
    ELSE
        INSERT INTO insumo (descripcion)
        VALUES (p_descripcion);
    END IF;
END//

CREATE PROCEDURE sp_modificacionInsumo(
    IN p_id_insumo INT,
    IN p_descripcion VARCHAR(100),
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM insumo WHERE id_insumo = p_id_insumo) THEN
        SET nResultado = -1;
        SET cMensaje = 'El insumo a modificar no existe.';
    ELSE
        UPDATE insumo
        SET descripcion = p_descripcion
        WHERE id_insumo = p_id_insumo;
    END IF;
END//

CREATE PROCEDURE sp_bajaInsumo(
    IN p_id_insumo INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM insumo WHERE id_insumo = p_id_insumo) THEN
        SET nResultado = -1;
        SET cMensaje = 'El insumo a eliminar no existe.';
    ELSEIF EXISTS (SELECT 1 FROM insumo_estacion WHERE id_insumo = p_id_insumo) THEN
        SET nResultado = -2;
        SET cMensaje = 'No se puede eliminar el insumo porque está asignado a estaciones de trabajo.';
    ELSEIF EXISTS (SELECT 1 FROM proveedor_insumo WHERE id_insumo = p_id_insumo) THEN
        SET nResultado = -3;
        SET cMensaje = 'No se puede eliminar el insumo porque pertenece a un catálogo de proveedor.';
    ELSEIF EXISTS (SELECT 1 FROM detalle_compra_insumo WHERE id_insumo = p_id_insumo) THEN
        SET nResultado = -4;
        SET cMensaje = 'No se puede eliminar el insumo porque está en un detalle de compra.';
    ELSE
        DELETE FROM insumo WHERE id_insumo = p_id_insumo;
    END IF;
END//


-- ============================================================
-- 4. PEDIDO VEHICULO (Cabecera)
-- ============================================================

CREATE PROCEDURE sp_altaPedidoVehiculo(
    IN p_id_concesionaria INT,
    IN p_fecha_entrega_esperada DATE,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM concesionaria WHERE id_concesionaria = p_id_concesionaria) THEN
        SET nResultado = -1;
        SET cMensaje = 'La concesionaria especificada no existe.';
    ELSE
        INSERT INTO pedido_vehiculo (id_concesionaria, fecha_pedido, fecha_entrega_esperada)
        VALUES (p_id_concesionaria, NOW(), p_fecha_entrega_esperada);
    END IF;
END//

CREATE PROCEDURE sp_modificacionPedidoVehiculo(
    IN p_id_pedido INT,
    IN p_id_concesionaria INT,
    IN p_fecha_entrega_esperada DATE,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SET nResultado = -1;
        SET cMensaje = 'El pedido a modificar no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM concesionaria WHERE id_concesionaria = p_id_concesionaria) THEN
        SET nResultado = -2;
        SET cMensaje = 'La concesionaria especificada no existe.';
    ELSE
        UPDATE pedido_vehiculo
        SET id_concesionaria = p_id_concesionaria,
            fecha_entrega_esperada = p_fecha_entrega_esperada
        WHERE id_pedido = p_id_pedido;
    END IF;
END//

CREATE PROCEDURE sp_bajaPedidoVehiculo(
    IN p_id_pedido INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SET nResultado = -1;
        SET cMensaje = 'El pedido a eliminar no existe.';
    ELSEIF EXISTS (SELECT 1 FROM detalle_pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SET nResultado = -2;
        SET cMensaje = 'No se puede eliminar el pedido porque posee un detalle de vehículos asociado.';
    ELSE
        DELETE FROM pedido_vehiculo WHERE id_pedido = p_id_pedido;
    END IF;
END//


-- ============================================================
-- 5. DETALLE PEDIDO VEHICULO (Clave Compuesta: id_pedido + id_modelo)
-- ============================================================

CREATE PROCEDURE sp_altaDetallePedidoVehiculo(
    IN p_id_pedido INT,
    IN p_id_modelo INT,
    IN p_cantidad INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM pedido_vehiculo WHERE id_pedido = p_id_pedido) THEN
        SET nResultado = -1;
        SET cMensaje = 'El pedido especificado no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM modelo WHERE id_modelo = p_id_modelo) THEN
        SET nResultado = -2;
        SET cMensaje = 'El modelo de vehículo especificado no existe.';
    ELSEIF EXISTS (SELECT 1 FROM detalle_pedido_vehiculo WHERE id_pedido = p_id_pedido AND id_modelo = p_id_modelo) THEN
        SET nResultado = -3;
        SET cMensaje = 'Este modelo ya fue agregado a este pedido.';
    ELSE
        INSERT INTO detalle_pedido_vehiculo (id_pedido, id_modelo, cantidad)
        VALUES (p_id_pedido, p_id_modelo, p_cantidad);
    END IF;
END//

CREATE PROCEDURE sp_modificacionDetallePedidoVehiculo(
    IN p_id_pedido INT,
    IN p_id_modelo INT,
    IN p_cantidad INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM detalle_pedido_vehiculo WHERE id_pedido = p_id_pedido AND id_modelo = p_id_modelo) THEN
        SET nResultado = -1;
        SET cMensaje = 'El detalle de pedido a modificar no existe.';
    ELSE
        UPDATE detalle_pedido_vehiculo
        SET cantidad = p_cantidad
        WHERE id_pedido = p_id_pedido AND id_modelo = p_id_modelo;
    END IF;
END//

CREATE PROCEDURE sp_bajaDetallePedidoVehiculo(
    IN p_id_pedido INT,
    IN p_id_modelo INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM detalle_pedido_vehiculo WHERE id_pedido = p_id_pedido AND id_modelo = p_id_modelo) THEN
        SET nResultado = -1;
        SET cMensaje = 'El detalle de pedido a eliminar no existe.';
    ELSE
        DELETE FROM detalle_pedido_vehiculo
        WHERE id_pedido = p_id_pedido AND id_modelo = p_id_modelo;
    END IF;
END//


-- ============================================================
-- 6. COMPRA INSUMO (Cabecera)
-- ============================================================

CREATE PROCEDURE sp_altaCompraInsumo(
    IN p_id_proveedor INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM proveedor WHERE id_proveedor = p_id_proveedor) THEN
        SET nResultado = -1;
        SET cMensaje = 'El proveedor especificado no existe.';
    ELSE
        INSERT INTO compra_insumo (id_proveedor, fecha_compra)
        VALUES (p_id_proveedor, NOW());
    END IF;
END//

CREATE PROCEDURE sp_modificacionCompraInsumo(
    IN p_id_compra INT,
    IN p_id_proveedor INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM compra_insumo WHERE id_compra = p_id_compra) THEN
        SET nResultado = -1;
        SET cMensaje = 'La compra a modificar no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM proveedor WHERE id_proveedor = p_id_proveedor) THEN
        SET nResultado = -2;
        SET cMensaje = 'El proveedor especificado no existe.';
    ELSE
        UPDATE compra_insumo
        SET id_proveedor = p_id_proveedor
        WHERE id_compra = p_id_compra;
    END IF;
END//

CREATE PROCEDURE sp_bajaCompraInsumo(
    IN p_id_compra INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM compra_insumo WHERE id_compra = p_id_compra) THEN
        SET nResultado = -1;
        SET cMensaje = 'La compra a eliminar no existe.';
    ELSEIF EXISTS (SELECT 1 FROM detalle_compra_insumo WHERE id_compra = p_id_compra) THEN
        SET nResultado = -2;
        SET cMensaje = 'No se puede eliminar la compra porque posee un detalle de insumos asociado.';
    ELSE
        DELETE FROM compra_insumo WHERE id_compra = p_id_compra;
    END IF;
END//


-- ============================================================
-- 7. DETALLE COMPRA INSUMO (Clave Compuesta: id_compra + id_insumo)
-- ============================================================

CREATE PROCEDURE sp_altaDetalleCompraInsumo(
    IN p_id_compra INT,
    IN p_id_insumo INT,
    IN p_cantidad INT,
    IN p_precio_unitario FLOAT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM compra_insumo WHERE id_compra = p_id_compra) THEN
        SET nResultado = -1;
        SET cMensaje = 'La compra especificada no existe.';
    ELSEIF NOT EXISTS (SELECT 1 FROM insumo WHERE id_insumo = p_id_insumo) THEN
        SET nResultado = -2;
        SET cMensaje = 'El insumo especificado no existe.';
    ELSEIF EXISTS (SELECT 1 FROM detalle_compra_insumo WHERE id_compra = p_id_compra AND id_insumo = p_id_insumo) THEN
        SET nResultado = -3;
        SET cMensaje = 'Este insumo ya fue agregado a esta compra.';
    ELSE
        INSERT INTO detalle_compra_insumo (id_compra, id_insumo, cantidad, precio_unitario)
        VALUES (p_id_compra, p_id_insumo, p_cantidad, p_precio_unitario);
    END IF;
END//

CREATE PROCEDURE sp_modificacionDetalleCompraInsumo(
    IN p_id_compra INT,
    IN p_id_insumo INT,
    IN p_cantidad INT,
    IN p_precio_unitario FLOAT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM detalle_compra_insumo WHERE id_compra = p_id_compra AND id_insumo = p_id_insumo) THEN
        SET nResultado = -1;
        SET cMensaje = 'El detalle de compra a modificar no existe.';
    ELSE
        UPDATE detalle_compra_insumo
        SET cantidad = p_cantidad,
            precio_unitario = p_precio_unitario
        WHERE id_compra = p_id_compra AND id_insumo = p_id_insumo;
    END IF;
END//

CREATE PROCEDURE sp_bajaDetalleCompraInsumo(
    IN p_id_compra INT,
    IN p_id_insumo INT,
    OUT nResultado INT,
    OUT cMensaje VARCHAR(256)
)
BEGIN
    SET nResultado = 0;
    SET cMensaje = '';

    IF NOT EXISTS (SELECT 1 FROM detalle_compra_insumo WHERE id_compra = p_id_compra AND id_insumo = p_id_insumo) THEN
        SET nResultado = -1;
        SET cMensaje = 'El detalle de compra a eliminar no existe.';
    ELSE
        DELETE FROM detalle_compra_insumo
        WHERE id_compra = p_id_compra AND id_insumo = p_id_insumo;
    END IF;
END//

DELIMITER ;

-- ============================================================
-- TESTS
-- ============================================================

USE terminal_automotriz;

-- ============================================================
-- 1. DATOS BASE OBLIGATORIOS (MODELOS)
-- ============================================================
INSERT INTO modelo (nombre) VALUES 
('Cronos Precision 1.3'),
('Toro Volcano 2.0 4x4'),
('Pulse Impetus 1.0T'),
('Fastback Audace 1.0T'),
('Strada Ranch 1.3 CD');

-- ============================================================
-- 2. POBLADO DE TABLAS
-- ============================================================

-- CONCESIONARIAS
CALL sp_altaConcesionaria('Taraborelli Autos', 'Av. Rivadavia 8600, CABA', 1140001111, @res, @msj);
CALL sp_altaConcesionaria('Dietrich San Isidro', 'Av. del Libertador 15100, San Isidro', 1140002222, @res, @msj);
CALL sp_altaConcesionaria('Auto del Sol', 'Av. Fondeaderes 450, Pilar', 1140003333, @res, @msj);
CALL sp_altaConcesionaria('Generali Automotores', 'Av. Mitre 1200, Avellaneda', 1140004444, @res, @msj);
CALL sp_altaConcesionaria('Verona Autos', 'Calle 47 Nro 890, La Plata', 1140005555, @res, @msj);
CALL sp_altaConcesionaria('Concesionaria Pruebas', 'Calle Falsa 123', 1140009999, @res, @msj);

-- PROVEEDORES
CALL sp_altaProveedor('Ternium Argentina S.A.', 'Av. Leandro N. Alem 1067, CABA', 1152001111, @res, @msj);
CALL sp_altaProveedor('Pirelli Neumaticos S.A.I.C.', 'Ruta 8 Km 60, Merlo', 1152002222, @res, @msj);
CALL sp_altaProveedor('PPG Industries Argentina', 'Calle 7 y 51, Pilar', 1152003333, @res, @msj);
CALL sp_altaProveedor('Brimax Cables y Mazos', 'Av. Marquez 2300, San Martin', 1152004444, @res, @msj);
CALL sp_altaProveedor('Opticas del Plata S.R.L.', 'Ruta 197 Km 12, Tigre', 1152005555, @res, @msj);

-- INSUMOS
CALL sp_altaInsumo('Pintura Bi-Capa Negro Vulcan 1L', @res, @msj);
CALL sp_altaInsumo('Cubierta 205/55 R16', @res, @msj);
CALL sp_altaInsumo('Cableado Eléctrico Principal 5m', @res, @msj);
CALL sp_altaInsumo('Lámpara Halógena H7 12V', @res, @msj);
CALL sp_altaInsumo('Plancha de Acero Laminado 2mm', @res, @msj);
CALL sp_altaInsumo('Insumo Para Pruebas', @res, @msj);

-- PEDIDOS DE VEHICULOS (CABECERA)
CALL sp_altaPedidoVehiculo(1, '2026-11-15', @res, @msj);
CALL sp_altaPedidoVehiculo(2, '2026-11-30', @res, @msj);
CALL sp_altaPedidoVehiculo(3, '2026-12-10', @res, @msj);
CALL sp_altaPedidoVehiculo(4, '2026-12-20', @res, @msj);
CALL sp_altaPedidoVehiculo(5, '2026-12-28', @res, @msj);

-- DETALLE PEDIDO VEHICULOS
CALL sp_altaDetallePedidoVehiculo(1, 1, 15, @res, @msj);
CALL sp_altaDetallePedidoVehiculo(1, 2, 5, @res, @msj);
CALL sp_altaDetallePedidoVehiculo(2, 3, 10, @res, @msj);
CALL sp_altaDetallePedidoVehiculo(3, 4, 8, @res, @msj);
CALL sp_altaDetallePedidoVehiculo(4, 5, 12, @res, @msj);
CALL sp_altaDetallePedidoVehiculo(5, 1, 20, @res, @msj);

-- COMPRAS DE INSUMOS (CABECERA)
CALL sp_altaCompraInsumo(1, @res, @msj);
CALL sp_altaCompraInsumo(2, @res, @msj);
CALL sp_altaCompraInsumo(3, @res, @msj);
CALL sp_altaCompraInsumo(4, @res, @msj);
CALL sp_altaCompraInsumo(5, @res, @msj);

-- DETALLE COMPRA INSUMOS
CALL sp_altaDetalleCompraInsumo(1, 5, 100, 15000.00, @res, @msj);
CALL sp_altaDetalleCompraInsumo(2, 2, 200, 45000.00, @res, @msj);
CALL sp_altaDetalleCompraInsumo(3, 1, 80, 12500.50, @res, @msj);
CALL sp_altaDetalleCompraInsumo(4, 3, 50, 8900.00, @res, @msj);
CALL sp_altaDetalleCompraInsumo(5, 4, 300, 3200.00, @res, @msj);


-- ============================================================
-- 3. CASOS DE PRUEBA Y VALIDACIÓN DE ERRORES
-- ============================================================

-- --- CONCESIONARIA ---
-- Error: Duplicado por dirección
CALL sp_altaConcesionaria('AutoCentral', 'Av. Rivadavia 8600, CABA', 1199999999, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Éxito: Modificación
CALL sp_modificacionConcesionaria(1, 'Taraborelli Autos Centro', 'Av. Rivadavia 8650, CABA', 1140009999, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Exito;

-- Éxito: Baja de concesionaria sin pedidos
CALL sp_bajaConcesionaria(6, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Exito;

-- Error: Baja de concesionaria con pedidos asociados
CALL sp_bajaConcesionaria(1, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;


-- --- PROVEEDOR ---
-- Error: Duplicado por Razón Social
CALL sp_altaProveedor('Ternium Argentina S.A.', 'Otra Direccion', 1100000000, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Error: Baja de proveedor con compras asociadas
CALL sp_bajaProveedor(1, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;


-- --- INSUMO ---
-- Error: Duplicado por descripción
CALL sp_altaInsumo('Cubierta 205/55 R16', @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Éxito: Baja de insumo sin relaciones
CALL sp_bajaInsumo(6, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Exito;


-- --- PEDIDO VEHICULO ---
-- Error: Concesionaria inexistente
CALL sp_altaPedidoVehiculo(999, '2026-12-31', @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Error: Eliminar cabecera con detalles cargados
CALL sp_bajaPedidoVehiculo(1, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;


-- --- DETALLE PEDIDO VEHICULO ---
-- Error: Clave compuesta duplicada (Mismo pedido y modelo)
CALL sp_altaDetallePedidoVehiculo(1, 1, 10, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Éxito: Modificación de cantidad
CALL sp_modificacionDetallePedidoVehiculo(1, 1, 25, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Exito;


-- --- DETALLE COMPRA INSUMO ---
-- Error: Clave compuesta duplicada (Misma compra e insumo)
CALL sp_altaDetalleCompraInsumo(1, 5, 20, 15000.00, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Error_Esperado;

-- Éxito: Modificación de precio/cantidad
CALL sp_modificacionDetalleCompraInsumo(1, 5, 120, 14200.00, @res, @msj);
SELECT @res AS Resultado, @msj AS Mensaje_Exito;


-- ============================================================
SELECT * FROM concesionaria;
SELECT * FROM proveedor;
SELECT * FROM insumo;
SELECT * FROM pedido_vehiculo;
SELECT * FROM detalle_pedido_vehiculo;
SELECT * FROM compra_insumo;
SELECT * FROM detalle_compra_insumo;