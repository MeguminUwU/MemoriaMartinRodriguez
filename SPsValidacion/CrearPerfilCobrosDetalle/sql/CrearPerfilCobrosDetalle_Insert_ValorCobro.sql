INSERT INTO "BSCL.Plataforma.BD::COM.ValorCobro"
(
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
	"EsPersonalizado"
)
VALUES (
	:IdValorCobro,
	:DescripcionValorCobro,
	:IdTipoProducto,
	:IdCobro,
	:ValorCobro,
	:ValorTopeMinimoOrden,
	:IdMoneda,
	:FechaCreacion,
	:IdEstado,
	:IdEmpresa,
	:EsPersonalizado
)
