-- Paso 2: Si la relación modificada quedó bloqueada (BLO) y era el representante actual, limpiarlo
UPDATE "BSCL.SocioNegocio.BD::PER.Persona" AS PER
SET "IdPersonaRepresentante" = 0
WHERE EXISTS (
    SELECT 1
    FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" REL
    WHERE REL."IdRelacionPersona" = :IdRelacionPersona
      AND REL."IdTipoRelacion" = 'REP'
      AND REL."IdEstado" = 'BLO'
      AND REL."IdPersonaOrigen" = PER."IdPersona"
      AND REL."IdPersonaDestino" = PER."IdPersonaRepresentante"
)
