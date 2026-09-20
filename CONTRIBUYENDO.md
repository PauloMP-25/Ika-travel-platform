# Guía de Contribución para Ika Travel & Experience

¡Bienvenido al equipo! Esta guía define las reglas base para colaborar en el desarrollo de la Plataforma Inteligente de Turismo de Ica.

## 1. Flujo de Ramas (Branching Strategy)
Trabajaremos bajo un esquema simplificado de Git Flow:
- `main`: **Intocable.** Solo contiene código listo para producción y probado.
- `develop`: La rama principal de integración. Todo el código nuevo se une aquí.
- `feature/<nombre>`: Ramas para nuevas funcionalidades (ej. `feature/login`, `feature/mapa`).
- `bugfix/<nombre>`: Ramas para corrección de errores (ej. `bugfix/crash-app`).

## 2. Cómo empezar a trabajar
1. Asegúrate de estar en `develop` y con la última versión: `git checkout develop` y luego `git pull origin develop`.
2. Crea tu rama de trabajo: `git checkout -b feature/mi-nueva-funcionalidad`.
3. Haz tus cambios y sigue la regla de **Commits Convencionales**.

## 3. Regla de Commits Convencionales
Cada vez que hagas un commit, debes usar un prefijo:
- `feat:` Una nueva funcionalidad.
- `fix:` Corrección de un error.
- `docs:` Cambios solo en la documentación.
- `style:` Cambios de formato (espacios, punto y coma, etc).
- `refactor:` Cambio en el código que no arregla un error ni añade una función.
- `test:` Agregar o modificar pruebas.
- `chore:` Tareas de mantenimiento o dependencias.

*Ejemplo:* `git commit -m "feat: agregar botón SOS al menú principal"`

## 4. Pull Requests (PR)
Cuando termines tu tarea:
1. Sube tu rama al repositorio remoto: `git push origin feature/mi-nueva-funcionalidad`.
2. Ve a GitHub y abre un Pull Request apuntando SIEMPRE a la rama `develop`.
3. Completa la plantilla automática que aparecerá en GitHub.
4. Avisa al equipo (y al QA) para que revisen tu código. ¡Nunca apruebes tu propio PR!
