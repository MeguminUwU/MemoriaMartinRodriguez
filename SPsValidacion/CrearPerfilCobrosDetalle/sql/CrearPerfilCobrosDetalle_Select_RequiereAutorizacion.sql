SELECT "RequiereAutorizacion"
FROM "BSCL.Plataforma.BD::PLA.RequiereAutorizacion"
WHERE "IdEmpresa" = :IdEmpresa
    AND "IdConcepto" = 'NDPCOB'
