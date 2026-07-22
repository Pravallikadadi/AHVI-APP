import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum AhviSpeechState { idle, initializing, listening, stopping, error }

class AhviSpeechService {
  AhviSpeechService._();

  static final AhviSpeechService instance = AhviSpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  AhviSpeechState _state = AhviSpeechState.idle;
  VoidCallback? _activeOnDone;

  bool get isListening => _state == AhviSpeechState.listening;
  AhviSpeechState get state => _state;

  Future<bool> ensureReady() async {
    if (_initialized) return true;

    if (_state == AhviSpeechState.initializing) {
      while (_state == AhviSpeechState.initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return _initialized;
    }

    _state = AhviSpeechState.initializing;

    try {
      final permission = await Permission.microphone.request();

      if (!permission.isGranted) {
        debugPrint('AHVI_STT microphone permission denied');
        _state = AhviSpeechState.error;
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
      _state = _initialized ? AhviSpeechState.idle : AhviSpeechState.error;
      return _initialized;
    } catch (e) {
      debugPrint('AHVI_STT initialize exception=$e');
      _initialized = false;
      _state = AhviSpeechState.error;
      return false;
    } finally {
      if (_state == AhviSpeechState.initializing) {
        _state = _initialized ? AhviSpeechState.idle : AhviSpeechState.error;
      }
    }
  }

  // `_speech.listen()` ప్రారంభమయ్యే ప్రతి session కీ `result.recognizedWords`
  // ఆ SESSION లోపలి cumulative transcript మాత్రమే (mic ఆఫ్ చేసి మళ్ళీ ఆన్
  // చేస్తే, ఇది మళ్ళీ '' నుండి start అవుతుంది) — ఫీల్డ్‌లో ఇప్పటికే ఉన్న
  // పాత టెక్స్ట్ గురించి ఈ package కి తెలియదు. కాబట్టి mic restart అయిన
  // ప్రతిసారి `existingText` (ఆ time కి controller/field లో ఉన్న text) ని
  // ఇక్కడ base గా పట్టుకుని, ప్రతి onResult callback లోనూ
  // `existingText + ఈ session transcript` గా కలిపి `onText`కి పంపిస్తాం.
  // దీనివల్ల caller ఎప్పుడూ `onText(combinedText)` ని నేరుగా
  // `controller.text = combinedText` గా వాడినా, పాత text పోకుండా
  // కొత్త voice input దాని మీద append అవుతుంది (replace అవ్వదు).
  Future<void> start({
    required ValueChanged<String> onText,
    VoidCallback? onDone,
    String existingText = '',
  }) async {
    if (_state == AhviSpeechState.initializing) {
      while (_state == AhviSpeechState.initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }

    if (_state == AhviSpeechState.stopping) return;

    final ready = await ensureReady();
    if (!ready) {
      return;
    }

    if (_state == AhviSpeechState.listening) {
      await stop();
    }

    _state = AhviSpeechState.listening;
    _activeOnDone = onDone;

    final baseText = existingText.trim();

    try {
      await _speech.listen(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        onResult: (result) {
          final sessionText = result.recognizedWords.trim();

          if (sessionText.isNotEmpty) {
            final combined = baseText.isEmpty
                ? sessionText
                : '$baseText $sessionText';
            onText(combined);
          }

          if (result.finalResult) {
            _markDone();
          }
        },
      );
    } catch (e) {
      debugPrint('AHVI_STT listen exception=$e');
      _state = AhviSpeechState.error;
      _markDone();
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;
    if (_state == AhviSpeechState.stopping) return;
    _state = AhviSpeechState.stopping;

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
    if (_state == AhviSpeechState.stopping) return;
    _state = AhviSpeechState.stopping;

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
    if (_state != AhviSpeechState.error) {
      _state = AhviSpeechState.idle;
    }
    done?.call();
  }
}