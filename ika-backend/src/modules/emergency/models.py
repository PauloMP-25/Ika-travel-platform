"""Modelos SQLAlchemy del módulo `emergency` (SOS y notificaciones)."""

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Enum, Float, ForeignKey, String, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.database import Base


class SOSStatus(str, enum.Enum):
    """Ciclo de vida de un reporte SOS."""

    PENDING = "pending"
    DISPATCHED = "dispatched"
    RESOLVED = "resolved"


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

    user = relationship("User", back_populates="sos_reports")
    notifications: Mapped[list["EmergencyNotification"]] = relationship(
        "EmergencyNotification",
        back_populates="report",
        cascade="all, delete-orphan",
    )


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
