from src.core.exceptions import ErrorDeNegocio


class AttractionNotFoundException(ErrorDeNegocio):
    codigo_http = 404
    codigo = "atractivo_no_encontrado"
    mensaje_por_defecto = "El atractivo solicitado no existe."


class InvalidCategoryFilterException(ErrorDeNegocio):
    codigo_http = 400
    codigo = "filtro_categoria_invalido"
    mensaje_por_defecto = "La categoría indicada en el filtro no existe."


class AgencyNotFoundException(ErrorDeNegocio):
    codigo_http = 404
    codigo = "agencia_no_encontrada"
    mensaje_por_defecto = "La agencia solicitada no existe."


class AgencyNotValidatedException(ErrorDeNegocio):
    codigo_http = 403
    codigo = "agencia_no_validada"
    mensaje_por_defecto = "La agencia no está validada por DIRCETUR (RN-01)."


class TourNotFoundException(ErrorDeNegocio):
    codigo_http = 404
    codigo = "tour_no_encontrado"
    mensaje_por_defecto = "El tour solicitado no existe."


class DuplicateResourceException(ErrorDeNegocio):
    codigo_http = 409
    codigo = "recurso_duplicado"
    mensaje_por_defecto = "Ya existe un registro con esos datos únicos."


class DircerturSyncFailedException(ErrorDeNegocio):
    codigo_http = 502
    codigo = "sincronizacion_dircetur_fallida"
    mensaje_por_defecto = "No se pudo sincronizar el padrón de DIRCETUR."
