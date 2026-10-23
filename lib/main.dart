
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meu Perfil',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const TelaPerfil(),
    );
  }
}

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  final TextEditingController nomeController =
      TextEditingController();

  final ImagePicker picker = ImagePicker();

  Uint8List? fotoBytes;
  String localizacao = 'Localização não obtida';
  bool carregandoLocalizacao = false;

  html.VideoElement? videoCamera;
  html.MediaStream? cameraStream;
  String? tipoVisualizacaoCamera;

  @override
  void initState() {
    super.initState();

    tipoVisualizacaoCamera =
        'camera-preview-${DateTime.now().microsecondsSinceEpoch}';

    videoCamera = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = '#111111';

    ui_web.platformViewRegistry.registerViewFactory(
      tipoVisualizacaoCamera!,
      (int viewId) => videoCamera!,
    );
  }

  Future<void> abrirCamera() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;

      if (mediaDevices == null) {
        mostrarMensagem(
          'Seu navegador não disponibiliza acesso à câmera.',
        );
        return;
      }

      cameraStream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
        },
        'audio': false,
      });

      videoCamera!.srcObject = cameraStream;
      await videoCamera!.play();

      if (!mounted) {
        fecharCamera();
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Tirar foto'),
            content: SizedBox(
              width: 420,
              height: 300,
              child: HtmlElementView(
                viewType: tipoVisualizacaoCamera!,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final foto = capturarFoto();

                  if (foto != null) {
                    setState(() {
                      fotoBytes = foto;
                    });

                    Navigator.of(dialogContext).pop();
                  }
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capturar foto'),
              ),
            ],
          );
        },
      );
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(
          'Não foi possível abrir a câmera. '
          'Verifique a permissão do Chrome.',
        );
      }
    } finally {
      fecharCamera();
    }
  }

  Uint8List? capturarFoto() {
    final video = videoCamera;

    if (video == null ||
        video.videoWidth == 0 ||
        video.videoHeight == 0) {
      mostrarMensagem('A câmera ainda está carregando.');
      return null;
    }

    final canvas = html.CanvasElement(
      width: video.videoWidth,
      height: video.videoHeight,
    );

    final contexto = canvas.context2D;
    contexto.drawImage(video, 0, 0);

    final imagemBase64 = canvas.toDataUrl('image/png');
    final dados = imagemBase64.split(',').last;

    return Uint8List.fromList(base64Decode(dados));
  }

  void fecharCamera() {
    cameraStream?.getTracks().forEach((track) {
      track.stop();
    });

    cameraStream = null;

    if (videoCamera != null) {
      videoCamera!.srcObject = null;
    }
  }

  Future<void> escolherGaleria() async {
    try {
      final XFile? imagem = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (imagem == null) return;

      final bytes = await imagem.readAsBytes();

      setState(() {
        fotoBytes = bytes;
      });
    } catch (erro) {
      mostrarMensagem('Não foi possível selecionar a imagem.');
    }
  }

  void removerFoto() {
    setState(() {
      fotoBytes = null;
    });
  }

  Future<void> obterLocalizacao() async {
    setState(() {
      carregandoLocalizacao = true;
    });

    try {
      final servicoAtivo =
          await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        setState(() {
          localizacao = 'Serviço de localização desativado';
        });
        return;
      }

      LocationPermission permissao =
          await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        setState(() {
          localizacao = 'Permissão de localização negada';
        });
        return;
      }

      final posicao = await Geolocator.getCurrentPosition();

      setState(() {
        localizacao =
            'Latitude: ${posicao.latitude.toStringAsFixed(4)}\n'
            'Longitude: ${posicao.longitude.toStringAsFixed(4)}';
      });
    } catch (erro) {
      setState(() {
        localizacao = 'Não foi possível obter a localização';
      });
    } finally {
      if (mounted) {
        setState(() {
          carregandoLocalizacao = false;
        });
      }
    }
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  void dispose() {
    fecharCamera();
    nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          'Meu Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 5,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 75,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: fotoBytes != null
                          ? MemoryImage(fotoBytes!)
                          : null,
                      child: fotoBytes == null
                          ? Icon(
                              Icons.person,
                              size: 85,
                              color: Colors.blue.shade700,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Meu perfil',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: abrirCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tirar foto'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: escolherGaleria,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Escolher da galeria'),
                      ),
                    ),
                    if (fotoBytes != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: removerFoto,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remover foto'),
                      ),
                    ],
                    const Divider(height: 36),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Minha localização',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.blue.shade700,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              localizacao,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: carregandoLocalizacao
                            ? null
                            : obterLocalizacao,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          carregandoLocalizacao
                              ? 'Obtendo localização...'
                              : 'Obter minha localização',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
