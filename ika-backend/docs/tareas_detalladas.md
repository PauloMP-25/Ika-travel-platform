# Manual de Tareas Atómicas — Sprint 1
## Módulos: `users` (Dev 1) y `catalog` (Dev 2)

Este documento desglosa el trabajo en pasos secuenciales y verificables. Cada paso indica el archivo exacto a modificar dentro de `src/modules/<módulo>/`. Sigan el orden: cada paso asume que el anterior ya está hecho.

---

## 🧑‍💻 Tareas Detalladas: Desarrollador 1 (Módulo `users` / Auth)

**Pantalla objetivo de este sprint:** "Más - ICA Turismo y Clima" (perfil del usuario).

### ☐ Paso 1 — Modelos SQLAlchemy (`src/modules/users/models.py`)
- [ ] Crear clase `User(Base)` con: `id` (UUID, PK, default `uuid4`), `email` (String, unique, index=True, nullable=False), `password_hash` (String, nullable=True), `full_name` (String, nullable=False), `phone` (String, nullable=True), `auth_provider` (Enum: `email`, `google`, `facebook`), `provider_id` (String, nullable=True), `is_active` (Boolean, default=True), `created_at`/`updated_at` (DateTime, server_default=`func.now()`).
- [ ] Definir `relationship()` hacia `Review`, `Favorite` y `SOSReport` con `back_populates` (aunque esos modelos vivan en otros módulos — usar `string` reference para evitar imports circulares, ej. `relationship("Review", back_populates="user")`).
- [ ] Agregar constraint `UniqueConstraint("email")` explícito si el equipo prefiere no depender solo del `unique=True` de la columna.

### ☐ Paso 2 — Esquemas Pydantic (`src/modules/users/schemas.py`)
- [ ] `UserCreate`: `email: EmailStr`, `password: str` (usar `Field(min_length=8)`), `full_name: str`.
- [ ] `UserLogin`: `email: EmailStr`, `password: str`.
- [ ] `UserSocialLogin`: `provider: Literal["google", "facebook"]`, `access_token: str`.
- [ ] `UserResponse` (con `model_config = ConfigDict(from_attributes=True)`): `id: UUID`, `email: EmailStr`, `full_name: str`, `phone: str | None`, `created_at: datetime`. **No incluir `password_hash` bajo ninguna circunstancia.**
- [ ] `UserUpdate`: `full_name: str | None = None`, `phone: str | None = None` (todos opcionales, para `PUT/PATCH /users/me`).
- [ ] `TokenResponse`: `access_token: str`, `token_type: str = "bearer"`, `expires_in: int`.

### ☐ Paso 3 — Excepciones Custom (`src/modules/users/exceptions.py`)
- [ ] `UserAlreadyExistsException(Exception)` — recibe `email` en el constructor para el mensaje.
- [ ] `InvalidCredentialsException(Exception)`.
- [ ] `InactiveUserException(Exception)`.
- [ ] Registrar los 3 handlers en `src/core/exceptions.py` (mapear a HTTP 409, 401 y 403 respectivamente).

### ☐ Paso 4 — Seguridad: hasheo y JWT (`src/core/security.py`)
- [ ] Función `hash_password(password: str) -> str` usando `passlib.context.CryptContext` (esquema `bcrypt`).
- [ ] Función `verify_password(plain: str, hashed: str) -> bool`.
- [ ] Función `create_access_token(user_id: UUID) -> str` — JWT firmado con `SECRET_KEY` de `config.py`, claim `sub` = `user_id`, `exp` con expiración configurable (ej. 24h).
- [ ] Función `decode_access_token(token: str) -> UUID` — lanza `InvalidCredentialsException` si el token es inválido o expiró.

### ☐ Paso 5 — Lógica de negocio (`src/modules/users/service.py`)
- [ ] `register_user(db: Session, data: UserCreate) -> User`:
  1. Buscar si ya existe un `User` con ese `email` → si existe, lanzar `UserAlreadyExistsException`.
  2. Llamar a `hash_password(data.password)`.
  3. Crear instancia `User(email=..., password_hash=..., full_name=..., auth_provider="email")`.
  4. `db.add()`, `db.commit()`, `db.refresh()`, retornar.
