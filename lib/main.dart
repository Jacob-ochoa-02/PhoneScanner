import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:convert';

void main() {
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
  var current = WordPair.random();
  String aiResponse = '';
  Future<Map<String, String>> getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    Map<String, String> deviceData = {};

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceData['Brand'] = androidInfo.brand ?? 'Unknown';
      deviceData['Model'] = androidInfo.model ?? 'Unknown';
      deviceData['Device'] = androidInfo.device ?? 'Unknown';
      deviceData['Hardware'] = androidInfo.hardware ?? 'Unknown';
      deviceData['Android Version'] = androidInfo.version.release ?? 'Unknown';
      deviceData['Screen'] = androidInfo.display ?? 'Unknown';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceData['Modelo'] = iosInfo.utsname.machine ?? 'Unknown';
      deviceData['Nombre'] = iosInfo.name ?? 'Unknown';
      deviceData['Sistema Operativo'] = iosInfo.systemName ?? 'Unknown';
      deviceData['Versión'] = iosInfo.systemVersion ?? 'Unknown';
    }
    return deviceData;
  }

  Future<void> fetchAIResponse() async {
    const apiKey =
        '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'; // Reemplaza con tu API key
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Obtener la información del dispositivo
        Map<String, String> deviceInfo = await getDeviceInfo();
        String deviceDetails =
            deviceInfo.entries.map((e) => "${e.key}: ${e.value}").join(", ");

        String prompt = '''
        Basándote en las siguientes características del dispositivo: $deviceDetails,
        proporciona recomendaciones específicas y personalizadas para:
        1. Optimizar la duración de la batería
        2. Mantener el rendimiento del dispositivo
        3. Proteger el hardware
        4. Gestionar el almacenamiento
        Por favor, da recomendaciones concisas y prácticas.
      ''';

        final response = await http.post(
          url,
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

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String aiResponse = data['choices'][0]['message']['content'];
          // Actualizar el estado con la respuesta
          notifyListeners();
          return;
        } else {
          print('Error en la solicitud: ${response.statusCode}');
          print('Respuesta: ${response.body}');
          retryCount++;
          await Future.delayed(
              Duration(seconds: 2 * retryCount)); // Espera exponencial
        }
      } catch (e) {
        print('Error durante la solicitud: $e');
        retryCount++;
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }

    // Si llegamos aquí, todos los intentos fallaron
    aiResponse =
        'No se pudieron obtener recomendaciones después de $maxRetries intentos.';
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

class MyHomePage extends StatelessWidget {
  static const platform = MethodChannel('com.example.device/health');

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
            backgroundColor: Colors
                .transparent, // Fondo transparente para mostrar el CustomPaint
            toolbarHeight: 200,
          ),
        ),
      ),
      body: Padding(
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
            ElevatedButton(
              onPressed: () {
                context.read<MyAppState>().fetchAIResponse();
              },
              child: const Text("Get AI Response"),
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

class DeviceHealth {}
