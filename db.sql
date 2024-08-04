-- Crear base de datos
CREATE DATABASE IF NOT EXISTS MyNetService;
USE MyNetService;

-- Crear tabla Usuarios
CREATE TABLE IF NOT EXISTS Usuarios (
    idusuario INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
    NombreUsuario VARCHAR(30) NOT NULL,
    Contraseña VARCHAR(32) NOT NULL,
    ApellidoUsuario VARCHAR(40) NOT NULL,
    CorreoUsuario VARCHAR(100) NOT NULL,
    FECHA_NACIMIENTO date,
    SOBREMI VARCHAR(250)
);

-- Crear tabla Servicios
CREATE TABLE IF NOT EXISTS Servicios (
    idservicios INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    gastototal FLOAT,
    idUsuario int,
    foreign key (idUsuario) references Usuarios (idusuario)
);
show triggers;
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
    PrecioGasto float not null default 0, -- Precio ya total
    FKusuario INT NOT NULL,
    GastoFecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    FKcantidadActual INT,
    FOREIGN KEY (FKusuario) REFERENCES Usuarios(idusuario),
    FOREIGN KEY (FKcantidadActual) REFERENCES CantidadActual(idCantidadActual)
);
CREATE TABLE IF NOT EXISTS Ingreso (
    idIngreso INT AUTO_INCREMENT PRIMARY KEY NOT NULL,
    NombreIngreso varchar(50),
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
    -- Calcular el nuevo gasto total basado en los precios de todos los servicios del usuario específico
    SELECT COALESCE(SUM(precioservicio), 0) INTO total
    FROM ServiciosStreaming
    WHERE idservicio = NEW.idservicio;

    -- Actualizar la tabla Servicios con el nuevo gasto total
    UPDATE Servicios
    SET gastototal = total
    WHERE idservicios = NEW.idservicio;

    -- Actualizar el monto en Egresos_Mensuales asociado al servicio recién agregado
    UPDATE Egresos_Mensuales
    SET MontoEgreso = total
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


-- Habilitar el programador de eventos si no está habilitado
SET GLOBAL event_scheduler = ON;

DELIMITER //
create event if not exists RegistroMensual
on SCHEDULE EVERY 1 MONTH 
STARTS '2024-08-01 00:00:00'
DO
BEGIN
    insert into RegistroMensual (MontoTotal, FKusuario)
    values ((SELECT CantidadActual from Cantidad actual), (SELECT FKusuario from cantidadActual));
END//
DELIMITER ;

-- Trigger que registre como un nuevo ingreso el restante de la cantidad del mes
DELIMITER //
create event if not exists RegistrarIngreso
on Schedule every 1 month
starts '2024-08-01 00:00:00'
DO 
BEGIN
	insert into Ingreso (MontoIngreso, FKusuario)
    values ((SELECT CantidadActual from CantidadActual), (SELECT FKusuario from CantidadActual));
END// 
DELIMITER ;

-- Trigger para actualizar CantidadActual después de una inserción en la tabla ingresos
DELIMITER //
CREATE TRIGGER actualizarCantidadActual
AFTER INSERT ON ingreso
FOR EACH ROW
BEGIN
    -- Actualizar la tabla de CantidadActual sumando el nuevo MontoIngreso
    UPDATE CantidadActual
    SET CantidadActual = CantidadActual + NEW.MontoIngreso, FechaCantidadActual = NEW.FechaIngreso
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ; 

-- Crear el evento programado para eliminar los registros de gastos al final de cada mes
DELIMITER //
CREATE EVENT if not exists eliminar_gastos_mensuales
ON SCHEDULE EVERY 1 MONTH
STARTS '2024-08-01 00:00:00'
DO
BEGIN
    DELETE FROM Gastos
    WHERE GastoFecha < LAST_DAY(NOW()) - INTERVAL 1 MONTH
    AND GastoFecha < NOW();
END//
DELIMITER ;

-- Trigger para actualizar egreso mensual después de un UPDATE en Servicios
DELIMITER //
CREATE TRIGGER ActualizarEgresoMensual
AFTER UPDATE ON Servicios
FOR EACH ROW
BEGIN
    DECLARE total_gasto FLOAT;
    DECLARE usuario_id INT;

    -- Obtener el nuevo total de gasto
    SELECT COALESCE(SUM(precioservicio), 0) INTO total_gasto
    FROM ServiciosStreaming
    WHERE idservicio = NEW.idservicios;

    -- Obtener el ID del usuario asociado
    SELECT idUsuario INTO usuario_id
    FROM Servicios
    WHERE idservicios = NEW.idservicios;

    -- Actualizar el total de gasto en la tabla Servicios
    UPDATE Servicios
    SET gastototal = total_gasto
    WHERE idservicios = NEW.idservicios;

    -- Actualizar el monto en Egresos_Mensuales para el usuario correspondiente
    UPDATE Egresos_Mensuales
    SET MontoEgreso = total_gasto
    WHERE FKServicios = NEW.idservicios AND FKusuario = usuario_id;
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

-- Trigger para actualizar el monto total en la tabla Ingresos_Mensuales
DELIMITER //
CREATE TRIGGER actualizar_monto_total_ingresos
AFTER INSERT ON RegistroMensual
FOR EACH ROW
BEGIN
    -- Actualizar el monto total en la tabla CantidadActual
    UPDATE CantidadActual
    SET CantidadActual = CantidadActual + NEW.MontoTotal
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ;

-- Trigger para encriptar contraseñas con MD5
DELIMITER //
create trigger encriptar_contraseña
before insert on Usuarios
for each row
begin
    set NEW.Contraseña = MD5(NEW.Contraseña);
end;
//

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

INSERT INTO RegistroMensual (MontoTotal, FechaRegistro, FKusuario) VALUES 
(100.50, '2023-01-15 10:00:00', 1),
(200.75, '2023-02-15 11:00:00', 1),
(150.00, '2023-03-15 12:00:00', 1),
(300.25, '2023-04-15 13:00:00', 1),
(400.50, '2023-05-15 14:00:00', 1),
(500.75, '2023-06-15 15:00:00', 1),
(250.00, '2023-07-15 16:00:00', 1),
(350.25, '2023-08-15 17:00:00', 1),
(450.50, '2023-09-15 18:00:00', 1),
(550.75, '2023-10-15 19:00:00', 1),
(600.00, '2023-11-15 20:00:00', 1),
(700.25, '2023-12-15 21:00:00', 1),
(800.50, '2024-01-15 10:00:00', 1),
(900.75, '2024-02-15 11:00:00', 1),
(1000.00, '2024-03-15 12:00:00', 1),
(1100.25, '2024-04-15 13:00:00', 1),
(1200.50, '2024-05-15 14:00:00', 1),
(1300.75, '2024-06-15 15:00:00', 1),
(1400.00, '2024-07-15 16:00:00', 1),
(1500.25, '2024-08-15 17:00:00', 1);

-- Trigger para inicializar los valores de ingresos, egresos, cantidad actual y gastos a 0
DELIMITER //
create trigger inicializar_valores_en0
after insert on Usuarios
for each row
begin
    declare ingreso_id int;
    declare egreso_id int;
    declare servicio_id int;
    declare cantidad_actual_id int;
    
    -- Insertar un registro inicial en Servicios para el nuevo usuario y obtener su ID
    insert into Servicios (gastototal, idUsuario) 
	values 
	(0, NEW.idusuario);
    set servicio_id = LAST_INSERT_ID();
    
    -- Insertar un registro con monto de ingreso inicial a 0 y obtener su ID
    insert into Ingresos_Mensuales (MontoIngreso, FKusuario) 
	values 
	(0, NEW.idusuario);
    set ingreso_id = LAST_INSERT_ID();
    
    -- Insertar un registro con monto de egreso inicial a 0 y obtener su ID
    insert into Egresos_Mensuales (MontoEgreso, FKusuario, FKServicios) 
	values 
	(0, NEW.idusuario, servicio_id);
    set egreso_id = LAST_INSERT_ID();
    
    -- Insertar un registro con cantidad actual inicial a 0 usando los IDs obtenidos y obtener su ID
    insert into CantidadActual (CantidadActual, FKusuario, FKingresos, FKegresos) 
	values
	(0, NEW.idusuario, ingreso_id, egreso_id);
    set cantidad_actual_id = LAST_INSERT_ID();
    
    -- Insertar un registro con gasto inicial a 0 usando el id de cantidad actual
    insert into Gastos (NombreGasto, CantidadGasto, FKusuario, FKcantidadActual) 
	values 
	('Inicial', 0, NEW.idusuario, cantidad_actual_id);
    
    -- Insertar un registro con ingreso inicial a 0
    insert into Ingreso (NombreIngreso, MontoIngreso, FKusuario) 
	values 
	('Inicial', 0, NEW.idusuario);
end;
//
select * from usuarios;


DELIMITER //
CREATE TRIGGER actualizarmontototalegreso
AFTER INSERT ON Egresos_Mensuales
FOR EACH ROW
BEGIN
    DECLARE nuevomontototal FLOAT;
    DECLARE sumagastos FLOAT;

    -- Calcular el nuevo monto total basado en los ingresos y egresos
    SELECT COALESCE(
        (SELECT SUM(MontoIngreso) FROM Ingresos_Mensuales WHERE FKusuario = NEW.FKusuario),
        0
    ) - COALESCE(
        (SELECT SUM(MontoEgreso) FROM Egresos_Mensuales WHERE FKusuario = NEW.FKusuario),
        0
    ) INTO nuevomontototal;

    -- Calcular la suma de los precios de los gastos
    SELECT COALESCE(SUM(PrecioGasto), 0) INTO sumagastos
    FROM Gastos
    WHERE FKusuario = NEW.FKusuario;

    -- Actualizar la tabla de CantidadActual
    UPDATE CantidadActual
    SET CantidadActual = COALESCE(nuevomontototal, 0) + COALESCE(sumagastos, 0), 
        FechaCantidadActual = NEW.FechaEgreso
    WHERE FKusuario = NEW.FKusuario;
END//
DELIMITER ;

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
    SET CantidadActual = COALESCE(SUM(nuevomontototal), (SELECT MontoIngreso From Ingreso Where FKusuario = NEW.FKusuario)), FechaCantidadActual = NEW.FechaIngreso
    WHERE FKusuario = NEW.FKusuario;
    
END//
DELIMITER ;