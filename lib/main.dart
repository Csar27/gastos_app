import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  ThemeData get currentTheme {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(shadowColor: Colors.transparent),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.black,
    cardTheme: const CardThemeData(shadowColor: Colors.transparent),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const GastosApp(),
    ),
  );
}

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('es');

  CurrencyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final number = int.parse(digits);
    final formatted = _formatter.format(number);
    final text = '\$$formatted';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class GastosApp extends StatelessWidget {
  const GastosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Gastos',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      home: const HomePage(),
    );
  }
}

class Gasto {
  final String descripcion;
  final double monto;
  final DateTime fecha;

  Gasto({required this.descripcion, required this.monto, required this.fecha});

  Map<String, dynamic> toJson() => {
    'descripcion': descripcion,
    'monto': monto,
    'fecha': fecha.toIso8601String(),
  };

  factory Gasto.fromJson(Map<String, dynamic> json) => Gasto(
    descripcion: json['descripcion'],
    monto: (json['monto'] as num).toDouble(),
    fecha: DateTime.parse(json['fecha']),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _salarioController = TextEditingController();

  double? _salarioTotal;
  final List<Gasto> _gastos = [];
  final NumberFormat _formatoMoneda = NumberFormat.currency(
    locale: 'es',
    symbol: '\$',
    decimalDigits: 0,
  );
  bool _datosCargados = false;
  DateTime _mesSeleccionado = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  double get _gastosAcumulados {
    return _gastosFiltrados.fold(0.0, (suma, gasto) => suma + gasto.monto);
  }

  double get _restante {
    return _salarioTotal != null ? _salarioTotal! - _gastosAcumulados : 0;
  }

  List<Gasto> get _gastosFiltrados {
    var filtered = _gastos
        .where(
          (gasto) =>
              gasto.fecha.month == _mesSeleccionado.month &&
              gasto.fecha.year == _mesSeleccionado.year,
        )
        .toList();
    filtered.sort((a, b) => a.fecha.compareTo(b.fecha));
    return filtered;
  }

  void _establecerSalario() {
    final raw = _salarioController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isNotEmpty) {
      setState(() {
        _salarioTotal = double.parse(raw);
        _salarioController.text = _formatoMoneda.format(_salarioTotal);
      });
      _guardarDatos();
    }
  }

  void _mostrarDialogoAgregarGasto() {
    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Agregar Gasto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(hintText: 'Descripción'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(hintText: '\$1.000'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Seleccionar'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (descripcionController.text.isNotEmpty &&
                      montoController.text.isNotEmpty) {
                    this.setState(() {
                      final rawMonto = montoController.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      _gastos.add(
                        Gasto(
                          descripcion: descripcionController.text,
                          monto: rawMonto.isNotEmpty
                              ? double.parse(rawMonto)
                              : 0,
                          fecha: selectedDate,
                        ),
                      );
                    });
                    _guardarDatos();
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Agregar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _eliminarGasto(int indice) {
    setState(() {
      _gastos.removeAt(indice);
    });
    _guardarDatos();
  }

  Future<void> _cargarDatos() async {
    if (_datosCargados) return;
    final prefs = await SharedPreferences.getInstance();
    final salarioGuardado = prefs.getDouble('salario');
    final gastosJson = prefs.getString('gastos');
    if (salarioGuardado != null) {
      _salarioTotal = salarioGuardado;
      _salarioController.text = salarioGuardado.toString();
    }
    if (gastosJson != null) {
      final List<dynamic> gastosList = jsonDecode(gastosJson);
      _gastos.clear();
      _gastos.addAll(gastosList.map((g) => Gasto.fromJson(g)));
    }
    _datosCargados = true;
  }

  Future<void> _guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    if (_salarioTotal != null) {
      await prefs.setDouble('salario', _salarioTotal!);
    }
    final gastosJson = jsonEncode(_gastos.map((g) => g.toJson()).toList());
    await prefs.setString('gastos', gastosJson);
  }

  Future<void> _descargarTabla() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Gastos'];

    // Title
    sheetObject.appendRow([TextCellValue('Control de Gastos')]);
    sheetObject.appendRow([
      TextCellValue('Salario Total:'),
      TextCellValue(_formatoMoneda.format(_salarioTotal)),
    ]);
    sheetObject.appendRow([TextCellValue('')]); // Empty row

    // Headers
    sheetObject.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Descripción'),
      TextCellValue('Monto'),
      TextCellValue('Acumulado'),
      TextCellValue('Restante'),
    ]);

