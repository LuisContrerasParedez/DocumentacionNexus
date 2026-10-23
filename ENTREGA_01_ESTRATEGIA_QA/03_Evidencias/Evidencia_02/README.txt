EVIDENCIA 02 - Bloqueo progresivo por intentos fallidos
======================================================================

Fecha de captura : 15 de septiembre de 2026
Ambiente         : Local Docker Compose (commit 28f3faf)
Archivo          : Evidencia_02_02_login_fallido.png

DESCRIPCION Y RELEVANCIA PARA QA
----------------------------------------------------------------------
Evidencia del hallazgo H-02 y H-08. El mensaje en linea revela 'Credenciales incorrectas. Intento 1 de 5', lo que confirma que el ambiente usa un umbral de 5 mientras el codigo define 3 por defecto, y expone el contador al usuario. Se observa ademas la inconsistencia con la notificacion emergente, que muestra un mensaje distinto de forma simultanea.
