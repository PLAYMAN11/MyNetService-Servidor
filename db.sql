-- Crear base de datos
CREATE DATABASE IF NOT EXISTS MyNetService;
USE MyNetService;

-- Crear tabla Usuarios
CREATE TABLE IF NOT EXISTS Usuarios (
    idusuario INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
    NombreUsuario VARCHAR(30) NOT NULL,
    Contraseña VARCHAR(20) NOT NULL,
    ApellidoUsuario VARCHAR(40) NOT NULL,
    CorreoUsuario VARCHAR(100) NOT NULL,
    FECHA_NACIMIENTO date,
    SOBREMI VARCHAR(250)
);

-- Crear tabla IMAGENESUSUARIO
CREATE TABLE IF NOT EXISTS IMAGENESUSUARIO (
    IDIMAGEN INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    NOMBREIMAGEN VARCHAR(30),
    IDIMAGENUSUARIO INT,
    FOREIGN KEY (IDIMAGENUSUARIO) REFERENCES USUARIOS (idusuario)
);

-- Crear tabla Servicios
CREATE TABLE IF NOT EXISTS Servicios (
    idservicios INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    gastototal FLOAT,
    idUsuario int,
    foreign key (idUsuario) references Usuarios (idusuario)
);

-- Crear tabla ServiciosStreaming
CREATE TABLE IF NOT EXISTS ServiciosStreaming (
    idservicioStr INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    nombreservicio VARCHAR(60),
    precioservicio FLOAT,
    idservicio INT NOT NULL,
    FOREIGN KEY (idservicio) REFERENCES Servicios (idservicios)
);

-- Crear tabla Ingresos_Mensuales
CREATE TABLE IF NOT EXISTS Ingresos_Mensuales (
    idIngreso INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    MontoIngreso FLOAT,
    FechaIngreso TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FKusuario INT NOT NULL,
    FOREIGN KEY (FKusuario) REFERENCES Usuarios(idusuario)
);

-- Crear tabla Egresos_Mensuales
CREATE TABLE IF NOT EXISTS Egresos_Mensuales (
    idEgreso INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    MontoEgreso FLOAT,
    FechaEgreso TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FKusuario INT NOT NULL,
    FKServicios INT NOT NULL,
    FOREIGN KEY (FKServicios) REFERENCES Servicios(idservicios),
    FOREIGN KEY (FKusuario) REFERENCES Usuarios(idusuario)
);

-- Crear tabla CantidadActual
CREATE TABLE IF NOT EXISTS CantidadActual (
    idCantidadActual INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    CantidadActual FLOAT,
    FechaCantidadActual TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FKusuario INT NOT NULL,
    FKingresos INT NOT NULL,
    FKegresos INT NOT NULL,
    FOREIGN KEY (FKusuario) REFERENCES Usuarios(idusuario),
    FOREIGN KEY (FKingresos) REFERENCES Ingresos_Mensuales(idIngreso),
    FOREIGN KEY (FKegresos) REFERENCES Egresos_Mensuales(idEgreso)
);

-- Crear tabla Gastos
CREATE TABLE IF NOT EXISTS Gastos (
    idGasto INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    NombreGasto VARCHAR(45) NOT NULL,
    CantidadGasto FLOAT NOT NULL,
    FKusuario INT NOT NULL,
    GastoFecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FKcantidadActual INT,
    FOREIGN KEY (FKusuario) REFERENCES Usuarios(idusuario),
    FOREIGN KEY (FKcantidadActual) REFERENCES CantidadActual(idCantidadActual)
);
CREATE TABLE IF NOT EXISTS Ingreso (
    idIngreso INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    MontoIngreso FLOAT,
    FechaIngreso TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FKusuario INT NOT NULL,
    FOREIGN KEY (FKusuario) REFERENCES Usuarios(idusuario)
);
CREATE TABLE IF NOT EXISTS RegistroMensual (
    idRegistroMensual INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    MontoTotal FLOAT,
    FechaRegistro TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FKusuario INT NOT NULL,
    FOREIGN KEY (FKusuario) REFERENCES Usuarios(idusuario)
);


