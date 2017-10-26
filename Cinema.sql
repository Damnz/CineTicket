-- Database: Cinema

--DROP DATABASE "Cinema";

CREATE DATABASE "Cinema"
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Spanish_Spain.1252'
    LC_CTYPE = 'Spanish_Spain.1252'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

CREATE SCHEMA Ventas;
CREATE SCHEMA Funciones;

CREATE TABLE Ventas.T_Venta(
	id_venta BIGSERIAL NOT NULL,
	hora TIME NOT NULL,
	total FLOAT NOT NULL,
	iva FLOAT NOT NULL,
	CONSTRAINT PK_VENTA PRIMARY KEY(id_venta)
);

CREATE TABLE Funciones.T_Sala(
	id_sala BIGSERIAL NOT NULL,
	num_sala INT NOT NULL,
	capacidad INT NOT NULL,
	tipo_sala VARCHAR(10) NOT NULL,
	CONSTRAINT PK_SALA PRIMARY KEY(id_sala)
);

ALTER TABLE Funciones.T_Sala
add CONSTRAINT unica_sala
unique (num_sala);

CREATE TABLE Funciones.T_Film(
	id_film BIGSERIAL NOT NULL,
	nombre_film VARCHAR(60),
	duracion INT NOT NULL,
	CONSTRAINT PK_FILM PRIMARY KEY(id_film)
);

ALTER TABLE Funciones.T_Film
add CONSTRAINT unico_film
unique (nombre_film);

CREATE TABLE Funciones.T_Horario(
	id_horario BIGSERIAL NOT NULL,
	id_film INT8 NOT NULL,
	hora TIME NOT NULL,
	fecha DATE NOT NULL,
	CONSTRAINT PK_HORARIO PRIMARY KEY(id_horario),
	CONSTRAINT FK_FILM FOREIGN KEY(id_film) REFERENCES Funciones.T_Film(id_film)
);

CREATE TABLE Funciones.T_Proyeccion(
	id_proyeccion BIGSERIAL NOT NULL,
	id_sala INT8 NOT NULL,
	id_horario INT8 NOT NULL,
    asientos_disponibles int NOT NULL,
	CONSTRAINT PK_PROYECCION PRIMARY KEY(id_proyeccion),
	CONSTRAINT FK_SALA FOREIGN KEY(id_sala) REFERENCES Funciones.T_Sala(id_sala),
	CONSTRAINT FK_HORARIO FOREIGN KEY(id_horario) REFERENCES Funciones.T_Horario(id_horario)
);

CREATE TABLE Ventas.T_DetalleVenta(
	id_detalleVenta BIGSERIAL NOT NULL,
	id_venta INT8 NOT NULL,
	id_proyeccion INT8 NOT NULL,
	tipo_boleto VARCHAR(12) NOT NULL,
	asiento INT NOT NULL,
	subtotal FLOAT NOT NULL,
	CONSTRAINT PK_DETALLEVENTA PRIMARY KEY(id_detalleVenta),
	CONSTRAINT FK_VENTA FOREIGN KEY(id_venta) REFERENCES Ventas.T_Venta(id_venta),
	CONSTRAINT FK_PROYECCION FOREIGN KEY(id_proyeccion) REFERENCES Funciones.T_Proyeccion(id_proyeccion)
);

--TIGGERS
--Actualiza Asientos de Tabla Proyeccion al realizar una venta 
CREATE OR REPLACE FUNCTION actualizaAsiento()
RETURNS TRIGGER AS $actualizaAsiento$
DECLARE
BEGIN
	UPDATE FUNCIONES.T_Proyeccion SET asientos_disponibles=asientos_disponibles-1
	WHERE FUNCIONES.T_Proyeccion.id_proyeccion = NEW.id_proyeccion;
	return NEW;
	END
	$actualizaAsiento$ LANGUAGE plpgsql;

CREATE TRIGGER actualizaAsiento
AFTER INSERT ON VENTAS.T_DetalleVenta
FOR EACH ROW
EXECUTE PROCEDURE actualizaAsiento();

