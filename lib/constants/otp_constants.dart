// Constante para la URL del servidor OTP local
// Asegúrate que la IP sea accesible desde el emulador/dispositivo

// --- Configuración de URL base para OTP ---
// Descomenta la línea que corresponda a tu entorno de ejecución:

// Para emulador Android (accede al localhost de la máquina host):
// const String OTP_BASE_URL = "http://10.0.2.2:8080";

// Para dispositivo físico conectado a la misma red Wi-Fi que el servidor OTP:
// Reemplaza 'TU_IP_LOCAL' con la dirección IP de la máquina donde corre el servidor OTP.
// Ejemplo: const String OTP_BASE_URL = "http://192.168.1.100:8080";
const String OTP_BASE_URL =
    "http://192.168.1.3:8080"; // ¡¡¡ATENCIÓN: MODIFICAR ESTA LÍNEA!!!

// --- Endpoints específicos de OTP ---
// Endpoint REST para planificación (se mantiene por si acaso o para futuras referencias)
const String OTP_SERVER_URL_REST = "$OTP_BASE_URL/otp/routers/default/plan";

// Endpoint GraphQL para planificación (principalmente usado)
const String OTP_SERVER_URL_GRAPHQL =
    "$OTP_BASE_URL/otp/routers/default/index/graphql";
