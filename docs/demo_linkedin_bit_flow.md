# Demo LinkedIn Bit Flow

## Guion de 60 segundos

1. Abrir Bit Flow en modo demo y mostrar el home premium.
2. Entrar a Plantillas y elegir Relevamiento con evidencias.
3. Mostrar la planilla "Patagonia Ingenieria - Relevamiento tecnico" con datos ya cargados.
4. Editar una celda de Estado o Medicion y mostrar que el cambio aparece al instante.
5. Editar el encabezado Medicion a "Medicion final".
6. Agregar una fila nueva y completar un dato corto.
7. Guardar, volver al inicio y reabrir la planilla.
8. Exportar PDF y mostrar el mensaje de exito.
9. Exportar XLSX real y mostrar el mensaje de exito.
10. Si hay evidencias cargadas, exportar paquete ZIP para mostrar datos + adjuntos.

## Pantallas recomendadas

- Home premium con acceso directo a planillas.
- Galeria de plantillas.
- Editor con la grilla tecnica cargada.
- Edicion inline de celda.
- Edicion de encabezado.
- Menu de exportacion.
- Mensaje de exportacion correcta.
- Vista de PDF/XLSX generado si el dispositivo permite abrirlo durante la grabacion.

## Texto sugerido para LinkedIn

Bit Flow es una app real para relevamientos tecnicos: planillas editables en campo, evidencias por celda y exportacion PDF/XLSX/ZIP para entregar resultados sin rearmar informes a mano.

En esta demo uso un caso ficticio de carteleria y puntos tecnicos en Neuquen: edito celdas y encabezados en vivo, guardo la planilla y exporto archivos listos para compartir.

El foco no es mostrar una maqueta, sino un flujo completo: datos, edicion, persistencia y entrega.

## Checklist antes de grabar

- Ejecutar `flutter pub get`.
- Ejecutar `flutter analyze`.
- Ejecutar `flutter test`.
- Abrir un emulador Android o Chrome.
- Crear la demo desde el template `linkedin` o `relevamiento-evidencias`.
- Editar una celda y un encabezado antes de exportar.
- Guardar y reabrir para confirmar persistencia.
- Probar PDF y XLSX antes de grabar.
- Si se muestran evidencias, agregar al menos una foto demo segura y ficticia.

## Datos demo usados

- Cliente: Patagonia Ingenieria SRL.
- Obra: Relevamiento de carteleria y puntos tecnicos.
- Ubicacion: Neuquen Capital.
- Responsable: Marco Luna.
- Tipo: Inspeccion tecnica / relevamiento.
- Estados: OK, Atención, Crítico, Pendiente.
- Columnas: Fecha, Progresiva, Sector, Elemento, Estado, Medicion, GPS, Evidencia, Observaciones.

Los registros son ficticios y seguros para publicacion. Incluyen campos vacios controlados, texto largo, comillas, tildes, eñe, emoji tecnico y salto de linea para validar exportacion y layout.

## Comandos de validacion

```powershell
flutter analyze
flutter test
flutter build web --release --pwa-strategy=none --base-href /bitacora_web/
flutter build apk --debug
```

## Riesgos conocidos

- En Android, el guardado directo de archivos puede abrir el share sheet segun permisos del sistema. Es comportamiento esperado del flujo actual.
- La exportacion ZIP aporta mas valor cuando la planilla tiene evidencias reales cargadas.
- Flutter 3.35.6 puede mostrar warnings de advisories de pub.dev aunque los comandos terminen con codigo 0.
