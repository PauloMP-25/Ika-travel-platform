import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Table,
    Text,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base

# Tabla puente N:M Atractivo <-> Categoría (PK compuesta)
attraction_category = Table(
    "attraction_category",
    Base.metadata,
    Column("attraction_id", Uuid, ForeignKey("attraction.id", ondelete="CASCADE"), primary_key=True),
    Column("category_id", Uuid, ForeignKey("category.id", ondelete="CASCADE"), primary_key=True),
    Index("ix_attraction_category_category_id", "category_id"),
)


class Category(Base):
    __tablename__ = "category"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    slug: Mapped[str] = mapped_column(String(120), unique=True, index=True, nullable=False)


class Attraction(Base):
    __tablename__ = "attraction"
    __table_args__ = (
        CheckConstraint("latitude BETWEEN -90 AND 90", name="ck_attraction_latitude"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="ck_attraction_longitude"),
        Index("ix_attraction_lat_lon", "latitude", "longitude"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200), index=True, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    district: Mapped[str] = mapped_column(String(100), index=True, nullable=False)
    official_recommendation: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Extensión sobre el modelo documentado: permite ocultar atractivos sin borrarlos
    # (weather.refresh_weather_cache "recorre atractivos activos").
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=text("true")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    images: Mapped[list["AttractionImage"]] = relationship(
        back_populates="attraction",
        order_by="AttractionImage.display_order",
        cascade="all, delete-orphan",
    )
    categories: Mapped[list["Category"]] = relationship(secondary=attraction_category)
    tours: Mapped[list["Tour"]] = relationship(back_populates="attraction", passive_deletes=True)


class AttractionImage(Base):
    __tablename__ = "attraction_image"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    attraction_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("attraction.id", ondelete="CASCADE"), index=True, nullable=False
    )
    url: Mapped[str] = mapped_column(String(500), nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    attraction: Mapped["Attraction"] = relationship(back_populates="images")


class Agency(Base):
    __tablename__ = "agency"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200), index=True, nullable=False)
    ruc: Mapped[str] = mapped_column(String(11), unique=True, nullable=False)
    dircetur_registry_number: Mapped[str | None] = mapped_column(String(50), nullable=True)
    # RN-01: solo las agencias validadas por DIRCETUR se exponen al público.
    is_validated: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=text("false"), index=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    contact_phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    contact_email: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    tours: Mapped[list["Tour"]] = relationship(
        back_populates="agency", cascade="all, delete-orphan", passive_deletes=True
    )


class Tour(Base):
    __tablename__ = "tour"
    __table_args__ = (
        CheckConstraint("price >= 0", name="ck_tour_price_non_negative"),
        CheckConstraint("duration_hours > 0", name="ck_tour_duration_positive"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    agency_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("agency.id", ondelete="CASCADE"), index=True, nullable=False
    )
    attraction_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("attraction.id", ondelete="SET NULL"), index=True, nullable=True
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    duration_hours: Mapped[int] = mapped_column(Integer, nullable=False)

    agency: Mapped["Agency"] = relationship(back_populates="tours")
    attraction: Mapped["Attraction | None"] = relationship(back_populates="tours")
