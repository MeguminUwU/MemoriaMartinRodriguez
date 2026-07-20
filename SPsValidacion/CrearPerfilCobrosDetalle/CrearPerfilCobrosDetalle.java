package cl.bcs.plataforma.com;

import java.math.BigDecimal;
import java.sql.Connection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import cl.bcs.plataforma.aut.CrearEventoAutorizacion;
import cl.bcs.plataforma.pla.utils.ConfiguracionSistema;
import cl.bcs.plataforma.pla.utils.PlataformaUtils;
import cl.bcs.utils.JavaCall;
import cl.bcs.utils.SQL;
import cl.bcs.utils.Utils;

public class CrearPerfilCobrosDetalle implements JavaCall {
	private static final Logger logger = LogManager.getLogger(CrearPerfilCobrosDetalle.class);

	private final String SQL_INSERT_DETALLE = loadResourceToString("cl/bcs/plataforma/com/sql/CrearPerfilCobrosDetalle_Insert_Detalle.sql");
	private final String SQL_INSERT_VALOR_COBRO = loadResourceToString("cl/bcs/plataforma/com/sql/CrearPerfilCobrosDetalle_Insert_ValorCobro.sql");
	private final String SQL_SELECT_GLOSA = loadResourceToString("cl/bcs/plataforma/com/sql/CrearPerfilCobrosDetalle_Select_Glosa.sql");
	private final String SQL_SELECT_REQUIERE_AUTORIZACION = loadResourceToString("cl/bcs/plataforma/com/sql/CrearPerfilCobrosDetalle_Select_RequiereAutorizacion.sql");

	public static class EntradaCrearPerfilCobrosDetalle {
		public Long p_IdEmpresa;
		public Long p_IdUsuario;
		public String p_IdModulo;
		public String p_UsaReglasNegocio;
		public String p_IdPerfilCobros;
		public String p_IdValorCobro;
		public String p_IdBolsa;
		public String p_IdTipoProducto;
		public String p_IdTipoOperacion;
		public String p_IdCanalIngreso;
		public String p_IdMoneda;
		public Long p_DiasPlazo;
		public Long p_Prioridad;
		public String p_IdEstado;
		public String p_EsPersonalizado;
		public String p_PrefijoIdValorCobro;
		public String p_IdCobro;
		public BigDecimal p_ValorCobro;
		public BigDecimal p_ValorTopeMinimoOrden;

		public String toString() {
			return Utils.printJson(this, false);
		}
	}

	public static class ErrorDetalle {
		public String Codigo;
		public String Descripcion;

		public ErrorDetalle(String codigo, String descripcion) {
			this.Codigo = codigo;
			this.Descripcion = descripcion;
		}
	}

	public static class AdvertenciaDetalle {
		public String Codigo;
		public String RequiereAutorizacion;
		public String Descripcion;

		public AdvertenciaDetalle(String codigo, String requiereAutorizacion, String descripcion) {
			this.Codigo = codigo;
			this.RequiereAutorizacion = requiereAutorizacion;
			this.Descripcion = descripcion;
		}
	}

	public static class SalidaCrearPerfilCobrosDetalle {
		public Long P_OUT_REFID;
		public int P_OUT_ADVERTENCIASCONTADOR;
		public List<AdvertenciaDetalle> P_OUT_ADVERTENCIASDETALLE;
		public int P_OUT_ERRORESCONTADOR;
		public List<ErrorDetalle> P_OUT_ERRORESDETALLE;

		public SalidaCrearPerfilCobrosDetalle() {
			this.P_OUT_REFID = 0L;
			this.P_OUT_ADVERTENCIASCONTADOR = 0;
			this.P_OUT_ADVERTENCIASDETALLE = new ArrayList<>();
			this.P_OUT_ERRORESCONTADOR = 0;
			this.P_OUT_ERRORESDETALLE = new ArrayList<>();
		}

		public String toString() {
			return Utils.printJson(this, false);
		}
	}

	public static class InsertDetalle {
		public Long IdDetallePerfilCobros;
		public String IdPerfilCobros;
		public String IdValorCobro;
		public String IdBolsa;
		public String IdTipoProducto;
		public String IdTipoOperacion;
		public String IdCanalIngreso;
		public String IdMoneda;
		public Long DiasPlazo;
		public Long Prioridad;
		public String FechaCreacion;
		public String IdEstado;
		public String FechaIngreso;
		public String FechaModificacion;
		public String IdEstadoAutorizacion;
		public Long IdUsuarioCreador;
	}

