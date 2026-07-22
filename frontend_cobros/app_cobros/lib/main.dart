import 'package:flutter/material.dart';
import 'colors.dart';
import 'app_styles.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'cierre_dia_service.dart';

String formatearDinero(dynamic valor) {
  if (valor == null) return '\$0';
  double cantidad = (valor is num) ? valor.toDouble() : double.tryParse(valor.toString()) ?? 0;
  bool negativo = cantidad < 0;
  if (negativo) cantidad = cantidad.abs();
  List<String> parts = cantidad.toStringAsFixed(0).split('');
  StringBuffer buf = StringBuffer();
  int cnt = 0;
  for (int i = parts.length - 1; i >= 0; i--) {
    if (cnt > 0 && cnt % 3 == 0) buf.write('.');
    buf.write(parts[i]);
    cnt++;
  }
  return '${negativo ? '-' : ''}\$${buf.toString().split('').reversed.join()}';
}

String _formatWithDots(String digits) {
  StringBuffer buf = StringBuffer();
  int cnt = 0;
  for (int i = digits.length - 1; i >= 0; i--) {
    if (cnt > 0 && cnt % 3 == 0) buf.write('.');
    buf.write(digits[i]);
    cnt++;
  }
  return buf.toString().split('').reversed.join();
}

void _onMontoChanged(TextEditingController ctrl) {
  String digits = ctrl.text.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) {
    if (ctrl.text.isNotEmpty) ctrl.text = '';
    return;
  }
  String formatted = _formatWithDots(digits);
  if (formatted != ctrl.text) {
    ctrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

double parseMonto(String text) {
  return double.tryParse(text.replaceAll('.', '')) ?? 0;
}

void main() => runApp(
  MaterialApp(
    home: LoginScreen(),
    theme: ThemeData(
      primarySwatch: Colors.blue,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  ),
);

// ============= SESIÓN GLOBAL =============
class SessionGlobal {
  static int? usuarioId;
  static String? nombreUsuario;
  static String? rol;
}

String obtenerTextoVistaClientes(bool esAdmin, String diaSeleccionado) {
  if (esAdmin) {
    return 'Vista general de todos los días';
  }
  final dia = diaSeleccionado[0].toUpperCase() + diaSeleccionado.substring(1);
  return 'Clientes del día $dia';
}

Future<bool> verificarBloqueo(BuildContext context, {String? mensaje}) async {
  final bloqueado = await CierreDiaService.isBlockedNow();
  if (bloqueado) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensaje ?? 'El cierre del día está activo hasta las 23:59.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return true;
  }
  return false;
}

// ============= PANTALLA DE LOGIN =============
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://proyecto-cobros.onrender.com/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        SessionGlobal.usuarioId = data['usuario_id'];
        SessionGlobal.nombreUsuario = data['nombre'];
        SessionGlobal.rol = data['rol'];

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MenuPrincipal()),
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error en login')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login - Sistema de Cobros"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.security, size: 100, color: Colors.blue),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Ingresar", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroUsuarioScreen(),
                    ),
                  );
                },
                child: const Text("¿No tienes cuenta? Regístrate"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= PANTALLA DE REGISTRO DE USUARIO =============
class RegistroUsuarioScreen extends StatefulWidget {
  const RegistroUsuarioScreen({super.key});

  @override
  _RegistroUsuarioScreenState createState() => _RegistroUsuarioScreenState();
}

class _RegistroUsuarioScreenState extends State<RegistroUsuarioScreen> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registro() async {
    if (_nombreController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }
    if (_passwordController.text.length > 72) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña no puede tener más de 72 caracteres."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://proyecto-cobros.onrender.com/api/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': _nombreController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'rol': 'administrador',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Administrador registrado exitosamente"),
          ),
        );
        Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error en registro')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Administrador")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                "Registro de Administrador",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registro,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Registrar Administrador"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= MENÚ PRINCIPAL =============
