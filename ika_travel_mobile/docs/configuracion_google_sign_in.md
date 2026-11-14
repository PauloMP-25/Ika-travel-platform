# Configuración de Google Sign-In (corrección ApiException 10)

## Qué causa el error

```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10)
```

`10` = `DEVELOPER_ERROR`. En la práctica significa una de estas cosas:

1. Falta el `serverClientId` (Client ID de tipo **Web**) → no se puede emitir el `idToken`.
2. El **paquete** (`com.example.ika_travel_mobile`) y/o la **huella SHA-1** del keystore
   con el que firmas la app **no están registrados** en Google Cloud Console.
3. El Client ID usado no es de tipo Web (los de tipo Android/iOS no sirven como
   `serverClientId`).

## Cambios ya aplicados en el código

- `lib/config/api_config.dart`: nueva constante `ApiConfig.googleWebClientId`
  leída desde `--dart-define=GOOGLE_WEB_CLIENT_ID`.
- `lib/services/auth_service.dart` → `loginConGoogle()`:
  - pasa `serverClientId: webClientId` a `GoogleSignIn(...)`;
  - aborta con un mensaje claro si `GOOGLE_WEB_CLIENT_ID` no está definido;
  - captura `PlatformException` y traduce el código `10` a un mensaje accionable.

## Pasos de configuración (obligatorios)

### 1. Crear las credenciales en Google Cloud Console

1. <https://console.cloud.google.com/apis/credentials> → **Crear credenciales → ID de cliente OAuth**.
2. **Aplicación Android**:
   - Nombre de paquete: `com.example.ika_travel_mobile`
   - Huella SHA-1 (debug, Windows):

     ```powershell
     keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" `
       -alias androiddebugkey -storepass android | findstr /C:"SHA1"
     ```

     > Si el keystore no existe, créalo con `keytool -genkeypair -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android`.
   - Huella SHA-1 (release): la del `.jks`/keystore usado en `key.properties`.
3. **Aplicación Web**: crea también un Client ID de tipo **Web application**
   y copia su valor (`xxxx.apps.googleusercontent.com`).

### 2. Ejecutar la app con el Client ID Web

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<TU_CLIENT_ID_WEB>.apps.googleusercontent.com
```

### 3. Registrar el Client ID Web en el backend

`ika-backend/.env`:

```env
GOOGLE_CLIENT_IDS=<TU_CLIENT_ID_WEB>.apps.googleusercontent.com,<client_id_android>.apps.googleusercontent.com
```

El backend valida el claim `aud` del `id_token` contra esta lista
(`src/modules/users/auth_strategies/google.py`); si está vacía o no coincide,
el login fallará con 401 aunque el flujo de Google funcione.

## Verificación

1. `flutter clean && flutter pub get && flutter run --dart-define=...`
2. Botón "Continuar con Google".
3. Si vuelve el error 10: re-verifica paquete + SHA-1 en la credencial Android
   (es la causa más común) y que no haya otra credencial Android duplicada
   para el mismo paquete con otra huella.
