-- Marca DireccionFisica como Borrado='S' al autorizar eliminación
UPDATE  DIRF 
SET     DIRF."Borrado" = 'S',
        DIRF."FechaModificacion" = CURRENT_UTCTIMESTAMP
FROM    "BSCL.SocioNegocio.BD::PER.DireccionFisica" AS DIRF
WHERE   DIRF."IdDireccionFisica" = :IdDireccionFisica;