-- Trigger para actualizar monto total con un ingreso
DELIMITER //
CREATE TRIGGER actualizarmontototal
AFTER INSERT ON Ingresos_Mensuales
FOR EACH ROW
BEGIN
    DECLARE nuevomontototal FLOAT;
    -- Calcular el nuevo monto total basado en los ingresos y egresos
    SELECT COALESCE(SUM(MontoIngreso), 0) - COALESCE(
        (SELECT SUM(MontoEgreso) FROM Egresos_Mensuales WHERE FKusuario = NEW.FKusuario),
        0
    ) INTO nuevomontototal
    FROM Ingresos_Mensuales
    WHERE FKusuario = NEW.FKusuario;

    -- Actualizar la tabla de CantidadActual
    UPDATE CantidadActual
    SET CantidadActual = nuevomontototal, FechaCantidadActual = NEW.FechaIngreso
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ;

-- Trigger para actualizar monto total con un egreso
DELIMITER //
CREATE TRIGGER actualizarmontototalegreso
AFTER INSERT ON Egresos_Mensuales
FOR EACH ROW
BEGIN
    DECLARE nuevomontototal FLOAT;
    -- Calcular el nuevo monto total basado en los ingresos y egresos
    SELECT COALESCE(
        (SELECT SUM(MontoIngreso) FROM Ingresos_Mensuales WHERE FKusuario = NEW.FKusuario),
        0
    ) - COALESCE(SUM(MontoEgreso), 0) INTO nuevomontototal
    FROM Egresos_Mensuales
    WHERE FKusuario = NEW.FKusuario;

    -- Actualizar la tabla de CantidadActual
    UPDATE CantidadActual
    SET CantidadActual = nuevomontototal, FechaCantidadActual = NEW.FechaEgreso
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ;

-- Trigger para actualizar el gasto total de servicios
DELIMITER //
CREATE TRIGGER ActualizarPrecioServicios
AFTER INSERT ON ServiciosStreaming
FOR EACH ROW
BEGIN
    DECLARE total FLOAT;
    -- Calcular el nuevo gasto total basado en los precios de todos los servicios
    SELECT COALESCE(SUM(precioservicio), 0) INTO total
    FROM ServiciosStreaming;

    -- Actualizar la tabla Servicios con el nuevo gasto total
    UPDATE Servicios
    SET gastototal = total
    WHERE idservicios = NEW.idservicio;

    -- Actualizar el monto en Egresos_Mensuales asociado al servicio recién agregado
    UPDATE Egresos_Mensuales
    SET MontoEgreso = (SELECT gastototal FROM Servicios WHERE idservicios = Egresos_Mensuales.FKServicios)
    WHERE FKServicios = NEW.idservicio;
END//
DELIMITER ;

-- Trigger para actualizar la cantidad actual con un gasto
DELIMITER //
CREATE TRIGGER actualizar_cantidad_actual
AFTER INSERT ON Gastos
FOR EACH ROW
BEGIN
    UPDATE CantidadActual
    SET CantidadActual = CantidadActual - NEW.CantidadGasto
    WHERE idCantidadActual = NEW.FKcantidadActual;
END//
DELIMITER ;

-- Trigger para actualizar monto total con una actualización de ingreso
DELIMITER //
CREATE TRIGGER actualizarmontototalU
AFTER UPDATE ON Ingresos_Mensuales
FOR EACH ROW
BEGIN
    DECLARE nuevomontototal FLOAT;
    -- Calcular el nuevo monto total basado en los ingresos y egresos
    SELECT COALESCE(SUM(MontoIngreso), 0) - COALESCE(
        (SELECT SUM(MontoEgreso) FROM Egresos_Mensuales WHERE FKusuario = NEW.FKusuario),
        0
    ) INTO nuevomontototal
    FROM Ingresos_Mensuales
    WHERE FKusuario = NEW.FKusuario;

    -- Actualizar la tabla de CantidadActual
    UPDATE CantidadActual
    SET CantidadActual = nuevomontototal, FechaCantidadActual = NEW.FechaIngreso
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ;

-- Trigger para actualizar monto total con una actualización de egreso
DELIMITER //
CREATE TRIGGER actualizarmontototalegresoU
AFTER UPDATE ON Egresos_Mensuales
FOR EACH ROW
BEGIN
    DECLARE nuevomontototal FLOAT;
    -- Calcular el nuevo monto total basado en los ingresos y egresos
    SELECT COALESCE(
        (SELECT SUM(MontoIngreso) FROM Ingresos_Mensuales WHERE FKusuario = NEW.FKusuario),
        0
    ) - COALESCE(SUM(MontoEgreso), 0) INTO nuevomontototal
    FROM Egresos_Mensuales
    WHERE FKusuario = NEW.FKusuario;

    -- Actualizar la tabla de CantidadActual
    UPDATE CantidadActual
    SET CantidadActual = nuevomontototal, FechaCantidadActual = NEW.FechaEgreso
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ;

