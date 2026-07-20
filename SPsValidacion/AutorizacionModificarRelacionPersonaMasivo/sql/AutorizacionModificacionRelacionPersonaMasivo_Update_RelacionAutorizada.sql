-- Actualizar RelacionPersona aplicando todos los cambios desde SolicitudCambio
-- Migración de ConfirmarModificarRelacionPersonaMasivo.sql
UPDATE "BSCL.SocioNegocio.BD::REL.RelacionPersona" AS TGT
SET 
    "FechaInicioRelacion" = COALESCE(
        (SELECT TO_DATE(MAX("ValorNuevo")) FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'FechaInicioRelacion'),
        TGT."FechaInicioRelacion"),
    "FechaFinRelacion" = COALESCE(
        (SELECT TO_DATE(MAX("ValorNuevo")) FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'FechaFinRelacion'),
        TGT."FechaFinRelacion"),
    "IdEstado" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'IdEstado'),
        TGT."IdEstado"),
    "PorcentajeParticipacion" = COALESCE(
        (SELECT TO_DECIMAL(MAX("ValorNuevo")) FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'PorcentajeParticipacion'),
        TGT."PorcentajeParticipacion"),
    "RetiraDocumentos" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'RetiraDocumentos'),
        TGT."RetiraDocumentos"),
    "Ciudad" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'Ciudad'),
        TGT."Ciudad"),
    "Calle" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'Calle'),
        TGT."Calle"),
    "Numero" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'Numero'),
        TGT."Numero"),
    "Email" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'Email'),
        TGT."Email"),
    "Telefono" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'Telefono'),
        TGT."Telefono"),
    "Complemento" = COALESCE(
        (SELECT MAX("ValorNuevo") FROM "BSCL.Plataforma.BD::PLA.SolicitudCambio" 
         WHERE "IdEntidadOrigen" = CAST(:IdRelacionPersona AS NVARCHAR(40))
           AND "IdTipoEntidad" = 'RELACION-PERSONA'
           AND "IdEstadoAutorizacion" = 'PEN'
           AND "CampoModificado" = 'Complemento'),
        TGT."Complemento"),
    "IdEstadoAutorizacion" = :IdEstadoAutorizacion,
    "FechaModificacion" = CURRENT_UTCTIMESTAMP
WHERE TGT."IdRelacionPersona" = :IdRelacionPersona