- [ ] `authenticate_user(db: Session, email: str, password: str) -> User`:
  1. Buscar `User` por email → si no existe, lanzar `InvalidCredentialsException` (mismo mensaje genérico que password incorrecto, por seguridad — no revelar si el email existe).
  2. Verificar `is_active` → si `False`, lanzar `InactiveUserException`.
  3. `verify_password(password, user.password_hash)` → si falla, lanzar `InvalidCredentialsException`.
  4. Retornar `user`.
- [ ] `authenticate_oauth(db: Session, provider: str, access_token: str) -> User`:
  1. Validar `access_token` contra la API del proveedor (Google/Facebook) para obtener `email` + `provider_id`.
  2. Buscar `User` por `provider_id` + `provider` → si existe, retornar.
  3. Si no existe, buscar por `email` (caso: usuario ya registrado por email, ahora entra por OAuth) → vincular `provider_id` y retornar.
  4. Si tampoco existe por email, crear usuario nuevo con `auth_provider=provider`.
- [ ] `update_user_profile(db: Session, user: User, data: UserUpdate) -> User` — actualiza solo los campos no-`None`.

### ☐ Paso 6 — Dependencia compartida de autenticación (`src/core/dependencies.py`)
- [ ] `get_db()` — generador de sesión SQLAlchemy (si no existe ya desde el setup inicial).
- [ ] `get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User`:
  1. `user_id = decode_access_token(token)`.
  2. Buscar `User` por `id` → si no existe o `is_active=False`, lanzar 401.
  3. Retornar `user`. **Esta dependencia es la que usarán TODOS los módulos protegidos (SOS, Reviews, Favorites) — avisar a Dev 3 en cuanto esté lista.**

### ☐ Paso 7 — Router / Endpoints (`src/modules/users/router.py`)
- [ ] `POST /auth/register` → body `UserCreate`, llama a `service.register_user`, retorna `UserResponse` (201).
- [ ] `POST /auth/login` → body `UserLogin`, llama a `service.authenticate_user`, luego `create_access_token`, retorna `TokenResponse`.
- [ ] `POST /auth/login/social` → body `UserSocialLogin`, llama a `service.authenticate_oauth`, retorna `TokenResponse`.
- [ ] `GET /users/me` → protegido con `Depends(get_current_user)`, retorna `UserResponse` directo del usuario inyectado. **Este es el endpoint que alimenta la pantalla "Más".**
- [ ] `PUT /users/me` → protegido, body `UserUpdate`, llama a `service.update_user_profile`, retorna `UserResponse` actualizado.

### ☐ Paso 8 — Registrar el router en `src/main.py`
- [ ] `app.include_router(users_router, prefix="/api/v1", tags=["users"])`.

### ☐ Paso 9 — Migración Alembic
- [ ] `alembic revision --autogenerate -m "create users table"`.
- [ ] Revisar manualmente el archivo generado antes de aplicar (verificar tipo `Enum` y `UniqueConstraint`).
- [ ] `alembic upgrade head`.

### ☐ Paso 10 — Tests mínimos (`tests/modules/test_users.py`)
- [ ] Test: registro exitoso retorna 201 y no expone `password_hash`.
- [ ] Test: registro con email duplicado retorna 409.
- [ ] Test: login con password incorrecto retorna 401.
- [ ] Test: `GET /users/me` sin token retorna 401; con token válido retorna el perfil correcto.

---

## 🧑‍💻 Tareas Detalladas: Desarrollador 2 (Módulo `catalog`)

**Pantallas objetivo de este sprint:** "Actividades - ICA Turismo" (listado + filtros) y "Sandboarding en Huacachina - Detalle" + "Detalle del día" (vista detallada).

### ☐ Paso 1 — Modelos SQLAlchemy (`src/modules/catalog/models.py`)
- [ ] `Category(Base)`: `id` (UUID, PK), `name` (String, unique), `slug` (String, unique).
- [ ] `Attraction(Base)`: `id` (UUID, PK), `name` (String), `description` (Text), `latitude`/`longitude` (Float), `district` (String), `official_recommendation` (Text, nullable), `created_at`/`updated_at`.
- [ ] `AttractionImage(Base)`: `id` (UUID, PK), `attraction_id` (FK → `attraction.id`, `ondelete="CASCADE"`), `url` (String), `display_order` (Integer, default=0).
- [ ] Tabla puente `attraction_category` (N:M) usando `Table()` de SQLAlchemy Core, con columnas `attraction_id` y `category_id` como FKs compuestas (PK).
- [ ] En `Attraction`, definir `images: Mapped[list["AttractionImage"]] = relationship(order_by="AttractionImage.display_order")` y `categories: Mapped[list["Category"]] = relationship(secondary=attraction_category)`.
- [ ] `Agency(Base)`: `id`, `name`, `ruc` (unique), `dircetur_registry_number` (nullable), `is_validated` (Boolean, default=False), `validated_at` (nullable), `contact_phone`, `contact_email`.
- [ ] `Tour(Base)`: `id`, `agency_id` (FK), `attraction_id` (FK, nullable), `name`, `description`, `price` (Numeric(10,2)), `duration_hours` (Integer).