-- Trigger para actualizar el gasto total de servicios con una actualización
DELIMITER //
CREATE TRIGGER ActualizarPrecioServiciosU
AFTER UPDATE ON ServiciosStreaming
FOR EACH ROW
BEGIN
    DECLARE total FLOAT;
    -- Calcular el nuevo gasto total basado en los precios de todos los servicios
    SELECT COALESCE(SUM(precioservicio), 0) INTO total
    FROM ServiciosStreaming;

    -- Actualizar la tabla Servicios con el nuevo gasto total
    UPDATE Servicios
    SET gastototal = total
    WHERE idservicios = NEW.idservicio;

    -- Actualizar el monto en Egresos_Mensuales asociado al servicio recién agregado
    UPDATE Egresos_Mensuales
    SET MontoEgreso = (SELECT gastototal FROM Servicios WHERE idservicios = Egresos_Mensuales.FKServicios)
    WHERE FKServicios = NEW.idservicio;
END//
DELIMITER ;

-- Habilitar el programador de eventos si no está habilitado
SET GLOBAL event_scheduler = ON;

-- Crear el procedimiento almacenado para capturar el monto mensual
DELIMITER //
CREATE PROCEDURE CapturarMontoMensual()
BEGIN
    INSERT INTO Ingreso (MontoIngreso, FKusuario)
    SELECT SUM(MontoIngreso), FKusuario
    FROM RegistroMensual
    WHERE MONTH(FechaIngreso) = MONTH(CURRENT_DATE())
      AND YEAR(FechaIngreso) = YEAR(CURRENT_DATE())
    GROUP BY FKusuario;
END //
DELIMITER ;

-- Crear el evento
CREATE EVENT IF NOT EXISTS CapturarMontoMensualEvento
ON SCHEDULE LAST_DAY(CURRENT_DATE()) + INTERVAL 23 HOUR + INTERVAL 59 MINUTE
DO
    CALL CapturarMontoMensual();



-- Crear el evento programado para eliminar los registros de gastos al final de cada mes
DELIMITER //
CREATE EVENT eliminar_gastos_mensuales
ON SCHEDULE EVERY 1 MONTH
STARTS '2024-08-01 00:00:00'
DO
BEGIN
    DELETE FROM Gastos
    WHERE GastoFecha < LAST_DAY(NOW()) - INTERVAL 1 MONTH
    AND GastoFecha < NOW();
END//
DELIMITER ;

DELIMITER //
CREATE TRIGGER insertar_servicio_nuevo_usuario
AFTER INSERT ON Usuarios
FOR EACH ROW
BEGIN
    -- Insertar un nuevo registro en la tabla Servicios con el idusuario del nuevo usuario
    INSERT INTO Servicios (gastototal, idusuario)
    VALUES (0, NEW.idusuario);
END//
DELIMITER ;

-- Trigger para capturar la cantidad actual al final del mes en la tabla RegistroMensual
DELIMITER //
CREATE TRIGGER capturar_cantidad_actual
AFTER INSERT ON RegistroMensual
FOR EACH ROW
BEGIN
    -- Obtener la cantidad actual al final del mes
    SELECT CantidadActual
    INTO NEW.MontoTotal
    FROM CantidadActual
    WHERE FKusuario = NEW.FKusuario
    AND FechaCantidadActual = LAST_DAY(NEW.FechaRegistro);
END//
DELIMITER ;

-- Trigger para actualizar el monto total en la tabla Ingresos_Mensuales
DELIMITER //
CREATE TRIGGER actualizar_monto_total_ingresos
AFTER INSERT ON RegistroMensual
FOR EACH ROW
BEGIN
    -- Actualizar el monto total en la tabla Ingresos_Mensuales
    UPDATE Ingresos_Mensuales
    SET MontoIngreso = MontoIngreso + NEW.MontoTotal
    WHERE FKusuario = NEW.FKusuario;

    -- Actualizar el monto total en la tabla CantidadActual
    UPDATE CantidadActual
    SET CantidadActual = CantidadActual + NEW.MontoTotal
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ;