    // Data
    double acumulado = 0;
    for (final gasto in _gastosFiltrados) {
      acumulado += gasto.monto;
      sheetObject.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(gasto.fecha)),
        TextCellValue(gasto.descripcion),
        TextCellValue(_formatoMoneda.format(gasto.monto)),
        TextCellValue(_formatoMoneda.format(acumulado)),
        TextCellValue(_formatoMoneda.format(_salarioTotal! - acumulado)),
      ]);
    }

    sheetObject.appendRow([TextCellValue('')]); // Empty row

    // Totals
    sheetObject.appendRow([
      TextCellValue('Gastos Totales:'),
      TextCellValue(_formatoMoneda.format(_gastosAcumulados)),
    ]);
    sheetObject.appendRow([
      TextCellValue('Restante:'),
      TextCellValue(_formatoMoneda.format(_restante)),
    ]);

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/gastos_$timestamp.xlsx');
    await file.writeAsBytes(excel.encode()!);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Archivo guardado'),
          content: Text('El archivo Excel se guardó en: ${file.path}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet),
              SizedBox(width: 8),
              Text('Gastos'),
            ],
          ),
          centerTitle: true,
          actions: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode
                        : Icons.dark_mode,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: _salarioTotal != null ? _descargarTabla : null,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Text(
                      'Mes:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _mesSeleccionado.month,
                      items: List.generate(12, (index) {
                        final month = index + 1;
                        return DropdownMenuItem(
                          value: month,
                          child: Text(
                            DateFormat(
                              'MMMM',
                              'es',
                            ).format(DateTime(2023, month)),
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _mesSeleccionado = DateTime(
                              _mesSeleccionado.year,
                              value,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _mesSeleccionado.year,
                      items: List.generate(5, (index) {
                        final year = DateTime.now().year - 2 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _mesSeleccionado = DateTime(
                              value,
                              _mesSeleccionado.month,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Saldo:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatoMoneda.format(_salarioTotal ?? 0),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              color: _salarioTotal == null
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withAlpha(153)
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      if (_salarioTotal != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Gastado: ${_formatoMoneda.format(_gastosAcumulados)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(153),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Restante: ${_formatoMoneda.format(_restante)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _restante < 0
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _salarioController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: InputDecoration(
                          hintText: _salarioTotal == null
                              ? 'Ingresa tu saldo'
                              : _formatoMoneda.format(_salarioTotal!),
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                        onSubmitted: (_) => _establecerSalario(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _establecerSalario,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _salarioTotal == null ? 'Guardar' : 'Editar',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _salarioTotal == null
                    ? Center(
                        child: Text(
                          'Ingresa tu saldo para comenzar',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                      )
                    : _gastos.isEmpty
                    ? Center(
                        child: Text(
                          'Sin gastos registrados',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _gastosFiltrados.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          double acumulado = 0;
                          for (int i = 0; i <= index; i++) {
                            acumulado += _gastosFiltrados[i].monto;
                          }
                          final restante = _salarioTotal! - acumulado;
                          return ListTile(
                            title: Text(_gastosFiltrados[index].descripcion),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(_gastosFiltrados[index].fecha),
                                ),
                                Text(
                                  'Restante: ${_formatoMoneda.format(restante)}',
                                  style: TextStyle(
                                    color: restante < 0 ? Colors.red : null,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatoMoneda.format(
                                    _gastosFiltrados[index].monto,
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => _eliminarGasto(
                                    _gastos.indexOf(_gastosFiltrados[index]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: _salarioTotal != null
            ? FloatingActionButton(
                onPressed: _mostrarDialogoAgregarGasto,
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _salarioController.dispose();
    super.dispose();
  }
}
