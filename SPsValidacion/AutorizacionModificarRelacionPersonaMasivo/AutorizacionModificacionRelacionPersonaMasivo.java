package cl.bcs.socionegocio.rel;

import java.sql.Connection;
import java.util.List;
import java.util.stream.Collectors;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import cl.bcs.plataforma.aut.BcsAutorizaciones;
import cl.bcs.plataforma.aut.BcsAutorizaciones.EntradaAutorizacion;
import cl.bcs.plataforma.aut.BcsAutorizaciones.SalidaAutorizacion;
import cl.bcs.plataforma.pla.utils.PlataformaUtils;
import cl.bcs.utils.SQL;
import cl.bcs.utils.Utils;

public class AutorizacionModificacionRelacionPersonaMasivo implements BcsAutorizaciones {

	private static final Logger logger = LogManager.getLogger(AutorizacionModificacionRelacionPersonaMasivo.class);

	private final String SQL_UPDATE_RELACION_AUTORIZADA = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/rel/sql/AutorizacionModificacionRelacionPersonaMasivo_Update_RelacionAutorizada.sql");
	private final String SQL_UPDATE_REPRESENTANTE_LEGAL_PASO1 = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/rel/sql/AutorizacionModificacionRelacionPersonaMasivo_Update_RepresentanteLegal_Paso1.sql");
	private final String SQL_UPDATE_REPRESENTANTE_LEGAL_PASO2 = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/rel/sql/AutorizacionModificacionRelacionPersonaMasivo_Update_RepresentanteLegal_Paso2.sql");
	private final String SQL_UPDATE_ESTADO_SOLICITUD = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/rel/sql/AutorizacionModificacionRelacionPersonaMasivo_Update_EstadoSolicitud.sql");
	private final String SQL_UPDATE_RELACION_RECHAZADA = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/rel/sql/AutorizacionModificacionRelacionPersonaMasivo_Update_RelacionRechazada.sql");
	
	public static class RelacionAutorizacion {
		public Long IdRelacionPersona;
		public String IdEstadoAutorizacion;
		public String IdConcepto;  // MODREL (solo modificaciones)
	}
	
	/**
	 * AUTORIZAR: Lógica completa migrada del SP ConfirmarModificarRelacionPersonaMasivo
	 * Solo maneja MODREL (concepto de modificación)
	 */
	@Override
	public SalidaAutorizacion autorizarEvento(Connection conn, EntradaAutorizacion entrada) {
		logger.info("INICIO::AutorizacionModificacionRelacionPersonaMasivo.autorizarEvento");
		SalidaAutorizacion salida = new SalidaAutorizacion();
		
		try {
			// Extraer IDs de relaciones desde entrada
			List<RelacionAutorizacion> relaciones = entrada.p_Lista.stream()
				.map(evento -> {
					RelacionAutorizacion r = new RelacionAutorizacion();
					r.IdRelacionPersona = Long.valueOf(evento.NumeroOperacionConcepto);
					r.IdEstadoAutorizacion = "AUT";  // Estado autorizado
					r.IdConcepto = evento.IdTipoEvento;  // MODREL
					return r;
				})
				.distinct()
				.collect(Collectors.toList());
			
			// 1. Actualizar RelacionPersona con valores desde SolicitudCambio (todos los campos)
			new SQL().batch(conn, SQL_UPDATE_RELACION_AUTORIZADA, relaciones, RelacionAutorizacion.class);
			
			// 2. Actualizar IdPersonaRepresentante si se modificó IdEstado de relación REP (paso 1)
			new SQL().batch(conn, SQL_UPDATE_REPRESENTANTE_LEGAL_PASO1, relaciones, RelacionAutorizacion.class);
			
			// 3. Actualizar IdPersonaRepresentante si se modificó IdEstado de relación REP (paso 2)
			new SQL().batch(conn, SQL_UPDATE_REPRESENTANTE_LEGAL_PASO2, relaciones, RelacionAutorizacion.class);
			
			// 4. Actualizar estado de SolicitudCambio a Autorizado
			new SQL().batch(conn, SQL_UPDATE_ESTADO_SOLICITUD, relaciones, RelacionAutorizacion.class);
			
			// Agregar resultado por cada relación procesada
			for (RelacionAutorizacion relacion : relaciones) {
				BcsAutorizaciones.ResultadoAutorizacion resultado = new BcsAutorizaciones.ResultadoAutorizacion();
				resultado.evento = relacion;
				resultado.resultado = BcsAutorizaciones.EXITO_AUTORIZACION;
				salida.P_OUT_RESULTADO.add(resultado);
			}
			
		} catch (Exception e) {
			logger.error("Error en autorizarEvento: " + e.getMessage(), e);
			salida.P_OUT_ERRORESCONTADOR = 1L;
		}
		
		logger.info("FIN::AutorizacionModificacionRelacionPersonaMasivo.autorizarEvento");
		return salida;
	}
	