-- 		INSERTAR VALORES
-- Insertar registros en la tabla Usuarios
INSERT INTO Usuarios (NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario)
VALUES 
('juan123', 'password1', 'Perez', 'juan.perez@example.com'),
('maria456', 'password2', 'Lopez', 'maria.lopez@example.com'),
('carlos789', 'password3', 'Gomez', 'carlos.gomez@example.com'),
('ana012', 'password4', 'Martinez', 'ana.martinez@example.com'),
('luis345', 'password5', 'Hernandez', 'luis.hernandez@example.com'),
('laura678', 'password6', 'Diaz', 'laura.diaz@example.com'),
('jose901', 'password7', 'Ramirez', 'jose.ramirez@example.com'),
('marta234', 'password8', 'Vasquez', 'marta.vasquez@example.com'),
('pedro567', 'password9', 'Rojas', 'pedro.rojas@example.com'),
('sofia890', 'password10', 'Mendoza', 'sofia.mendoza@example.com');

-- Insertar registros en la tabla Ingresos_Mensuales
INSERT INTO Ingresos_Mensuales (MontoIngreso, FKusuario)
VALUES 
(2500.00, 1),
(2700.00, 2),
(3000.00, 3),
(3200.00, 4),
(2800.00, 5),
(2900.00, 6),
(3100.00, 7),
(3300.00, 8),
(3400.00, 9),
(3600.00, 10);

-- Insertar registros en la tabla Egresos_Mensuales
INSERT INTO Egresos_Mensuales (MontoEgreso, FKusuario, FKServicios)
VALUES 
(1000.00, 1, 1),
(1200.00, 2, 2),
(1100.00, 3, 3),
(1300.00, 4, 4),
(1250.00, 5, 5),
(1150.00, 6, 6),
(1400.00, 7, 7),
(1350.00, 8, 8),
(1500.00, 9, 9),
(1600.00, 10, 10);

-- Insertar registros en la tabla CantidadActual
INSERT INTO CantidadActual (CantidadActual, FKusuario, FKingresos, FKegresos)
VALUES 
(1500.00, 1, 1, 1),
(1500.00, 2, 2, 2),
(1900.00, 3, 3, 3),
(1900.00, 4, 4, 4),
(1550.00, 5, 5, 5),
(1750.00, 6, 6, 6),
(1700.00, 7, 7, 7),
(1950.00, 8, 8, 8),
(1900.00, 9, 9, 9),
(2000.00, 10, 10, 10);

-- Insertar registros en la tabla Gastos
INSERT INTO Gastos (NombreGasto, CantidadGasto, FKusuario, FKcantidadActual)
VALUES 
('Compra Supermercado', 200.00, 1, 1),
('Ropa', 150.00, 2, 2),
('Electrónica', 300.00, 3, 3),
('Viaje', 500.00, 4, 4),
('Restaurante', 100.00, 5, 5),
('Gimnasio', 50.00, 6, 6),
('Cine', 30.00, 7, 7),
('Libros', 80.00, 8, 8),
('Juegos', 60.00, 9, 9),
('Mascota', 120.00, 10, 10);

INSERT INTO Gastos (NombreGasto, CantidadGasto, FKusuario, FKcantidadActual)
VALUES 
('Compra Supermercado', 200.00, 1, 1),
('Ropa', 150.00, 2, 2),
('Electrónica', 300.00, 3, 3),
('Viaje', 500.00, 4, 4),
('Restaurante', 100.00, 5, 5),
('Gimnasio', 50.00, 6, 6),
('Cine', 30.00, 7, 7),
('Libros', 80.00, 8, 8),
('Juegos', 60.00, 9, 9),
('Mascota', 120.00, 10, 10);

INSERT INTO ServiciosStreaming (nombreservicio, precioservicio, idservicio) VALUES 
('Netflix', 13.99, 1),
('Mandado', 3000, 1),
('Amazon Prime Video', 8.99, 2),
('Disney+', 7.99, 3),
('Hulu', 11.99, 4),
('HBO Max', 14.99, 5),
('Apple TV+', 4.99, 6),
('YouTube Premium', 11.99, 7),
('Paramount+', 9.99, 8),
('Peacock', 4.99, 9),
('Crunchyroll', 7.99, 10);


