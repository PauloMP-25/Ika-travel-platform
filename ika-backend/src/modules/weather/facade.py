"""Patrón Fachada (Facade Pattern) para la Orquestación de Clima y Recomendaciones Inteligentes.

Proporciona una interfaz unificada y de alto nivel que simplifica y coordina:
1. Agregador meteorológico consensuado (Open-Meteo, OpenWeatherMap, WeatherAPI).
2. Evaluación de seguridad y alertas oficiales (DIRCETUR, SERNANP, DICAPI).
3. Selección de algoritmo de personalización mediante Strategy Pattern.
4. Redacción estructurada con IA generativa (Gemini) y fallback determinista.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.modules.catalog.models import Attraction
from src.modules.weather import rules, scoring
from src.modules.weather.safety import evaluar_seguridad_temporal
from src.modules.weather.schemas import ClimaActualResponse, RecomendacionResponse
from src.modules.weather.strategies import RecommendationStrategyFactory
from src.modules.ai_engine.recommender import redactar_con_gemini

logger = logging.getLogger(__name__)


class WeatherRecommendationFacade:
    """Fachada que simplifica el flujo completo de evaluación meteorológica y recomendación personalizada."""

    @classmethod
    async def generar_recomendacion_personalizada(
        cls,
        *,
        atractivo: Attraction,
        clima: ClimaActualResponse,
        preferencias_usuario: list[str] | None = None,
        estilo: str | None = None,
        presupuesto: str | None = None,
        compania: str | None = None,
        idioma: str = "es",
        narrativa_previa: str | None = None,
        atractivos_alternativos: list[str] | None = None,
        horas_pronostico: list[Any] | None = None,
    ) -> tuple[RecomendacionResponse, bool]:
        """Ejecuta el ciclo de vida completo de recomendación turística personalizada.

        Devuelve (RecomendacionResponse, hay_peligro).
        """
        # 1. Estrategia personalizada (Strategy Pattern)
        slugs_categorias = [c.slug for c in atractivo.categories]
        categoria_primaria = slugs_categorias[0] if slugs_categorias else "general"
        estrategia = RecommendationStrategyFactory.obtener_estrategia(
            preferencias_turista=preferencias_usuario,
            categoria_principal=categoria_primaria,
        )

        # 2. Scoring base con ajuste de estrategia
        resultado_base = scoring.generar_recomendacion(
            nombre_atractivo=atractivo.name,
            slugs_categorias=slugs_categorias,
            temperatura=clima.temperatura_actual,
            uv=clima.indice_uv,
            viento=clima.velocidad_viento,
            precipitacion=clima.probabilidad_precipitacion / 100.0 * 3.0,
            preferencias_usuario=preferencias_usuario,
        )

        afinidad_estrategia = estrategia.calcular_afinidad(preferencias_usuario, slugs_categorias)
        ajuste_clima_estrategia = estrategia.calcular_ajuste_climatico(
            clima.temperatura_actual, clima.velocidad_viento, clima.indice_uv
        )
        score_combinado = min(1.0, (resultado_base.score * 0.8 + afinidad_estrategia) * ajuste_clima_estrategia)

        # 3. Alertas y Reglas de Seguridad Meteorológica Georreferenciadas
        alertas_candidatas = rules.evaluar_alertas(
            temperatura=clima.temperatura_actual,
            uv=clima.indice_uv,
            viento=clima.velocidad_viento,
            precipitacion=clima.precipitacion_mm or (clima.probabilidad_precipitacion / 100.0 * 3.0),
            temperatura_arena=clima.temperatura_suelo_arena,
            zona=atractivo.name,
        )
        hay_peligro = any(a.severity == "high" for a in alertas_candidatas)
        mensajes_alertas = [a.message for a in alertas_candidatas]

        # 4. Cálculo final de score y nivel según seguridad
        if hay_peligro:
            score_final = min(score_combinado, 0.30)
            nivel_final = "no_recomendado"
        else:
            score_final = score_combinado
            nivel_final = rules.nivel_desde_puntaje(score_final)

        resultado_evaluado = scoring.ResultadoRecomendacion(
            score=score_final,
            nivel=nivel_final,
            texto=f"Condiciones de riesgo en {atractivo.name}. Se desaconseja la visita temporalmente." if hay_peligro else resultado_base.texto,
            factores=resultado_base.factores,
            consejos=resultado_base.consejos,
            perfil=resultado_base.perfil,
            afinidad_preferencia=afinidad_estrategia,
        )

        # 5. Directiva personalizada para Gemini AI
        directiva_ia = estrategia.directiva_personalizada_ia(estilo, presupuesto, compania)

        # 6. Redacción enriquecida con Gemini AI
        texto, consejos_gemini = await redactar_con_gemini(
            nombre_atractivo=atractivo.name,
            resultado=resultado_evaluado,
            alertas_activas=mensajes_alertas,
            atractivos_alternativos=atractivos_alternativos or [],
            temperatura=clima.temperatura_actual,
            uv=clima.indice_uv,
            viento=clima.velocidad_viento,
            condicion=clima.descripcion_clima,
            preferencias_usuario=preferencias_usuario,
            estilo=estilo,
            presupuesto=presupuesto,
            compania=compania,
            directiva_estrategia=directiva_ia,
            idioma=idioma,
            presion_hpa=clima.presion_atmosferica,
            precipitacion_mm=clima.precipitacion_mm,
            temperatura_arena=clima.temperatura_suelo_arena,
            pm10=clima.calidad_aire_pm10,
            ventana_pico_uv=clima.ventana_pico_uv,
            horas_sol=clima.horas_sol_directo,
            altura_ola=clima.altura_ola_metros,
            narrativa_previa=narrativa_previa,
        )

        # 7. Evaluación de seguridad temporal (noche / madrugada / horarios DIRCETUR)
        eval_seg = evaluar_seguridad_temporal(
            slugs_categorias=slugs_categorias,
            nombre_atractivo=atractivo.name,
            horas_pronostico=horas_pronostico or [],
        )

        texto_base = texto or resultado_evaluado.texto
        if eval_seg.es_planificacion_manana:
            prefijo = (
                f"🌅 [Planificación para Mañana]\n"
                f"• Hora sugerida de salida / visita: {eval_seg.hora_sugerida}\n"
                f"• Motivo de seguridad: {eval_seg.justificacion_seguridad}\n"
                f"• Pronóstico proyectado: {eval_seg.justificacion_climatica_manana}\n\n"
            )
            texto_recomendacion = prefijo + texto_base
        else:
            texto_recomendacion = texto_base

        fecha_generacion = datetime.now(tz=timezone.utc)
        return RecomendacionResponse(
            atractivo_id=atractivo.id,
            atractivo_nombre=atractivo.name,
            score=round(score_final, 2),
            nivel=nivel_final,
            recommendation_text=texto_recomendacion,
            consejos=consejos_gemini or resultado_evaluado.consejos,
            generated_at=fecha_generacion,
            es_planificacion_manana=eval_seg.es_planificacion_manana,
            hora_sugerida=eval_seg.hora_sugerida,
            normativa_oficial=eval_seg.normativa_oficial,
        ), hay_peligro
