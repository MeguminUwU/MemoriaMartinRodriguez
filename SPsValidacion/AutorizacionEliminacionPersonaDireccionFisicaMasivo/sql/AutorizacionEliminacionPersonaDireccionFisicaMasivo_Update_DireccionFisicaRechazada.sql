-- Actualiza IdEstadoAutorizacion en DireccionFisica al rechazar eliminación
UPDATE  DIR
SET     DIR."IdEstadoAutorizacion" = :IdEstadoAutorizacion,
        DIR."FechaModificacion" = CURRENT_UTCTIMESTAMP
FROM    "BSCL.SocioNegocio.BD::PER.DireccionFisica" AS DIR
WHERE   DIR."IdDireccionFisica" = :IdDireccionFisica;
