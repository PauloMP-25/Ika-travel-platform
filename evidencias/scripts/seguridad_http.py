"""Pruebas de seguridad ejecutables por HTTP (sin acceso a base de datos,
sin Docker y sin cuenta de administración). Guarda cada solicitud/respuesta en
evidencias/casos/seguridad/ y un resumen en evidencias/seguridad/.
"""
from __future__ import annotations

import time
import uuid

from comun import API, EVID, registrar

D = EVID / "casos" / "seguridad"
SUF = uuid.uuid4().hex[:8]
res: list[dict] = []


def marca(n, titulo, esperado, obtenido, ok):
    res.append({"n": n, "titulo": titulo, "esperado": esperado,
                "obtenido": obtenido, "estado": "Aprobado" if ok else "Observado"})
    print(f"[S{n}] {'OK ' if ok else 'OBS'} {titulo}: {obtenido}")


def crear_usuario(tag):
    email = f"seg.{tag}.{SUF}@qa-ikatravel.com"
    registrar(D, f"user_{tag}_register", "POST", f"{API}/auth/register",
              json={"email": email, "password": "ClaveSegura123", "full_name": f"Seg {tag}"})
    r = registrar(D, f"user_{tag}_login", "POST", f"{API}/auth/login",
                  json={"email": email, "password": "ClaveSegura123"})
    tok = r.json().get("access_token") if r.status_code == 200 else None
    return tok


def tunel_vivo() -> bool:
    import httpx
    try:
        r = httpx.get(f"{API}/catalog/categories",
                      headers={"ngrok-skip-browser-warning": "true"}, timeout=15)
        return r.status_code == 200 and "application/json" in r.headers.get("content-type", "")
    except Exception:
        return False


