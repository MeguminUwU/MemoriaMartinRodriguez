-- Actualiza IdEstadoAutorizacion en SolicitudCambio (para AUT o RZD)
UPDATE "BSCL.Plataforma.BD::PLA.SolicitudCambio"
SET "IdEstadoAutorizacion" = :IdEstadoAutorizacion
WHERE "IdTipoEntidad" = 'DIRECCIONFISICA-BORRAR'
  AND "IdEntidadOrigen" = CAST(:IdDireccionFisica AS NVARCHAR(40))
  AND "IdEstadoAutorizacion" = 'PEN';
