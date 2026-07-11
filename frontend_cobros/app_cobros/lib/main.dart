import 'package:flutter/material.dart';
import 'colors.dart';
import 'app_styles.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'cierre_dia_service.dart';

String formatearDinero(dynamic valor) {
  if (valor == null) return '\$0';
  double num = (valor is num) ? valor.toDouble() : double.tryParse(valor.toString()) ?? 0;
  bool negativo = num < 0;
  if (negativo) num = num.abs();
  List<String> parts = num.toStringAsFixed(0).split('');
  StringBuffer buf = StringBuffer();
  int cnt = 0;
  for (int i = parts.length - 1; i >= 0; i--) {
    if (cnt > 0 && cnt % 3 == 0) buf.write('.');
    buf.write(parts[i]);
    cnt++;
  }
  return '${negativo ? '-' : ''}\$${buf.toString().split('').reversed.join()}';
}

void main() => runApp(
  MaterialApp(
    home: LoginScreen(),
    theme: ThemeData(primarySwatch: Colors.blue),
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
  }

  Future<void> _cargarClientesPorDia() async {
    if (!mounted) return;
    setState(() => _cargandoClientes = true);
    try {
      String url;
      if (_esAdmin) {
        url =
            'https://proyecto-cobros.onrender.com/api/admin/listar-clientes?admin_id=${SessionGlobal.usuarioId}';
      } else {
        url =
            'https://proyecto-cobros.onrender.com/api/clientes/dia/$_diaSeleccionado?usuario_id=${SessionGlobal.usuarioId}';
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
          const Divider(),
          // Barra de días y lista de clientes
          const SizedBox(height: 10),
          if (!_esAdmin)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _diasSemana.map((dia) {
                  final seleccionado = _diaSeleccionado == dia;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(dia[0].toUpperCase() + dia.substring(1)),
                      selected: seleccionado,
                      onSelected: (val) {
                        setState(() {
                          _diaSeleccionado = dia;
                        });
                        _cargarClientesPorDia();
                      },
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: seleccionado ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _cargandoClientes
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          obtenerTextoVistaClientes(_esAdmin, _diaSeleccionado),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
        ).showSnackBar(const SnackBar(content: Text('Cliente desactivado')));
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

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(cliente['nombres'] ?? 'Cliente'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deuda total: ${formatearDinero(data['resumen']['deuda_total'])}'),
                const SizedBox(height: 10),
                ...historial.expand((prestamo) {
                  final cuotas = prestamo['cuotas'] as List;
                  return cuotas
                      .where((cuota) => !(cuota['pagada'] ?? false))
                      .map<Widget>((cuota) {
                        final vencimiento = DateTime.tryParse(
                          cuota['vencimiento'].toString(),
                        );
                        final atrasada =
                            vencimiento != null &&
                            !vencimiento.isAfter(DateTime.now());
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text('Cuota #${cuota['numero']}'),
                                Text('Valor: ${formatearDinero(cuota['valor'])}'),
                                Text('Vence: ${cuota['vencimiento']}'),
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
                      })
                      .toList();
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
    bool activo = cliente['activo'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                await _editarCliente(
                  cliente['id'],
                  nombresController.text,
                  telefonoController.text,
                  diaCobro,
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

  Future<void> _editarCliente(
    int id,
    String nombres,
    String telefono,
    String diaCobro,
    bool activo,
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
          'activo': activo,
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
          'monto_prestado': double.parse(_montoController.text),
          'interes_porcentaje': _interes,
          'numero_cuotas': int.parse(_cuotasController.text),
          'frecuencia': _frecuencia,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cliente y préstamo registrados. Monto: ${formatearDinero(_montoController.text)}",
            ),
          ),
        );
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
              const Text(
                "Datos del Préstamo",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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

// ============= NUEVO PRÉSTAMO =============
class NuevoPrestamoScreen extends StatefulWidget {
  const NuevoPrestamoScreen({super.key});

  @override
  _NuevoPrestamoScreenState createState() => _NuevoPrestamoScreenState();
}

class _NuevoPrestamoScreenState extends State<NuevoPrestamoScreen> {
  final _cedulaController = TextEditingController();
  final _montoController = TextEditingController();
  final _cuotasController = TextEditingController();
  final _interesController = TextEditingController(text: '20.0');
  String _frecuencia = "semanal";
  double _interes = 20.0;
  int? _clienteId;
  String? _nombreCliente;
  bool _isLoading = false;
  bool _bloqueado = false;

  @override
  void initState() {
    super.initState();
    _verificarBloqueo();
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _montoController.dispose();
    _cuotasController.dispose();
    _interesController.dispose();
    super.dispose();
  }

  Future<void> _buscarCliente() async {
    if (_cedulaController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ingrese una cédula")));
      return;
    }

    try {
      final uid = SessionGlobal.usuarioId;
      final response = await http.get(
        Uri.parse(
          'https://proyecto-cobros.onrender.com/api/clientes/buscar?cedula=${_cedulaController.text}&usuario_id=$uid',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _clienteId = data[0]['id'];
          _nombreCliente = data[0]['nombres'];
        });
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No existe un cliente con esa cédula.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
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
          'monto_prestado': double.parse(_montoController.text),
          'interes_porcentaje': _interes,
          'numero_cuotas': int.parse(_cuotasController.text),
          'frecuencia': _frecuencia,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Préstamo creado\nTotal a cobrar: ${formatearDinero(data['total_deuda'])}\nCartulina: ${formatearDinero(data['valor_cartulina'])}",
            ),
          ),
        );
        _cedulaController.clear();
        _montoController.clear();
        _cuotasController.clear();
        setState(() => _clienteId = null);
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
                controller: _cedulaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Cédula del Cliente",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.badge),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _buscarCliente,
                  ),
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
  const RegistroCobrosScreen({super.key});

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
              const SizedBox(height: 20),
              TextField(
                controller: _pagoController,
                keyboardType: TextInputType.number,
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
            content: Text("¡Pago registrado exitosamente!"),
            backgroundColor: Colors.green,
          ),
        );

        // Limpiar campos
        _cedulaController.clear();
        _pagoController.clear();
        setState(() {
          _clienteInfo = null;
          _cuotasPendientes = [];
        });
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
        body: jsonEncode({'concepto': concepto, 'valor': double.parse(valor)}),
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
