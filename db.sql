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
    SET MontoEgreso = (SELECT gastototal FROM Servicios WHERE idservicios = NEW.idservicio)
    WHERE FKServicios = NEW.idservicio;
    
    -- Actualizar el monto en Egresos_Mensuales asociado al servicio recién agregado
    UPDATE Egresos_Mensuales
    SET MontoEgreso = (SELECT gastototal FROM Servicios WHERE idservicios = NEW.idservicio)
    WHERE FKServicios = NEW.idservicio;
END//
DELIMITER ;

