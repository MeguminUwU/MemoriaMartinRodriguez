-- Actualizar estado de SolicitudCambio (AUT para autorizar, RZD para rechazar)
-- Usado por ambos: ConfirmarModificar y RechazarModificar
UPDATE "BSCL.Plataforma.BD::PLA.SolicitudCambio"
SET "IdEstadoAutorizacion" = :IdEstadoAutorizacion
WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
  AND "IdTipoEntidad" = 'RELACION-PERSONA'
  AND "IdEstadoAutorizacion" = 'PEN'
