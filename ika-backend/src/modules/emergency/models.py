"""Modelos SQLAlchemy del módulo `emergency` (SOS, reportes de informalidad/incidencias y notificaciones)."""

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base


class SOSStatus(str, enum.Enum):
    """Ciclo de vida de un reporte SOS."""

    PENDING = "pending"
    DISPATCHED = "dispatched"
    RESOLVED = "resolved"


class IncidentType(str, enum.Enum):
    """Tipos de reporte e incidencias / informalidad turística (RF-05 / CUN06)."""

    INFORMAL_SERVICE = "informal_service"       # Agencia pirata, jaladores sin carnet, transporte informal
    INFORMATION_ERROR = "information_error"     # Horarios o datos turísticos erróneos
    ROUTE_OBSTRUCTION = "route_obstruction"     # Bloqueo o peligro en vía turística (e.g., dunas, carretera)
    SAFETY_HAZARD = "safety_hazard"             # Incidente de seguridad o estafa
    OTHER = "other"                             # Otro tipo de incidencia


class IncidentStatus(str, enum.Enum):
    """Estado de atención de un reporte por la DIRCETUR Ica."""

    RECEIVED = "received"
    IN_REVIEW = "in_review"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class NotificationChannel(str, enum.Enum):
    """Canal por el que se avisa de un incidente."""

    SMS = "sms"
    EMAIL = "email"
    PUSH = "push"


class NotificationStatus(str, enum.Enum):
    """Estado de entrega de una notificación."""

    QUEUED = "queued"
    SENT = "sent"
    FAILED = "failed"


def _enum_values(enum_cls: enum.EnumMeta) -> list[str]:
    """Persiste el valor (`'pending'`) y no el nombre del miembro."""
    return [member.value for member in enum_cls]


class SOSReport(Base):
    """Reporte de emergencia emitido por el botón SOS."""

    __tablename__ = "sos_reports"
    __table_args__ = (
        # Sprint 4, F2/F4: historial del usuario ordenado por fecha y
        # unicidad de la Idempotency-Key dentro del ámbito del usuario
        # (PostgreSQL admite varios NULL, así que el header sigue siendo
        # opcional).
        Index("idx_sos_reports_user_created", "user_id", text("created_at DESC")),
        UniqueConstraint(
            "user_id", "idempotency_key", name="uq_sos_reports_user_idempotency"
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[SOSStatus] = mapped_column(
        Enum(SOSStatus, name="sos_status", values_callable=_enum_values),
        nullable=False,
        default=SOSStatus.PENDING,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Sprint 4, F4: clave opcional de idempotencia y huella del payload, para
    # detectar la misma clave usada con un cuerpo distinto.
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    request_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    user = relationship("User", back_populates="sos_reports")
    notifications: Mapped[list["EmergencyNotification"]] = relationship(
        "EmergencyNotification",
        back_populates="report",
        cascade="all, delete-orphan",
    )


class TouristIncidentReport(Base):
    """Reporte de informalidad o incidencia enviado a DIRCETUR Ica (RF-05 / CUN06)."""

    __tablename__ = "tourist_incident_reports"
    __table_args__ = (
        # Sprint 4, F2: panel de fiscalización DIRCETUR (filtro por estado,
        # más recientes primero) y unicidad de la Idempotency-Key por usuario.
        Index("idx_incident_reports_status_created", "status", text("created_at DESC")),
        UniqueConstraint(
            "user_id", "idempotency_key", name="uq_incident_reports_user_idempotency"
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    incident_type: Mapped[IncidentType] = mapped_column(
        Enum(IncidentType, name="incident_type", values_callable=_enum_values),
        nullable=False,
        default=IncidentType.INFORMAL_SERVICE,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    agency_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    status: Mapped[IncidentStatus] = mapped_column(
        Enum(IncidentStatus, name="incident_status", values_callable=_enum_values),
        nullable=False,
        default=IncidentStatus.RECEIVED,
        index=True,
    )
    admin_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Sprint 4, F4: idempotencia opcional de la creación del reporte.
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    request_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    user = relationship("User")


class EmergencyNotification(Base):
    """Aviso generado por un reporte SOS (email, SMS o push)."""

    __tablename__ = "emergency_notifications"

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    sos_report_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("sos_reports.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    channel: Mapped[NotificationChannel] = mapped_column(
        Enum(
            NotificationChannel,
            name="notification_channel",
            values_callable=_enum_values,
        ),
        nullable=False,
    )
    recipient: Mapped[str] = mapped_column(String(255), nullable=False)
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[NotificationStatus] = mapped_column(
        Enum(
            NotificationStatus,
            name="notification_status",
            values_callable=_enum_values,
        ),
        nullable=False,
        default=NotificationStatus.QUEUED,
    )

    report = relationship("SOSReport", back_populates="notifications")
