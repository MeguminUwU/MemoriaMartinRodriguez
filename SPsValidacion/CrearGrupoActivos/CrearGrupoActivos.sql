SET SCHEMA "BSCL";

DROP PROCEDURE  "BSCL.Plataforma.BD.Servicios::COM.CrearGrupoActivos";

CREATE PROCEDURE  
-- 
--  Proposito: Creacion de Grupo de Activos, recibe Cabecera y Detalle.
--  Autor: JG - BCS
--  Fecha Creacion: 07/01/2016
--  
"BSCL.Plataforma.BD.Servicios::COM.CrearGrupoActivos" (
	-- Parametros entrada comunes en todos los servicios publicos

	IN  p_IdEmpresa							bigint,			--ID Empresa destino
	IN  p_IdUsuario							bigint,			--ID del usuario que solicita el servicio
	IN  p_IdModulo							nvarchar(3),  	--ID del Modulo que lo invoca
	IN  p_simularOperacion					nvarchar(1),	-- S/N se usa para simular operacion (algunos casos)
	IN  p_UsaReglasNegocio	 				nvarchar(1),	-- S/N se usa en caso de servicios anidados.	

	IN p_IdGrupoActivos						NVARCHAR(40),	
	IN p_DescripcionGrupoActivos			NVARCHAR(100),		
	IN p_IdTipoGrupoActivos					NVARCHAR(40),			
	IN p_IdEstado							NVARCHAR(3),	
	IN p_PorDefecto							NVARCHAR(1),

	-- Parametros salida del servicio publico
	OUT p_out_RefId bigint,	
	-- Salidas para mensajes de advertencias y errores
	OUT p_out_AdvertenciasContador int,
	OUT p_out_AdvertenciasDetalle table ("Codigo" nvarchar(40),"RequiereAutorizacion" nvarchar(40),"Descripcion" nvarchar(520)),	
	OUT p_out_ErroresContador int,
	OUT p_out_ErroresDetalle table ("Codigo" nvarchar(40),"Descripcion" nvarchar(520))
) 
	LANGUAGE SQLSCRIPT
	SQL SECURITY INVOKER 
	DEFAULT SCHEMA "BSCL"
AS
BEGIN
	--------------------
	--DECLARE Manejo de Errores
	--------------------	
	DECLARE SALIDA_CONTROLADA CONDITION; 
	DECLARE v_errorcuenta INT DEFAULT 0;  
	DECLARE v_errorhashmsg table ("Codigo" nvarchar(40),"Valor" nvarchar(520));
	DECLARE v_erroroutmsg  nvarchar(520);	        	
	DECLARE EXIT HANDLER FOR SALIDA_CONTROLADA	 
	BEGIN
		--salida/error/advertencia controlado por este servicio
		select count(1) into p_out_ErroresContador 
		from :p_out_ErroresDetalle;
		select count(1) into p_out_AdvertenciasContador 
		from :p_out_AdvertenciasDetalle;		 					 	
	END;
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		declare v_errorExt nvarchar(40);
		IF ::SQL_ERROR_CODE > 10000 THEN
			--error pseudo-controlado pero desde un Sub-SP
			call "BSCL.Plataforma.BD.Servicios::ConsultarCodigoMensajeError" (::SQL_ERROR_CODE,v_errorExt);			
			p_out_ErroresDetalle = select * from :p_out_ErroresDetalle UNION ALL  
								   select v_errorExt,::SQL_ERROR_MESSAGE from dummy;				
			select count(1) into p_out_ErroresContador 
			from :p_out_ErroresDetalle;										
		ELSE
			--Error interno no manejado  (El log será captado por la capa de XS control)		
			RESIGNAL; 
		END IF;		
	END;	
	p_out_AdvertenciasContador	:= 0;
	p_out_ErroresContador		:= 0;
	p_out_AdvertenciasDetalle	= select '' as "Codigo",'' as "RequiereAutorizacion",'' as "Descripcion" from dummy where 1=2;
	p_out_ErroresDetalle		= select '' as "Codigo",'' as "Descripcion" from dummy where 1=2;
	BEGIN	
		-----------------------------------------------------
		--Declaraciones Variables
		-----------------------------------------------------
		DECLARE p_sysDate 						NVARCHAR(20);
		DECLARE p_DetalleLog TABLE ("SubRegistro" nvarchar(40), "CampoRegistro" nvarchar(40), "ValorAntiguo" nvarchar(250), "ValorNuevo" nvarchar(250));
		
		-----------------------------------------------------
		--Validaciones básicas (Codigos,Existencias,etc)
		-----------------------------------------------------
			
		--------------------
		--Reglas Negocio 
		--------------------		
		
		
		--Solo fue una simulacion del servicio... move bitch,get out the way
		if p_simularOperacion = 'S' then
			SIGNAL SALIDA_CONTROLADA;
		end if;		
				
		--------------------
		--Negocio Aqui
		--------------------
		BEGIN
		
			INSERT INTO "BSCL.Plataforma.BD::COM.GrupoActivos"(
				"IdGrupoActivos",
				"DescripcionGrupoActivos",
				"IdTipoGrupoActivos",
				"FechaCreacion",
				"FechaModificacion",
				"IdEstado",
				"PorDefecto",
				"IdEmpresa"
			)
			VALUES(
				:p_IdGrupoActivos,	
				:p_DescripcionGrupoActivos,	
				:p_IdTipoGrupoActivos,	
				CURRENT_UTCTIMESTAMP,
				CURRENT_UTCTIMESTAMP,		
				:p_IdEstado,	
				:p_PorDefecto,
				:p_IdEmpresa
			);

			select 1 into p_out_RefId from dummy;
					
		END;
		
		BEGIN
					--LOG
					--REEMPLAZAR POR LOG MASIVO							
						p_DetalleLog =  
						SELECT 	'INGRESO' as "SubRegistro", 
								'IdGrupoActivos' as "CampoRegistro", 
								'' as "ValorAntiguo", 
								:p_IdGrupoActivos as "ValorNuevo" FROM dummy;
						
						SELECT CURRENT_DATE into p_sysDate from DUMMY;
					
						CALL "BSCL.Plataforma.BD.Servicios::AgregarLog" (
							 p_IdTipoLog => 'INGRESO' 
							,p_IdModulo => 'PLA' 
							,p_IdUsuario => p_IdUsuario 
							,p_IdEmpresa => p_IdEmpresa 
							,p_FechaSistemaLog => TO_VARCHAR (p_sysDate, 'YYYY-MM-DD')
							,p_IdUsuarioAtendido => p_IdUsuario
							,p_IdTipoRegistro => 'GRUPO ACTIVOS'
							,p_DetalleLog => :p_DetalleLog
						);
					
	 	END;			
		--------------------
		--Normativo 
		--------------------
		
		--------------------
		--FIN SP 
		--------------------
	END;	
END;