--Verifica si hay cupo en la Proyeccion si no cancela la venta
CREATE OR REPLACE FUNCTION revisaCupo()
RETURNS TRIGGER AS $revisaCupo$
DECLARE
BEGIN 
	IF ((SELECT asientos_disponibles FROM FUNCIONES.T_Proyeccion 
	    WHERE FUNCIONES.T_Proyeccion.id_proyeccion = NEW.id_proyeccion) <=-1)
	    THEN
		rollback transaction;
		raise notice 'No hay cupo!!';
		return NEW;
	    ELSE
		  return NEW;
	    END IF;
	END;
	$revisaCupo$ LANGUAGE plpgsql;
			
CREATE TRIGGER revisaCupo
AFTER INSERT ON VENTAS.T_DetalleVenta
FOR EACH ROW
EXECUTE PROCEDURE revisaCupo();


--Checa tipo de boleto
alter table ventas.t_detalleventa add constraint checaBoleto check(tipo_boleto= 'Niño' or tipo_boleto= 'Especial' or tipo_boleto= 'Adulto');
--Checa tipo de sala
alter table funciones.t_sala add constraint checaSala check(tipo_sala= '3D' or tipo_sala= '4D' or tipo_sala= 'Normal');


--Al realizar una venta,si el cliente es especial, hacer el descuento correspondiente
CREATE OR REPLACE FUNCTION aplicaDescuento()
RETURNS TRIGGER AS $aplicaDescuento$
DECLARE
BEGIN 
	IF ((SELECT tipo_boleto FROM Ventas.T_DetalleVenta
	    WHERE ventas.T_DetalleVenta.id_detalleVenta= NEW.id_DetalleVenta) ='Especial')
	    THEN
		UPDATE Ventas.T_DetalleVenta SET subtotal= subtotal*.7
		 WHERE Ventas.T_DetalleVenta.id_DetalleVenta= NEW.id_DetalleVenta;
		raise notice 'Se aplico el descuento!!';
		return NEW;
	ELSE
		return NEW;
	END IF;
END;
$aplicaDescuento$ LANGUAGE plpgsql;

CREATE TRIGGER aplicaDescuento
AFTER INSERT ON VENTAS.T_DetalleVenta
FOR EACH ROW
EXECUTE PROCEDURE aplicaDescuento();


--Al generar un detalle de venta, actualizar el total e iva
CREATE OR REPLACE FUNCTION actualizaTotal()
RETURNS TRIGGER AS $actualizaTotal$
DECLARE
BEGIN
	UPDATE Ventas.T_Venta SET total = total + NEW.subtotal, iva = iva + (NEW.subtotal * .16)
	WHERE Ventas.T_Venta.id_venta = NEW.id_venta;
	
	UPDATE Ventas.T_Venta SET total = total + (NEW.subtotal * .16)
	WHERE Ventas.T_Venta.id_venta = NEW.id_venta;
	return NEW;
END
$actualizaTotal$ LANGUAGE plpgsql;

CREATE TRIGGER actualizaTotal
AFTER INSERT ON VENTAS.T_DetalleVenta
FOR EACH ROW
EXECUTE PROCEDURE actualizaTotal();

 -- DROP TRIGGER actualizaTotal ON Ventas.T_DetalleVenta
 -- DROP TRIGGER aplicaDescuento ON Ventas.T_DetalleVenta

CREATE ROLE programador LOGIN PASSWORD '123';
GRANT ALL PRIVILEGES ON SCHEMA Funciones TO programador;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA Funciones TO programador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA Funciones TO programador;


CREATE ROLE cajero LOGIN PASSWORD '123';
GRANT ALL PRIVILEGES ON SCHEMA Funciones TO cajero;
GRANT ALL PRIVILEGES ON SCHEMA Ventas TO cajero;
GRANT ALL PRIVILEGES ON ALL SEQUENCES  IN SCHEMA Ventas TO cajero;
GRANT ALL PRIVILEGES ON ALL SEQUENCES  IN SCHEMA Funciones TO cajero;
GRANT ALL PRIVILEGES ON TABLE Ventas.T_Venta TO cajero;
GRANT ALL PRIVILEGES ON TABLE Ventas.T_DetalleVenta TO cajero;
GRANT ALL PRIVILEGES ON TABLE Funciones.T_Proyeccion TO cajero;
GRANT SELECT, REFERENCES ON TABLE funciones.t_film to cajero;
GRANT SELECT, REFERENCES ON TABLE funciones.t_horario to cajero;
GRANT SELECT, REFERENCES ON TABLE funciones.t_sala to cajero;







 