### ☐ Paso 2 — Esquemas Pydantic (`src/modules/catalog/schemas.py`)
- [ ] `CategoryResponse`: `id`, `name`, `slug`.
- [ ] `AttractionListItem` (para el listado de "Actividades"): `id`, `name`, `district`, `cover_image_url: str | None`, `categories: list[str]`. **Nota:** `cover_image_url` se resuelve en `service.py` tomando la imagen con `display_order == 0`, no se expone la lista completa aquí (por peso de payload en el listado).
- [ ] `PaginatedAttractionsResponse`: `items: list[AttractionListItem]`, `total: int`, `page: int`, `page_size: int`, `has_next: bool`.
- [ ] `AttractionDetailResponse` (para "Sandboarding - Detalle"): `id`, `name`, `description`, `official_recommendation`, `district`, `latitude`, `longitude`, `images: list[str]`, `categories: list[CategoryResponse]`, `avg_rating: float | None`.
- [ ] `TourResponse` (para "Detalle del día"): `id`, `name`, `description`, `price`, `duration_hours`, `agency_name`.
- [ ] `AgencyListItem`: `id`, `name`, `is_validated`, `tour_count: int`.
- [ ] `AgencyDetailResponse`: `id`, `name`, `contact_phone`, `contact_email`, `tours: list[TourResponse]`.

### ☐ Paso 3 — Excepciones Custom (`src/modules/catalog/exceptions.py`)
- [ ] `AttractionNotFoundException`.
- [ ] `InvalidCategoryFilterException` — se pasa un `slug` de categoría que no existe.
- [ ] `AgencyNotValidatedException`.
- [ ] `AgencyNotFoundException`.

### ☐ Paso 4 — Capa de repositorio (`src/modules/catalog/repository.py`)
Aquí van las queries SQLAlchemy puras, sin lógica de negocio:
- [ ] `get_attractions_query(db: Session, category_slug: str | None, district: str | None)`:
  ```python
  query = db.query(Attraction).options(
      selectinload(Attraction.images),
      selectinload(Attraction.categories),
  )
  if category_slug:
      query = query.join(Attraction.categories).filter(Category.slug == category_slug)
  if district:
      query = query.filter(Attraction.district == district)
  return query
  ```
- [ ] `paginate(query, page: int, page_size: int)` — aplica `.offset((page-1)*page_size).limit(page_size)` y retorna también `query.count()` para el `total`. **Usar `func.count()` sobre una subquery, no `len(query.all())`, para no traer todos los registros a memoria.**
- [ ] `get_attraction_by_id(db: Session, attraction_id: UUID) -> Attraction | None` — con `selectinload` de `images` y `categories`.
- [ ] `get_agencies_query(db: Session, search_term: str | None)`:
  ```python
  query = db.query(Agency).filter(Agency.is_validated == True)  # RN-01 aplicado aquí, no en el service
  if search_term:
      query = query.filter(Agency.name.ilike(f"%{search_term}%"))
  return query
  ```
- [ ] `get_agency_with_tours(db: Session, agency_id: UUID) -> Agency | None` — `selectinload(Agency.tours)`.

### ☐ Paso 5 — Lógica de negocio (`src/modules/catalog/service.py`)
- [ ] `get_paginated_attractions(db, category_slug, district, page, page_size) -> PaginatedAttractionsResponse`:
  1. Llamar a `repository.get_attractions_query(...)`.
  2. Llamar a `repository.paginate(...)`.
  3. Mapear cada `Attraction` a `AttractionListItem`, resolviendo `cover_image_url` desde `attraction.images[0].url if attraction.images else None`.
  4. Construir y retornar `PaginatedAttractionsResponse`.
