-- Actualizar estado de RelacionPersona cuando se rechaza (solo MODREL)
-- Migración de RechazarModificarRelacionPersonaMasivo.sql
UPDATE "BSCL.SocioNegocio.BD::REL.RelacionPersona"
SET "IdEstadoAutorizacion" = :IdEstadoAutorizacion
WHERE "IdRelacionPersona" = :IdRelacionPersona
