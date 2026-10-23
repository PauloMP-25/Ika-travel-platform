package com.example.ika_travel_mobile

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ika_travel_mobile/sms_directo"
    private val SMS_PERMISSION_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enviarSmsDirecto" -> {
                    val telefono = call.argument<String>("telefono") ?: ""
                    val mensaje = call.argument<String>("mensaje") ?: ""

                    if (telefono.isBlank() || mensaje.isBlank()) {
                        result.error("ARG_INVALIDOS", "Teléfono o mensaje vacío", null)
                        return@setMethodCallHandler
                    }

                    val tienePermiso = ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED

                    if (!tienePermiso) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(android.Manifest.permission.SEND_SMS),
                            SMS_PERMISSION_CODE
                        )
                        result.error("SIN_PERMISO", "Permiso SEND_SMS no concedido", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val cleanPhone = telefono.replace(Regex("[^0-9+]"), "")
                        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            applicationContext.getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }

                        val partes = smsManager.divideMessage(mensaje)
                        smsManager.sendMultipartTextMessage(cleanPhone, null, partes, null, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR_ENVIO", e.localizedMessage, null)
                    }
                }
                "realizarLlamadaDirecta" -> {
                    val telefono = call.argument<String>("telefono") ?: ""
                    val cleanPhone = telefono.replace(Regex("[^0-9+]"), "")
                    try {
                        val intent = Intent(Intent.ACTION_DIAL).apply {
                            data = Uri.parse("tel:$cleanPhone")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR_LLAMADA", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