def main():
    if not tunel_vivo():
        print("ABORTA: el backend/túnel ngrok no responde con JSON (probablemente offline). "
              "No se ejecutan las pruebas para no registrar resultados inválidos.")
        return
    tokA = crear_usuario("A")
    tokB = crear_usuario("B")
    hA = {"Authorization": f"Bearer {tokA}"}
    hB = {"Authorization": f"Bearer {tokB}"}

    # S1. Ruta protegida sin token -> 401
    r = registrar(D, "s1_sin_token", "GET", f"{API}/users/me")
    marca(1, "Ruta protegida sin token", "401", str(r.status_code), r.status_code == 401)

    # S2. Token con firma manipulada -> 401
    if tokA:
        partes = tokA.split(".")
        firma = partes[2]
        alterada = ("A" if firma[0] != "A" else "B") + firma[1:]
        tok_malo = f"{partes[0]}.{partes[1]}.{alterada}"
        r = registrar(D, "s2_token_manipulado", "GET", f"{API}/users/me",
                      headers={"Authorization": f"Bearer {tok_malo}"})
        marca(2, "Token con firma manipulada", "401", str(r.status_code), r.status_code == 401)
    else:
        marca(2, "Token con firma manipulada", "401", "sin token base", False)

    # S3. Turista en operación de administración -> 403
    r1 = registrar(D, "s3_turista_analytics", "GET", f"{API}/admin/analytics/summary", headers=hA)
    r2 = registrar(D, "s3_turista_admin_reports", "GET", f"{API}/emergency/admin/reports", headers=hA)
    ok3 = r1.status_code == 403 and r2.status_code == 403
    marca(3, "Turista en endpoints de administración (analytics y DIRCETUR)",
          "403", f"analytics={r1.status_code}, admin/reports={r2.status_code}", ok3)

    # S4. Endpoint de administración (X-Admin-Key) sin clave -> rechazo
    r = registrar(D, "s4_admin_sin_clave", "POST", f"{API}/catalog/admin/attractions",
                  json={"name": "x", "description": "x", "latitude": -14, "longitude": -75, "district": "Ica"})
    marca(4, "Endpoint admin (X-Admin-Key) sin clave", "401/403/503",
          str(r.status_code), r.status_code in (401, 403, 503))

    # S5. Inyección SQL en search -> sin 500 y sin fuga de datos
    normal = registrar(D, "s5_search_normal", "GET", f"{API}/catalog/attractions",
                       params={"search": "Huacachina"})
    inj = registrar(D, "s5_search_sqli", "GET", f"{API}/catalog/attractions",
                    params={"search": "' OR 1=1 --"})
    def n_items(r):
        try:
            j = r.json(); it = j.get("items", j) if isinstance(j, dict) else j
            return len(it) if isinstance(it, list) else None
        except Exception:
            return None
    n_norm, n_inj = n_items(normal), n_items(inj)
    ok5 = inj.status_code != 500 and (n_inj is None or n_norm is None or n_inj <= max(n_norm, 1) or n_inj == 0)
    marca(5, "Inyección SQL en search ('OR 1=1 --)",
          "sin 500; no devuelve el catálogo completo",
          f"código={inj.status_code}; resultados inyección={n_inj} vs normal={n_norm}", ok5)

    # S6. XSS almacenado en el comentario de una reseña -> sin 500; texto tal cual
    at = registrar(D, "s6_attr", "GET", f"{API}/catalog/attractions", params={"page_size": 1})
    it = at.json(); it = it.get("items", it) if isinstance(it, dict) else it
    at_id = it[0]["id"] if isinstance(it, list) and it else None
    if at_id:
        payload = "<script>alert(1)</script>"
        rv = registrar(D, "s6_review_xss", "POST", f"{API}/catalog/attractions/{at_id}/reviews",
                       headers=hA, json={"rating": 5, "comment": payload})
        guardado = ""
        try:
            guardado = rv.json().get("comment", "")
        except Exception:
            pass
        ok6 = rv.status_code != 500 and (rv.status_code >= 400 or guardado == payload)
        marca(6, "XSS en comentario de reseña",
              "sin 500; el texto se guarda tal cual (sin ejecutar ni alterar)",
              f"código={rv.status_code}; comentario guardado={'igual al enviado' if guardado == payload else repr(guardado)[:40]}", ok6)
        # Limpieza de la reseña de prueba
        try:
            rid = rv.json().get("id")
            if rid:
                registrar(D, "s6_review_delete", "DELETE", f"{API}/reviews/{rid}", headers=hA)
        except Exception:
            pass
    else:
        marca(6, "XSS en comentario de reseña", "sin 500", "no se obtuvo atractivo", False)

    # S7. IDOR: usuario B edita/borra una reseña del usuario A -> 403/404
    if at_id and tokA and tokB:
        rv = registrar(D, "s7_review_A", "POST", f"{API}/catalog/attractions/{at_id}/reviews",
                       headers=hA, json={"rating": 4, "comment": f"Reseña de A {SUF}"})
        rid = None
        try:
            rid = rv.json().get("id")
        except Exception:
            pass
        if rid and rv.status_code in (200, 201):
            e = registrar(D, "s7_B_edita_resena_de_A", "PUT", f"{API}/reviews/{rid}",
                          headers=hB, json={"rating": 1, "comment": "editada por B"})
            d = registrar(D, "s7_B_borra_resena_de_A", "DELETE", f"{API}/reviews/{rid}", headers=hB)
            ok7 = e.status_code in (403, 404) and d.status_code in (403, 404)
            marca(7, "IDOR: usuario B edita/borra reseña de usuario A",
                  "403 o 404", f"PUT={e.status_code}, DELETE={d.status_code}", ok7)
            registrar(D, "s7_A_borra_su_resena", "DELETE", f"{API}/reviews/{rid}", headers=hA)
        else:
            marca(7, "IDOR en reseñas", "403/404", f"no se pudo crear reseña base ({rv.status_code})", False)
    else:
        marca(7, "IDOR en reseñas", "403/404", "faltan datos base", False)

    # S8. Límite de peticiones en /translation/translate
    codigos = []
    for i in range(35):
        r = registrar(D, f"s8_translate_{i+1:02d}", "POST", f"{API}/translation/translate",
                      json={"text": f"Hola número {i}", "source_lang": "es", "target_lang": "en"})
        codigos.append(r.status_code)
        if r.status_code == 429:
            break
        time.sleep(0.05)
    hay_429 = 429 in codigos
    primer_429 = codigos.index(429) + 1 if hay_429 else None
    marca(8, "Límite de peticiones en /translation/translate (35 llamadas)",
          "429 a partir de ~la 31", f"primer 429 en la llamada {primer_429}" if hay_429 else
          f"no se observó 429 en 35 llamadas (códigos: {sorted(set(codigos))})", hay_429)

    # S11. HTTPS
    marca(11, "Transporte cifrado (HTTPS)", "https con certificado válido",
          f"la API se sirve por {API.split('://')[0]}:// (túnel ngrok con TLS)", API.startswith("https"))

    import json
    (EVID / "seguridad" / "_resumen_seguridad.json").write_text(
        json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
    ap = sum(1 for r in res if r["estado"] == "Aprobado")
    print(f"\n== Seguridad: {ap}/{len(res)} aprobadas ==")


if __name__ == "__main__":
    main()
