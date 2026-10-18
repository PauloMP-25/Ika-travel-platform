"""Frasebook oficial es↔en: frases turísticas curadas e inmutables.

El contenido es informativo (saludos, emergencia, transporte, etc.); no
incluye frases de reserva o pago, que quedan fuera del producto.
"""

from __future__ import annotations

import hashlib
from collections.abc import Sequence
from dataclasses import dataclass

from src.modules.translation.normalization import normalize_for_lookup
from src.modules.translation.schemas import Language, PhraseCategory


@dataclass(frozen=True, slots=True)
class TouristPhrase:
    id: str
    category: PhraseCategory
    es: str
    en: str

    def text_in(self, language: Language) -> str:
        return self.es if language is Language.ES else self.en


class Phrasebook:
    """Colección inmutable e indexada de frases turísticas oficiales."""

    def __init__(self, phrases: Sequence[TouristPhrase]) -> None:
        self._phrases: tuple[TouristPhrase, ...] = tuple(phrases)
        self._index: dict[tuple[Language, str], TouristPhrase] = {}
        for phrase in self._phrases:
            for language in Language:
                key = (language, normalize_for_lookup(phrase.text_in(language)))
                if key in self._index:
                    raise ValueError(f"Frase duplicada en el frasebook: {key}")
                self._index[key] = phrase
        digest = hashlib.sha256(
            "|".join(f"{p.id}:{p.es}:{p.en}" for p in self._phrases).encode("utf-8")
        ).hexdigest()
        self.version: str = digest[:12]

    def find(self, language: Language, normalized_text: str) -> TouristPhrase | None:
        return self._index.get((language, normalized_text))

    def list(self, category: PhraseCategory | None = None) -> list[TouristPhrase]:
        if category is None:
            return list(self._phrases)
        return [p for p in self._phrases if p.category is category]


_C = PhraseCategory

_PHRASES: tuple[TouristPhrase, ...] = (
    # Saludos
    TouristPhrase("sal-01", _C.GREETINGS, "Buenos días, ¿cómo está?", "Good morning, how are you?"),
    TouristPhrase("sal-02", _C.GREETINGS, "Mucho gusto, soy turista.", "Nice to meet you, I am a tourist."),
    TouristPhrase("sal-03", _C.GREETINGS, "¿Habla inglés?", "Do you speak English?"),
    TouristPhrase("sal-04", _C.GREETINGS, "Hablo muy poco español.", "I speak very little Spanish."),
    # Emergencia
    TouristPhrase("eme-01", _C.EMERGENCY, "Necesito ayuda, es una emergencia.", "I need help, this is an emergency."),
    TouristPhrase("eme-02", _C.EMERGENCY, "Llame a la policía, por favor.", "Please call the police."),
    TouristPhrase("eme-03", _C.EMERGENCY, "Necesito una ambulancia.", "I need an ambulance."),
    TouristPhrase("eme-04", _C.EMERGENCY, "He perdido mi pasaporte.", "I have lost my passport."),
    # Transporte
    TouristPhrase("tra-01", _C.TRANSPORT, "¿Cómo llego a la Laguna de Huacachina?", "How do I get to the Huacachina Lagoon?"),
    TouristPhrase("tra-02", _C.TRANSPORT, "¿Dónde puedo tomar un taxi seguro?", "Where can I get a safe taxi?"),
    TouristPhrase("tra-03", _C.TRANSPORT, "¿Cuánto tiempo demora el viaje?", "How long does the trip take?"),
    TouristPhrase("tra-04", _C.TRANSPORT, "Por favor, deténgase aquí.", "Please stop here."),
    # Alimentación
    TouristPhrase("ali-01", _C.FOOD, "Una mesa para dos, por favor.", "A table for two, please."),
    TouristPhrase("ali-02", _C.FOOD, "Soy alérgico a los frutos secos.", "I am allergic to nuts."),
    TouristPhrase("ali-03", _C.FOOD, "¿Esta agua es potable?", "Is this water safe to drink?"),
    TouristPhrase("ali-04", _C.FOOD, "¿Dónde puedo probar pisco local?", "Where can I try local pisco?"),
    # Actividades
    TouristPhrase("act-01", _C.ACTIVITIES, "¿A qué hora sale el tour de sandboarding?", "What time does the sandboarding tour leave?"),
    TouristPhrase("act-02", _C.ACTIVITIES, "¿El tour incluye guía en inglés?", "Does the tour include an English-speaking guide?"),
    TouristPhrase("act-03", _C.ACTIVITIES, "¿Cuánto dura el recorrido?", "How long is the tour?"),
    TouristPhrase("act-04", _C.ACTIVITIES, "¿Hay equipo de seguridad incluido?", "Is safety equipment included?"),
    # Orientación
    TouristPhrase("ori-01", _C.ORIENTATION, "¿Dónde queda el centro histórico de Ica?", "Where is the historic center of Ica?"),
    TouristPhrase("ori-02", _C.ORIENTATION, "¿Está lejos de aquí?", "Is it far from here?"),
    TouristPhrase("ori-03", _C.ORIENTATION, "¿Puede mostrarme en el mapa?", "Can you show me on the map?"),
    TouristPhrase("ori-04", _C.ORIENTATION, "¿A qué hora cierra este lugar?", "What time does this place close?"),
    # Salud
    TouristPhrase("sld-01", _C.HEALTH, "Me siento mareado por el calor.", "I feel dizzy from the heat."),
    TouristPhrase("sld-02", _C.HEALTH, "Necesito una farmacia.", "I need a pharmacy."),
    TouristPhrase("sld-03", _C.HEALTH, "Tengo una reacción alérgica.", "I am having an allergic reaction."),
    TouristPhrase("sld-04", _C.HEALTH, "Necesito agua y un lugar con sombra.", "I need water and a shady place."),
    # Servicios formales (RN-01)
    TouristPhrase("ser-01", _C.FORMAL_SERVICES, "¿Su agencia está registrada en DIRCETUR?", "Is your agency registered with DIRCETUR?"),
    TouristPhrase("ser-02", _C.FORMAL_SERVICES, "¿Puede mostrarme su autorización oficial?", "Can you show me your official authorization?"),
    TouristPhrase("ser-03", _C.FORMAL_SERVICES, "¿Cuál es su número de contacto oficial?", "What is your official contact number?"),
    TouristPhrase("ser-04", _C.FORMAL_SERVICES, "Quisiera denunciar un servicio informal.", "I would like to report an informal service."),
)

PHRASEBOOK = Phrasebook(_PHRASES)
