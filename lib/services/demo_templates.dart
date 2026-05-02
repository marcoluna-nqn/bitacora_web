class DemoTemplateSpec {
  const DemoTemplateSpec({
    required this.slug,
    required this.name,
    required this.sheetName,
    required this.headers,
    required this.rows,
  });

  final String slug;
  final String name;
  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;
}

const List<DemoTemplateSpec> kDemoTemplateSpecs = <DemoTemplateSpec>[
  DemoTemplateSpec(
    slug: 'relevamiento-evidencias',
    name: 'Relevamiento con evidencias',
    sheetName: 'Patagonia Ingenieria - Relevamiento tecnico',
    headers: <String>[
      'Fecha',
      'Progresiva',
      'Sector',
      'Elemento',
      'Estado',
      'Medicion',
      'GPS',
      'Evidencia',
      'Observaciones'
    ],
    rows: <List<String>>[
      <String>[
        '2026-05-02',
        '120',
        'Acceso norte',
        'Cartel informativo principal',
        'OK',
        '1.20 x 0.80 m',
        '-38.951320, -68.059820',
        'Foto pendiente',
        'Cliente: Patagonia Ingenieria SRL. Obra: Relevamiento de carteleria y puntos tecnicos. Ubicacion: Neuquen Capital. Responsable: Marco Luna.'
      ],
      <String>[
        '2026-05-02',
        '245',
        'Playa de maniobras',
        'Poste metalico Nro. 04',
        'Atención',
        'Altura 3.40 m',
        '-38.952040, -68.060510',
        'Sin evidencia adjunta',
        'Se observa leve desplazamiento respecto del eje de circulacion. Verificar aplome con nivel antes de liberar.'
      ],
      <String>[
        '2026-05-02',
        '310',
        'Sector bombas',
        'Baliza de seguridad',
        'Crítico',
        'Sin tension',
        '-38.952710, -68.061090',
        'Requiere foto',
        'Baliza fuera de servicio. Prioridad alta porque queda en zona de maniobra nocturna.'
      ],
      <String>[
        '2026-05-02',
        '415',
        'Galpon tecnico',
        'Tablero T-02',
        'Pendiente',
        'Etiqueta ausente',
        '-38.953210, -68.061880',
        '',
        'Falta identificacion externa. Agendar rotulado y registrar evidencia al cierre.'
      ],
      <String>[
        '2026-05-02',
        '560',
        'Cerco perimetral',
        'Cartel "Uso obligatorio de EPP"',
        'OK',
        '0.60 x 0.40 m',
        '-38.953930, -68.062540',
        'OK visual',
        'Texto legible, fijaciones firmes y sin corrosion visible.'
      ],
      <String>[
        '2026-05-02',
        '690',
        'Camino interno',
        'Punto de control vial',
        'Atención',
        'Pintura reflectiva baja',
        '-38.954670, -68.063110',
        '',
        'La senal conserva forma y ubicacion, pero la reflectividad esta degradada. Proponer recambio preventivo.'
      ],
      <String>[
        '2026-05-02',
        '820',
        'Sala electrica',
        'Placa de advertencia',
        'OK',
        'Nivel visual OK',
        '-38.955220, -68.063760',
        'Foto cargada',
        'Incluye tilde y eñe: señalización eléctrica verificada; no requiere accion.'
      ],
      <String>[
        '2026-05-02',
        '940',
        'Area carga',
        'Demarcacion horizontal',
        'Pendiente',
        'Tramo 18 m',
        '-38.955780, -68.064390',
        '',
        'Demarcacion parcialmente cubierta por polvo. Relevar de nuevo luego de limpieza del sector.'
      ],
      <String>[
        '2026-05-02',
        '1030',
        'Acceso sur',
        'Cartel de evacuacion',
        'Crítico',
        'Fijacion floja',
        '-38.956410, -68.065020',
        'Video sugerido',
        'El cartel vibra con viento. Corregir anclajes antes de la recorrida de seguridad.'
      ],
      <String>[
        '2026-05-02',
        '1180',
        'Oficina tecnica',
        'Plano de ubicacion',
        'OK',
        'A3 plastificado',
        '-38.957090, -68.065650',
        '',
        'Version vigente visible en ingreso. Validado por inspeccion tecnica / relevamiento.'
      ],
      <String>[
        '2026-05-02',
        '1320',
        'Deposito',
        'Identificacion de estanterias',
        'Atención',
        'Codigos incompletos',
        '-38.957760, -68.066270',
        'Foto pendiente',
        'Hay etiquetas con comillas: "Rack A" y "Rack B"; normalizar formato para evitar duplicados.'
      ],
      <String>[
        '2026-05-02',
        '1470',
        'Patio oeste',
        'Punto de reunion',
        'OK',
        'Radio despejado 5 m',
        '-38.958310, -68.066910',
        'OK visual',
        'Area libre de obstrucciones. Confirmar mantenimiento mensual.'
      ],
      <String>[
        '2026-05-02',
        '1620',
        'Canalizacion',
        'Marcador subterraneo',
        'Pendiente',
        '',
        '-38.958980, -68.067530',
        '',
        'Campo medicion vacio a proposito para probar exportacion con datos incompletos controlados.'
      ],
      <String>[
        '2026-05-02',
        '1780',
        'Linea peatonal',
        'Flecha direccional',
        'Atención',
        'Desgaste 35%',
        '-38.959610, -68.068180',
        'Foto sugerida',
        'Texto largo de prueba: la observacion debe envolver en PDF/XLSX sin romper la tabla ni tapar celdas vecinas; incluye barra / guion - y salto de linea\nSegunda linea de observacion para validar layout.'
      ],
      <String>[
        '2026-05-02',
        '1930',
        'Porton ingreso',
        'Codigo QR operativo',
        'OK',
        'Lectura OK',
        '-38.960260, -68.068840',
        'QR probado',
        'Caracteres especiales: ñ, á, é, í, ó, ú, emoji tecnico ⚙️. Registro ficticio para demo publica.'
      ],
      <String>[
        '2026-05-02',
        '2050',
        'Cierre recorrido',
        'Resumen de inspeccion',
        'Pendiente',
        'Acta a emitir',
        '-38.960910, -68.069470',
        '',
        'Revisar criticidades antes de exportar paquete ZIP con evidencias.'
      ],
    ],
  ),
  DemoTemplateSpec(
    slug: 'campo',
    name: 'Campo',
    sheetName: 'Demo Campo',
    headers: <String>[
      'Fecha',
      'Frente',
      'Actividad',
      'Estado',
      'Observaciones'
    ],
    rows: <List<String>>[
      <String>['2026-02-14', 'Norte', 'Replanteo', 'OK', 'Sin novedad'],
      <String>[
        '2026-02-14',
        'Norte',
        'Hormigonado',
        'Pendiente',
        'Falta mixer'
      ],
      <String>['2026-02-14', 'Sur', 'Excavacion', 'OK', 'Cota verificada'],
      <String>['2026-02-14', 'Sur', 'Compactacion', 'Obs', 'Humedad alta'],
      <String>['2026-02-14', 'Este', 'Canaleta', 'OK', ''],
    ],
  ),
  DemoTemplateSpec(
    slug: 'inventario',
    name: 'Inventario',
    sheetName: 'Demo Inventario',
    headers: <String>['SKU', 'Item', 'Cantidad', 'Unidad', 'Ubicación'],
    rows: <List<String>>[
      <String>['MAT-001', 'Cemento', '35', 'bolsas', 'Deposito A'],
      <String>['MAT-014', 'Hierro 8mm', '120', 'u', 'Deposito B'],
      <String>['MAT-032', 'Arena', '18', 'm3', 'Patio'],
      <String>['EPP-002', 'Guantes', '56', 'pares', 'Panuelo'],
      <String>['EPP-010', 'Cascos', '24', 'u', 'Oficina'],
    ],
  ),
  DemoTemplateSpec(
    slug: 'rendicion',
    name: 'Rendicion',
    sheetName: 'Demo Rendicion',
    headers: <String>['Fecha', 'Concepto', 'Categoria', 'Monto', 'Comprobante'],
    rows: <List<String>>[
      <String>['2026-02-10', 'Combustible', 'Movilidad', '45200', 'TK-1001'],
      <String>['2026-02-10', 'Peaje', 'Movilidad', '7800', 'TK-1002'],
      <String>[
        '2026-02-11',
        'Almuerzo cuadrilla',
        'Viaticos',
        '23500',
        'TK-1003'
      ],
      <String>['2026-02-12', 'Ferreteria', 'Materiales', '68400', 'TK-1004'],
      <String>['2026-02-13', 'Taxi', 'Movilidad', '9800', 'TK-1005'],
    ],
  ),
  DemoTemplateSpec(
    slug: 'gastos',
    name: 'Control de gastos',
    sheetName: 'Control de Gastos',
    headers: <String>[
      'Fecha',
      'Categoria',
      'Descripcion',
      'Monto',
      'Medio',
      'Estado'
    ],
    rows: <List<String>>[
      <String>[
        '2026-03-01',
        'Movilidad',
        'Combustible',
        '42000',
        'Tarjeta',
        'OK'
      ],
      <String>[
        '2026-03-01',
        'Comidas',
        'Almuerzo equipo',
        '18500',
        'Efectivo',
        'OK'
      ],
      <String>[
        '2026-03-02',
        'Materiales',
        'Ferreteria',
        '63800',
        'Transferencia',
        'OK'
      ],
      <String>[
        '2026-03-02',
        'Servicios',
        'Mensajeria',
        '9200',
        'Tarjeta',
        'Obs'
      ],
      <String>[
        '2026-03-03',
        'Viaticos',
        'Taxi cliente',
        '12600',
        'Efectivo',
        'OK'
      ],
      <String>['2026-03-03', 'TOTAL', '', '=SUM(D1:D5)', '', ''],
    ],
  ),
  DemoTemplateSpec(
    slug: 'proyectos',
    name: 'Seguimiento de proyectos',
    sheetName: 'Seguimiento de Proyectos',
    headers: <String>[
      'Proyecto',
      'Responsable',
      'Inicio',
      'Fin objetivo',
      '% Avance',
      'Estado',
      'Riesgo'
    ],
    rows: <List<String>>[
      <String>[
        'Pipeline Norte',
        'Ana',
        '2026-02-10',
        '2026-04-30',
        '45',
        'OK',
        'Bajo'
      ],
      <String>[
        'SCADA Planta',
        'Luis',
        '2026-01-20',
        '2026-05-15',
        '62',
        'Obs',
        'Medio'
      ],
      <String>[
        'Relevamiento RTU',
        'Marta',
        '2026-03-01',
        '2026-03-25',
        '30',
        'Urgente',
        'Alto'
      ],
      <String>[
        'Backlog interno',
        'PMO',
        '2026-02-01',
        '2026-03-31',
        '=ROUND(AVERAGE(E1:E3), 0)',
        '',
        ''
      ],
    ],
  ),
  DemoTemplateSpec(
    slug: 'mediciones',
    name: 'Mediciones técnicas',
    sheetName: 'Mediciones técnicas',
    headers: <String>[
      'Fecha',
      'Punto',
      'Parámetro',
      'Lectura',
      'Unidad',
      'Limite',
      'Estado'
    ],
    rows: <List<String>>[
      <String>[
        '2026-03-02',
        'P-01',
        'Resistencia',
        '4.3',
        'Ohm',
        '5.0',
        '=IF(D1<=F1, "OK", "CHECK")'
      ],
      <String>[
        '2026-03-02',
        'P-02',
        'Resistencia',
        '5.8',
        'Ohm',
        '5.0',
        '=IF(D2<=F2, "OK", "CHECK")'
      ],
      <String>[
        '2026-03-02',
        'P-03',
        'Resistencia',
        '4.9',
        'Ohm',
        '5.0',
        '=IF(D3<=F3, "OK", "CHECK")'
      ],
      <String>[
        '2026-03-02',
        'PROM',
        'Lectura promedio',
        '=ROUND(AVERAGE(D1:D3),2)',
        'Ohm',
        '',
        ''
      ],
    ],
  ),
];

DemoTemplateSpec? resolveDemoTemplateFromSlug(String? slug) {
  final normalized = (slug ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return null;
  const aliases = <String, String>{
    'evidencias': 'relevamiento-evidencias',
    'relevamiento': 'relevamiento-evidencias',
    'demo-tecnica': 'relevamiento-evidencias',
    'linkedin': 'relevamiento-evidencias',
    'patagonia': 'relevamiento-evidencias',
    'demo-linkedin': 'relevamiento-evidencias',
  };
  final effective = aliases[normalized] ?? normalized;
  for (final spec in kDemoTemplateSpecs) {
    if (spec.slug == effective) return spec;
  }
  return null;
}
