# lib/constants/otp_constants.dart

Este archivo define constantes para la interacción con un servidor OpenTripPlanner (OTP) local.

## Responsabilidades:

- Almacenar la URL base del servidor OTP.
- Almacenar los endpoints específicos (REST y GraphQL) para la planificación de rutas.

## Entradas:

- La constante `OTP_BASE_URL` requiere que la IP del servidor OTP sea accesible desde el dispositivo o emulador donde corre la aplicación.

## Salidas/Efectos:

- Provee las constantes `OTP_BASE_URL`, `OTP_SERVER_URL_REST`, y `OTP_SERVER_URL_GRAPHQL` que serán utilizadas por los servicios o módulos que interactúen con el servidor OTP para obtener planes de viaje.
