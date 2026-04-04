import 'package:flutter/material.dart';
import 'colors.dart';
import 'app_styles.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/auth/login',
        ),
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
  String _rolSeleccionado = "trabajador";
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
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/auth/registro',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': _nombreController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'rol': _rolSeleccionado,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registrado exitosamente")),
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
      appBar: AppBar(title: const Text("Registrar Usuario")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
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
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _rolSeleccionado,
                decoration: const InputDecoration(
                  labelText: "Rol",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "trabajador",
                    child: Text("Trabajador"),
                  ),
                  DropdownMenuItem(
                    value: "administrador",
                    child: Text("Administrador"),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _rolSeleccionado = value ?? "trabajador");
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registro,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Registrarse"),
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
  bool _cargandoClientes = false;

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
    _cargarClientesPorDia();
  }

  Future<void> _cargarClientesPorDia() async {
    setState(() => _cargandoClientes = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/clientes/dia/$_diaSeleccionado',
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          _clientes = jsonDecode(response.body);
        });
      } else {
        setState(() {
          _clientes = [];
        });
      }
    } catch (e) {
      setState(() {
        _clientes = [];
      });
    } finally {
      setState(() => _cargandoClientes = false);
    }
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
                ],
              ),
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
              leading: const Icon(Icons.attach_money, color: Colors.blue),
              title: const Text('Registrar Cobro'),
              onTap: () {
                Navigator.pop(context);
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
              onTap: () {
                Navigator.pop(context);
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
            ListTile(
              leading: const Icon(Icons.lock_clock, color: Colors.red),
              title: const Text('Cierre del Día'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CierreDiaScreen()),
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
                : _clientes.isEmpty
                ? const Center(child: Text('No hay clientes para este día'))
                : ListView.builder(
                    itemCount: _clientes.length,
                    itemBuilder: (context, idx) {
                      final cliente = _clientes[idx];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(cliente['nombres'] ?? ''),
                          subtitle: Text(
                            'Cédula: ${cliente['cedula']} | Tel: ${cliente['telefono']}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
  String _diaCobro = 'lunes';
  bool _isLoading = false;

  Future<void> _registrarCliente() async {
    if (_nombresController.text.isEmpty ||
        _cedulaController.text.isEmpty ||
        _telefonoController.text.isEmpty ||
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
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/clientes/registrar?usuario_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombres': _nombresController.text,
          'cedula': _cedulaController.text,
          'telefono': _telefonoController.text,
          'dia_cobro': _diaCobro,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cliente registrado exitosamente")),
        );
        _nombresController.clear();
        _cedulaController.clear();
        _telefonoController.clear();
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
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrarCliente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Registrar Cliente"),
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
      final response = await http.get(
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/clientes/buscar?cedula=${_cedulaController.text}',
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

  Future<void> _crearPrestamo() async {
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
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/prestamos/crear?usuario_id=${SessionGlobal.usuarioId}',
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
              "Préstamo creado\nTotal a cobrar: \$${data['total_deuda']}\nCartulina: \$${data['valor_cartulina']}",
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
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_clienteId == null || _isLoading)
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
  final _cedulaController = TextEditingController();
  final _pagoController = TextEditingController();
  Map<String, dynamic>? _clienteInfo;
  List<dynamic> _cuotasPendientes = [];
  int? _clienteId;
  bool _isLoading = false;

  Future<void> _cargarCuotas() async {
    if (_cedulaController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ingrese una cédula")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Primero buscar el cliente
      final searchResponse = await http.get(
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/clientes/buscar?cedula=${_cedulaController.text}',
        ),
      );

      if (searchResponse.statusCode == 200) {
        final clients = jsonDecode(searchResponse.body) as List;
        if (clients.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cliente no encontrado")),
          );
          setState(() => _isLoading = false);
          return;
        }

        _clienteId = clients[0]['id'];
        final clienteName = clients[0]['nombres'];

        // Luego obtener el reporte completo
        final reportResponse = await http.get(
          Uri.parse(
            'https://african-endorsed-sign-vacuum.trycloudflare.com/api/reportes/cliente/$_clienteId',
          ),
        );

        if (reportResponse.statusCode == 200) {
          final reportData = jsonDecode(reportResponse.body);
          final historial = reportData['historial_prestamos'] as List;

          // Extraer todas las cuotas pendientes
          List<dynamic> cuotas = [];
          for (var prestamo in historial) {
            for (var cuota in prestamo['cuotas']) {
              if (!(cuota['pagada'] ?? false)) {
                cuotas.add({...cuota, 'prestamo_id': prestamo['prestamo_id']});
              }
            }
          }

          // Ordenar por fecha de vencimiento
          cuotas.sort(
            (a, b) => DateTime.parse(
              a['vencimiento'].toString(),
            ).compareTo(DateTime.parse(b['vencimiento'].toString())),
          );

          setState(() {
            _clienteInfo = reportData;
            _cuotasPendientes = cuotas;
          });
        }
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
      appBar: AppBar(title: const Text("Registrar Cobro")),
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
                    onPressed: _cargarCuotas,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_clienteInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deuda Total: \$${_clienteInfo!['resumen']['deuda_total']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Cuotas Pendientes: ${_cuotasPendientes.length}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_cuotasPendientes.isNotEmpty) ...[
                  const Text(
                    'Próxima Cuota a Vencer:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
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
                          'Valor: \$${_cuotasPendientes[0]['valor']}',
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
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading || _clienteInfo == null
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
      final montoPagado = double.parse(_pagoController.text);
      final cuotaId = _cuotasPendientes[0]['id'];

      final response = await http.post(
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/cobros/registrar-pago?usuario_id=${SessionGlobal.usuarioId}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cuota_id': cuotaId, 'cantidad_pagada': montoPagado}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

    try {
      final response = await http.get(
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/clientes/buscar?cedula=${_busquedaController.text}',
        ),
      );

      if (response.statusCode == 200) {
        setState(() => _clientes = jsonDecode(response.body));
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
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/reportes/cliente/$clienteId',
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
                    'Deuda Total: \$${resumen['deuda_total']}',
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
                            'Préstamo \$${prestamo['monto_prestado']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Deuda: \$${prestamo['deuda_restante']} | Cuotas: $cPendientes pendientes',
                            style: const TextStyle(fontSize: 12),
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

  int _contarCuotasPendientes(List historial) {
    int total = 0;
    for (var prestamo in historial) {
      final cuotas = prestamo['cuotas'] as List;
      total += cuotas.where((c) => !(c['pagada'] ?? false)).length;
    }
    return total;
  }

  int _contarPrestamosActivos(List historial) {
    return historial.where((p) => !(p['pagada'] ?? false)).length;
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

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/ingresos-gastos/resumen-dia?usuario_id=${SessionGlobal.usuarioId}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ingresos del Día")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resumen == null
          ? const Center(child: Text("Sin datos"))
          : Padding(
              padding: const EdgeInsets.all(20),
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
                            "Fecha: ${_resumen!['fecha']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Cuotas: \$${_resumen!['ingreso_cuotas']}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            "Cartulinas: \$${_resumen!['ingreso_cartulinas']}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Divider(),
                          Text(
                            "Total Ingresos: \$${_resumen!['total_ingresos']}",
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
                  const Text(
                    "Gastos:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ..._resumen!['gastos'].map<Widget>((gasto) {
                    return Text("${gasto['concepto']}: \$${gasto['valor']}");
                  }).toList(),
                  const Divider(),
                  Text(
                    "Total Gastos: \$${_resumen!['total_gastos']}",
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
                      "Saldo Neto: \$${_resumen!['saldo_neto']}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
      final response = await http.post(
        Uri.parse(
          'https://african-endorsed-sign-vacuum.trycloudflare.com/api/cierre-dia/crear?usuario_id=${SessionGlobal.usuarioId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cierre completado\nSaldo Neto: \$${data['saldo_neto']}",
            ),
          ),
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
