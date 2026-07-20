package cl.bcs.plataforma.com;

import java.sql.Connection;
import java.util.ArrayList;
import java.util.List;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import cl.bcs.plataforma.pla.AgregarLog;
import cl.bcs.plataforma.pla.utils.ConfiguracionSistema;
import cl.bcs.plataforma.pla.utils.PlataformaUtils;
import cl.bcs.utils.JavaCall;
import cl.bcs.utils.SQL;
import cl.bcs.utils.Utils;

public class CrearGrupoActivos implements JavaCall {
	private static final Logger logger = LogManager.getLogger(CrearGrupoActivos.class);

	private final String SQL_INSERT_GRUPO = loadResourceToString("cl/bcs/plataforma/com/sql/CrearGrupoActivos_Insert_Grupo.sql");

	public static class EntradaCrearGrupoActivos {
		public Long p_IdEmpresa;
		public Long p_IdUsuario;
		public String p_IdModulo;
		public String p_simularOperacion;
		public String p_UsaReglasNegocio;
		public String p_IdGrupoActivos;
		public String p_DescripcionGrupoActivos;
		public String p_IdTipoGrupoActivos;
		public String p_IdEstado;
		public String p_PorDefecto;

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

	public static class SalidaCrearGrupoActivos {
		public Long P_OUT_REFID;
		public int P_OUT_ADVERTENCIASCONTADOR;
		public List<AdvertenciaDetalle> P_OUT_ADVERTENCIASDETALLE;
		public int P_OUT_ERRORESCONTADOR;
		public List<ErrorDetalle> P_OUT_ERRORESDETALLE;

		public SalidaCrearGrupoActivos() {
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

	public static class InsertGrupo {
		public String IdGrupoActivos;
		public String DescripcionGrupoActivos;
		public String IdTipoGrupoActivos;
		public String FechaCreacion;
		public String FechaModificacion;
		public String IdEstado;
		public String PorDefecto;
		public Long IdEmpresa;
	}

	public SalidaCrearGrupoActivos logica(Connection conn, EntradaCrearGrupoActivos in) throws Exception {
		logger.info("INIT CrearGrupoActivos");
		SalidaCrearGrupoActivos salida = new SalidaCrearGrupoActivos();
		SQL sql = new SQL();

		try {
			// Verificar si es simulación
			if ("S".equals(in.p_simularOperacion)) {
				logger.debug("Operación simulada, se omite ejecución");
				return salida;
			}

			String v_FechaHoraSistema = Utils.getFechaSistema(conn, Utils.getSchema(), in.p_IdEmpresa.intValue());

			// Insertar grupo de activos
			logger.debug("INSERT grupo activos");
			InsertGrupo insertGrupo = new InsertGrupo();
			insertGrupo.IdGrupoActivos = in.p_IdGrupoActivos;
			insertGrupo.DescripcionGrupoActivos = in.p_DescripcionGrupoActivos;
			insertGrupo.IdTipoGrupoActivos = in.p_IdTipoGrupoActivos;
			insertGrupo.FechaCreacion = v_FechaHoraSistema;
			insertGrupo.FechaModificacion = v_FechaHoraSistema;
			insertGrupo.IdEstado = in.p_IdEstado;
			insertGrupo.PorDefecto = in.p_PorDefecto;
			insertGrupo.IdEmpresa = in.p_IdEmpresa;

			sql.batch(conn, SQL_INSERT_GRUPO, java.util.Arrays.asList(insertGrupo), InsertGrupo.class);

			salida.P_OUT_REFID = 1L;

			// Agregar log
			logger.debug("Agregar log de ingreso");
			String fechaSistema = ConfiguracionSistema.getParametroConfiguracionString(conn, in.p_IdEmpresa, "PLATAFORMA", "PLA.FechaSistema");

			AgregarLog.InAgregarLog entradaAgregarLog = new AgregarLog.InAgregarLog();

			AgregarLog.InAgregarLog.Log log = new AgregarLog.InAgregarLog.Log();
			log.IdCabeceraLog = 1L;
			log.IdTipoLog = "INGRESO";
			log.IdModulo = "COM";
			log.IdUsuario = in.p_IdUsuario;
			log.IdEmpresa = in.p_IdEmpresa;
			log.FechaSistemaLog = fechaSistema;
			log.IdUsuarioAtendido = in.p_IdUsuario;
			log.IdTipoRegistro = "GRUPO ACTIVOS";
			entradaAgregarLog.p_Log.add(log);

			AgregarLog.InAgregarLog.DetalleLog detLog = new AgregarLog.InAgregarLog.DetalleLog();
			detLog.IdCabeceraLog = 1L;
			detLog.IdTrabajo = 0L;
			detLog.SubRegistro = "INGRESO";
			detLog.CampoRegistro = "IdGrupoActivos";
			detLog.ValorAntiguo = "";
			detLog.ValorNuevo = in.p_IdGrupoActivos;
			entradaAgregarLog.p_LogDetalle.add(detLog);

			AgregarLog agregarLogService = new AgregarLog();
			agregarLogService.logica(conn, entradaAgregarLog);

		} catch (Exception ex) {
			logger.error("Error en CrearGrupoActivos: " + ex.getMessage());
			salida.P_OUT_ERRORESDETALLE.add(new ErrorDetalle("ERROR_CREAR_GRUPO_ACTIVOS", ex.getMessage()));
			salida.P_OUT_ERRORESCONTADOR = salida.P_OUT_ERRORESDETALLE.size();
		}

		logger.info("END CrearGrupoActivos");
		return salida;
	}

	@Override
	public JsonObject call(Connection conn, JsonObject jin) throws Exception {
		Gson gson = Utils.getGsonBuilder();
		EntradaCrearGrupoActivos in = gson.fromJson(jin.toString(), EntradaCrearGrupoActivos.class);
		SalidaCrearGrupoActivos out = logica(conn, in);
		JsonParser parser = new JsonParser();
		JsonObject dataout = parser.parse(gson.toJson(out)).getAsJsonObject();
		return dataout;
	}

	public static void main(String[] args) throws Exception {
		try (Connection conn = PlataformaUtils.getPropertiesConnection("desa01", "connections.properties")) {
			System.out.println("== BEGIN ==");
			Gson gson = Utils.getGsonBuilder();
			String json = "{\"p_IdEmpresa\":1,\"p_IdUsuario\":1,\"p_IdModulo\":\"COM\",\"p_simularOperacion\":\"N\",\"p_UsaReglasNegocio\":\"N\",\"p_IdGrupoActivos\":\"GA001\",\"p_DescripcionGrupoActivos\":\"Grupo Test\",\"p_IdTipoGrupoActivos\":\"TIPO1\",\"p_IdEstado\":\"ACT\",\"p_PorDefecto\":\"N\"}";
			EntradaCrearGrupoActivos entrada = gson.fromJson(json, EntradaCrearGrupoActivos.class);
			CrearGrupoActivos demo = new CrearGrupoActivos();
			SalidaCrearGrupoActivos salida = demo.logica(conn, entrada);
			System.out.println(salida.toString());
			conn.rollback();
		} catch (Exception e) {
			e.printStackTrace();
		}
		System.out.println("== END ==");
	}
}