	public static class InsertValorCobro {
		public String IdValorCobro;
		public String DescripcionValorCobro;
		public String IdTipoProducto;
		public String IdCobro;
		public BigDecimal ValorCobro;
		public BigDecimal ValorTopeMinimoOrden;
		public String IdMoneda;
		public String FechaCreacion;
		public String IdEstado;
		public Long IdEmpresa;
		public String EsPersonalizado;
	}

	public static class GlosaResult {
		public String DescripcionPerfilCobros;
	}

	public static class RequiereAutorizacion {
		public String RequiereAutorizacion;
	}

	public SalidaCrearPerfilCobrosDetalle logica(Connection conn, EntradaCrearPerfilCobrosDetalle in) throws Exception {
		logger.info("INIT CrearPerfilCobrosDetalle");
		SalidaCrearPerfilCobrosDetalle salida = new SalidaCrearPerfilCobrosDetalle();
		SQL sql = new SQL();

		try {
			String v_FechaIngreso = ConfiguracionSistema.getParametroConfiguracionString(conn, in.p_IdEmpresa, "PLATAFORMA", "PLA.FechaSistema");
			String v_FechaHoraSistema = Utils.getFechaSistema(conn, Utils.getSchema(), in.p_IdEmpresa.intValue());
			String v_IdConcepto = "NDPCOB";
			String v_IdEstadoAutorizacion = "PEN";

			// Generar secuencia para ID
			List<Long> secuencia = Utils.getSecuencia(conn, "BSCL.Plataforma.BD.Secuencias::DetallePerfilCobros", 1L);
			Long v_IdDetallePerfilCobros = secuencia.get(0);
			salida.P_OUT_REFID = v_IdDetallePerfilCobros;

			String v_IdValorCobro = in.p_IdValorCobro;

			// Si es personalizado, crear el valor de cobro
			if ("S".equals(in.p_EsPersonalizado)) {
				v_IdValorCobro = in.p_PrefijoIdValorCobro + v_IdDetallePerfilCobros;
				
				logger.debug("INSERT valor cobro personalizado");
				InsertValorCobro insertValorCobro = new InsertValorCobro();
				insertValorCobro.IdValorCobro = v_IdValorCobro;
				insertValorCobro.DescripcionValorCobro = "COBRO PERSONALIZADO";
				insertValorCobro.IdTipoProducto = in.p_IdTipoProducto;
				insertValorCobro.IdCobro = in.p_IdCobro;
				insertValorCobro.ValorCobro = in.p_ValorCobro;
				insertValorCobro.ValorTopeMinimoOrden = in.p_ValorTopeMinimoOrden;
				insertValorCobro.IdMoneda = in.p_IdMoneda;
				insertValorCobro.FechaCreacion = v_FechaHoraSistema;
				insertValorCobro.IdEstado = in.p_IdEstado;
				insertValorCobro.IdEmpresa = in.p_IdEmpresa;
				insertValorCobro.EsPersonalizado = "S";

				sql.batch(conn, SQL_INSERT_VALOR_COBRO, java.util.Arrays.asList(insertValorCobro), InsertValorCobro.class);
			}

			// Insertar detalle del perfil
			logger.debug("INSERT detalle perfil cobros");
			InsertDetalle insertDetalle = new InsertDetalle();
			insertDetalle.IdDetallePerfilCobros = v_IdDetallePerfilCobros;
			insertDetalle.IdPerfilCobros = in.p_IdPerfilCobros;
			insertDetalle.IdValorCobro = v_IdValorCobro;
			insertDetalle.IdBolsa = in.p_IdBolsa;
			insertDetalle.IdTipoProducto = in.p_IdTipoProducto;
			insertDetalle.IdTipoOperacion = in.p_IdTipoOperacion;
			insertDetalle.IdCanalIngreso = in.p_IdCanalIngreso;
			insertDetalle.IdMoneda = in.p_IdMoneda;
			insertDetalle.DiasPlazo = in.p_DiasPlazo;
			insertDetalle.Prioridad = in.p_Prioridad;
			insertDetalle.FechaCreacion = v_FechaHoraSistema;
			insertDetalle.IdEstado = in.p_IdEstado;
			insertDetalle.FechaIngreso = v_FechaIngreso;
			insertDetalle.FechaModificacion = v_FechaHoraSistema;
			insertDetalle.IdEstadoAutorizacion = v_IdEstadoAutorizacion;
			insertDetalle.IdUsuarioCreador = in.p_IdUsuario;

			sql.batch(conn, SQL_INSERT_DETALLE, java.util.Arrays.asList(insertDetalle), InsertDetalle.class);

			// Consultar si requiere autorización
			HashMap<String, Object> paramsAuth = new HashMap<>();
			paramsAuth.put("IdEmpresa", in.p_IdEmpresa);
			
			logger.debug("Consultando si requiere autorización");
			List<RequiereAutorizacion> reqAutList = sql.query(conn, SQL_SELECT_REQUIERE_AUTORIZACION, paramsAuth, RequiereAutorizacion.class);
			
			String v_RequiereAutorizacion = "N";
			if (!reqAutList.isEmpty()) {
				v_RequiereAutorizacion = reqAutList.get(0).RequiereAutorizacion;
			}

			if ("S".equals(v_RequiereAutorizacion)) {
				// Obtener glosa para el evento
				logger.debug("Obtener glosa del perfil");
				HashMap<String, Object> params = new HashMap<>();
				params.put("IdPerfilCobros", in.p_IdPerfilCobros);

				List<GlosaResult> glosaList = sql.query(conn, SQL_SELECT_GLOSA, params, GlosaResult.class);
				String v_Glosa = (glosaList != null && !glosaList.isEmpty()) ? glosaList.get(0).DescripcionPerfilCobros : "";

				// Generar evento de autorización
				logger.debug("Crear evento de autorización");
				CrearEventoAutorizacion.ServiceEntrada crearEvtIn = new CrearEventoAutorizacion.ServiceEntrada();
				crearEvtIn.p_IdEmpresa = in.p_IdEmpresa;
				crearEvtIn.p_IdUsuario = in.p_IdUsuario;
				crearEvtIn.p_IdModulo = in.p_IdModulo;
				crearEvtIn.p_UsaReglasNegocio = "N";
				crearEvtIn.p_IdTipoEvento = v_IdConcepto;
				crearEvtIn.p_IdModuloSolicita = in.p_IdModulo;
				crearEvtIn.p_IdUsuarioSolicita = in.p_IdUsuario;
				crearEvtIn.p_Fecha = v_FechaIngreso;
				crearEvtIn.p_IdConcepto = v_IdConcepto;
				crearEvtIn.p_NumeroOperacionConcepto = String.valueOf(v_IdDetallePerfilCobros);
				crearEvtIn.p_FechaOperacionConcepto = v_FechaIngreso;
				crearEvtIn.p_IdCliente = 0L;
				crearEvtIn.p_Glosa = v_Glosa;
				crearEvtIn.p_IdCanal = "OPT";

				CrearEventoAutorizacion crearEvtWrapper = new CrearEventoAutorizacion();
				CrearEventoAutorizacion.ServiceSalida crearEvtOut = crearEvtWrapper.logica(conn, crearEvtIn);

				salida.P_OUT_ADVERTENCIASCONTADOR += crearEvtOut.p_out_AdvertenciasContador.intValue();
				for (CrearEventoAutorizacion.ObjADVERTENCIASDETALLE adv : crearEvtOut.p_out_AdvertenciasDetalle) {
					salida.P_OUT_ADVERTENCIASDETALLE.add(new AdvertenciaDetalle(adv.Codigo, adv.RequiereAutorizacion, adv.Descripcion));
				}

				salida.P_OUT_ERRORESCONTADOR += crearEvtOut.p_out_ErroresContador.intValue();
				for (CrearEventoAutorizacion.ObjERRORESDETALLE err : crearEvtOut.p_out_ErroresDetalle) {
					salida.P_OUT_ERRORESDETALLE.add(new ErrorDetalle(err.Codigo, err.Descripcion));
				}

				if (salida.P_OUT_ERRORESCONTADOR > 0) {
					return salida;
				}

				// Agregar advertencia de autorización requerida
				salida.P_OUT_ADVERTENCIASCONTADOR++;
				salida.P_OUT_ADVERTENCIASDETALLE.add(new AdvertenciaDetalle("REQUIERE_AUTORIZACION", "S", "El cambio requiere autorización"));

			} else {
				// Confirma la creación directamente
				logger.debug("Confirmar creación de detalle");
				v_IdEstadoAutorizacion = "ING";

				ConfirmarCrearPerfilCobrosDetalle.EntradaConfirmarCrearPerfilCobrosDetalle confirmarIn = new ConfirmarCrearPerfilCobrosDetalle.EntradaConfirmarCrearPerfilCobrosDetalle();
				confirmarIn.p_IdEmpresa = in.p_IdEmpresa;
				confirmarIn.p_IdUsuario = in.p_IdUsuario;
				confirmarIn.p_IdModulo = in.p_IdModulo;
				confirmarIn.p_UsaReglasNegocio = in.p_UsaReglasNegocio;
				confirmarIn.p_IdDetallePerfilCobros = v_IdDetallePerfilCobros;
				confirmarIn.p_IdEstadoAutorizacion = v_IdEstadoAutorizacion;

				ConfirmarCrearPerfilCobrosDetalle confirmarWrapper = new ConfirmarCrearPerfilCobrosDetalle();
				ConfirmarCrearPerfilCobrosDetalle.SalidaConfirmarCrearPerfilCobrosDetalle confirmarOut = confirmarWrapper.logica(conn, confirmarIn);

				salida.P_OUT_ADVERTENCIASCONTADOR += confirmarOut.p_out_AdvertenciasContador.intValue();
				for (ConfirmarCrearPerfilCobrosDetalle.AdvertenciaDetalle adv : confirmarOut.p_out_AdvertenciasDetalle) {
					salida.P_OUT_ADVERTENCIASDETALLE.add(new AdvertenciaDetalle(adv.Codigo, adv.RequiereAutorizacion, adv.Descripcion));
				}

				salida.P_OUT_ERRORESCONTADOR += confirmarOut.p_out_ErroresContador.intValue();
				for (ConfirmarCrearPerfilCobrosDetalle.ErrorDetalle err : confirmarOut.p_out_ErroresDetalle) {
					salida.P_OUT_ERRORESDETALLE.add(new ErrorDetalle(err.Codigo, err.Descripcion));
				}
			}

		} catch (Exception ex) {
			logger.error("Error en CrearPerfilCobrosDetalle: " + ex.getMessage());
			salida.P_OUT_ERRORESDETALLE.add(new ErrorDetalle("ERROR_CREAR_PERFIL_COBROS_DETALLE", ex.getMessage()));
			salida.P_OUT_ERRORESCONTADOR = salida.P_OUT_ERRORESDETALLE.size();
		}

		logger.info("END CrearPerfilCobrosDetalle");
		return salida;
	}

