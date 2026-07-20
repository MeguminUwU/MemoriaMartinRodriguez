-- Actualizar IdPersonaRepresentante cuando se modifica IdEstado de relaciones REP
-- Lógica migrada del SP ConfirmarModificarRelacionPersonaMasivo.sql (líneas 249-285)

-- Paso 1: Si hay exactamente 1 representante activo (REP+ACT), asignarlo
UPDATE "BSCL.SocioNegocio.BD::PER.Persona" AS PER
SET "IdPersonaRepresentante" = (
    SELECT TOP 1 REL."IdPersonaDestino"
    FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" REL
    WHERE REL."IdPersonaOrigen" = PER."IdPersona"
      AND REL."IdTipoRelacion" = 'REP'
      AND REL."IdEstado" = 'ACT'
)
WHERE EXISTS (
    -- Solo si hay relaciones REP modificadas para esta persona
    SELECT 1 
    FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" R
    WHERE R."IdRelacionPersona" = :IdRelacionPersona
      AND R."IdPersonaOrigen" = PER."IdPersona"
      AND R."IdTipoRelacion" = 'REP'
)
AND (
    -- Contar representantes activos = exactamente 1
    SELECT COUNT(*)
    FROM "BSCL.SocioNegocio.BD::REL.RelacionPersona" REL
    WHERE REL."IdPersonaOrigen" = PER."IdPersona"
      AND REL."IdTipoRelacion" = 'REP'
      AND REL."IdEstado" = 'ACT'
) = 1;

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