- [ ] `get_attraction_detail(db, attraction_id) -> AttractionDetailResponse`:
  1. `attraction = repository.get_attraction_by_id(...)` → si `None`, lanzar `AttractionNotFoundException`.
  2. Calcular `avg_rating` (llamando a la función pura de `reviews.service.calculate_average_rating`, import explícito entre módulos — está permitido porque `catalog` puede depender de `reviews` para lectura, no al revés).
  3. Mapear a `AttractionDetailResponse` y retornar.
- [ ] `search_agencies(db, search_term) -> list[AgencyListItem]` — **la regla RN-01 ya viene filtrada desde `repository.get_agencies_query`, este método solo mapea el DTO**, no debe volver a filtrar (evita duplicar la regla de negocio en dos capas).
- [ ] `get_agency_detail(db, agency_id) -> AgencyDetailResponse`:
  1. `agency = repository.get_agency_with_tours(...)` → si `None`, lanzar `AgencyNotFoundException`.
  2. Si `agency.is_validated == False`, lanzar `AgencyNotValidatedException` (defensa en profundidad, aunque ya no debería aparecer en listados).
  3. Mapear a `AgencyDetailResponse`.

### ☐ Paso 6 — Router / Endpoints (`src/modules/catalog/router.py`)
- [ ] `GET /catalog/attractions?category=&district=&page=1&page_size=10` → llama a `service.get_paginated_attractions`, retorna `PaginatedAttractionsResponse`. **Alimenta la pantalla "Actividades".**
- [ ] `GET /catalog/categories` → llama a un `service.list_categories` simple, retorna `list[CategoryResponse]`. **Alimenta los filtros de "Actividades".**
- [ ] `GET /catalog/attractions/{attraction_id}` → llama a `service.get_attraction_detail`, retorna `AttractionDetailResponse`. **Alimenta "Sandboarding - Detalle".**
- [ ] `GET /catalog/attractions/{attraction_id}/tours` → retorna `list[TourResponse]` filtrando `Tour.attraction_id == attraction_id`. **Alimenta "Detalle del día".**
- [ ] `GET /catalog/agencies?query=` → llama a `service.search_agencies`, retorna `list[AgencyListItem]`.
- [ ] `GET /catalog/agencies/{agency_id}` → llama a `service.get_agency_detail`, retorna `AgencyDetailResponse`.

### ☐ Paso 7 — Registrar el router en `src/main.py`
- [ ] `app.include_router(catalog_router, prefix="/api/v1", tags=["catalog"])`.

### ☐ Paso 8 — Migración Alembic
- [ ] `alembic revision --autogenerate -m "create catalog tables"`.
- [ ] Verificar que la tabla puente `attraction_category` se generó con PK compuesta correcta.
- [ ] `alembic upgrade head`.

### ☐ Paso 9 — Datos semilla (seed) para desarrollo local
- [ ] Crear script `src/modules/catalog/seed.py` con al menos: categoría "Sandboarding", atracción "Huacachina" con 2-3 imágenes, 1 agencia validada con 1 tour — para que Dev 1 y Dev 3 puedan probar contra datos reales sin esperar contenido real del cliente.

### ☐ Paso 10 — Tests mínimos (`tests/modules/test_catalog.py`)
- [ ] Test: `GET /catalog/attractions` retorna paginación correcta (`total`, `has_next`).
- [ ] Test: filtro por `category` inexistente retorna 400 (`InvalidCategoryFilterException`).
- [ ] Test: `GET /catalog/attractions/{id}` con ID inexistente retorna 404.
- [ ] Test: `GET /catalog/agencies` nunca retorna una agencia con `is_validated=False`, incluso si existe en la BD (test crítico de RN-01).

---

## ⚠️ Puntos de sincronización entre Dev 1 y Dev 2

- Dev 2 **no depende** de Auth para estos endpoints (todos son públicos por RN-02), así que puede arrancar el Paso 1 el día 1 sin esperar a Dev 1.
- Dev 1 debe avisar en el canal del equipo en cuanto `get_current_user()` (Paso 6) esté funcional — aunque Dev 2 no lo necesita en este sprint, Dev 3 sí, y depende de este mismo módulo.
- Si el diseño de Figma para "Actividades" muestra rating con estrellas en las tarjetas del listado, avisar a Dev 2: eso requeriría agregar `avg_rating` también a `AttractionListItem` (hoy solo está en el detalle) — confirmar con diseño antes de cerrar el Paso 2.