	/**
	 * RECHAZAR: Lógica completa migrada del SP RechazarModificarRelacionPersonaMasivo
	 * Solo maneja MODREL (modificar relación)
	 */
	@Override
	public SalidaAutorizacion rechazarEvento(Connection conn, EntradaAutorizacion entrada) {
		logger.info("INICIO::AutorizacionModificacionRelacionPersonaMasivo.rechazarEvento");
		SalidaAutorizacion salida = new SalidaAutorizacion();
		
		try {
			// Extraer IDs de relaciones desde entrada
			List<RelacionAutorizacion> relaciones = entrada.p_Lista.stream()
				.map(evento -> {
					RelacionAutorizacion r = new RelacionAutorizacion();
					r.IdRelacionPersona = Long.valueOf(evento.NumeroOperacionConcepto);
					r.IdEstadoAutorizacion = "RZD";  // Estado rechazado
					r.IdConcepto = evento.IdTipoEvento;  // MODREL
					return r;
				})
				.distinct()
				.collect(Collectors.toList());
			
			// 1. Actualizar estado de SolicitudCambio a Rechazado (solo MODREL)
			new SQL().batch(conn, SQL_UPDATE_ESTADO_SOLICITUD, relaciones, RelacionAutorizacion.class);
			
			// 2. Actualizar IdEstadoAutorizacion de RelacionPersona
			new SQL().batch(conn, SQL_UPDATE_RELACION_RECHAZADA, relaciones, RelacionAutorizacion.class);
			
			// Agregar resultado por cada relación procesada
			for (RelacionAutorizacion relacion : relaciones) {
				BcsAutorizaciones.ResultadoAutorizacion resultado = new BcsAutorizaciones.ResultadoAutorizacion();
				resultado.evento = relacion;
				resultado.resultado = BcsAutorizaciones.EXITO_AUTORIZACION;
				salida.P_OUT_RESULTADO.add(resultado);
			}
			
		} catch (Exception e) {
			logger.error("Error en rechazarEvento: " + e.getMessage(), e);
			salida.P_OUT_ERRORESCONTADOR = 1L;
		}
		
		logger.info("FIN::AutorizacionModificacionRelacionPersonaMasivo.rechazarEvento");
		return salida;
	}
	
	public static void main(String[] args) {
		System.out.println("== INICIO TEST ==");
		
		try (Connection conn = PlataformaUtils.getPropertiesConnection("desa01", "connections.properties")) {
			try {
				String json = "{\"p_IdEmpresa\":1,\"p_IdUsuario\":76770,\"p_IdModulo\":\"AUT\",\"p_simularOperacion\":\"N\",\"p_UsaReglasNegocio\":\"N\",\"p_Comentario\":\"\",\"p_Eventos\":[{\"IdEvento\":0}],\"p_Etapas\":[{\"IdEvento\":832489,\"IdEtapa\":832490}],\"p_EventoEtapa\":\"ETAPA\",\"p_IdEstado\":\"AUT\",\"p_Observaciones\":\" \",\"p_Lista\":[{\"IdEvento\":832489,\"NumeroOperacionConcepto\":\"123456\",\"IdTipoEvento\":\"MODREL\"}]}";
				EntradaAutorizacion entrada = Utils.getGsonBuilder().fromJson(json, EntradaAutorizacion.class);
				
				AutorizacionModificacionRelacionPersonaMasivo servicio = new AutorizacionModificacionRelacionPersonaMasivo();
				
				// Probar AUTORIZAR
				System.out.println("\n=== Probando AUTORIZAR ===");
				SalidaAutorizacion salidaAutorizar = servicio.autorizarEvento(conn, entrada);
				System.out.println("Salida autorizar: " + salidaAutorizar);
				System.out.println("Errores: " + salidaAutorizar.P_OUT_ERRORESCONTADOR);
				conn.rollback();
				
				// Probar RECHAZAR
				System.out.println("\n=== Probando RECHAZAR ===");
				SalidaAutorizacion salidaRechazar = servicio.rechazarEvento(conn, entrada);
				System.out.println("Salida rechazar: " + salidaRechazar);
				System.out.println("Errores: " + salidaRechazar.P_OUT_ERRORESCONTADOR);
				conn.rollback();
				
			} catch (Exception e) {
				e.printStackTrace();
			} finally {
				conn.rollback();
			}
			
		} catch (Exception e) {
			e.printStackTrace();
		}
		
		System.out.println("== FIN TEST ==");
	}
}
