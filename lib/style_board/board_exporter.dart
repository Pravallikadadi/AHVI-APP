import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BoardExporter {
  static Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    final ctx = boundaryKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;

    if (ro.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    final ui.Image image = await ro.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  static Future<File?> writeToTempFile(
    Uint8List bytes, {
    String filename = 'ahvi_look.png',
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareBoard(
    GlobalKey boundaryKey, {
    String? subject,
    String? text,
  }) async {
    final bytes = await capturePng(boundaryKey);
    if (bytes == null) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = await writeToTempFile(bytes, filename: 'ahvi_look_$ts.png');
    if (file == null) return;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: subject ?? 'AHVI Look',
      text: text,
    );
  }
}
