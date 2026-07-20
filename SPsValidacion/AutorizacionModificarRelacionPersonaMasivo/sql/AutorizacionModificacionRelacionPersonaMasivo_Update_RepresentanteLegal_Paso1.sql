-- Paso 1: Si hay exactamente 1 representante activo (REP+ACT), asignarlo
UPDATE "BSCL.SocioNegocio.BD::PER.Persona" AS PER
SET "IdPersonaRepresentante" = (
    SELECT REL."IdPersonaDestino"
    FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" REL
    WHERE REL."IdPersonaOrigen" = PER."IdPersona"
      AND REL."IdTipoRelacion" = 'REP'
      AND REL."IdEstado" = 'ACT'
)
WHERE EXISTS (
    SELECT 1 
    FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" R
    WHERE R."IdRelacionPersona" = :IdRelacionPersona
      AND R."IdPersonaOrigen" = PER."IdPersona"
      AND R."IdTipoRelacion" = 'REP'
)
AND (
    SELECT COUNT(*)
    FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" REL
    WHERE REL."IdPersonaOrigen" = PER."IdPersona"
      AND REL."IdTipoRelacion" = 'REP'
      AND REL."IdEstado" = 'ACT'
) = 1
