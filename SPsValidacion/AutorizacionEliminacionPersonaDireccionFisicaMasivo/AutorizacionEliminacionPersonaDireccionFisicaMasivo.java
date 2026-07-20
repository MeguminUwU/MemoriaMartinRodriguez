package cl.bcs.socionegocio.per;

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

public class AutorizacionEliminacionPersonaDireccionFisicaMasivo implements BcsAutorizaciones {

	private static final Logger logger = LogManager.getLogger(AutorizacionEliminacionPersonaDireccionFisicaMasivo.class);

	private final String SQL_UPDATE_DIRECCION_BORRADA = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/per/sql/AutorizacionEliminacionPersonaDireccionFisicaMasivo_Update_DireccionBorrada.sql");
	private final String SQL_UPDATE_ESTADO_SOLICITUD = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/per/sql/AutorizacionEliminacionPersonaDireccionFisicaMasivo_Update_EstadoSolicitud.sql");
	private final String SQL_UPDATE_DIRECCION_FISICA_RECHAZADA = PlataformaUtils.loadResourceToString("cl/bcs/socionegocio/per/sql/AutorizacionEliminacionPersonaDireccionFisicaMasivo_Update_DireccionFisicaRechazada.sql");

	public static class DireccionFisicaEliminacion {
		public Long IdDireccionFisica;
		public String IdEstadoAutorizacion;
		public String IdConcepto;  // BORDIF
	}

	/**
	 * AUTORIZAR: Migración directa de ConfirmarEliminarPersonaDireccionFisicaMasivo.sql
	 * Marca Borrado='S' en DireccionFisica y actualiza solicitudes
	 * (migración de ConfirmarEliminarPersonaDireccionFisicaMasivo.sql)
	 */
	@Override
	public SalidaAutorizacion autorizarEvento(Connection conn, EntradaAutorizacion entrada) {
		logger.info("INICIO::AutorizacionEliminacionPersonaDireccionFisicaMasivo.autorizarEvento");
		SalidaAutorizacion salida = new SalidaAutorizacion();

		try {
			List<DireccionFisicaEliminacion> direcciones = entrada.p_Lista.stream()
				.map(evento -> {
					DireccionFisicaEliminacion d = new DireccionFisicaEliminacion();
					d.IdDireccionFisica = Long.valueOf(evento.NumeroOperacionConcepto);
					d.IdEstadoAutorizacion = "AUT";
					d.IdConcepto = evento.IdTipoEvento;
					return d;
				})
				.distinct()
				.collect(Collectors.toList());

			// 1. Marcar DireccionFisica como Borrado='S'
			new SQL().batch(conn, SQL_UPDATE_DIRECCION_BORRADA, direcciones, DireccionFisicaEliminacion.class);

			// 2. Actualizar estado de solicitudes a AUT
			new SQL().batch(conn, SQL_UPDATE_ESTADO_SOLICITUD, direcciones, DireccionFisicaEliminacion.class);

			// Agregar resultado por cada dirección procesada
			for (DireccionFisicaEliminacion direccion : direcciones) {
				BcsAutorizaciones.ResultadoAutorizacion resultado = new BcsAutorizaciones.ResultadoAutorizacion();
				resultado.evento = direccion;
				resultado.resultado = BcsAutorizaciones.EXITO_AUTORIZACION;
				salida.P_OUT_RESULTADO.add(resultado);
			}

		} catch (Exception e) {
			logger.error("Error en autorizarEvento: " + e.getMessage(), e);
			salida.P_OUT_ERRORESCONTADOR = 1L;
		}

		logger.info("FIN::AutorizacionEliminacionPersonaDireccionFisicaMasivo.autorizarEvento");
		return salida;
	}

	/**
	 * RECHAZAR: Migración directa de RechazaAutorizacionBorrarPersonaDireccionFisicaMasivo.sql
	 * Actualiza IdEstadoAutorizacion='RZD' en DireccionFisica y solicitudes (NO toca Borrado)
	 */
	@Override
	public SalidaAutorizacion rechazarEvento(Connection conn, EntradaAutorizacion entrada) {
		logger.info("INICIO::AutorizacionEliminacionPersonaDireccionFisicaMasivo.rechazarEvento");
		SalidaAutorizacion salida = new SalidaAutorizacion();

		try {
			List<DireccionFisicaEliminacion> direcciones = entrada.p_Lista.stream()
				.map(evento -> {
					DireccionFisicaEliminacion d = new DireccionFisicaEliminacion();
					d.IdDireccionFisica = Long.valueOf(evento.NumeroOperacionConcepto);
					d.IdEstadoAutorizacion = "RZD";
					d.IdConcepto = evento.IdTipoEvento;
					return d;
				})
				.distinct()
				.collect(Collectors.toList());

			// 1. Actualizar estado de solicitudes a RZD
			new SQL().batch(conn, SQL_UPDATE_ESTADO_SOLICITUD, direcciones, DireccionFisicaEliminacion.class);

			// 2. Actualizar IdEstadoAutorizacion en DireccionFisica (NO marca como borrado)
			new SQL().batch(conn, SQL_UPDATE_DIRECCION_FISICA_RECHAZADA, direcciones, DireccionFisicaEliminacion.class);

			// Agregar resultado por cada dirección procesada
			for (DireccionFisicaEliminacion direccion : direcciones) {
				BcsAutorizaciones.ResultadoAutorizacion resultado = new BcsAutorizaciones.ResultadoAutorizacion();
				resultado.evento = direccion;
				resultado.resultado = BcsAutorizaciones.EXITO_AUTORIZACION;
				salida.P_OUT_RESULTADO.add(resultado);
			}

		} catch (Exception e) {
			logger.error("Error en rechazarEvento: " + e.getMessage(), e);
			salida.P_OUT_ERRORESCONTADOR = 1L;
		}

		logger.info("FIN::AutorizacionEliminacionPersonaDireccionFisicaMasivo.rechazarEvento");
		return salida;
	}

	public static void main(String[] args) {
		System.out.println("== INICIO TEST ==");

		try (Connection conn = PlataformaUtils.getPropertiesConnection("desa01", "connections.properties")) {
			try {
				String json = "{\"p_IdEmpresa\":1,\"p_IdUsuario\":76770,\"p_IdModulo\":\"AUT\",\"p_simularOperacion\":\"N\",\"p_UsaReglasNegocio\":\"N\",\"p_Comentario\":\"\",\"p_Eventos\":[{\"IdEvento\":0}],\"p_Etapas\":[{\"IdEvento\":832489,\"IdEtapa\":832490}],\"p_EventoEtapa\":\"ETAPA\",\"p_IdEstado\":\"AUT\",\"p_Observaciones\":\" \",\"p_Lista\":[{\"IdEvento\":832489,\"NumeroOperacionConcepto\":\"123456\",\"IdTipoEvento\":\"BORDIF\"}]}";
				EntradaAutorizacion entrada = Utils.getGsonBuilder().fromJson(json, EntradaAutorizacion.class);

				AutorizacionEliminacionPersonaDireccionFisicaMasivo servicio = new AutorizacionEliminacionPersonaDireccionFisicaMasivo();

				System.out.println("\n=== Probando AUTORIZAR ===");
				SalidaAutorizacion salidaAutorizar = servicio.autorizarEvento(conn, entrada);
				System.out.println("Salida autorizar: " + salidaAutorizar);
				System.out.println("Errores: " + salidaAutorizar.P_OUT_ERRORESCONTADOR);
				conn.rollback();

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
