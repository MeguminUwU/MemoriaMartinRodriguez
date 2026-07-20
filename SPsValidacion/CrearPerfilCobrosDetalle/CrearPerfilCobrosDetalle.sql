SET SCHEMA "BSCL";

DROP PROCEDURE  "BSCL.Plataforma.BD.Servicios::COM.CrearPerfilCobrosDetalle"  ;

CREATE PROCEDURE
-- 
--  Proposito: Servicio para la creacion del detalle de un Perfil comercial.
--  Autor: CFlores - BCS
--  Fecha Creacion: 23/03/2016
--
--  Modificación: Se incorpora caso de creacion personalizada del detalle (aplicado en modalidad extra)
--  Autor: Jgarces - Jueee
--  Fecha Creacion: 05/05/2017
-- 

 "BSCL.Plataforma.BD.Servicios::COM.CrearPerfilCobrosDetalle"  (
	-- Parametros entrada comunes en todos los servicios publicos
	IN  p_IdEmpresa					bigint,			-- ID  Empresa destino
	IN  p_IdUsuario					bigint,			-- ID  del usuario que solicita el servicio
	IN  p_IdModulo					nvarchar(3),  	-- ID  del Modulo que lo invoca
	IN  p_UsaReglasNegocio	 		nvarchar(1)	,	-- S/N se usa en caso de servicios anidados.
		  
	-- Parametros entrada del servicio publico
	IN  p_IdPerfilCobros					NVARCHAR(40), 
	IN  p_IdValorCobro						NVARCHAR(40), 
	IN  p_IdBolsa							NVARCHAR(10), 
	IN  p_IdTipoProducto					NVARCHAR(4), 
	IN  p_IdTipoOperacion					NVARCHAR(6), 
	IN  p_IdCanalIngreso					VARCHAR(3), 
	IN  p_IdMoneda							VARCHAR(3),
	IN  p_DiasPlazo							BIGINT, 
	IN  p_Prioridad							BIGINT,
	IN  p_IdEstado					   		NVARCHAR(3), 
	-- datos adicionales para el caso personalizado:
	IN	p_EsPersonalizado					NVARCHAR(1) default 'N',
	IN	p_PrefijoIdValorCobro				NVARCHAR(20) default '', -- <IdCobro>_<IdPortafolio>_
	IN  p_IdCobro							NVARCHAR(10) default '',
	IN  p_ValorCobro						DECIMAL(26,8) default null, -- si es variable: porcentaje! -> 5 es 5%, si es fijo 5 es 5 pesos/uf etc.
	IN  p_ValorTopeMinimoOrden				DECIMAL(26,8) default null,
	-- Parametros salida del servicio publico
    OUT p_out_RefId bigint,
	-- Salidas para mensajes de advertencias y errores
	OUT p_out_AdvertenciasContador 	int,
	OUT p_out_AdvertenciasDetalle 	table ("Codigo" nvarchar(40),"RequiereAutorizacion" nvarchar(40),"Descripcion" nvarchar(520)),	
	OUT p_out_ErroresContador 		int,
	OUT p_out_ErroresDetalle 		table ("Codigo" nvarchar(40),"Descripcion" nvarchar(520))
) 
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA BSCL
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
		--------------------
		--Declare Variables
		--------------------
		DECLARE v_IdDetallePerfilCobros, v_IdDetallePerfilCobrosIva, v_IvaExiste	bigint:=0;
		DECLARE v_FechaIngreso					SECONDDATE;-- FORMATO 'YYYY-MM-DD HH24:MI:SS.FF7'
		DECLARE v_IdConcepto	       			NVARCHAR(6):='NDPCOB';
		DECLARE v_RequiereAutorizacion			NVARCHAR(1):='';
		DECLARE v_IdEstadoAutorizacion			NVARCHAR(3):='PEN';
		
	    DECLARE v_out_AdvertenciasContador, v_out_ErroresContador INT;
	    DECLARE v_out_ErroresDetalle           table ("Codigo" nvarchar(40),"Descripcion" nvarchar(520));
        DECLARE v_out_AdvertenciasDetalle      table ("Codigo" nvarchar(40),"RequiereAutorizacion" nvarchar(40),"Descripcion" nvarchar(520));	
       
       	DECLARE v_IdValorCobro,v_IdValorCobroIva	NVARCHAR(40):='';
		DECLARE	v_DescripcionValorCobro			NVARCHAR(100):='';
		DECLARE p_sysDate 						NVARCHAR(20);
	
		--Variables Logs
		DECLARE v_TipoEntidad						NVARCHAR(100):='PERFILCOBROSDETALLE';
		DECLARE v_fechaHoraSistema 					NVARCHAR(40);
		DECLARE v_NombreProceso						NVARCHAR(100):='Ingreso DETALLE PERFIL COBROS';
		DECLARE v_IdCliente							BIGINT:=0;
		DECLARE v_EstadoCliente						NVARCHAR(5):='';
		DECLARE	v_NombreCliente						NVARCHAR(100):='';
		DECLARE	v_IdDocumentoIdentidad				NVARCHAR(40):='';
		DECLARE	v_IdTipoDocumentoIdentidad			NVARCHAR(40):='';
		DECLARE v_IdEntidadBase						NVARCHAR(40):='0';  ---DEBERIA SER SOLO PARA PORTAFOLIO
		DECLARE v_IdPortafilio						BIGINT:=0;
		DECLARE v_countPortafolio					BIGINT:=0;
		DECLARE v_EstadoPortafolio					NVARCHAR(5):='';
		DECLARE v_IdDetalleProducto					BIGINT:=0;
		DECLARE v_subregistro						NVARCHAR(100):='DetallePerfilCobros';
		DECLARE v_TipoProducto						NVARCHAR(100):='';								--OKEI
		DECLARE v_ClasificacionCobro				NVARCHAR(100):='';								--OKEI
		DECLARE v_NombreCobro						NVARCHAR(100):='';								--OKEI
		DECLARE v_TipoOperacion						NVARCHAR(100):='';								--OKEI
		DECLARE v_IdMoneda							NVARCHAR(40):='';								--OKEI
		DECLARE v_TipoCanal							NVARCHAR(100):='';								--OKEI
		DECLARE v_EstadoDetalleProducto				NVARCHAR(100):='';								--OKEI
		DECLARE v_Bolsa								NVARCHAR(100):='';								--OKEI


		BEGIN
			CALL "BSCL.Plataforma.BD.Utilitarios::ObtenerFechaHoraSistema"(p_IdEmpresa,:v_FechaIngreso);
			-- recuperamos numero de secuencia que usaremos para el id 
		    SELECT "BSCL.Plataforma.BD.Secuencias::DetallePerfilCobros".NEXTVAL INTO v_IdDetallePerfilCobros FROM DUMMY;
			p_out_RefId:=v_IdDetallePerfilCobros;
			v_IdValorCobro:=p_IdValorCobro;
			
			if(:p_EsPersonalizado='S') then
				v_IdValorCobro = p_PrefijoIdValorCobro||cast(:v_IdDetallePerfilCobros as nvarchar);
				v_DescripcionValorCobro	= 'COBRO PERSONALIZADO';
				insert into "BSCL.Plataforma.BD::COM.ValorCobro"(
					"IdValorCobro",
					"DescripcionValorCobro",
					"IdTipoProducto",
					"IdCobro",
					"ValorCobro",
					"ValorTopeMinimoOrden",
					"IdMoneda",
					"FechaCreacion",
					"IdEstado",
					"IdEmpresa",
					"EsPersonalizado")
				values(
					:v_IdValorCobro,
					:v_DescripcionValorCobro,
					:p_IdTipoProducto,
					:p_IdCobro,
					:p_ValorCobro,
					:p_ValorTopeMinimoOrden,
					:p_IdMoneda,
					CURRENT_UTCTIMESTAMP,
					:p_IdEstado,
					:p_IdEmpresa,
					'S');
			end if;

			insert into "BSCL.Plataforma.BD::COM.DetallePerfilCobros"(					
				"IdDetallePerfilCobros", 
				"IdPerfilCobros", 
				"IdValorCobro", 
				"IdBolsa", 
				"IdTipoProducto", 
				"IdTipoOperacion", 
				"IdCanalIngreso", 
				"IdMoneda",
				"DiasPlazo", 
				"Prioridad",
				"FechaCreacion", 
				"IdEstado",
				"FechaIngreso",
				"FechaModificacion",
				"IdEstadoAutorizacion",
				"IdUsuarioCreador") 
			values(
				v_IdDetallePerfilCobros,
				p_IdPerfilCobros,
			    v_IdValorCobro,
			    p_IdBolsa,
		 	    p_IdTipoProducto,
			    p_IdTipoOperacion,
				p_IdCanalIngreso,
				p_IdMoneda,
				p_DiasPlazo,
				p_Prioridad,
				CURRENT_UTCTIMESTAMP,
				p_IdEstado,
				v_FechaIngreso,--TO_TIMESTAMP(p_FechaIngreso,'YYYY-MM-DD HH24:MI:SS.FF7') 						
				CURRENT_UTCTIMESTAMP,
				v_IdEstadoAutorizacion,
				p_IdUsuario);--IdUsuarioCreador
				
							
				
			----Agrega iva automatico
			SELECT TOP 1 VC."IdValorCobro" INTO v_IdValorCobroIva DEFAULT NULL FROM "BSCL.Plataforma.BD::COM.Cobro" as C INNER JOIN "BSCL.Plataforma.BD::COM.CobroClasificacion" as CC ON C."IdCobroClasificacion" =  CC."IdCobroClasificacion" INNER JOIN "BSCL.Plataforma.BD::COM.ValorCobro" AS VC ON VC."IdCobro" = C."IdCobro" WHERE C."IdCobro" = 'IVA' AND "IdTipoProducto" = :p_IdTipoProducto ORDER BY VC."IdValorCobro";
			IF (v_IdValorCobroIva IS NOT NULL) THEN
			
				SELECT Count(1) INTO v_IvaExiste FROM "BSCL.Plataforma.BD::COM.DetallePerfilCobros" WHERE "IdPerfilCobros" = :p_IdPerfilCobros AND "Borrado" = 'N' AND "IdValorCobro" LIKE '%IVA%' AND "IdTipoProducto" = :p_IdTipoProducto;
				
				if (v_IvaExiste = 0) then 			
				   SELECT "BSCL.Plataforma.BD.Secuencias::DetallePerfilCobros".NEXTVAL INTO v_IdDetallePerfilCobrosIva FROM DUMMY;
				   
				   insert into "BSCL.Plataforma.BD::COM.DetallePerfilCobros"(					
					"IdDetallePerfilCobros", 
					"IdPerfilCobros", 
					"IdValorCobro", 
					"IdBolsa", 
					"IdTipoProducto", 
					"IdTipoOperacion", 
					"IdCanalIngreso", 
					"IdMoneda",
					"DiasPlazo", 
					"Prioridad",
					"FechaCreacion", 
					"IdEstado",
					"FechaIngreso",
					"FechaModificacion",
					"IdEstadoAutorizacion",
					"IdUsuarioCreador") 
				   values(
					:v_IdDetallePerfilCobrosIva,
					:p_IdPerfilCobros,
				    :v_IdValorCobroIva,
				    :p_IdBolsa,
			 	    :p_IdTipoProducto,
				    :p_IdTipoOperacion,
					:p_IdCanalIngreso,
					:p_IdMoneda,
					:p_DiasPlazo,
					:p_Prioridad,
					CURRENT_UTCTIMESTAMP,
					:p_IdEstado,
					v_FechaIngreso, 						
					CURRENT_UTCTIMESTAMP,
					'ING',
					:p_IdUsuario); 
				end if;
  			END IF;
  			
			------------------------------------------
			--Pregunta Si requiere autorizacion
			------------------------------------------
			V_RegistroSolicitudCambio = select * from "BSCL.Plataforma.BD::PLA.SolicitudCambio" WHERE 1=2;
			
			call "BSCL.Plataforma.BD.Servicios::AUT.RequiereEventoAutorizacion" (
				:p_IdEmpresa,
				:p_IdUsuario,
				:p_IdModulo,
				:V_RegistroSolicitudCambio,
				:v_IdConcepto,
				:v_RequiereAutorizacion
			);
						
			if v_RequiereAutorizacion='S' then
			------------------------------------------
			--Genera Evento de Autorizacion
			------------------------------------------

				DECLARE	 v_Glosa		NVARCHAR(255);
				DECLARE v_out_idAuth 		bigint;
				DECLARE v_out_AuthAdvertenciasContador 	int;
				DECLARE v_out_AuthErroresContador 		int;
				v_out_AuthAdvertenciasDetalle	= select '' as "Codigo",'' as "RequiereAutorizacion",'' as "Descripcion" from dummy where 1=2;
				v_out_AuthErroresDetalle		= select '' as "Codigo",'' as "Descripcion" from dummy where 1=2;
				
				SELECT CAST("DescripcionPerfilCobros" AS NVARCHAR(255))  into  v_Glosa from "BSCL.Plataforma.BD::COM.PerfilCobros" WHERE "IdPerfilCobros"=p_IdPerfilCobros;		
						
						CALL "BSCL.Plataforma.BD.Servicios::AUT.CrearEventoAutorizacion" (
							p_IdEmpresa => p_IdEmpresa,
							p_IdUsuario => p_IdUsuario,
							p_IdModulo => p_IdModulo,
							p_UsaReglasNegocio => 'N',								
							p_IdTipoEvento => v_IdConcepto,--'NUEDOC',
							p_IdModuloSolicita => p_IdModulo,
							p_IdUsuarioSolicita => p_IdUsuario,
							p_Fecha => TO_VARCHAR (CURRENT_UTCTIMESTAMP, 'YYYY-MM-DD'), 
							p_IdConcepto => v_IdConcepto,
							p_NumeroOperacionConcepto =>  CAST (v_IdDetallePerfilCobros AS NVARCHAR(40)),--v_secuencia_IdSolicitudCambio,
							p_FechaOperacionConcepto => TO_VARCHAR (CURRENT_UTCTIMESTAMP, 'YYYY-MM-DD'),
							p_IdCliente => 0,--Mp_IdPersona, --v_IdCliente,
							p_Glosa => v_Glosa,
							--salida
							p_out_IdEvento => v_out_idAuth,
							p_out_AdvertenciasContador => v_out_AuthAdvertenciasContador,
							p_out_AdvertenciasDetalle =>  v_out_AuthAdvertenciasDetalle,
							p_out_ErroresContador =>  v_out_AuthErroresContador,
							p_out_ErroresDetalle =>  v_out_AuthErroresDetalle);		
					
			 p_out_AdvertenciasContador := p_out_AdvertenciasContador + v_out_AuthAdvertenciasContador;	
					  			 
			 p_out_AdvertenciasDetalle = Select "Codigo","RequiereAutorizacion", "Descripcion" 
			                             From :v_out_AuthAdvertenciasDetalle Union All 
			                             Select "Codigo","RequiereAutorizacion", "Descripcion"
			                             From :p_out_AdvertenciasDetalle;  
					                                          
					                                          
			 p_out_ErroresContador := p_out_ErroresContador + v_out_AuthErroresContador;
					                                         
			 p_out_ErroresDetalle = Select "Codigo", "Descripcion" 
			                        From :v_out_AuthErroresDetalle Union All 
			                        Select "Codigo", "Descripcion" 
			                        From :p_out_ErroresDetalle; 
			 if 	p_out_ErroresContador > 0 then
						SIGNAL SALIDA_CONTROLADA;
						
					else
						--Mensaje de Salida
						p_out_AdvertenciasContador := p_out_AdvertenciasContador + 1;	
						v_hash= select '' as "Codigo",'' as "Valor" FROM DUMMY;
						CALL "BSCL.Plataforma.BD.Servicios::ConsultarMensajeDiccionario" ('REQUIERE_AUTORIZACION',:v_hash,:v_erroroutmsg);
						p_out_AdvertenciasDetalle =  select 'REQUIERE_AUTORIZACION' as "Codigo",'S' as "RequiereAutorizacion",:v_erroroutmsg as "Descripcion" from dummy UNION ALL
												     select * from :p_out_AdvertenciasDetalle;
						SIGNAL SALIDA_CONTROLADA;
			  end if;								
			              	                                     
					                                     
			else	--Confirma la creacion y cambia el estado del documento

				v_IdEstadoAutorizacion:='ING';
				CALL "BSCL.Plataforma.BD.Servicios::COM.ConfirmarCrearPerfilCobrosDetalle"(
					p_IdEmpresa,
					p_IdUsuario,
					p_IdModulo,
					p_UsaReglasNegocio,
					v_IdDetallePerfilCobros,
					v_IdEstadoAutorizacion,
					v_out_AdvertenciasContador,
					v_out_AdvertenciasDetalle,
					v_out_ErroresContador,
					v_out_ErroresDetalle);

				 p_out_AdvertenciasContador := p_out_AdvertenciasContador + v_out_AdvertenciasContador;	
					  			 
				 p_out_AdvertenciasDetalle = Select "Codigo","RequiereAutorizacion", "Descripcion" 
				                             From :v_out_AdvertenciasDetalle Union All 
				                             Select "Codigo","RequiereAutorizacion", "Descripcion"
				                             From :p_out_AdvertenciasDetalle;  
				                                         
					                                          
				 p_out_ErroresContador := p_out_ErroresContador + v_out_ErroresContador;
					                                         
				 p_out_ErroresDetalle = Select "Codigo", "Descripcion" 
				                             From :v_out_ErroresDetalle Union All 
				                             Select "Codigo", "Descripcion" 
				                             From :p_out_ErroresDetalle; 
							
							
			end if;
			
		
			
		END;		
		
		--INICIO LOG AUDITORIA
		BEGIN
			
			SELECT 
				CASE 
					WHEN "PERFCOBROS"."IdPerfilCobros" LIKE_REGEXPR 'EXT' THEN REPLACE("PERFCOBROS"."IdPerfilCobros", 'EXT_', '')
					ELSE '0'
				END 															AS "IdEntidadBase",
				COALESCE("PERFCOBROS"."TipoProducto", '')						AS "Producto",
				COALESCE("PERFCOBROS"."CodigoCobroClasificacion", '')			AS "ClasificiacionCobro",
				COALESCE("PERFCOBROS"."NombreCobro", '')						AS "Cobro",
				COALESCE("PERFCOBROS"."IdMoneda", '')							AS "Moneda",
				COALESCE("BOL"."Nombre", '')									AS "Bolsa",
				COALESCE("PERFCOBROS"."TipoOperacion", '')						AS "Operacion",
				COALESCE("PERFCOBROS"."CanalIngreso", '')						AS "Canal",
				COALESCE("PERFCOBROS"."EstadoPerfilCobros", '')					AS "Estado"
			INTO 
				v_IdEntidadBase,
				v_TipoProducto,
				v_ClasificacionCobro,
				v_NombreCobro,
				v_IdMoneda,
				v_Bolsa,
				v_TipoOperacion,
				v_TipoCanal,
				v_EstadoDetalleProducto
				FROM "BSCL.Plataforma.BD.Vistas::COM.ConsultarDetallePerfilCobros" "PERFCOBROS"
				LEFT JOIN "BSCL.Plataforma.BD::INS.Bolsa" "BOL"
					ON ("PERFCOBROS"."IdBolsa" =  "BOL"."IdBolsa")
				WHERE  "PERFCOBROS"."IdDetallePerfilCobros" = :v_IdDetallePerfilCobros;
			
			--PREPARAR CABECERA LOG
			IF(v_IdEntidadBase <> '0') THEN 
			
				SELECT count(*) INTO v_countPortafolio FROM "BSCL.Portafolio.BD.Vistas::ConsultarPortafolio" WHERE "IdPortafolio" = :v_IdEntidadBase;
				
				IF(v_countPortafolio = 1) THEN 
				
					SELECT 
						"CLI"."IdCliente",									
						COALESCE("CLI"."NombreCompleto",''),					
						"CLI"."DocumentoIdentidad",
						"CLI"."TipoDocumentoIdentidad",
						"CLI"."IdEstado",	
						"PORT"."IdPortafolio", 
						"PORT"."IdEstado"
					INTO 
						v_IdCliente,
						v_NombreCliente,
						v_IdDocumentoIdentidad,
						v_IdTipoDocumentoIdentidad,
						v_EstadoCliente,
						v_IdPortafilio,
						v_EstadoPortafolio
							FROM "BSCL.Portafolio.BD.Vistas::ConsultarPortafolio" "PORT"
							LEFT JOIN "BSCL.SocioNegocio.BD.Vistas::CLI.ConsultarCliente" "CLI"
								ON ("PORT"."IdCliente" = "CLI"."IdCliente")
							WHERE "IdPortafolio" = :v_IdEntidadBase;	
				
					v_TipoEntidad:= v_TipoEntidad||'PORTAFOLIO';
				
				END IF;
			
			END IF;

			--DETALLE LOG
			p_DetalleLog = (SELECT v_subregistro AS "SubRegistro", 'TipoPoroducto' AS "CampoRegistro", '' AS "ValorAntiguo", v_TipoProducto AS "ValorNuevo"
										FROM dummy
									UNION ALL 
									SELECT v_subregistro AS "SubRegistro", 'ClasificacionCobro' AS "CampoRegistro", '' AS "ValorAntiguo", v_ClasificacionCobro AS "ValorNuevo"
										FROM dummy
									UNION ALL
									SELECT v_subregistro AS "SubRegistro", 'NombreCobro' AS "CampoRegistro", '' AS "ValorAntiguo", v_NombreCobro AS "ValorNuevo"
										FROM dummy
									UNION ALL
									SELECT v_subregistro AS "SubRegistro", 'Moneda' AS "CampoRegistro", '' AS "ValorAntiguo", v_IdMoneda AS "ValorNuevo"
										FROM dummy
									UNION ALL
									SELECT v_subregistro AS "SubRegistro", 'Bolsa' AS "CampoRegistro", '' AS "ValorAntiguo", v_Bolsa AS "ValorNuevo"
										FROM dummy
									UNION ALL
									SELECT v_subregistro AS "SubRegistro", 'TipoOperacion' AS "CampoRegistro", '' AS "ValorAntiguo", v_TipoOperacion AS "ValorNuevo"
										FROM dummy
									UNION ALL
									SELECT v_subregistro AS "SubRegistro", 'TipoCanal' AS "CampoRegistro", '' AS "ValorAntiguo", v_TipoCanal AS "ValorNuevo"
										FROM dummy
									UNION ALL
									SELECT v_subregistro AS "SubRegistro", 'Estado' AS "CampoRegistro", '' AS "ValorAntiguo", v_EstadoDetalleProducto AS "ValorNuevo"
										FROM dummy);
		
			CALL "BSCL.Plataforma.BD.Utilitarios::ObtenerFechaHoraSistema"(
				p_IdEmpresa => p_IdEmpresa,
				p_out_FechaHoraSistema => v_fechaHoraSistema
			);

			--GRABAR LOG
			CALL "BSCL.Plataforma.BD.Servicios::AgregarLog" (
				p_IdTipoLog => 'INGRESO' 
				,p_IdModulo => 'PLA'
				,p_IdUsuario => p_IdUsuario 
				,p_IdEmpresa => p_IdEmpresa 
				,p_FechaSistemaLog => TO_VARCHAR (v_fechaHoraSistema, 'YYYY-MM-DD')
				,p_IdUsuarioAtendido => p_IdUsuario
				,p_IdTipoRegistro => v_TipoEntidad
				,p_DetalleLog => :p_DetalleLog	-- hacia arriba obligatorios
				,p_NombreProceso => :v_NombreProceso-- hacia abajo opcionales
				,p_IdRegistro => :v_IdDetallePerfilCobros
				,p_IdPortafolio => :v_IdPortafilio
				,p_EstadoPortafolio => :v_EstadoPortafolio
				,p_EstadoProceso => :v_IdEstadoAutorizacion
				,p_IdCliente => :v_IdCliente
				,p_NombreCliente => :v_NombreCliente
				,p_IdTipoDocumentoIdentidad => :v_IdTipoDocumentoIdentidad
				,p_IdDocumentoIdentidad => :v_IdDocumentoIdentidad
				,p_EstadoCliente => :v_EstadoCliente
			);
					
	 	END;	
	 	--FIN LOG AUDITORIA
		--------------------
		-- Normativo 
		--------------------
		
		
		--------------------
		--FIN SP 
		--------------------
	END;	
END;