class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  _MenuPrincipalState createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  String _diaSeleccionado = 'lunes';
  List<dynamic> _clientes = [];
  List<dynamic> _alertasCuotas = [];
  bool _cargandoClientes = false;
  bool _cargandoAlertas = false;
  final Map<int, TextEditingController> _controladoresPorcentaje = {};

  // Search
  final _busquedaController = TextEditingController();
  List<dynamic> _sugerencias = [];
  bool _buscando = false;
  Timer? _debounce;

  // Filters (admin)
  String? _filtroDia;
  String? _filtroFrecuencia;

  final List<String> _diasSemana = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  bool get _esAdmin => SessionGlobal.rol == 'administrador';

  @override
  void initState() {
    super.initState();
    _cargarClientesPorDia();
    if (_esAdmin) {
      _cargarAlertasCuotasVencidas();
    }
    _busquedaController.addListener(_onSearchChanged);
    _verificarSesionPeriodicamente();
  }

  Timer? _checkTimer;

  void _verificarSesionPeriodicamente() {
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (mounted) await verificarCuentaActiva(context);
    });
  }

  @override
  void dispose() {
    _busquedaController.removeListener(_onSearchChanged);
    _busquedaController.dispose();
    _debounce?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarClientesPorDia() async {
    if (!mounted) return;
    setState(() => _cargandoClientes = true);
    try {
      final uid = SessionGlobal.usuarioId;
      String url;
      if (_esAdmin) {
        url =
            'https://proyecto-cobros.onrender.com/api/admin/listar-clientes?admin_id=$uid';
        if (_filtroDia != null) {
          url += '&dia=$_filtroDia';
        }
        if (_filtroFrecuencia != null && _filtroFrecuencia!.isNotEmpty) {
          url += '&frecuencia=$_filtroFrecuencia';
        }
      } else {
        url =
            'https://proyecto-cobros.onrender.com/api/clientes/dia/$_diaSeleccionado?usuario_id=$uid';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _clientes = jsonDecode(response.body);
        });
      } else if (mounted) {
        setState(() {
          _clientes = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _clientes = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoClientes = false);
      }
    }
  }

  Future<void> _cargarAlertasCuotasVencidas() async {
    if (!mounted) return;
    setState(() => _cargandoAlertas = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/alertas-cuotas-vencidas?admin_id=${SessionGlobal.usuarioId}',
        ),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _alertasCuotas = jsonDecode(response.body);
        });
      } else if (mounted) {
        setState(() {
          _alertasCuotas = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alertasCuotas = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoAlertas = false);
      }
    }
  }

  Future<void> _gestionarCuotaVencida(
    int cuotaId,
    String accion, {
    double? nuevoPorcentaje,
    String? frecuencia,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/gestionar-cuota-vencida?admin_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cuota_id': cuotaId,
          'accion': accion,
          if (nuevoPorcentaje != null) 'nuevo_porcentaje': nuevoPorcentaje,
          if (frecuencia != null) 'frecuencia': frecuencia,
        }),
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acción aplicada correctamente')),
        );
        await _cargarAlertasCuotasVencidas();
      } else if (mounted) {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'No se pudo procesar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la cuota: $e')),
        );
      }
    }
  }

  Future<void> _mostrarDialogoRodarCuota(int cuotaId) async {
    String frecuencia = 'semanal';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rodar cuota'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Por cuánto tiempo se rodará la cuota?'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: frecuencia,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'semanal', child: Text('Semanal (7 días)')),
                  DropdownMenuItem(value: 'quincenal', child: Text('Quincenal (15 días)')),
                  DropdownMenuItem(value: 'mensual', child: Text('Mensual (30 días)')),
                ],
                onChanged: (value) => setDialogState(() => frecuencia = value ?? 'semanal'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _gestionarCuotaVencida(
                  cuotaId,
                  'rodar_cuota',
                  frecuencia: frecuencia,
                );
              },
              child: const Text('Rodar'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== SEARCH & CLIENT INFO =====
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _buscarSugerencias();
    });
  }

  Future<void> _buscarSugerencias() async {
    final texto = _busquedaController.text.trim();
    if (texto.isEmpty) {
      if (mounted) setState(() => _sugerencias = []);
      return;
    }

    setState(() => _buscando = true);
    try {
      final uid = SessionGlobal.usuarioId;
      final esNumero = RegExp(r'^\d+$').hasMatch(texto);
      final url = esNumero
          ? 'https://proyecto-cobros.onrender.com/api/clientes/buscar?cedula=$texto&usuario_id=$uid'
          : 'https://proyecto-cobros.onrender.com/api/clientes/buscar?nombre=$texto&usuario_id=$uid';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() => _sugerencias = jsonDecode(response.body) as List);
      } else if (mounted) {
        setState(() => _sugerencias = []);
      }
    } catch (e) {
      if (mounted) setState(() => _sugerencias = []);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  List<Widget> _buildUltimasCuotasAtrasadas(List historial, dynamic cliente, BuildContext ctx) {
    List<Widget> widgets = [];
    for (var p in historial) {
      if (p['pagado'] == true) continue;
      var cuotas = (p['cuotas'] as List).where((c) => c['pagada'] != true).toList();
      if (cuotas.isEmpty) continue;
      var ultima = cuotas.reduce((a, b) => (a['numero'] ?? 0) > (b['numero'] ?? 0) ? a : b);
      if (ultima['atrasada'] != true) continue;
      widgets.add(const Divider());
      widgets.add(Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Última cuota vencida', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            Text('Cuota #${ultima['numero']} - ${formatearDinero(ultima['valor'])}'),
            Text('Vence: ${ultima['vencimiento']}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _gestionarCuotaDesdeDialog(ultima['id'], 'aplazar', null, cliente);
                      },
                      icon: const Icon(Icons.date_range, size: 14),
                      label: const Text('Aplazar', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mostrarDialogoAplazarConInteres(ultima['id'], cliente);
                      },
                      icon: const Icon(Icons.percent, size: 14),
                      label: const Text('+ Interés', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ));
    }
    return widgets;
  }

  Future<void> _gestionarCuotaDesdeDialog(int cuotaId, String accion, double? porcentaje, dynamic cliente) async {
    try {
      String url = 'https://proyecto-cobros.onrender.com/api/cobros/gestionar-cuota?cuota_id=$cuotaId&accion=$accion&usuario_id=${SessionGlobal.usuarioId}';
      if (porcentaje != null) url += '&nuevo_porcentaje=$porcentaje';
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['mensaje'] ?? 'Cuota gestionada'), backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al gestionar cuota')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _mostrarDialogoAplazarConInteres(int cuotaId, dynamic cliente) async {
    final porcentajeController = TextEditingController(text: '20');
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplazar con interés'),
        content: TextField(
          controller: porcentajeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Porcentaje de interés', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (aplicar == true) {
      final pct = double.tryParse(porcentajeController.text.trim());
      if (pct == null || pct <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un porcentaje válido')));
        return;
      }
      await _gestionarCuotaDesdeDialog(cuotaId, 'aplazar_con_interes', pct, cliente);
    }
  }

  Future<void> _mostrarInfoCliente(dynamic cliente) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/reportes/cliente/${cliente['id']}',
        ),
      );
      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body);
      final historial = data['historial_prestamos'] as List;
      final cuotasPendientes = historial.expand((p) => (p['cuotas'] as List)
          .where((c) => !(c['pagada'] ?? false))).toList();

      // Count remaining periods grouped by frequency
      String infoPeriodos = '';
      for (var p in historial) {
        if (!(p['pagado'] ?? false)) {
          final freq = p['frecuencia'] ?? 'semanal';
          final cuotas = (p['cuotas'] as List).where(
            (c) => !(c['pagada'] ?? false)
          ).length;
          if (cuotas > 0) {
            infoPeriodos += '• ${cuotas} ${freq}(es) restantes\n';
          }
        }
      }

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(cliente['nombres'] ?? ''),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cédula: ${cliente['cedula'] ?? ''}'),
              Text('Tel: ${cliente['telefono'] ?? ''}'),
              Text('Día de cobro: ${cliente['dia_cobro'] ?? ''}'),
              const Divider(),
              Text(
                'Deuda Total: ${formatearDinero(data['resumen']['deuda_total'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              Text('Préstamos activos: ${data['resumen']['total_prestamos'] - data['resumen']['prestamos_completos']}'),
              if (infoPeriodos.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Periodos restantes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(infoPeriodos),
              ],
              if (cuotasPendientes.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Próxima cuota:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Cuota #${cuotasPendientes[0]['numero']} - ${formatearDinero(cuotasPendientes[0]['valor'])}'),
                Text('Vence: ${cuotasPendientes[0]['vencimiento']}'),
              ],
              // Últimas cuotas atrasadas de cada préstamo
              ..._buildUltimasCuotasAtrasadas(historial, cliente, ctx),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegistroCobrosScreen(clienteId: cliente['id'], clienteNombre: cliente['nombres']),
                  ),
                );
              },
              child: const Text('Registrar Cobro'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildAlertasCuotasSection() {
    if (!_esAdmin) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alertas de cuotas vencidas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_cargandoAlertas)
              const Center(child: CircularProgressIndicator())
            else if (_alertasCuotas.isEmpty)
              const Text('No hay cuotas vencidas por revisar')
            else
              ..._alertasCuotas.map((alerta) {
                final controller = _controladoresPorcentaje.putIfAbsent(
                  alerta['cuota_id'],
                  () => TextEditingController(text: '20'),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alerta['cliente_nombre']} • Cuota ${alerta['numero_cuota']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vencida hace ${alerta['dias_atrasados']} días • Pendiente: ${formatearDinero(alerta['pendiente'])}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Porcentaje',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _mostrarDialogoRodarCuota(alerta['cuota_id']),
                              icon: const Icon(Icons.date_range),
                              label: const Text('Rodar cuota'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _gestionarCuotaVencida(
                                alerta['cuota_id'],
                                'aplicar_interes',
                                nuevoPorcentaje: double.tryParse(
                                  controller.text,
                                ),
                              ),
                              icon: const Icon(Icons.percent),
                              label: const Text('Aplicar interés'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bienvenido, " + (SessionGlobal.nombreUsuario ?? '')),
        backgroundColor: Colors.blueAccent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              SessionGlobal.usuarioId = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    SessionGlobal.nombreUsuario != null
                        ? 'Usuario: ${SessionGlobal.nombreUsuario}'
                        : 'Usuario',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Rol: ${SessionGlobal.rol}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            // MENÚ SOLO PARA ADMINISTRADOR
            if (SessionGlobal.rol == 'administrador') ...[
              ListTile(
                leading: const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.purple,
                ),
                title: const Text('Registrar Trabajador'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroTrabajadorScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.manage_accounts,
                  color: Colors.blueGrey,
                ),
                title: const Text('Administrar Trabajadores'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GestionTrabajadoresScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.orange),
                title: const Text('Asignar Días'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AsignarDiasScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.green),
                title: const Text('Registrar Cliente'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroClienteScreen(),
                    ),
                  ).then((_) => _cargarClientesPorDia());
                },
              ),
              ListTile(
                leading: const Icon(Icons.group, color: Colors.teal),
                title: const Text('Administrar Clientes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GestionClientesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.book, color: Colors.brown),
                title: const Text('Cliente Anterior (Libro)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroClienteAnteriorScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.blue),
                title: const Text('Registrar Cobro'),
                onTap: () async {
                  Navigator.pop(context);
                  if (await verificarBloqueo(context)) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroCobrosScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_card, color: Colors.orange),
                title: const Text('Nuevo Préstamo'),
                onTap: () async {
                  Navigator.pop(context);
                  if (await verificarBloqueo(context)) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NuevoPrestamoScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
            ],
            // MENÚ PARA TRABAJADOR
            if (SessionGlobal.rol == 'trabajador') ...[
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.blue),
                title: const Text('Registrar Cobro'),
                onTap: () async {
                  Navigator.pop(context);
                  if (await verificarBloqueo(context)) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroCobrosScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_card, color: Colors.orange),
                title: const Text('Nuevo Préstamo'),
                onTap: () async {
                  Navigator.pop(context);
                  if (await verificarBloqueo(context)) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NuevoPrestamoScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.purple),
                title: const Text('Buscar Cliente'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BuscarClienteScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
            ],
            // MENÚ PARA DESARROLLADOR
            if (SessionGlobal.rol == 'desarrollador') ...[
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                title: const Text('Panel Desarrollador'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DesarrolladorScreen()),
                  );
                },
              ),
              const Divider(),
            ],
            // OPCIONES COMUNES
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.teal),
              title: const Text('Resumen del Día'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ResumenDiaScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente (nombre o cédula)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          // Suggestions
          if (_sugerencias.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sugerencias.length,
                itemBuilder: (context, i) {
                  final c = _sugerencias[i];
                  return ListTile(
                    dense: true,
                    title: Text(c['nombres'] ?? ''),
                    subtitle: Text('${c['cedula']} | ${c['dia_cobro'] ?? ''}'),
                    onTap: () {
                      setState(() {
                        _busquedaController.clear();
                        _sugerencias = [];
                      });
                      _mostrarInfoCliente(c);
                    },
                  );
                },
              ),
            ),
          // Filters
          if (_esAdmin) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _filtroDia,
                      decoration: const InputDecoration(
                        labelText: 'Día',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        ..._diasSemana.map((dia) => DropdownMenuItem(
                          value: dia,
                          child: Text(dia[0].toUpperCase() + dia.substring(1)),
                        )),
                      ],
                      onChanged: (v) {
                        setState(() => _filtroDia = v);
                        _cargarClientesPorDia();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _filtroFrecuencia,
                      decoration: const InputDecoration(
                        labelText: 'Frecuencia',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Todas')),
                        DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                        DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                        DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                      ],
                      onChanged: (v) {
                        setState(() => _filtroFrecuencia = v);
                        _cargarClientesPorDia();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Worker day selector
          if (!_esAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonFormField<String>(
                value: _diaSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Día',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: _diasSemana.map((dia) => DropdownMenuItem(
                  value: dia,
                  child: Text(dia[0].toUpperCase() + dia.substring(1)),
                )).toList(),
                onChanged: (v) {
                  setState(() => _diaSeleccionado = v ?? 'lunes');
                  _cargarClientesPorDia();
                },
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _cargandoClientes
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (!_esAdmin && _clientes.isEmpty)
                        const Center(
                          child: Text('No hay clientes para este día'),
                        )
                      else if (_esAdmin && _clientes.isEmpty)
                        const Center(child: Text('No hay clientes registrados'))
                      else
                        ..._clientes.map((cliente) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(cliente['nombres'] ?? ''),
                              subtitle: Text(
                                'Cédula: ${cliente['cedula']} | Tel: ${cliente['telefono']} | Día: ${cliente['dia_cobro'] ?? _diaSeleccionado}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _mostrarInfoCliente(cliente),
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 12),
                      _buildAlertasCuotasSection(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ============= REGISTRO DE TRABAJADOR (SOLO ADMIN) =============
class RegistroTrabajadorScreen extends StatefulWidget {
  const RegistroTrabajadorScreen({super.key});

  @override
  _RegistroTrabajadorScreenState createState() =>
      _RegistroTrabajadorScreenState();
}

class _RegistroTrabajadorScreenState extends State<RegistroTrabajadorScreen> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registrarTrabajador() async {
    if (_nombreController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    if (_passwordController.text.length > 72) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña no puede tener más de 72 caracteres."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/registrar-trabajador?admin_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': _nombreController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'rol': 'trabajador',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['mensaje'] ?? 'Trabajador registrado')),
        );
        _nombreController.clear();
        _emailController.clear();
        _passwordController.clear();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error en registro')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Trabajador"),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(
                Icons.person_add_alt_1,
                size: 80,
                color: Colors.purple,
              ),
              const SizedBox(height: 20),
              const Text(
                "Registrar Nuevo Trabajador",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrarTrabajador,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Registrar Trabajador"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= ASIGNAR DÍAS A TRABAJADORES =============
class AsignarDiasScreen extends StatefulWidget {
  const AsignarDiasScreen({super.key});

  @override
  _AsignarDiasScreenState createState() => _AsignarDiasScreenState();
}

class _AsignarDiasScreenState extends State<AsignarDiasScreen> {
  List<dynamic> _trabajadores = [];
  List<dynamic> _asignaciones = [];
  int? _trabajadorSeleccionado;
  String _diaSeleccionado = 'lunes';
  bool _cargando = false;

  final List<String> _diasSemana = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final resTrabajadores = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/listar-trabajadores?admin_id=${SessionGlobal.usuarioId}',
        ),
      );
      final resAsignaciones = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/listar-asignaciones?admin_id=${SessionGlobal.usuarioId}',
        ),
      );

      if (resTrabajadores.statusCode == 200 &&
          resAsignaciones.statusCode == 200) {
        setState(() {
          _trabajadores = jsonDecode(resTrabajadores.body);
          _asignaciones = jsonDecode(resAsignaciones.body);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cargar datos: $e")));
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _asignarDia() async {
    if (_trabajadorSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Seleccione un trabajador")));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/asignar-trabajador-dia?admin_id=${SessionGlobal.usuarioId}&trabajador_id=$_trabajadorSeleccionado&dia=$_diaSeleccionado',
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Día asignado correctamente")),
        );
        _cargarDatos();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error al asignar día')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _desasignar(int asignacionId) async {
    try {
      final asignacion = _asignaciones.firstWhere(
        (a) => a['id'] == asignacionId,
      );
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/desasignar-trabajador-dia?admin_id=${SessionGlobal.usuarioId}&trabajador_id=${asignacion['trabajador_id']}&dia=${asignacion['dia']}',
        ),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Asignación eliminada")));
        _cargarDatos();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error al desasignar')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Asignar Días"),
        backgroundColor: Colors.orange,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asignar día a trabajador',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Trabajador',
                        border: OutlineInputBorder(),
                      ),
                      items: _trabajadores
                          .map<DropdownMenuItem<int>>(
                            (t) => DropdownMenuItem<int>(
                              value: t['id'],
                              child: Text(t['nombre']),
                            ),
                          )
                          .toList(),
                      value: _trabajadorSeleccionado,
                      onChanged: (value) =>
                          setState(() => _trabajadorSeleccionado = value),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Día',
                        border: OutlineInputBorder(),
                      ),
                      items: _diasSemana
                          .map(
                            (dia) => DropdownMenuItem<String>(
                              value: dia,
                              child: Text(
                                dia[0].toUpperCase() + dia.substring(1),
                              ),
                            ),
                          )
                          .toList(),
                      value: _diaSeleccionado,
                      onChanged: (value) =>
                          setState(() => _diaSeleccionado = value ?? 'lunes'),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _asignarDia,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Asignar Día'),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'Asignaciones actuales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _asignaciones.isEmpty
                        ? const Text('No hay asignaciones')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _asignaciones.length,
                            itemBuilder: (context, idx) {
                              final asignacion = _asignaciones[idx];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    '${asignacion['trabajador_nombre']}',
                                  ),
                                  subtitle: Text('Día: ${asignacion['dia']}'),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _desasignar(asignacion['id']),
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ============= ADMINISTRAR TRABAJADORES =============
class GestionTrabajadoresScreen extends StatefulWidget {
  const GestionTrabajadoresScreen({super.key});

  @override
  _GestionTrabajadoresScreenState createState() =>
      _GestionTrabajadoresScreenState();
}

class _GestionTrabajadoresScreenState extends State<GestionTrabajadoresScreen> {
  List<dynamic> _trabajadores = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarTrabajadores();
  }

  Future<void> _cargarTrabajadores() async {
    setState(() => _cargando = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/listar-trabajadores?admin_id=${SessionGlobal.usuarioId}',
        ),
      );
      if (response.statusCode == 200) {
        setState(() => _trabajadores = jsonDecode(response.body));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarTrabajador(int id) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/eliminar-trabajador?admin_id=${SessionGlobal.usuarioId}&trabajador_id=$id',
        ),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trabajador desactivado')));
        _cargarTrabajadores();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? 'Error al eliminar trabajador'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editarTrabajadorDialog(Map<String, dynamic> trabajador) async {
    final nombreController = TextEditingController(text: trabajador['nombre']);
    final emailController = TextEditingController(text: trabajador['email']);
    bool activo = trabajador['activo'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Trabajador'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('Activo'),
                  value: activo,
                  onChanged: (value) => setDialogState(() => activo = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _editarTrabajador(
                  trabajador['id'],
                  nombreController.text,
                  emailController.text,
                  activo,
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarTrabajador(
    int id,
    String nombre,
    String email,
    bool activo,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/editar-trabajador?admin_id=${SessionGlobal.usuarioId}&trabajador_id=$id',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombres': nombre, 'email': email, 'activo': activo}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trabajador actualizado')));
        _cargarTrabajadores();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? 'Error al editar trabajador'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Trabajadores'),
        backgroundColor: Colors.blueGrey,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _trabajadores.length,
              itemBuilder: (context, index) {
                final trabajador = _trabajadores[index];
                return Card(
                  child: ListTile(
                    title: Text(trabajador['nombre'] ?? ''),
                    subtitle: Text('Email: ${trabajador['email'] ?? ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green),
                          onPressed: () => _editarTrabajadorDialog(trabajador),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _eliminarTrabajador(trabajador['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============= ADMINISTRAR CLIENTES =============
class GestionClientesScreen extends StatefulWidget {
  const GestionClientesScreen({super.key});

  @override
  _GestionClientesScreenState createState() => _GestionClientesScreenState();
}

class _GestionClientesScreenState extends State<GestionClientesScreen> {
  List<dynamic> _clientes = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    setState(() => _cargando = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/listar-clientes?admin_id=${SessionGlobal.usuarioId}',
        ),
      );
      if (response.statusCode == 200) {
        setState(() => _clientes = jsonDecode(response.body));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarCliente(int id) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/eliminar-cliente?admin_id=${SessionGlobal.usuarioId}&cliente_id=$id',
        ),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cliente eliminado permanentemente')));
        _cargarClientes();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? 'Error al eliminar cliente'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _mostrarDetallesClienteAdmin(
    Map<String, dynamic> cliente,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/reportes/cliente/${cliente['id']}',
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('No se pudo cargar el reporte');
      }

      final data = jsonDecode(response.body);
      final historial = data['historial_prestamos'] as List;

      if (!mounted) return;

      // Collect all pagos from all prestamos
      List<Map<String, dynamic>> todosLosPagos = [];
      for (var prestamo in historial) {
        final pagos = prestamo['pagos'] as List? ?? [];
        for (var p in pagos) {
          todosLosPagos.add({
            ...p,
            'prestamo_id': prestamo['prestamo_id'],
            'monto_prestado': prestamo['monto_prestado'],
          });
        }
      }
      todosLosPagos.sort(
        (a, b) => (b['fecha_pago'] ?? '').toString().compareTo(
          (a['fecha_pago'] ?? '').toString(),
        ),
      );

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(cliente['nombres'] ?? 'Cliente'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deuda total: ${formatearDinero(data['resumen']['deuda_total'])}'),
                Text('Préstamos totales: ${data['resumen']['total_prestamos']}'),
                Text('Préstamos completos: ${data['resumen']['prestamos_completos']}'),
                Text('Préstamos atrasados: ${data['resumen']['prestamos_atrasados']}'),
                const Divider(height: 20),
                const Text(
                  'Historial de Pagos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (todosLosPagos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No hay pagos registrados'),
                  )
                else
                  ...todosLosPagos.map((p) {
                    String estado = 'Pagada';
                    int? numeroCuota;
                    for (var prestamo in historial) {
                      for (var c in (prestamo['cuotas'] as List)) {
                        if (c['id'] == p['cuota_id']) {
                          numeroCuota = c['numero'];
                          if (c['pagada'] == true && (c['valor_pagado'] ?? 0) < (c['valor'] ?? 0)) {
                            estado = 'Pagada parcialmente';
                          }
                          break;
                        }
                      }
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuota #${numeroCuota ?? p['cuota_id']} - $estado',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Monto: ${formatearDinero(p['cantidad_pagada'])}'),
                            Text('Fecha: ${p['fecha_pago']}'),
                          ],
                        ),
                      ),
                    );
                  }),
                const Divider(height: 20),
                const Text(
                  'Cuotas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                ...historial.expand((prestamo) {
                  final cuotas = prestamo['cuotas'] as List;
                  return cuotas.map<Widget>((cuota) {
                    final pagada = cuota['pagada'] ?? false;
                    final vencimiento = DateTime.tryParse(
                      cuota['vencimiento'].toString(),
                    );
                    final atrasada =
                        vencimiento != null &&
                        !vencimiento.isAfter(DateTime.now()) &&
                        !pagada;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Cuota #${cuota['numero']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: pagada
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: pagada ? Colors.grey : null,
                                  ),
                                ),
                                if (pagada)
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20)
                                else if (atrasada)
                                  const Icon(Icons.warning,
                                      color: Colors.red, size: 20),
                              ],
                            ),
                            Text('Valor: ${formatearDinero(cuota['valor'])}'),
                            Text('Vence: ${cuota['vencimiento']}'),
                            Text(
                              pagada
                                  ? 'Pagado: ${formatearDinero(cuota['valor_pagado'])}'
                                  : 'Pendiente: ${formatearDinero(cuota['pendiente'])}',
                            ),
                            if (atrasada)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final montoController =
                                        TextEditingController();
                                    final aplicar = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Aumentar interés de mora',
                                        ),
                                        content: TextField(
                                          controller: montoController,
                                          keyboardType:
                                              TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Monto de interés',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              false,
                                            ),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              true,
                                            ),
                                            child: const Text('Aplicar'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (aplicar == true) {
                                      final monto = double.tryParse(
                                        montoController.text.trim(),
                                      );
                                      if (monto == null || monto <= 0) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Ingrese un monto válido',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      await _aplicarInteresCuota(
                                        cuota['id'],
                                        monto,
                                      );
                                      Navigator.pop(context);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.warning_amber_rounded,
                                  ),
                                  label: const Text('Aumentar interés'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList();
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _aplicarInteresCuota(int cuotaId, double monto) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/agregar-interes-mora?admin_id=${SessionGlobal.usuarioId}&cuota_id=$cuotaId&monto_interes=$monto',
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interés agregado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['detail'] ?? 'No se pudo aplicar el interés'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _editarClienteDialog(Map<String, dynamic> cliente) async {
    final nombresController = TextEditingController(text: cliente['nombres']);
    final telefonoController = TextEditingController(text: cliente['telefono']);
    String diaCobro = cliente['dia_cobro'] ?? 'lunes';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Cliente'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nombresController,
                decoration: const InputDecoration(labelText: 'Nombres'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: diaCobro,
                decoration: const InputDecoration(labelText: 'Día de cobro'),
                items:
                    [
                          'lunes',
                          'martes',
                          'miércoles',
                          'jueves',
                          'viernes',
                          'sábado',
                          'domingo',
                        ]
                        .map(
                          (dia) => DropdownMenuItem(
                            value: dia,
                            child: Text(
                              dia[0].toUpperCase() + dia.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => diaCobro = value ?? 'lunes',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _editarCliente(
                cliente['id'],
                nombresController.text,
                telefonoController.text,
                diaCobro,
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarCliente(
    int id,
    String nombres,
    String telefono,
    String diaCobro,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/editar-cliente?admin_id=${SessionGlobal.usuarioId}&cliente_id=$id',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': nombres,
          'telefono': telefono,
          'dia_cobro': diaCobro,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cliente actualizado')));
        _cargarClientes();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error al editar cliente')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Clientes'),
        backgroundColor: Colors.teal,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _clientes.length,
              itemBuilder: (context, index) {
                final cliente = _clientes[index];
                return Card(
                  child: ListTile(
                    title: Text(cliente['nombres'] ?? ''),
                    subtitle: Text(
                      'Día: ${cliente['dia_cobro'] ?? ''} | Tel: ${cliente['telefono'] ?? ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.receipt_long,
                            color: Colors.orange,
                          ),
                          onPressed: () =>
                              _mostrarDetallesClienteAdmin(cliente),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green),
                          onPressed: () => _editarClienteDialog(cliente),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarCliente(cliente['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.titulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.blue),
            const SizedBox(height: 10),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= REGISTRO DE CLIENTE =============
class RegistroClienteScreen extends StatefulWidget {
  const RegistroClienteScreen({super.key});

  @override
  _RegistroClienteScreenState createState() => _RegistroClienteScreenState();
}

class _RegistroClienteScreenState extends State<RegistroClienteScreen> {
  final _nombresController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _montoController = TextEditingController();
  final _cuotasController = TextEditingController();
  String _diaCobro = 'lunes';
  String _frecuencia = 'mensual';
  double _interes = 20.0;
  bool _isLoading = false;
  bool _bloqueado = false;

  @override
  void initState() {
    super.initState();
    _verificarBloqueo();
  }

  Future<void> _verificarBloqueo() async {
    final bloqueado = await CierreDiaService.isBlockedNow();
    if (mounted) {
      setState(() => _bloqueado = bloqueado);
    }
  }

  Future<void> _registrarCliente() async {
    if (await verificarBloqueo(context)) return;

    if (_nombresController.text.isEmpty ||
        _cedulaController.text.isEmpty ||
        _telefonoController.text.isEmpty ||
        _montoController.text.isEmpty ||
        _cuotasController.text.isEmpty ||
        _diaCobro.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/clientes/registrar-con-prestamo?admin_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': _nombresController.text,
          'cedula': _cedulaController.text,
          'telefono': _telefonoController.text,
          'dia_cobro': _diaCobro,
          'monto_prestado': parseMonto(_montoController.text),
          'interes_porcentaje': _interes,
          'numero_cuotas': int.parse(_cuotasController.text),
          'frecuencia': _frecuencia,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          final d = jsonDecode(response.body);
          final montoPrestado = d['monto_prestado'] ?? 0;
          final cartulina = d['valor_cartulina'] ?? 0;
          final totalEntregado = d['total_entregado'] ?? 0;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Préstamo Registrado'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${_nombresController.text}'),
                  const SizedBox(height: 8),
                  Text('Valor prestado: ${formatearDinero(montoPrestado)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Cartulina: -${formatearDinero(cartulina)}', style: TextStyle(color: Colors.grey.shade600)),
                  const Divider(),
                  Text('Total a pagar: ${formatearDinero(d['total_deuda'])}'),
                  Text('Cuotas: ${d['numero_cuotas']} de ${formatearDinero(d['valor_cuota'])}'),
                  const SizedBox(height: 8),
                  Text('Valor recibido: ${formatearDinero(totalEntregado)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
              ],
            ),
          );
        }
        _nombresController.clear();
        _cedulaController.clear();
        _telefonoController.clear();
        _montoController.clear();
        _cuotasController.clear();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error['detail'] ?? 'Error')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Cliente")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nombresController,
                decoration: const InputDecoration(
                  labelText: "Nombres y Apellidos",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _cedulaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Cédula",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Teléfono",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _diaCobro,
                decoration: const InputDecoration(
                  labelText: "Día de cobro",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items:
                    [
                          'lunes',
                          'martes',
                          'miércoles',
                          'jueves',
                          'viernes',
                          'sábado',
                          'domingo',
                        ]
                        .map(
                          (dia) => DropdownMenuItem(
                            value: dia,
                            child: Text(
                              dia[0].toUpperCase() + dia.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _diaCobro = value ?? 'lunes';
                  });
                },
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Datos del Préstamo",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _onMontoChanged(_montoController),
                decoration: const InputDecoration(
                  labelText: "Monto a prestar",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _cuotasController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Número de cuotas",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _frecuencia,
                decoration: const InputDecoration(
                  labelText: "Frecuencia",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: ['semanal', 'quincenal', 'mensual']
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(f[0].toUpperCase() + f.substring(1)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _frecuencia = value ?? 'mensual';
                  });
                },
              ),
              const SizedBox(height: 15),
              Text("Interés: ${_interes.toStringAsFixed(1)}%"),
              Slider(
                value: _interes,
                min: 0,
                max: 50,
                divisions: 50,
                label: "${_interes.toStringAsFixed(1)}%",
                onChanged: (value) {
                  setState(() {
                    _interes = value;
                  });
                },
              ),
              const SizedBox(height: 30),
              if (_bloqueado)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'El cierre del día está activo hasta las 23:59. No se permiten préstamos ni cobros.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoading || _bloqueado)
                      ? null
                      : _registrarCliente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Registrar Cliente y Préstamo"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= REGISTRO DE CLIENTE ANTERIOR (DESDE LIBRO) =============
class RegistroClienteAnteriorScreen extends StatefulWidget {
  const RegistroClienteAnteriorScreen({super.key});

  @override
  _RegistroClienteAnteriorScreenState createState() =>
      _RegistroClienteAnteriorScreenState();
}

class _RegistroClienteAnteriorScreenState
    extends State<RegistroClienteAnteriorScreen> {
  final _nombresController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _montoController = TextEditingController();
  final _cuotasCountController = TextEditingController();
  String _diaCobro = 'lunes';
  String _frecuencia = 'semanal';
  double _interes = 20.0;
  bool _isLoading = false;

  List<_CuotaAnteriorState> _cuotas = [];

  @override
  void dispose() {
    _nombresController.dispose();
    _cedulaController.dispose();
    _telefonoController.dispose();
    _montoController.dispose();
    _cuotasCountController.dispose();
    for (var c in _cuotas) {
      c.valorController.dispose();
      c.pagadoController.dispose();
      c.pagosController.dispose();
    }
    super.dispose();
  }

  void _generarCuotas() {
    final count = int.tryParse(_cuotasCountController.text) ?? 0;
    if (count <= 0) return;
    final monto = parseMonto(_montoController.text);
    final interes = monto * (_interes / 100);
    final totalDeuda = monto + interes;
    final valorBase = totalDeuda / count;

    setState(() {
      for (var c in _cuotas) {
        c.valorController.dispose();
        c.pagadoController.dispose();
        c.pagosController.dispose();
      }
      _cuotas = List.generate(count, (i) {
        return _CuotaAnteriorState(
          numero: i + 1,
          valorBase: valorBase,
        );
      });
    });
  }

  void _detectarFrecuencia() {
    final fechas = _cuotas
        .where((c) => c.pagada && c.fechaPago != null)
        .map((c) => c.fechaPago!)
        .toList()
      ..sort();
    if (fechas.length < 2) return;

    double totalDiff = 0;
    for (int i = 1; i < fechas.length; i++) {
      totalDiff += fechas[i].difference(fechas[i - 1]).inDays.abs();
    }
    final avgGap = totalDiff / (fechas.length - 1);

    String nuevaFrecuencia;
    if (avgGap <= 10) {
      nuevaFrecuencia = 'semanal';
    } else if (avgGap <= 20) {
      nuevaFrecuencia = 'quincenal';
    } else {
      nuevaFrecuencia = 'mensual';
    }

    if (_frecuencia != nuevaFrecuencia) {
      setState(() => _frecuencia = nuevaFrecuencia);
    }
  }

  Future<void> _registrar() async {
    if (_nombresController.text.isEmpty ||
        _cedulaController.text.isEmpty ||
        _telefonoController.text.isEmpty ||
        _montoController.text.isEmpty ||
        _cuotasCountController.text.isEmpty ||
        _cuotas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cuotasData = _cuotas.map((c) => {
        'numero_cuota': c.numero,
        'valor_cuota': parseMonto(c.valorController.text),
        'pagada': c.pagada,
        'valor_pagado': c.pagada ? parseMonto(c.pagadoController.text) : 0.0,
        'numero_pagos': c.pagada ? (int.tryParse(c.pagosController.text) ?? 1) : 0,
        if (c.fechaPago != null)
          'fecha_pago': c.fechaPago!.toIso8601String().split('T')[0],
      }).toList();

      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/registrar-cliente-anterior?admin_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': _nombresController.text,
          'cedula': _cedulaController.text,
          'telefono': _telefonoController.text,
          'dia_cobro': _diaCobro,
          'monto_prestado': parseMonto(_montoController.text),
          'interes_porcentaje': _interes,
          'frecuencia': _frecuencia,
          'cuotas': cuotasData,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        final d = jsonDecode(response.body);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cliente Anterior Registrado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cliente: ${_nombresController.text}'),
                const SizedBox(height: 8),
                Text('Total deuda: ${formatearDinero(d['total_deuda'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Total pagado: ${formatearDinero(d['total_pagado'])}',
                    style: const TextStyle(color: Colors.green)),
                Text('Deuda restante: ${formatearDinero(d['deuda_restante'])}',
                    style: TextStyle(
                        color: d['deuda_restante'] > 0
                            ? Colors.red
                            : Colors.green)),
                Text('Cuotas creadas: ${d['cuotas_creadas']}'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Aceptar')),
            ],
          ),
        );
        _nombresController.clear();
        _cedulaController.clear();
        _telefonoController.clear();
        _montoController.clear();
        _cuotasCountController.clear();
        for (var c in _cuotas) {
          c.valorController.dispose();
          c.pagadoController.dispose();
          c.pagosController.dispose();
        }
        setState(() => _cuotas = []);
      } else if (mounted) {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error al registrar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monto = parseMonto(_montoController.text);
    final interesCalc = monto * (_interes / 100);
    final totalDeuda = monto + interesCalc;
    final cuotasCount = int.tryParse(_cuotasCountController.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cliente Anterior (Libro)"),
        backgroundColor: Colors.brown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Datos del Cliente",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombresController,
              decoration: const InputDecoration(
                labelText: "Nombres y Apellidos",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cedulaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Cédula",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Teléfono",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _diaCobro,
              decoration: const InputDecoration(
                labelText: "Día de cobro",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: ['lunes', 'martes', 'miércoles', 'jueves', 'viernes',
                      'sábado', 'domingo']
                  .map((dia) => DropdownMenuItem(
                        value: dia,
                        child: Text(dia[0].toUpperCase() + dia.substring(1)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _diaCobro = v ?? 'lunes'),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Datos del Préstamo",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                _onMontoChanged(_montoController);
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: "Monto prestado",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 12),
            Text("Interés: ${_interes.toStringAsFixed(1)}%"),
            Slider(
              value: _interes,
              min: 0,
              max: 50,
              divisions: 50,
              label: "${_interes.toStringAsFixed(1)}%",
              onChanged: (v) => setState(() => _interes = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _frecuencia,
              decoration: InputDecoration(
                labelText: "Frecuencia",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.schedule),
                helperText: _cuotas.any((c) => c.pagada && c.fechaPago != null)
                    ? 'Detectada automáticamente de las fechas'
                    : null,
                helperStyle: const TextStyle(fontSize: 11, color: Colors.green),
              ),
              items: ['semanal', 'quincenal', 'mensual']
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f[0].toUpperCase() + f.substring(1)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _frecuencia = v ?? 'semanal'),
            ),
            if (monto > 0) ...[
              const SizedBox(height: 8),
              Text(
                "Total deuda (con interés): ${formatearDinero(totalDeuda)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_view_week, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Configurar Cuotas",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cuotasCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Número de cuotas",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _generarCuotas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  child: const Text("Generar"),
                ),
              ],
            ),
            if (_cuotas.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                "Total deuda: ${formatearDinero(totalDeuda)} | "
                "Valor base por cuota: ${formatearDinero(cuotasCount > 0 ? totalDeuda / cuotasCount : 0)}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ..._cuotas.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Cuota #${c.numero}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Spacer(),
                            Checkbox(
                              value: c.pagada,
                              onChanged: (v) {
                                setState(() => c.pagada = v ?? false);
                                if (!c.pagada) {
                                  c.pagadoController.clear();
                                  c.pagosController.text = '1';
                                }
                              },
                            ),
                            Text(
                              c.pagada ? "Pagada" : "Pendiente",
                              style: TextStyle(
                                color: c.pagada ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: c.valorController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _onMontoChanged(c.valorController),
                          decoration: const InputDecoration(
                            labelText: "Valor de la cuota",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        if (c.pagada) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: c.pagadoController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _onMontoChanged(c.pagadoController),
                            decoration: const InputDecoration(
                              labelText: "¿Cuánto pagó?",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: c.pagosController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "¿Cuántos pagos hizo?",
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              c.fechaPago != null
                                  ? 'Pagado: ${c.fechaPago!.day}/${c.fechaPago!.month}/${c.fechaPago!.year}'
                                  : 'Seleccionar fecha de pago',
                              style: const TextStyle(fontSize: 13),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: c.fechaPago ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  c.fechaPago = picked;
                                });
                                _detectarFrecuencia();
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registrar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Registrar Cliente Anterior",
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _CuotaAnteriorState {
  final int numero;
  final TextEditingController valorController;
  final TextEditingController pagadoController;
  final TextEditingController pagosController;
  bool pagada;
  DateTime? fechaPago;

  _CuotaAnteriorState({
    required this.numero,
    required double valorBase,
  })  : valorController = TextEditingController(
          text: valorBase > 0 ? valorBase.toStringAsFixed(0) : ''),
        pagadoController = TextEditingController(),
        pagosController = TextEditingController(text: '1'),
        pagada = false;
}

// ============= NUEVO PRÉSTAMO =============
class NuevoPrestamoScreen extends StatefulWidget {
  const NuevoPrestamoScreen({super.key});

  @override
  _NuevoPrestamoScreenState createState() => _NuevoPrestamoScreenState();
}

class _NuevoPrestamoScreenState extends State<NuevoPrestamoScreen> {
  final _busquedaController = TextEditingController();
  final _montoController = TextEditingController();
  final _cuotasController = TextEditingController();
  final _interesController = TextEditingController(text: '20.0');
  List<dynamic> _sugerencias = [];
  String _frecuencia = "semanal";
  double _interes = 20.0;
  int? _clienteId;
  String? _nombreCliente;
  bool _isLoading = false;
  bool _buscando = false;
  bool _bloqueado = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _verificarBloqueo();
    _busquedaController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _busquedaController.removeListener(_onSearchChanged);
    _busquedaController.dispose();
    _montoController.dispose();
    _cuotasController.dispose();
    _interesController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _buscarSugerencias();
    });
  }

  Future<void> _buscarSugerencias() async {
    final texto = _busquedaController.text.trim();
    if (texto.isEmpty) {
      if (mounted) setState(() => _sugerencias = []);
      return;
    }

    setState(() => _buscando = true);
    try {
      final uid = SessionGlobal.usuarioId;
      final esNumero = RegExp(r'^\d+$').hasMatch(texto);
      final url = esNumero
          ? 'https://proyecto-cobros.onrender.com/api/clientes/buscar?cedula=$texto&usuario_id=$uid'
          : 'https://proyecto-cobros.onrender.com/api/clientes/buscar?nombre=$texto&usuario_id=$uid';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() => _sugerencias = jsonDecode(response.body) as List);
      } else if (mounted) {
        setState(() => _sugerencias = []);
      }
    } catch (e) {
      if (mounted) setState(() => _sugerencias = []);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _seleccionarCliente(Map<String, dynamic> cliente) {
    setState(() {
      _clienteId = cliente['id'];
      _nombreCliente = cliente['nombres'];
      _busquedaController.text = cliente['nombres'] ?? '';
      _sugerencias = [];
    });
  }

  Future<void> _verificarBloqueo() async {
    final bloqueado = await CierreDiaService.isBlockedNow();
    if (mounted) {
      setState(() => _bloqueado = bloqueado);
    }
  }

  Future<void> _crearPrestamo() async {
    if (await verificarBloqueo(context)) return;

    if (_clienteId == null ||
        _montoController.text.isEmpty ||
        _cuotasController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/prestamos/crear?usuario_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente_id': _clienteId,
          'monto_prestado': parseMonto(_montoController.text),
          'interes_porcentaje': _interes,
          'numero_cuotas': int.parse(_cuotasController.text),
          'frecuencia': _frecuencia,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final montoPrestado = data['monto_prestado'] ?? 0;
        final deudaAnterior = data['deuda_anterior'] ?? 0;
        final cartulina = data['valor_cartulina'] ?? 0;
        final valorEntregado = data['valor_entregado'] ?? 0;
        final totalEntregado = data['total_entregado'] ?? 0;
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Préstamo Registrado'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: $_nombreCliente'),
                  const SizedBox(height: 8),
                  Text('Valor prestado: ${formatearDinero(montoPrestado)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (deudaAnterior > 0 && totalEntregado < valorEntregado) ...[
                    Text('Deuda anterior cancelada: -${formatearDinero(deudaAnterior)}', style: const TextStyle(color: Colors.red)),
                  ] else if (deudaAnterior > 0) ...[
                    Text('Deuda anterior: ${formatearDinero(deudaAnterior)} (se suma)', style: const TextStyle(color: Colors.orange)),
                  ],
                  Text('Cartulina: -${formatearDinero(cartulina)}', style: TextStyle(color: Colors.grey.shade600)),
                  const Divider(),
                  Text('Total a pagar: ${formatearDinero(data['total_deuda'])}'),
                  Text('Cuotas: ${data['numero_cuotas']} de ${formatearDinero(data['valor_cuota'])}'),
                  const SizedBox(height: 8),
                  Text('Valor recibido: ${formatearDinero(totalEntregado)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
              ],
            ),
          );
        }
        _busquedaController.clear();
        _montoController.clear();
        _cuotasController.clear();
        setState(() {
          _clienteId = null;
          _nombreCliente = null;
        });
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error['detail'] ?? 'Error')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Préstamo")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _busquedaController,
                decoration: InputDecoration(
                  labelText: "Buscar cliente (nombre o cédula)",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (_sugerencias.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sugerencias.length,
                    itemBuilder: (context, i) {
                      final c = _sugerencias[i];
                      return ListTile(
                        dense: true,
                        title: Text(c['nombres'] ?? ''),
                        subtitle: Text('Cédula: ${c['cedula']} | Tel: ${c['telefono']}'),
                        onTap: () => _seleccionarCliente(c),
                      );
                    },
                  ),
                ),
              if (_nombreCliente != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.green[100],
                  child: Text(
                    "Cliente: $_nombreCliente",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              TextField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _onMontoChanged(_montoController),
                decoration: const InputDecoration(
                  labelText: "Monto a Prestar",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _interesController,
                keyboardType: TextInputType.number,
                onChanged: (value) => _interes = double.tryParse(value) ?? 20.0,
                decoration: const InputDecoration(
                  labelText: "Interés (%)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _cuotasController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Número de Cuotas",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _frecuencia,
                decoration: const InputDecoration(
                  labelText: "Frecuencia de Pago",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "semanal", child: Text("Semanal")),
                  DropdownMenuItem(
                    value: "quincenal",
                    child: Text("Quincenal"),
                  ),
                  DropdownMenuItem(value: "mensual", child: Text("Mensual")),
                ],
                onChanged: (value) {
                  setState(() => _frecuencia = value ?? "semanal");
                },
              ),
              const SizedBox(height: 30),
              if (_bloqueado)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'El cierre del día está activo hasta las 23:59. No se permiten préstamos ni cobros.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_clienteId == null || _isLoading || _bloqueado)
                      ? null
                      : _crearPrestamo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Crear Préstamo"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= REGISTRO DE COBROS =============
class RegistroCobrosScreen extends StatefulWidget {
  final int? clienteId;
  final String? clienteNombre;
  const RegistroCobrosScreen({super.key, this.clienteId, this.clienteNombre});

  @override
  _RegistroCobrosScreenState createState() => _RegistroCobrosScreenState();
}

class _RegistroCobrosScreenState extends State<RegistroCobrosScreen> {
  final _busquedaController = TextEditingController();
  final _pagoController = TextEditingController();
  Map<String, dynamic>? _clienteInfo;
  List<dynamic> _cuotasPendientes = [];
  List<dynamic> _sugerencias = [];
  int? _clienteId;
  String? _nombreCliente;
  bool _isLoading = false;
  bool _buscando = false;
  bool _bloqueado = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _verificarBloqueo();
    _busquedaController.addListener(_onSearchChanged);
    if (widget.clienteId != null) {
      _cargarClientePorId(widget.clienteId!);
    }
  }

  Future<void> _cargarClientePorId(int clienteId) async {
    final nombre = widget.clienteNombre ?? 'Cliente';
    if (mounted) {
      setState(() {
        _isLoading = true;
        _clienteId = clienteId;
        _nombreCliente = nombre;
      });
    }
    await _seleccionarCliente({'id': clienteId, 'nombres': nombre});
  }

  @override
  void dispose() {
    _busquedaController.removeListener(_onSearchChanged);
    _busquedaController.dispose();
    _pagoController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _verificarBloqueo() async {
    final bloqueado = await CierreDiaService.isBlockedNow();
    if (mounted) {
      setState(() => _bloqueado = bloqueado);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _buscarSugerencias();
    });
  }

  Future<void> _buscarSugerencias() async {
    final texto = _busquedaController.text.trim();
    if (texto.isEmpty) {
      if (mounted) setState(() => _sugerencias = []);
      return;
    }

    setState(() => _buscando = true);
    try {
      final uid = SessionGlobal.usuarioId;
      final esNumero = RegExp(r'^\d+$').hasMatch(texto);
      final url = esNumero
          ? 'https://proyecto-cobros.onrender.com/api/clientes/buscar?cedula=$texto&usuario_id=$uid'
          : 'https://proyecto-cobros.onrender.com/api/clientes/buscar?nombre=$texto&usuario_id=$uid';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        setState(() => _sugerencias = jsonDecode(response.body) as List);
      } else if (mounted) {
        setState(() => _sugerencias = []);
      }
    } catch (e) {
      if (mounted) setState(() => _sugerencias = []);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _seleccionarCliente(Map<String, dynamic> cliente) async {
    setState(() {
      _clienteId = cliente['id'];
      _nombreCliente = cliente['nombres'];
      _busquedaController.text = cliente['nombres'] ?? '';
      _sugerencias = [];
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/reportes/cliente/${cliente['id']}',
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final reportData = jsonDecode(response.body);
        final historial = reportData['historial_prestamos'] as List;

        List<dynamic> cuotas = [];
        for (var prestamo in historial) {
          for (var cuota in prestamo['cuotas']) {
            if (!(cuota['pagada'] ?? false)) {
              cuotas.add({...cuota, 'prestamo_id': prestamo['prestamo_id']});
            }
          }
        }

        cuotas.sort(
          (a, b) => DateTime.parse(
            a['vencimiento'].toString(),
          ).compareTo(DateTime.parse(b['vencimiento'].toString())),
        );

        if (mounted) {
          setState(() {
            _clienteInfo = reportData;
            _cuotasPendientes = cuotas;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  List<Map<String, dynamic>> _obtenerUltimasCuotasAtrasadas() {
    if (_clienteInfo == null) return [];
    final historial = _clienteInfo!['historial_prestamos'] as List? ?? [];
    List<Map<String, dynamic>> resultado = [];

    for (var prestamo in historial) {
      if (prestamo['pagado'] == true) continue;
      final cuotas = prestamo['cuotas'] as List? ?? [];
      // Última cuota no pagada (mayor número)
      Map<String, dynamic>? ultima;
      for (var c in cuotas) {
        if (c['pagada'] == true) continue;
        if (ultima == null || (c['numero'] ?? 0) > (ultima['numero'] ?? 0)) {
          ultima = c;
        }
      }
      if (ultima != null && ultima['atrasada'] == true) {
        resultado.add({
          'cuota': ultima,
          'monto_prestado': prestamo['monto_prestado'],
          'prestamo_id': prestamo['prestamo_id'],
        });
      }
    }
    return resultado;
  }

  Future<void> _aplazarCuota(int cuotaId, String accion, double? porcentaje) async {
    if (await verificarBloqueo(context)) return;
    try {
      String url = 'https://proyecto-cobros.onrender.com/api/cobros/gestionar-cuota?cuota_id=$cuotaId&accion=$accion&usuario_id=${SessionGlobal.usuarioId}';
      if (porcentaje != null) {
        url += '&nuevo_porcentaje=$porcentaje';
      }
      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['mensaje'] ?? 'Cuota gestionada'), backgroundColor: Colors.green),
        );
        // Recargar info del cliente
        if (_clienteId != null) {
          final r = await http.get(Uri.parse(
            'https://proyecto-cobros.onrender.com/api/reportes/cliente/$_clienteId',
          ));
          if (r.statusCode == 200 && mounted) {
            final reportData = jsonDecode(r.body);
            final historial = reportData['historial_prestamos'] as List;
            List<dynamic> cuotas = [];
            for (var prestamo in historial) {
              for (var cuota in prestamo['cuotas']) {
                if (!(cuota['pagada'] ?? false)) {
                  cuotas.add({...cuota, 'prestamo_id': prestamo['prestamo_id']});
                }
              }
            }
            cuotas.sort((a, b) => DateTime.parse(a['vencimiento'].toString()).compareTo(DateTime.parse(b['vencimiento'].toString())));
            if (mounted) setState(() { _clienteInfo = reportData; _cuotasPendientes = cuotas; });
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _mostrarDialogoAplazarConInteres(int cuotaId) async {
    final porcentajeController = TextEditingController(text: '20');
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplazar con interés'),
        content: TextField(
          controller: porcentajeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Porcentaje de interés', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (aplicar == true) {
      final pct = double.tryParse(porcentajeController.text.trim());
      if (pct == null || pct <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un porcentaje válido')));
        return;
      }
      await _aplazarCuota(cuotaId, 'aplazar_con_interes', pct);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Cobro")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _busquedaController,
                decoration: InputDecoration(
                  labelText: "Buscar cliente (nombre o cédula)",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (_sugerencias.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sugerencias.length,
                    itemBuilder: (context, i) {
                      final c = _sugerencias[i];
                      return ListTile(
                        dense: true,
                        title: Text(c['nombres'] ?? ''),
                        subtitle: Text('Cédula: ${c['cedula']} | Tel: ${c['telefono']}'),
                        onTap: () => _seleccionarCliente(c),
                      );
                    },
                  ),
                ),
              if (_nombreCliente != null && _clienteInfo != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente: $_nombreCliente',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deuda Total: ${formatearDinero(_clienteInfo!['resumen']['deuda_total'])}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Cuotas Pendientes: ${_cuotasPendientes.length}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (_cuotasPendientes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Próxima Cuota a Vencer:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuota #${_cuotasPendientes[0]['numero']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Valor: ${formatearDinero(_cuotasPendientes[0]['valor'])}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Vence: ${_cuotasPendientes[0]['vencimiento']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              // Cuotas atrasadas (última cuota de cada préstamo)
              if (_clienteInfo != null) ..._obtenerUltimasCuotasAtrasadas().map((item) =>
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠ Última cuota vencida - Préstamo \$${formatearDinero(item['monto_prestado'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Text('Cuota #${item['cuota']['numero']} - ${formatearDinero(item['cuota']['valor'])}'),
                          Text('Vence: ${item['cuota']['vencimiento']}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _aplazarCuota(item['cuota']['id'], 'aplazar', null),
                                  icon: const Icon(Icons.date_range, size: 16),
                                  label: const Text('Aplazar', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _mostrarDialogoAplazarConInteres(item['cuota']['id']),
                                  icon: const Icon(Icons.percent, size: 16),
                                  label: const Text('Aplazar + Interés', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pagoController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _onMontoChanged(_pagoController),
                decoration: const InputDecoration(
                  labelText: "Valor a Cobrar",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 30),
              if (_bloqueado)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'El cierre del día está activo hasta las 23:59. No se permiten préstamos ni cobros.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading || _clienteInfo == null || _bloqueado
                      ? null
                      : _registrarPago,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Registrar Pago"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registrarPago() async {
    if (await verificarBloqueo(context)) return;

    if (_pagoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingrese el valor a cobrar")),
      );
      return;
    }

    if (_cuotasPendientes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No hay cuotas pendientes")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final montoPagado = parseMonto(_pagoController.text);
      final cuotaId = int.parse(_cuotasPendientes[0]['id'].toString());

      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/cobros/registrar-pago?usuario_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cuota_id': cuotaId, 'cantidad_pagada': montoPagado}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final montoCuota = _cuotasPendientes[0]['valor'];
        final cuotaPagada = result['cuota_pagada'] ?? false;
        final deudaRestante = result['deuda_restante'] ?? 0;

        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Pago Registrado'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: $_nombreCliente'),
                  const SizedBox(height: 8),
                  Text('Monto pagado: ${formatearDinero(montoPagado)}'),
                  Text('Valor cuota: ${formatearDinero(montoCuota)}'),
                  const SizedBox(height: 8),
                  Text(
                    cuotaPagada
                        ? 'Cuota #${_cuotasPendientes[0]['numero']} pagada completamente'
                        : 'Pago parcial registrado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cuotaPagada ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deuda restante total: ${formatearDinero(deudaRestante)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }

        // Recargar datos del cliente para ver cambios en la siguiente cuota
        _pagoController.clear();
        if (_clienteId != null) {
          final r = await http.get(Uri.parse(
            'https://proyecto-cobros.onrender.com/api/reportes/cliente/$_clienteId',
          ));
          if (r.statusCode == 200 && mounted) {
            final reportData = jsonDecode(r.body);
            final historial = reportData['historial_prestamos'] as List;
            List<dynamic> cuotas = [];
            for (var prestamo in historial) {
              for (var cuota in prestamo['cuotas']) {
                if (!(cuota['pagada'] ?? false)) {
                  cuotas.add({...cuota, 'prestamo_id': prestamo['prestamo_id']});
                }
              }
            }
            cuotas.sort((a, b) => DateTime.parse(a['vencimiento'].toString())
                .compareTo(DateTime.parse(b['vencimiento'].toString())));
            if (mounted) {
              setState(() {
                _clienteInfo = reportData;
                _cuotasPendientes = cuotas;
              });
            }
          }
        }
      } else {
        final error = jsonDecode(response.body);
        var mensajeError = 'Error al registrar pago';
        if (error['detail'] != null) {
          if (error['detail'] is List) {
            // FastAPI 422: lista de errores
            mensajeError = error['detail'].map((e) => e['msg']).join(' | ');
          } else if (error['detail'] is String) {
            mensajeError = error['detail'];
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeError)));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ============= BÚSQUEDA DE CLIENTES =============
class BuscarClienteScreen extends StatefulWidget {
  const BuscarClienteScreen({super.key});

  @override
  _BuscarClienteScreenState createState() => _BuscarClienteScreenState();
}

class _BuscarClienteScreenState extends State<BuscarClienteScreen> {
  final _busquedaController = TextEditingController();
  List<dynamic> _clientes = [];

  Future<void> _buscar() async {
    if (_busquedaController.text.isEmpty) return;

    final busqueda = _busquedaController.text.trim();
    final uid = SessionGlobal.usuarioId;
    String url;
    if (RegExp(r'^\d+$').hasMatch(busqueda)) {
      url =
          'https://proyecto-cobros.onrender.com/api/clientes/buscar?cedula=$busqueda&usuario_id=$uid';
    } else {
      url =
          'https://proyecto-cobros.onrender.com/api/clientes/buscar?nombre=$busqueda&usuario_id=$uid';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() => _clientes = jsonDecode(response.body));
      } else {
        setState(() => _clientes = []);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No se encontraron clientes")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar Cliente")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                labelText: "Buscar por cédula o nombre",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscar,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _clientes.length,
                itemBuilder: (context, index) {
                  final cliente = _clientes[index];
                  return ListTile(
                    title: Text(cliente['nombres']),
                    subtitle: Text("Cédula: ${cliente['cedula']}"),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () async {
                      // Mostrar detalles del cliente
                      _mostrarDetallesCliente(
                        cliente['id'],
                        cliente['nombres'],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDetallesCliente(
    int clienteId,
    String clienteNombre,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/reportes/cliente/$clienteId',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resumen = data['resumen'];
        final historial = data['historial_prestamos'] as List;

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(clienteNombre),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deuda Total: ${formatearDinero(resumen['deuda_total'])}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cuotas Pendientes: ${_contarCuotasPendientes(historial)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Préstamos Activos: ${_contarPrestamosActivos(historial)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (resumen['prestamos_atrasados'] > 0)
                    Text(
                      'Préstamos Atrasados: ${resumen['prestamos_atrasados']}',
                      style: const TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  const SizedBox(height: 15),
                  const Text(
                    'Detalles por Préstamo:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...historial.map((prestamo) {
                    final cuotas = prestamo['cuotas'] as List;
                    final cPendientes = cuotas
                        .where((c) => !(c['pagada'] ?? false))
                        .length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Préstamo ${formatearDinero(prestamo['monto_prestado'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Deuda: ${formatearDinero(prestamo['deuda_restante'])} | Cuotas: $cPendientes pendientes',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => _mostrarCuotasDialog(prestamo),
                            child: const Text('Ver cuotas'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _mostrarCuotasDialog(Map prestamo) async {
    final cuotas = prestamo['cuotas'] as List;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cuotas del préstamo ${formatearDinero(prestamo['monto_prestado'])}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: cuotas.map<Widget>((cuota) {
              final pagada = cuota['pagada'] ?? false;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cuota #${cuota['numero']} - Valor: ${formatearDinero(cuota['valor'])}',
                      ),
                      Text('Vence: ${cuota['vencimiento']}'),
                      Text('Pagada: ${pagada ? 'Sí' : 'No'}'),
                      if (SessionGlobal.rol == 'administrador')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              // Pedir monto de interés
                              final montoController = TextEditingController();
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Agregar interés de mora'),
                                  content: TextField(
                                    controller: montoController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Monto interés',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Aplicar'),
                                    ),
                                  ],
                                ),
                              );

                              if (result == true) {
                                final text = montoController.text.trim();
                                if (text.isEmpty) return;
                                final monto = double.tryParse(text);
                                if (monto == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Monto inválido'),
                                    ),
                                  );
                                  return;
                                }

                                await _aplicarInteres(cuota['id'], monto);
                                Navigator.pop(
                                  context,
                                ); // cerrar listado de cuotas
                              }
                            },
                            child: const Text('Agregar interés'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _aplicarInteres(int cuotaId, double monto) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/admin/agregar-interes-mora?admin_id=${SessionGlobal.usuarioId}&cuota_id=$cuotaId&monto_interes=$monto',
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interés aplicado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String msg = 'Error al aplicar interés';
        try {
          final body = jsonDecode(response.body);
          if (body['detail'] != null) msg = body['detail'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  int _contarCuotasPendientes(List historial) {
    int total = 0;
    for (var prestamo in historial) {
      final cuotas = prestamo['cuotas'] as List;
      total += cuotas.where((c) => !(c['pagada'] ?? false)).length;
    }
    return total;
  }

  int _contarPrestamosActivos(List historial) {
    return historial.where((p) => !(p['pagado'] ?? false)).length;
  }
}

// ============= RESUMEN DEL DÍA =============
class ResumenDiaScreen extends StatefulWidget {
  const ResumenDiaScreen({super.key});

  @override
  _ResumenDiaScreenState createState() => _ResumenDiaScreenState();
}

class _ResumenDiaScreenState extends State<ResumenDiaScreen> {
  Map<String, dynamic>? _resumen;
  bool _isLoading = true;
  bool _bloqueado = false;
  final _conceptoController = TextEditingController();
  final _valorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarResumen();
    _verificarBloqueo();
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _verificarBloqueo() async {
    final bloqueado = await CierreDiaService.isBlockedNow();
    if (mounted) {
      setState(() => _bloqueado = bloqueado);
    }
  }

  Future<void> _cargarResumen() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/ingresos-gastos/resumen-dia?usuario_id=${SessionGlobal.usuarioId}',
        ),
      );

      if (response.statusCode == 200) {
        setState(() => _resumen = jsonDecode(response.body));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _mostrarDialogoGasto() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar gasto del día'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _conceptoController,
              decoration: const InputDecoration(labelText: 'Concepto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valorController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _onMontoChanged(_valorController),
              decoration: const InputDecoration(labelText: 'Valor'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final concepto = _conceptoController.text.trim();
              final valor = _valorController.text.trim();

              if (concepto.isEmpty || valor.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Complete concepto y valor')),
                );
                return;
              }

              Navigator.pop(context);
              await _registrarGasto(concepto, valor);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarGasto(String concepto, String valor) async {
    if (await verificarBloqueo(
      context,
      mensaje:
          'No puedes agregar gastos mientras el cierre del día está activo.',
    )) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/gastos/registrar?usuario_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'concepto': concepto, 'valor': parseMonto(valor)}),
      );

      if (response.statusCode == 200) {
        _conceptoController.clear();
        _valorController.clear();
        await _cargarResumen();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gasto registrado correctamente')),
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? 'Error al registrar gasto'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _hacerCierre() async {
    if (await verificarBloqueo(
      context,
      mensaje: 'El cierre del día ya está activo para este turno.',
    )) {
      return;
    }

    // Validar que es admin
    if (SessionGlobal.rol != 'administrador') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo administradores pueden hacer cierre del día'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usuarioId = SessionGlobal.usuarioId;
      if (usuarioId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/cierre-dia/crear?usuario_id=$usuarioId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        await CierreDiaService.saveClosedAt(DateTime.now());
        await _verificarBloqueo();
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cierre completado\nSaldo Neto: ${formatearDinero(data['saldo_neto'])}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error al hacer cierre')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _desactivarCierre() async {
    setState(() => _isLoading = true);
    try {
      final usuarioId = SessionGlobal.usuarioId;
      if (usuarioId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/cierre-dia/desactivar?usuario_id=$usuarioId',
        ),
      );

      if (response.statusCode == 200) {
        await CierreDiaService.clearClosedAt();
        await _verificarBloqueo();
        await _cargarResumen();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cierre desactivado. Los trabajadores pueden operar nuevamente.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error al desactivar cierre')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del Día')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resumen == null
          ? const Center(child: Text('Sin datos'))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fecha: ${_resumen!['fecha']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              'Cuotas: ${formatearDinero(_resumen!['ingreso_cuotas'])}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Cartulinas: ${formatearDinero(_resumen!['ingreso_cartulinas'])}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Préstamos del día: ${formatearDinero(_resumen!['prestamos_hoy'])}',
                              style: const TextStyle(fontSize: 16, color: Colors.purple),
                            ),
                            const Divider(),
                            Text(
                              'Total Ingresos: ${formatearDinero(_resumen!['total_ingresos'])}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (SessionGlobal.rol == 'administrador') ...[
                      if (!_bloqueado) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _mostrarDialogoGasto,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Agregar gasto'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _hacerCierre,
                                icon: const Icon(Icons.lock_clock),
                                label: const Text('Hacer cierre'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _mostrarDialogoGasto,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Agregar gasto'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _desactivarCierre,
                                icon: const Icon(Icons.lock_open),
                                label: const Text('Desactivar cierre'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'Gastos:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._resumen!['gastos'].map<Widget>((gasto) {
                      return Text('${gasto['concepto']}: ${formatearDinero(gasto['valor'])}');
                    }).toList(),
                    const Divider(),
                    Text(
                      'Total Gastos: ${formatearDinero(_resumen!['total_gastos'])}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      color: Colors.blue[100],
                      child: Text(
                        'Saldo Neto: ${formatearDinero(_resumen!['saldo_neto'])}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ============= CIERRE DEL DÍA =============
class CierreDiaScreen extends StatefulWidget {
  const CierreDiaScreen({super.key});

  @override
  _CierreDiaScreenState createState() => _CierreDiaScreenState();
}

class _CierreDiaScreenState extends State<CierreDiaScreen> {
  bool _isLoading = false;

  Future<void> _hacerCierre() async {
    setState(() => _isLoading = true);

    try {
      final usuarioId = SessionGlobal.usuarioId;
      if (usuarioId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await http.post(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/cierre-dia/crear?usuario_id=$usuarioId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cierre completado\nSaldo Neto: ${formatearDinero(data['saldo_neto'])}",
            ),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Error al hacer cierre')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cierre del Día")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 100, color: Colors.blue),
            const SizedBox(height: 30),
            const Text(
              "¿Deseas hacer el cierre del día de hoy?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _hacerCierre,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Confirmar Cierre"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= VERIFICAR CUENTA ACTIVA =============

Future<bool> verificarCuentaActiva(BuildContext context) async {
  try {
    final response = await http.get(
      Uri.parse(
        'https://proyecto-cobros.onrender.com/api/auth/verificar-activo?usuario_id=${SessionGlobal.usuarioId}',
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['activo'] == false) {
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Cuenta Desactivada'),
              content: const Text('No has pagado. Contacta al administrador.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          );
        }
        return false;
      }
    }
  } catch (_) {}
  return true;
}

// ============= PANEL DESARROLLADOR =============

class DesarrolladorScreen extends StatefulWidget {
  const DesarrolladorScreen({super.key});
  @override
  State<DesarrolladorScreen> createState() => _DesarrolladorScreenState();
}

class _DesarrolladorScreenState extends State<DesarrolladorScreen> {
  List _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/desarrollador/listar-usuarios?usuario_id=${SessionGlobal.usuarioId}',
        ),
      );
      if (response.statusCode == 200) {
        setState(() => _admins = jsonDecode(response.body));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _desactivar(int userId, String nombre) async {
    await http.post(Uri.parse(
      'https://proyecto-cobros.onrender.com/api/desarrollador/desactivar-usuario?usuario_id=${SessionGlobal.usuarioId}&target_id=$userId',
    ));
    _cargarUsuarios();
  }

  Future<void> _activar(int userId, String nombre) async {
    await http.post(Uri.parse(
      'https://proyecto-cobros.onrender.com/api/desarrollador/activar-usuario?usuario_id=${SessionGlobal.usuarioId}&target_id=$userId',
    ));
    _cargarUsuarios();
  }

  Future<void> _eliminar(int userId, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Eliminar a $nombre permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      await http.post(Uri.parse(
        'https://proyecto-cobros.onrender.com/api/desarrollador/eliminar-usuario?usuario_id=${SessionGlobal.usuarioId}&target_id=$userId',
      ));
      _cargarUsuarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Desarrollador'), backgroundColor: Colors.red),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarUsuarios,
              child: ListView.builder(
                itemCount: _admins.length,
                itemBuilder: (_, i) {
                  final admin = _admins[i];
                  final workers = admin['trabajadores'] as List;
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ExpansionTile(
                      leading: Icon(
                        admin['activo'] ? Icons.check_circle : Icons.cancel,
                        color: admin['activo'] ? Colors.green : Colors.red,
                      ),
                      title: Text(admin['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${admin['email']} — Clientes: ${admin['clientes_count']}'),
                      children: [
                        _buildUserActions(admin['id'], admin['nombre'], admin['email'], admin['activo']),
                        const Divider(),
                        if (workers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Sin trabajadores', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ...workers.map((w) => ListTile(
                                leading: Icon(
                                  w['activo'] ? Icons.person : Icons.person_off,
                                  color: w['activo'] ? Colors.blue : Colors.red,
                                ),
                                title: Text(w['nombre']),
                                subtitle: Text(w['email']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(w['activo'] ? Icons.block : Icons.check, color: Colors.orange),
                                      onPressed: () => w['activo'] ? _desactivar(w['id'], w['nombre']) : _activar(w['id'], w['nombre']),
                                      tooltip: w['activo'] ? 'Desactivar' : 'Activar',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                                      onPressed: () => _eliminar(w['id'], w['nombre']),
                                      tooltip: 'Eliminar',
                                    ),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildUserActions(int id, String nombre, String email, bool activo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(email, style: const TextStyle(color: Colors.grey)),
          ),
          IconButton(
            icon: Icon(activo ? Icons.block : Icons.check, color: Colors.orange),
            onPressed: () => activo ? _desactivar(id, nombre) : _activar(id, nombre),
            tooltip: activo ? 'Desactivar' : 'Activar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: () => _eliminar(id, nombre),
            tooltip: 'Eliminar',
          ),
        ],
      ),
    );
  }
}
