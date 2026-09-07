CREATE DATABASE Vinyl_Record_Heaven
GO

USE Vinyl_Record_Heaven
GO

-- Tabla de Proveedores
CREATE TABLE Proveedores(
ProveedorID INT PRIMARY KEY,
Nombre VARCHAR (50),
Contanto INT,
Email VARCHAR (50),
CalificacionEtica INT
);
GO

-- Tabla de Discos
CREATE TABLE Discos(
DiscoID INT PRIMARY KEY,
Titulo VARCHAR (20),
Artista VARCHAR (30),
Genero VARCHAR (15),
PrecioVenta numeric (6,2),
Stock INT,
ProveedoresID INT
CONSTRAINT FK_Discos_Proveedores
FOREIGN KEY REFERENCES Proveedores (ProveedorID)
);
GO

-- Tabla de Clientes
CREATE TABLE Clientes(
ClienteID INT PRIMARY KEY,
Nombre VARCHAR (20),
Apellido VARCHAR (20),
Email VARCHAR (50),
PuntosLealtad INT,
EstadoCuenta BIT
);
GO

-- Tabla de PedidosProveedores
CREATE TABLE PedidosProveedores(
PedidoID INT PRIMARY KEY,
FechaPedido DATE,
Total INT,
Estado BIT,
ProveedorID INT NOT NULL
CONSTRAINT FK_PedidosProveedores_Proveedores FOREIGN KEY (ProveedorID) 
REFERENCES Proveedores(ProveedorID) ,
);
GO

-- Tabla de Ventas
CREATE TABLE Ventas(
VentasID INT PRIMARY KEY,
Fecha DATE,
TotalVenta INT,
ClienteID INT NOT NULL
CONSTRAINT FK_Ventas_Clientes FOREIGN KEY (ClienteID) 
REFERENCES CLientes(ClienteID) ,
);
GO


-- Clientes
INSERT INTO Clientes (ClienteID, Nombre, Apellido, Email, PuntosLealtad, EstadoCuenta) 
VALUES 
(1, 'Carlos', 'Gómez', 'carlos.gomez@email.com', 150, 1),
(2, 'María', 'Rodríguez', 'maria.rodriguez@email.com', 420, 1),
(3, 'Juan', 'Pérez', 'juan.perez@email.com', 50, 0),
(4, 'Ana', 'Torres', 'ana.torres@email.com', 890, 1);

SELECT * FROM Clientes
GO

CREATE PROC p_RegVentas
	@VentasID INT,
	@Fecha DATE,
	@TotalVenta INT,
	@ClienteID INT

AS
BEGIN
	IF exists(
		SELECT * FROM  Clientes where ClienteID = @ClienteID and EstadoCuenta = 1
	)
	BEGIN
		INSERT INTO Ventas(
			VentasID,
			Fecha,
			TotalVenta,
			ClienteID
		) VALUES (
				@VentasID,
				@Fecha,
				@TotalVenta,
				@ClienteID
		)
		PRINT 'Venta registrada correctamente'
	end
	else
	BEGIN
		PRINT 'Venta no registrada, Cliente no activo o no hay registro de cliente'
	end
end
-- exce llamamos al procedimiento
EXEC p_RegVentas
-- ingresar datos de cada variable
	@VentasID = 1,
	@Fecha = '2026-08-19',
	@TotalVenta = 200,
	@ClienteID = 2

SELECT * FROM Clientes
GO

CREATE FUNCTION fn_Descuentos(
	@Precio numeric(6,2),
	@PuntosLealtad int
)
returns numeric(6,2)
as
begin
	declare @PrecioTotal numeric(6,2);
	if @PuntosLealtad >= 10
		set @Precio = @Precio * 0.8;
	else if @PuntosLealtad >= 8
		set @PrecioTotal = @Precio - 0.9;
	else if @PuntosLealtad >= 3
		set @PrecioTotal = @Precio * 0.95;
	else
		set @PrecioTotal = @Precio;
	return @PrecioTotal
end
go
select dbo.fn_Descuentos (80, PuntosLealtad) from Clientes
Go