	@Override
	public JsonObject call(Connection conn, JsonObject jin) throws Exception {
		Gson gson = Utils.getGsonBuilder();
		EntradaCrearPerfilCobrosDetalle in = gson.fromJson(jin.toString(), EntradaCrearPerfilCobrosDetalle.class);
		SalidaCrearPerfilCobrosDetalle out = logica(conn, in);
		JsonParser parser = new JsonParser();
		JsonObject dataout = parser.parse(gson.toJson(out)).getAsJsonObject();
		return dataout;
	}

	public static void main(String[] args) throws Exception {
		try (Connection conn = PlataformaUtils.getPropertiesConnection("desa01", "connections.properties")) {
			System.out.println("== BEGIN ==");
			Gson gson = Utils.getGsonBuilder();
			String json = "{\"p_IdEmpresa\":1,\"p_IdUsuario\":1,\"p_IdModulo\":\"COM\",\"p_UsaReglasNegocio\":\"N\",\"p_IdPerfilCobros\":\"PERFCOB001\",\"p_IdValorCobro\":\"VC001\",\"p_IdBolsa\":\"BCS\",\"p_IdTipoProducto\":\"ACC\",\"p_IdTipoOperacion\":\"COM\",\"p_IdCanalIngreso\":\"WEB\",\"p_IdMoneda\":\"CLP\",\"p_DiasPlazo\":0,\"p_Prioridad\":1,\"p_IdEstado\":\"ACT\",\"p_EsPersonalizado\":\"N\",\"p_PrefijoIdValorCobro\":\"\",\"p_IdCobro\":\"\",\"p_ValorCobro\":null,\"p_ValorTopeMinimoOrden\":null}";
			EntradaCrearPerfilCobrosDetalle entrada = gson.fromJson(json, EntradaCrearPerfilCobrosDetalle.class);
			CrearPerfilCobrosDetalle demo = new CrearPerfilCobrosDetalle();
			SalidaCrearPerfilCobrosDetalle salida = demo.logica(conn, entrada);
			System.out.println(salida.toString());
			conn.rollback();
		} catch (Exception e) {
			e.printStackTrace();
		}
		System.out.println("== END ==");
	}
}
