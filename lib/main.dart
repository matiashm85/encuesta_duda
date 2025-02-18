import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  _setupLogging();
  tz.initializeTimeZones();
  runApp(const EncuestaApp());
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

class EncuestaApp extends StatelessWidget {
  const EncuestaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const EncuestaScreen(),
    );
  }
}

class EncuestaScreen extends StatefulWidget {
  const EncuestaScreen({Key? key}) : super(key: key);

  @override
  _EncuestaScreenState createState() => _EncuestaScreenState();
}

class _EncuestaScreenState extends State<EncuestaScreen>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger('EncuestaScreen');

  final List<String> preguntas = const [
    "¿Qué te pareció la música?",
    "¿Qué te pareció el servicio?",
    "¿Qué te pareció la bebida?",
    "¿Cómo calificas la limpieza del bar?",
    "¿Cómo fue tu experiencia general?"
  ];

  late String preguntaActual;
  final Random random = Random();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    preguntaActual = preguntas[random.nextInt(preguntas.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

 Future<void> enviarRespuesta(String respuesta) async {
  final location = tz.getLocation('America/La_Paz');
  final now = tz.TZDateTime.now(location);
  String fechaHora = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  final url = Uri.parse("https://script.google.com/macros/s/AKfycbxPx8womoPymIWh1jWgkNaXgdtKmocuTP2haV5peIqSEp7Keuok7TDr5jSe4SexECLZ/exec");

  _logger.info("Enviando respuesta: $respuesta");
  _logger.info("Fecha y hora: $fechaHora");
  _logger.info("URL: $url");

  try {
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",  // Permitir CORS
      },
      body: jsonEncode({
        "fecha": fechaHora.split(' ')[0],
        "hora": fechaHora.split(' ')[1],
        "pregunta": preguntaActual,
        "respuesta": respuesta,
      }),
    );

    _logger.info("HTTP status code: ${response.statusCode}");
    _logger.info("HTTP response body: ${response.body}");

    if (response.statusCode == 200) {
      _logger.info("Respuesta guardada correctamente.");
    } else {
      _logger.severe("Error al guardar la respuesta: ${response.statusCode}");
    }
  } catch (e) {
    _logger.severe("Error al enviar la respuesta: $e");
  }
}


  void registrarRespuesta(String respuesta) {
    enviarRespuesta(respuesta);
    _logger.info("Registro: Pregunta: $preguntaActual, Respuesta: $respuesta");

    _controller.forward().then((_) {
      setState(() {
        String nuevaPregunta;
        do {
          nuevaPregunta = preguntas[random.nextInt(preguntas.length)];
        } while (nuevaPregunta == preguntaActual && preguntas.length > 1);
        preguntaActual = nuevaPregunta;
      });
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    double buttonSize = min(MediaQuery.of(context).size.width * 0.25, 200);
    double logoSize = MediaQuery.of(context).size.width * 0.18;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HeaderWidget(logoSize: logoSize, maxWidth: constraints.maxWidth),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: QuestionContainer(
                      pregunta: preguntaActual,
                      width: constraints.maxWidth * 0.9,
                      fontSize: constraints.maxWidth * 0.05 * 0.7,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EncuestaBoton(texto: "MAL", color: Colors.red, onPressed: () => registrarRespuesta("MAL"), size: buttonSize),
                      const SizedBox(width: 100),
                      EncuestaBoton(texto: "REGULAR", color: Colors.yellow, onPressed: () => registrarRespuesta("REGULAR"), size: buttonSize),
                      const SizedBox(width: 100),
                      EncuestaBoton(texto: "BIEN", color: Colors.green, onPressed: () => registrarRespuesta("BIEN"), size: buttonSize),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class HeaderWidget extends StatelessWidget {
  final double logoSize;
  final double maxWidth;
  const HeaderWidget({Key? key, required this.logoSize, required this.maxWidth}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/logo.png', height: logoSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "TU OPINIÓN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: maxWidth * 0.08,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                "vale más que 1000 comentarios en redes sociales",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: maxWidth * 0.014,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Image.asset('assets/logo.png', height: logoSize),
      ],
    );
  }
}

class QuestionContainer extends StatelessWidget {
  final String pregunta;
  final double width;
  final double fontSize;
  const QuestionContainer({Key? key, required this.pregunta, required this.width, required this.fontSize})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Text(
        pregunta,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class EncuestaBoton extends StatefulWidget {
  final String texto;
  final Color color;
  final VoidCallback onPressed;
  final double size;

  const EncuestaBoton({Key? key, required this.texto, required this.color, required this.onPressed, required this.size})
      : super(key: key);

  @override
  _EncuestaBotonState createState() => _EncuestaBotonState();
}

class _EncuestaBotonState extends State<EncuestaBoton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
        _animationController = AnimationController(
          duration: const Duration(milliseconds: 100),
          vsync: this,
          lowerBound: 0.9,
        );
        _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_animationController);
      }
    
      @override
      void dispose() {
        _animationController.dispose();
        super.dispose();
      }
    
      @override
      Widget build(BuildContext context) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) {
              _animationController.reverse();
              widget.onPressed();
            },
            onTapCancel: () => _animationController.reverse(),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.texto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }