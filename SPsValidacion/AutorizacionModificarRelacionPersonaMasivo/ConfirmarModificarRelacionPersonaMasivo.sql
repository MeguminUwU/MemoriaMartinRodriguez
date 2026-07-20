SET SCHEMA "BSCL";

DROP PROCEDURE  "BSCL.SocioNegocio.BD.Servicios::REL.ConfirmarModificarRelacionPersonaMasivo";

CREATE PROCEDURE
-- 
--  Proposito: Servicio para confirmar la modificacion a las relaciones entre entidades.
--  Invocado desde el modulo de autorizaciones o del propio negocio al no requerir autorizacion. 
--  Autor: CFLORES - BCS
--  Fecha Creacion: 03-02-2016
--  
"BSCL.SocioNegocio.BD.Servicios::REL.ConfirmarModificarRelacionPersonaMasivo" (
	-- Parametros entrada comunes en todos los servicios publicos
	IN  p_IdEmpresa									BIGINT,			--ID Empresa destino
	IN  p_IdUsuario									BIGINT,			--ID del usuario que solicita el servicio
	IN  p_IdModulo									NVARCHAR(3),  	--ID del Modulo que lo invoca
	IN  p_UsaReglasNegocio	 						NVARCHAR(1),	-- S/N se usa en caso de servicios anidados.
		  
	-- Parametros entrada del servicio publico

	IN 	p_RelacionPersona							TABLE ("IdRelacionPersona"	BIGINT),
	IN  p_IdEstadoAutorizacion						NVARCHAR(3),
	
	-- Parametros salida del servicio publico
	--OUT p_out_RefId 								BIGINT,
			
	-- Salidas para mensajes de advertencias y errores
	OUT p_out_AdvertenciasContador 		int,
	OUT p_out_AdvertenciasDetalle 		table ("Codigo" nvarchar(40),"RequiereAutorizacion" nvarchar(40),"Descripcion" nvarchar(5000)),	
	OUT p_out_ErroresContador 			int,
	OUT p_out_ErroresDetalle 			table ("Codigo" nvarchar(40),"Descripcion" nvarchar(5000))
	
) 
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA "BSCL"
AS
BEGIN
	--------------------
	--DECLARE Manejo de Errores
	--------------------	
	DECLARE SALIDA_CONTROLADA 		CONDITION; 
	DECLARE v_errorcuenta 			INT DEFAULT 0;  
	DECLARE v_errorhashmsg 			table ("Codigo" nvarchar(40),"Valor" nvarchar(5000));
	DECLARE v_erroroutmsg  			nvarchar(5000);	        	
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
			DECLARE v_countSolicitud								BIGINT:=0;
			DECLARE v_countAutorizacionesPendientes					BIGINT;
			DECLARE v_IdEntidadOrigen								NVARCHAR(40);
			DECLARE v_TipoEntidad									NVARCHAR(40):= 'RELACION-PERSONA';
			DECLARE v_CampoModificado								NVARCHAR(255):='';
			DECLARE v_CountAtributoModificado						BIGINT:=0;
			DECLARE v_CountAtributoNuevo							BIGINT:=0;
			DECLARE v_countProcesados								BIGINT:=0;
			
			-- CUENTA DE CAMPOS A MODIFICAR.
			DECLARE v_count_FechaInicioRelacion			 			BIGINT:=0;
			DECLARE v_count_FechaFinRelacion						BIGINT:=0;
			DECLARE v_count_IdEstado	 							BIGINT:=0;
			DECLARE v_count_PorcentajeParticipacion					BIGINT:=0;
			
			DECLARE v_count_Ciudad									BIGINT:=0;
			DECLARE v_count_Calle									BIGINT:=0;
			DECLARE v_count_Numero									BIGINT:=0;
			DECLARE v_count_Email									BIGINT:=0;
			DECLARE v_count_Telefono								BIGINT:=0;
			DECLARE v_count_Complemento								BIGINT:=0;

			
		--------------------
		--Validaciones
		--------------------
		
		-- Existencia de solicitud.	


		BEGIN
			--v_IdEntidadOrigen:=CAST (p_IdRelacionPersona AS NVARCHAR(40));
			
			SELECT COUNT("IdSolicitudCambio") INTO v_countSolicitud
			FROM "BSCL.Plataforma.BD.Vistas::PLA.ConsultarSolicitudCambio" SOL
			JOIN :p_RelacionPersona P ON  CAST(P."IdRelacionPersona" AS NVARCHAR(40)) = SOL."IdEntidadOrigen"
				AND SOL."IdTipoEntidad" 		= v_TipoEntidad
                AND SOL."IdEstadoAutorizacion"	='PEN';
                
                IF(v_countSolicitud=0) THEN
				p_out_ErroresDetalle =  select 'SOLICITUD_NO_EXISTE' as "Codigo",:v_erroroutmsg as "Descripcion" from dummy;
				SIGNAL SALIDA_CONTROLADA; 	
			END IF;

			
		END;

		--------------------
		--Reglas Negocio
		--------------------		
		
		--------------------
		--Lógica Negocio
		--------------------
		BEGIN
			DECLARE v_fechaHoraSistema NVARCHAR(40);

			--ACTUALIZACION DE VALORES (* ENTIDAD EXISTENTE *)
									
			--DATOS MAESTROS DE LA ENTIDAD 
			v_DatosSolicitudCambio = SELECT SOL.*, REL."IdPersonaOrigen" 
			FROM "BSCL.Plataforma.BD.Vistas::PLA.ConsultarSolicitudCambio" SOL
			JOIN :p_RelacionPersona P ON  CAST(P."IdRelacionPersona" AS NVARCHAR(40)) = SOL."IdEntidadOrigen"
				AND SOL."IdTipoEntidad" 		= v_TipoEntidad
                AND SOL."IdEstadoAutorizacion"	='PEN'
            LEFT JOIN "BSCL.SocioNegocio.BD::REL.RelacionPersona"REL ON P."IdRelacionPersona" = REL."IdRelacionPersona"; 
			
			SELECT 	COUNT("IdSolicitudCambio") INTO	v_CountAtributoModificado FROM	:v_DatosSolicitudCambio;
			
			IF (v_CountAtributoModificado > 0) 	 THEN
			
					call "BSCL.Plataforma.BD.Utilitarios::ObtenerFechaHoraSistema"(
						p_IdEmpresa => p_IdEmpresa,
						p_out_FechaHoraSistema => v_fechaHoraSistema
					);
					INSERT INTO "BSCL.SocioNegocio.BD::CLI.LogGenerarContratos"
					("Idlog","CodigoFormulario","CampoBackend","IdEmpresa", "IdCliente", "IdPersona", "IdUsuario", "FechaSistema", "IdPrograma", "Estado", "Mensaje")
					SELECT "BSCL.SocioNegocio.BD.Secuencias::LogGenerarContratos".NEXTVAL, 'RELACIONES_', "CampoModificado", :p_IdEmpresa, 0, "IdPersonaOrigen", :p_IdUsuario, LEFT(:v_fechaHoraSistema,10) , 0, 'PEN', 'Persona - ConfirmarModificarRelacionPersonaMasivo.sql'
					FROM :v_DatosSolicitudCambio
					WHERE "ValorAntiguo" != "ValorNuevo";
			
					v_CampoModificado:='FechaInicioRelacion';
					SELECT count("ValorNuevo") INTO v_count_FechaInicioRelacion
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					
					IF (v_count_FechaInicioRelacion > 0) THEN
		
						UPDATE  DOC
						SET
							DOC."FechaInicioRelacion" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
							
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
								INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
								MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"			= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
							
							v_countProcesados:=v_countProcesados + 1;
					END IF;


			
					v_CampoModificado:='FechaFinRelacion';
					SELECT count("ValorNuevo") INTO v_count_FechaFinRelacion
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					
					IF (v_count_FechaFinRelacion > 0) THEN
		
						UPDATE  DOC
						SET
							DOC."FechaFinRelacion" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
							
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
								INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
								MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"			= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
							
							v_countProcesados:=v_countProcesados + 1;
					END IF;
					
					v_CampoModificado:='RetiraDocumentos';
					SELECT count("ValorNuevo") INTO v_count_FechaFinRelacion
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					
					IF (v_count_FechaFinRelacion > 0) THEN
		
						UPDATE  DOC
						SET
							DOC."RetiraDocumentos" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
							
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
								INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
								MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"			= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
							
							v_countProcesados:=v_countProcesados + 1;
					END IF;


					v_CampoModificado:='IdEstado';
					SELECT count("ValorNuevo") INTO v_count_IdEstado
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					
					IF (v_count_IdEstado > 0) THEN
		
						UPDATE  DOC
						SET
							DOC."IdEstado" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
							
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
								INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
								MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"			= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
							
							v_countProcesados:=v_countProcesados + 1;
						
						--busco todas las rel que son de repLegal que esten activas
						v_repLegalOrigen =	SELECT DOC."IdRelacionPersona",DOC."IdTipoRelacion",DOC."IdPersonaOrigen",DOC."IdPersonaDestino",DOC."IdEstado"--,count(DOC."IdRelacionPersona") AS "CountRep"
										FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
											INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
										WHERE 
											MOD."CampoModificado" 		= v_CampoModificado
											AND	MOD."IdTipoEntidad"		= v_TipoEntidad;
											
						v_repLegalCount = SELECT DOC."IdTipoRelacion",DOC."IdPersonaOrigen",DOC."IdEstado",count(DOC."IdTipoRelacion") AS "CountRep"
									FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
										INNER JOIN :v_repLegalOrigen MOD ON (DOC."IdPersonaOrigen"= MOD."IdPersonaOrigen" )
									GROUP BY DOC."IdTipoRelacion",DOC."IdPersonaOrigen",DOC."IdEstado";
						
						v_repLegal = SELECT DOC."IdRelacionPersona",DOC."IdTipoRelacion",DOC."IdPersonaOrigen",DOC."IdPersonaDestino",DOC."IdEstado"
									FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
										INNER JOIN :v_repLegalOrigen MOD ON (DOC."IdPersonaOrigen"= MOD."IdPersonaOrigen" );
								
								UPDATE per
								SET per."IdPersonaRepresentante" = rep."IdPersonaDestino"
								FROM "BSCL.SocioNegocio.BD::PER.Persona" per 
									INNER JOIN :v_repLegalcount repCount ON per."IdPersona" = repCount."IdPersonaOrigen" AND repCount."IdTipoRelacion" ='REP' AND repCount."IdEstado" = 'ACT'
									INNER JOIN :v_repLegal rep ON per."IdPersona" = rep."IdPersonaOrigen" AND rep."IdTipoRelacion" ='REP' AND rep."IdEstado" = 'ACT'
								WHERE repCount."CountRep" = 1 ;
							 
						v_repLegalPer = SELECT per."IdPersona",per."IdPersonaRepresentante",rep."IdEstado" 
									 FROM "BSCL.SocioNegocio.BD::PER.Persona" per 
										INNER  JOIN :v_repLegal rep ON per."IdPersona" = rep."IdPersonaOrigen" AND per."IdPersonaRepresentante" = rep."IdPersonaDestino"
									 WHERE rep."IdTipoRelacion" ='REP'; 

								UPDATE per
								SET per."IdPersonaRepresentante" = 0
								FROM "BSCL.SocioNegocio.BD::PER.Persona" per 
									INNER JOIN :v_repLegalPer rep ON per."IdPersona" = rep."IdPersona" AND per."IdPersonaRepresentante" = rep."IdPersonaRepresentante"--rep."CountRep" < 1;
								WHERE rep."IdEstado"='BLO';
					END IF;


					v_CampoModificado:='PorcentajeParticipacion';
					SELECT count("ValorNuevo") INTO v_count_PorcentajeParticipacion
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					
					IF (v_count_PorcentajeParticipacion > 0) THEN
		
						UPDATE  DOC
						SET
							DOC."PorcentajeParticipacion" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
							
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
								INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
								MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"			= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
							
							v_countProcesados:=v_countProcesados + 1;
					END IF;
					
						v_CampoModificado:='Ciudad';
					SELECT count("ValorNuevo") INTO v_count_Ciudad
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					IF (v_count_Ciudad > 0) THEN
						UPDATE  DOC
						SET
							DOC."Ciudad" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
							INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
							MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"		= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
						v_countProcesados:=v_countProcesados + 1;
					END IF;
					
					v_CampoModificado:='Calle';
					SELECT count("ValorNuevo") INTO v_count_Calle
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					IF (v_count_Calle > 0) THEN
						UPDATE  DOC
						SET
							DOC."Calle" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
							INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
							MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"		= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
						v_countProcesados:=v_countProcesados + 1;
					END IF;
					
					v_CampoModificado:='Numero';
					SELECT count("ValorNuevo") INTO v_count_Numero
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					IF (v_count_Numero > 0) THEN
						UPDATE  DOC
						SET
							DOC."Numero" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
							INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
							MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"		= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
						v_countProcesados:=v_countProcesados + 1;
					END IF;
					
					v_CampoModificado:='Email';
					SELECT count("ValorNuevo") INTO v_count_Email
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					IF (v_count_Email > 0) THEN
						UPDATE  DOC
						SET
							DOC."Email" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
							INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
							MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"		= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
						v_countProcesados:=v_countProcesados + 1;
					END IF;
					
					v_CampoModificado:='Telefono';
					SELECT count("ValorNuevo") INTO v_count_Telefono
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					IF (v_count_Telefono > 0) THEN
						UPDATE  DOC
						SET
							DOC."Telefono" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
							INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
							MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"		= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
						v_countProcesados:=v_countProcesados + 1;
					END IF;
					
					v_CampoModificado:='Complemento';
					SELECT count("ValorNuevo") INTO v_count_Complemento
					FROM :v_DatosSolicitudCambio WHERE "CampoModificado" = v_CampoModificado
					AND "IdTipoEntidad"= v_TipoEntidad;
					IF (v_count_Complemento > 0) THEN
						UPDATE  DOC
						SET
							DOC."Complemento" = MOD."ValorNuevo",
							DOC."FechaModificacion" = CURRENT_UTCTIMESTAMP
						FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" DOC
							INNER JOIN :v_DatosSolicitudCambio MOD ON (DOC."IdRelacionPersona"= cast (MOD."IdEntidadOrigen" as int))
						WHERE 
							MOD."CampoModificado" 		= v_CampoModificado
							AND	MOD."IdTipoEntidad"		= v_TipoEntidad
							AND DOC."IdRelacionPersona"	= cast (MOD."IdEntidadOrigen" as int);
						v_countProcesados:=v_countProcesados + 1;
					END IF;
				
			END IF;	
			--Se termina el flujo con la actualizacion del registro de solicitud.
			v_SolicitudCambio = SELECT 0 as "IdSolicitudCambio" FROM dummy where 1=2;
			v_EntidadOrigen = SELECT "IdEntidadOrigen", "IdTipoEntidad" FROM :v_DatosSolicitudCambio;
			CALL "BSCL.Plataforma.BD.Servicios::PLA.ModificarEstadoRegistroSolicitudCambioMasivo" (
				p_IdEmpresa				=>:p_IdEmpresa,
				p_IdUsuario				=>:p_IdUsuario,
				p_IdModulo				=>:p_IdModulo,
				p_SolicitudCambio			=>:v_SolicitudCambio,
				p_EntidadOrigen			    =>:v_EntidadOrigen,
				p_IdEstadoAutorizacion	=>:p_IdEstadoAutorizacion,
				p_out_AdvertenciasContador		=>:p_out_AdvertenciasContador,
				p_out_AdvertenciasDetalle		=>:p_out_AdvertenciasDetalle,	
				p_out_ErroresContador			=>:p_out_ErroresContador,
				p_out_ErroresDetalle			=>:p_out_ErroresDetalle	
			);
						
		END;
			--LOG DE AUDITORIA (inicio)
			BEGIN 
				DECLARE v_DetalleLog TABLE ("SubRegistro" nvarchar(40), "CampoRegistro" nvarchar(40), "ValorAntiguo" nvarchar(250), "ValorNuevo" nvarchar(250));
				DECLARE v_fechaHoraSistema NVARCHAR(40);
				DECLARE v_NombreProceso	NVARCHAR(100):='Confirmar Solicitud de Cambio';
				
				
				--DATOS CABECERA LOG
				call "BSCL.Plataforma.BD.Utilitarios::ObtenerFechaHoraSistema"(
					p_IdEmpresa => p_IdEmpresa,
					p_out_FechaHoraSistema => v_fechaHoraSistema
				);
				
				--DATOS DETALLE LOG
				p_DetalleLog = 
				(Select MOD."IdTipoEntidad"		 as "SubRegistro",
						MOD."CampoModificado"	 as "CampoRegistro",
						MOD."ValorAntiguo"  	 as "ValorAntiguo",
						MOD."ValorNuevo" 		 as "ValorNuevo" 
				FROM :v_DatosSolicitudCambio MOD);
				


				--GRABAR LOG

					CALL "BSCL.Plataforma.BD.Servicios::AgregarLog" (
					p_IdTipoLog => 'EDICION' 
					,p_IdModulo => 'SOC' 
					,p_IdUsuario => p_IdUsuario 
					,p_IdEmpresa => p_IdEmpresa 
					,p_FechaSistemaLog => TO_VARCHAR (v_fechaHoraSistema, 'YYYY-MM-DD')
					,p_IdUsuarioAtendido => p_IdUsuario
					,p_IdTipoRegistro => v_TipoEntidad--'CLIENTE'
					,p_DetalleLog => :p_DetalleLog	-- hacia arriba obligatorios
					,p_NombreProceso => :v_NombreProceso-- hacia abajo opcionales
					,p_IdRegistro => :v_IdEntidadOrigen
					,p_EstadoProceso => :p_IdEstadoAutorizacion
					);
	
			END;
			--LOG DE AUDITORIA (Fin)			
			
			
		--------------------
		--FIN SP 
		--------------------
	END;	
END;