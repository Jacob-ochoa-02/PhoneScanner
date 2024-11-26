import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    await dotenv.load(fileName: ".env");
    print("Archivo .env cargado correctamente.");
    print("Clave API: ${dotenv.env['API_KEY']}");
  } catch (e) {
    print("Error cargando el archivo .env: $e");
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String aiResponse = '';
  String myResponse = '';
  String batteryR = '';
  String ramR = '';
  String screenR = '';
  String storage = '';
  String operatingSystem = '';

  Future<Map<String, String>> getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    Map<String, String> deviceData = {};

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceData['Brand'] = androidInfo.brand;
      deviceData['Model'] = androidInfo.model;
      deviceData['Device'] = androidInfo.device;
      deviceData['Hardware'] = androidInfo.hardware;
      deviceData['Android Version'] = androidInfo.version.release;
      deviceData['Screen'] = androidInfo.display;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceData['Modelo'] = iosInfo.utsname.machine;
      deviceData['Nombre'] = iosInfo.name;
      deviceData['Sistema Operativo'] = iosInfo.systemName;
      deviceData['Versión'] = iosInfo.systemVersion;
    }
    return deviceData;
  }

  Future<void> fetchAIResponse({int retries = 3}) async {
    String apiKey = dotenv.env["API_KEY"] ?? 'No API Key Found';
    print("Clave API: $apiKey");
    String baseUrl = 'https://api.openai.com/v1/completions';

    if (apiKey == 'No API Key Found') {
      aiResponse =
          'La clave de API no está configurada. Verifica el archivo .env.';
      notifyListeners();
      return;
    }

    try {
      // Obtener la información del dispositivo
      Map<String, String> deviceInfo = await getDeviceInfo();
      String deviceDetails =
          deviceInfo.entries.map((e) => "${e.key}: ${e.value}").join(", ");

      String prompt =
          '''Basándote en las siguientes características del dispositivo: $deviceDetails,proporciona recomendaciones específicas y personalizadas para:1. Optimizar la duración de la batería.2. Mantener el rendimiento del dispositivo.3. Proteger el hardware.4. Gestionar el almacenamiento.Por favor, da recomendaciones concisas y prácticas.''';
      print(prompt);
      var response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Eres un experto en mantenimiento de dispositivos móviles que proporciona recomendaciones precisas y personalizadas.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );
      print(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        aiResponse = data['choices'][0]['message']['content'];
      } else {
        aiResponse = '';
      }
    } catch (e) {
      aiResponse = 'Error durante la solicitud: $e';
      print('Respuesta de la API: $aiResponse');
    } finally {
      if (aiResponse == '') {
        myResponse = await rootBundle.loadString('assets/recomendations.json');
        final jsonData = json.decode(myResponse);
        batteryR =
            jsonData['smartphone_care_tips']['battery']['recommendations'][0];
        ramR = jsonData['smartphone_care_tips']['ram']['recommendations'][0];
        screenR =
            jsonData['smartphone_care_tips']['screen']['recommendations'][0];
        storage =
            jsonData['smartphone_care_tips']['storage']['recommendations'][0];
        operatingSystem = jsonData['smartphone_care_tips']['operating_system']
            ['recommendations'][0];
        aiResponse =
            'Batería: $batteryR\n\nRam: $ramR\n\nPantalla: $screenR\n\nAlmacenamiento: $storage\n\nSistema Operativo: $operatingSystem';
      }
    }
    notifyListeners();
  }
}

class HeaderOfPage extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromRGBO(234, 227, 201, 1) // Color del fondo
      ..style = PaintingStyle.fill;

    final path = Path();
    path.lineTo(0, size.height * 1.0);
    path.lineTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width, size.height * 1.0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: must_be_immutable
class MyHomePage extends StatelessWidget {
  static const platform = MethodChannel('com.example.device/health');
  String? deviceYear;
  final TextEditingController yearController = TextEditingController();

  // Aquí colocamos el método sendYearToPython
  Future<void> sendYearToPython(BuildContext context, String year) async {
    try {
      // Datos que se enviarán al servidor
      final data = {
        'edad_dispositivo': int.parse(year), // Convierte el año a entero
        'estado_bateria': 80, // Ejemplo de datos adicionales
        'rendimiento': 90, // Ejemplo de datos adicionales
        'frecuencia_reparacion': 0 // Ejemplo de datos adicionales
      };

      // URL del servidor Python
      final url = Uri.parse('http://127.0.0.1:5000/predict');

      // Realizar la solicitud POST
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        // Manejar la respuesta
        final responseData = jsonDecode(response.body);
        final recommendation = responseData['recomendacion'];

        // Mostrar recomendación en la app
        print("Recomendación: $recommendation");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Recomendación: $recommendation")),
        );
      } else {
        // Manejar errores
        print("Error: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}")),
        );
      }
    } catch (e) {
      print("Error enviando datos al servidor: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error enviando datos al servidor: $e")),
      );
    }
  }

  Future<int> getBatteryHealth() async {
    try {
      final int result = await platform.invokeMethod('getBatteryHealth');
      return result;
    } on PlatformException catch (e) {
      print("Error obteniendo la salud de la batería: '${e.message}'.");
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(200), // Altura del AppBar
        child: CustomPaint(
          painter: HeaderOfPage(),
          child: AppBar(
            title: Image.asset(
              'assets/logo.png',
              height: 100,
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent, // Fondo transparente
            toolbarHeight: 200,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            FutureBuilder<Map<String, String>>(
              future: appState.getDeviceInfo(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return const Text(
                    'Error al obtener información del dispositivo',
                    style: TextStyle(
                      color: Color.fromRGBO(68, 0, 0, 1),
                    ),
                  );
                } else {
                  var deviceInfo = snapshot.data ?? {};
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device Information:',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromRGBO(68, 0, 0, 1),
                                ),
                          ),
                          const SizedBox(height: 10),
                          ...deviceInfo.entries.map((entry) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                '${entry.key}: ${entry.value}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            // Campo para ingresar el año de obtención del dispositivo
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Cuantos años llevas con el dispositivo",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final year = yearController.text; // Obtener el año ingresado
                if (year.isNotEmpty && int.tryParse(year) != null) {
                  sendYearToPython(context,
                      year); // Llama a la función para enviar los datos
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Por favor, ingresa un año válido.")),
                  );
                }
              },
              child: const Text("Enviar datos"),
            ),
            const SizedBox(height: 20),
            Text(
              appState.aiResponse,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
