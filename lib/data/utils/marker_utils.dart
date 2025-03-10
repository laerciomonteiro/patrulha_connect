import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> createCustomMarker(String title, Color color) async {
  const iconSize = 150.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Carrega e desenha a imagem da viatura
  final image = await loadImage('assets/images/viatura.png');
  final imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final scale = iconSize / imageSize.width;
  final scaledSize = Size(imageSize.width * scale, imageSize.height * scale);
  final offset = Offset(
    (iconSize - scaledSize.width) / 2,
    (iconSize - scaledSize.height) / 2,
  );

  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, imageSize.width, imageSize.height),
    Rect.fromLTWH(offset.dx, offset.dy, scaledSize.width, scaledSize.height),
    Paint(),
  );

  // Configuração do texto com fundo branco
  final textStyle = TextStyle(
    color: Colors.black,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  final textPainter = TextPainter(
    text: TextSpan(text: title, style: textStyle),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout();

  // Calcula a posição do texto (40 pixels abaixo do centro da imagem)
  final textOffset = Offset(
    iconSize / 2 - textPainter.width / 2,
    iconSize / 2 - textPainter.height / 2 + 40,
  );

  // Desenha o fundo branco atrás do texto
  final backgroundRect = Rect.fromLTWH(
    textOffset.dx - 4, // Padding horizontal
    textOffset.dy - 2, // Padding vertical
    textPainter.width + 8, // Largura do texto + padding
    textPainter.height + 4, // Altura do texto + padding
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
    Paint()..color = Colors.white,
  );

  // Desenha o texto por cima do fundo
  textPainter.paint(canvas, textOffset);

  // Converte para BitmapDescriptor
  final renderedImage = await recorder.endRecording().toImage(iconSize.toInt(), iconSize.toInt());
  final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}

Future<ui.Image> loadImage(String assetPath) async {
  final byteData = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}