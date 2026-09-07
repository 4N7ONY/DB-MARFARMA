-- ==============================================================================
-- PROYECTO INTEGRADOR: BOTICA MARFARMA (ADAPTADO AL DESAFÍO DATASALUD)
-- ==============================================================================

CREATE DATABASE MarfarmaDB;
GO
USE MarfarmaDB;
GO

-- ------------------------------------------------------------------------------
-- BLOQUE 2: SEGURIDAD Y CUMPLIMIENTO (LEY N.º 29733)
-- ------------------------------------------------------------------------------
-- Creación de roles con segregación de privilegios[cite: 2]
CREATE ROLE Rol_Administrador_Datos;
CREATE ROLE Rol_Analista_BI;
CREATE ROLE Rol_Auditor_Seguridad;
GO

-- Tabla de Log de Auditoría para rastrear quién modifica qué y cuándo[cite: 2]
CREATE TABLE Auditoria_Log (
    ID_Log INT IDENTITY(1,1) PRIMARY KEY,
    Tabla_Afectada VARCHAR(50),
    Accion VARCHAR(50), -- INSERT, UPDATE, DELETE
    Usuario_DB VARCHAR(100),
    Fecha_Hora DATETIME DEFAULT GETDATE(),
    Detalles NVARCHAR(MAX)
);
GO

-- ------------------------------------------------------------------------------
-- BLOQUE 3: INTELIGENCIA DE NEGOCIOS - MODELO KIMBALL (BOTTOM-UP)[cite: 2]
-- Esquema Estrella (Star Schema)[cite: 2]
-- ------------------------------------------------------------------------------

-- Dimensiones
CREATE TABLE Dim_Tiempo (
    DateKey INT PRIMARY KEY,
    Fecha DATE,
    Anio INT,
    Mes INT,
    Dia INT,
    NombreMes VARCHAR(20)
);

CREATE TABLE Dim_Cliente (
    ClienteKey INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Completo VARCHAR(150),
    Grupo_Etario VARCHAR(50)
);

CREATE TABLE Dim_Producto (
    ProductoKey INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Producto VARCHAR(150),
    Tipo_Producto VARCHAR(50),
    Es_Medicamento VARCHAR(2),
    Es_Agente_BCP VARCHAR(2)
);

CREATE TABLE Dim_Sede (
    SedeKey INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Sede VARCHAR(100)
);

-- Tabla de Hechos
CREATE TABLE Fact_Transacciones (
    TransaccionKey INT IDENTITY(1,1) PRIMARY KEY,
    ID_Transaccion_Original VARCHAR(20),
    DateKey INT FOREIGN KEY REFERENCES Dim_Tiempo(DateKey),
    ClienteKey INT FOREIGN KEY REFERENCES Dim_Cliente(ClienteKey),
    ProductoKey INT FOREIGN KEY REFERENCES Dim_Producto(ProductoKey),
    SedeKey INT FOREIGN KEY REFERENCES Dim_Sede(SedeKey),
    Cantidad INT DEFAULT 1,
    Monto_Estimado DECIMAL(10,2) NULL -- Para agregar métricas en tu dashboard
);
GO

-- ------------------------------------------------------------------------------
-- BLOQUE 1: AUTOMATIZACIÓN (PROCEDIMIENTOS, TRIGGERS Y FUNCIONES)[cite: 2]
-- ------------------------------------------------------------------------------

-- 1. Función Escalar: Categorizar si es grupo de riesgo para reportes de morbilidad[cite: 2]
CREATE FUNCTION fn_EsGrupoRiesgo (@GrupoEtario VARCHAR(50))
RETURNS BIT
AS
BEGIN
    DECLARE @EsRiesgo BIT = 0;
    IF @GrupoEtario IN ('Niño (0-11)', 'Adulto Mayor (60+)')
        SET @EsRiesgo = 1;
    RETURN @EsRiesgo;
END;
GO

-- 2. Procedimiento Almacenado 1: Ingesta segura con TRY/CATCH y Transacciones[cite: 2]
CREATE PROCEDURE sp_IngestarNuevaTransaccion
    @ID_Transaccion VARCHAR(20),
    @Fecha DATE,
    @NombreCliente VARCHAR(150),
    @GrupoEtario VARCHAR(50),
    @NombreProducto VARCHAR(150),
    @TipoProducto VARCHAR(50)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Aquí iría la lógica de buscar IDs (ClienteKey, ProductoKey, etc.)
        -- Para el ejemplo, insertamos directamente a clientes si no existe
        IF NOT EXISTS (SELECT 1 FROM Dim_Cliente WHERE Nombre_Completo = @NombreCliente)
        BEGIN
            INSERT INTO Dim_Cliente (Nombre_Completo, Grupo_Etario) VALUES (@NombreCliente, @GrupoEtario);
        END

        -- Simulación de inserción en la tabla de hechos
        -- INSERT INTO Fact_Transacciones (...) VALUES (...)

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        -- Registro del error para control de excepciones[cite: 2]
        INSERT INTO Auditoria_Log (Tabla_Afectada, Accion, Usuario_DB, Detalles)
        VALUES ('Fact_Transacciones', 'ERROR_SP', SYSTEM_USER, ERROR_MESSAGE());
    END CATCH
END;
GO

-- 3. Procedimiento Almacenado 2: Limpieza de datos (Manejo de nulos)[cite: 2]
CREATE PROCEDURE sp_LimpiarNulosGrupoEtario
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        UPDATE Dim_Cliente
        SET Grupo_Etario = 'No Especificado'
        WHERE Grupo_Etario IS NULL OR Grupo_Etario = 'nan';
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4. Trigger 1: Auditoría DML (Registra quién inserta datos)[cite: 2]
CREATE TRIGGER trg_AuditarTransacciones
ON Fact_Transacciones
AFTER INSERT, UPDATE
AS
BEGIN
    INSERT INTO Auditoria_Log (Tabla_Afectada, Accion, Usuario_DB, Detalles)
    SELECT 
        'Fact_Transacciones', 
        CASE WHEN EXISTS(SELECT * FROM DELETED) THEN 'UPDATE' ELSE 'INSERT' END,
        SYSTEM_USER,
        'Se modificó el registro de transacción ID: ' + CAST(i.TransaccionKey AS VARCHAR)
    FROM inserted i;
END;
GO

-- 5. Trigger 2: Integridad (Bloquea transacciones de fechas futuras)[cite: 2]
CREATE TRIGGER trg_IntegridadFecha
ON Dim_Tiempo
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE Fecha > GETDATE())
    BEGIN
        RAISERROR ('No se pueden registrar fechas futuras por integridad de los datos.', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        INSERT INTO Dim_Tiempo (DateKey, Fecha, Anio, Mes, Dia, NombreMes)
        SELECT DateKey, Fecha, Anio, Mes, Dia, NombreMes FROM inserted;
    END
END;
GO