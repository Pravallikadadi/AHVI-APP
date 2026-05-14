import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AhviSpeechService {
  AhviSpeechService._();

  static final AhviSpeechService instance = AhviSpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  bool _initializing = false;
  bool _starting = false;
  bool _listening = false;
  VoidCallback? _activeOnDone;

  bool get isListening => _listening;

  Future<bool> ensureReady() async {
    if (_initialized) return true;

    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return _initialized;
    }

    _initializing = true;

    try {
      final permission = await Permission.microphone.request();

      if (!permission.isGranted) {
        debugPrint('AHVI_STT microphone permission denied');
        return false;
      }

      _initialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('AHVI_STT status=$status');

          if (status == 'done' || status == 'notListening') _markDone();
        },
        onError: (error) {
          debugPrint('AHVI_STT error=$error');
          _markDone();
        },
      );

      debugPrint('AHVI_STT initialized=$_initialized');
      return _initialized;
    } catch (e) {
      debugPrint('AHVI_STT initialize exception=$e');
      _initialized = false;
      return false;
    } finally {
      _initializing = false;
    }
  }

  Future<void> start({
    required ValueChanged<String> onText,
    VoidCallback? onDone,
  }) async {
    if (_starting) {
      while (_starting) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }

    _starting = true;

    final ready = await ensureReady();
    if (!ready) {
      _starting = false;
      return;
    }

    if (_listening) {
      await stop();
    }

    _listening = true;
    _activeOnDone = onDone;

    try {
      await _speech.listen(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        onResult: (result) {
          final text = result.recognizedWords.trim();

          if (text.isNotEmpty) {
            onText(text);
          }

          if (result.finalResult) {
            _markDone();
          }
        },
      );
    } catch (e) {
      debugPrint('AHVI_STT listen exception=$e');
      _markDone();
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;

    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('AHVI_STT stop exception=$e');
    } finally {
      _markDone();
    }
  }

  Future<void> cancel() async {
    if (!_initialized) return;

    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('AHVI_STT cancel exception=$e');
    } finally {
      _markDone();
    }
  }

  void _markDone() {
    final done = _activeOnDone;
    _activeOnDone = null;
    _listening = false;
    done?.call();
  }
}
