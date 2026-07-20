SELECT 
	"DescripcionPerfilCobros",
	"IdEstado",
	"PorDefecto"
FROM "BSCL.Plataforma.BD::COM.PerfilCobros"
WHERE "IdPerfilCobros" = :IdPerfilCobros
