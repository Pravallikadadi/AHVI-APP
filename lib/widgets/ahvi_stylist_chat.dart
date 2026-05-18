import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/services/backend_service.dart';
import 'package:myapp/widgets/ahvi_chat_prompt_bar.dart';
import 'package:myapp/widgets/ahvi_home_text.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:provider/provider.dart';

// ════════════════════════════════════════════════════════════════════
//  ATTACHMENT MODEL
// ════════════════════════════════════════════════════════════════════

class Attachment {
  final String label;
  final File? file;
  final String? mimeType;
  final bool isWebSearch;
  final String? searchQuery;

  const Attachment({
    required this.label,
    this.file,
    this.mimeType,
    this.isWebSearch = false,
    this.searchQuery,
  });

  bool get isImage {
    if (mimeType != null) return mimeType!.startsWith('image/');
    if (file == null) return false;
    return (lookupMimeType(file!.path) ?? '').startsWith('image/');
  }

  IconData get icon {
    if (isWebSearch) return Icons.travel_explore_rounded;
    if (isImage) return Icons.image_outlined;
    final m = mimeType ?? lookupMimeType(file?.path ?? '') ?? '';
    if (m.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (m.contains('word') || label.endsWith('.docx'))
      return Icons.description_outlined;
    if (m.contains('sheet') ||
        label.endsWith('.xlsx') ||
        label.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

// ════════════════════════════════════════════════════════════════════
//  MODULE CONFIG  — ప్రతి screen కి context, prompts, subtitle
// ════════════════════════════════════════════════════════════════════

class AhviModuleConfig {
  final String moduleContext;
  final String subtitle;
  final String hintTextKey;
  final String greetingKey;
  final List<String> Function(BuildContext) quickPrompts;

  const AhviModuleConfig({
    required this.moduleContext,
    required this.subtitle,
    required this.hintTextKey,
    required this.greetingKey,
    required this.quickPrompts,
  });
}

/// అన్ని screens కి configs — moduleContext తో match అవుతాయి
final Map<String, AhviModuleConfig> _moduleConfigs = {
  'style': AhviModuleConfig(
    moduleContext: 'style',
    subtitle: 'AI Stylist',
    hintTextKey: 'daily_wear_chat_hint',
    greetingKey: 'chat_greeting',
    quickPrompts: (ctx) => [
      AppLocalizations.t(ctx, 'wear_chip_today'),
      AppLocalizations.t(ctx, 'wear_chip_style_tips'),
      AppLocalizations.t(ctx, 'wear_chip_first_date'),
      AppLocalizations.t(ctx, 'wear_chip_linen'),
      AppLocalizations.t(ctx, 'wear_chip_colours'),
    ],
  ),
  'skincare': AhviModuleConfig(
    moduleContext: 'skincare',
    subtitle: 'Skincare Assistant',
    hintTextKey: 'daily_wear_chat_hint',
    greetingKey: 'chat_greeting',
    quickPrompts: (ctx) => [
      'Morning routine tips',
      'Best SPF for my skin',
      'Night skincare steps',
      'Acne care advice',
      'Hydration routine',
    ],
  ),
  'medi': AhviModuleConfig(
    moduleContext: 'medi',
    subtitle: 'Medicine Assistant',
    hintTextKey: 'daily_wear_chat_hint',
    greetingKey: 'chat_greeting',
    quickPrompts: (ctx) => [
      'My medicines today',
      'Missed dose — what to do?',
      'Drug interactions?',
      'Set a reminder',
      'Add new medicine',
    ],
  ),
  'bills': AhviModuleConfig(
    moduleContext: 'bills',
    subtitle: 'Bills Assistant',
    hintTextKey: 'daily_wear_chat_hint',
    greetingKey: 'chat_greeting',
    quickPrompts: (ctx) => [
      'Pending bills',
      'Total this month',
      'Add a bill',
      'Best category?',
      'Scan receipt',
    ],
  ),
  'diet': AhviModuleConfig(
    moduleContext: 'diet',
    subtitle: 'Diet & Nutrition Assistant',
    hintTextKey: 'diet_chat_hint',
    greetingKey: 'diet_chat_welcome',
    quickPrompts: (ctx) => [
      'Weekly keto plan',
      'High protein meals',
      'Vegan meal ideas',
      'Calorie count today',
      'Mediterranean diet',
    ],
  ),
  'fitness': AhviModuleConfig(
    moduleContext: 'fitness',
    subtitle: 'Fitness Coach',
    hintTextKey: 'daily_wear_chat_hint',
    greetingKey: 'chat_greeting',
    quickPrompts: (ctx) => [
      'Today\'s workout',
      'Beginner plan',
      'Lose weight fast',
      'Home exercises',
      'Rest day tips',
    ],
  ),
  'wardrobe': AhviModuleConfig(
    moduleContext: 'wardrobe',
    subtitle: 'Wardrobe Stylist',
    hintTextKey: 'daily_wear_chat_hint',
    greetingKey: 'chat_greeting',
    quickPrompts: (ctx) => [
      'Outfit for today',
      'Style capsule wardrobe',
      'What to buy next?',
      'Color combinations',
      'Wardrobe detox tips',
    ],
  ),
};

AhviModuleConfig _configFor(String moduleContext) =>
    _moduleConfigs[moduleContext] ?? _moduleConfigs['style']!;

// ════════════════════════════════════════════════════════════════════
//  PUBLIC API — showAhviStylistChatSheet (same as before, + moduleContext)
// ════════════════════════════════════════════════════════════════════

/// ఏ screen నుండైనా ఇలా call చేయండి:
///   showAhviStylistChatSheet(context, moduleContext: 'bills')
///   showAhviStylistChatSheet(context, moduleContext: 'skincare')
///   showAhviStylistChatSheet(context)  // default: 'style'
Future<void> showAhviStylistChatSheet(
  BuildContext context, {
  String moduleContext = 'style',
  Map<String, dynamic> contextData = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final screenH = MediaQuery.of(ctx).size.height;
      final topPad = MediaQuery.of(ctx).padding.top;
      final kbH = MediaQuery.of(ctx).viewInsets.bottom;
      final sheetH = (screenH - topPad) * 0.92;
      return Padding(
        padding: EdgeInsets.only(bottom: kbH),
        child: SizedBox(
          height: sheetH,
          child: _AhviStylistChatSheet(
            moduleContext: moduleContext,
            contextData: contextData,
            rootContext: context,
          ),
        ),
      );
    },
  );
}

// ════════════════════════════════════════════════════════════════════
//  FAB WIDGET  — same as before, unchanged
// ════════════════════════════════════════════════════════════════════

class AhviStylistFab extends StatefulWidget {
  final VoidCallback onTap;

  const AhviStylistFab({super.key, required this.onTap});

  @override
  State<AhviStylistFab> createState() => _AhviStylistFabState();
}

class _AhviStylistFabState extends State<AhviStylistFab> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 22, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [t.accent.secondary, t.accent.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: t.accent.primary.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: t.accent.secondary.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.20),
                child: const Text('✦', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(context, 'ask_ahvi'),
                    style: GoogleFonts.anton(
                      fontSize: 13,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CHAT HISTORY MODEL
// ════════════════════════════════════════════════════════════════════

class _ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<_SheetMessage> messages;

  _ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}

// ════════════════════════════════════════════════════════════════════
//  SHEET WIDGET  — universal, module-aware
// ════════════════════════════════════════════════════════════════════

class _AhviStylistChatSheet extends StatefulWidget {
  final String moduleContext;
  final Map<String, dynamic> contextData;
  final BuildContext rootContext;

  const _AhviStylistChatSheet({
    this.moduleContext = 'style',
    this.contextData = const {},
    required this.rootContext,
  });

  @override
  State<_AhviStylistChatSheet> createState() => _AhviStylistChatSheetState();
}

class _AhviStylistChatSheetState extends State<_AhviStylistChatSheet>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_SheetMessage> _messages = [];
  final List<Map<String, String>> _chatHistory = [];
  String _runningMemory = '';
  bool _typing = false;
  bool _chipsVisible = true;
  bool _chatHasText = false;
  Attachment? _pendingAttachment;

  final List<_ChatSession> _history = [];
  String? _currentSessionId;

  AhviModuleConfig get _config => _configFor(widget.moduleContext);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _chatHasText && mounted) {
        setState(() => _chatHasText = hasText);
      }
    });
    // Keyboard వచ్చినప్పుడు scroll to bottom
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
    Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _messages.isNotEmpty) return;
      setState(() {
        _messages.add(
          _SheetMessage(textKey: _config.greetingKey, isUser: false),
        );
      });
    });
  }

  void _saveCurrentSession() {
    if (_messages.isEmpty) return;
    final userMessages = _messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;
    final rawText = userMessages.first.text ?? '';
    final title = rawText.length > 40
        ? '${rawText.substring(0, 40)}…'
        : rawText;
    final existingIdx = _history.indexWhere((s) => s.id == _currentSessionId);
    final session = _ChatSession(
      id: _currentSessionId!,
      title: title,
      createdAt: DateTime.now(),
      messages: List.from(_messages),
    );
    if (existingIdx != -1) {
      _history[existingIdx] = session;
    } else {
      _history.insert(0, session);
    }
  }

  void _startNewChat() {
    _saveCurrentSession();
    Navigator.of(context).pop();
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _chatHistory.clear();
      _runningMemory = '';
      _chipsVisible = true;
      _chatHasText = false;
      _inputController.clear();
      _messages.add(_SheetMessage(textKey: _config.greetingKey, isUser: false));
    });
  }

  void _loadSession(_ChatSession session) {
    _saveCurrentSession();
    Navigator.of(context).pop();
    setState(() {
      _currentSessionId = session.id;
      _messages
        ..clear()
        ..addAll(session.messages);
      _chatHistory
        ..clear()
        ..addAll(
          session.messages
              .map(
                (m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.resolve(context),
                },
              )
              .where((m) => (m['content'] ?? '').trim().isNotEmpty),
        );
      _chipsVisible = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputFocusNode.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {}); // bottomInset re-read కావాలంటే rebuild కావాలి
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Attachment helpers ────────────────────────────────────────────

  void _setPendingAttachment(Attachment a) {
    if (mounted) setState(() => _pendingAttachment = a);
  }

  void _clearPendingAttachment() {
    if (mounted) setState(() => _pendingAttachment = null);
  }

  Future<void> _openAttachment(Attachment att) async {
    if (att.isWebSearch && att.searchQuery != null) {
      final uri = Uri.parse(att.searchQuery!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (att.file != null) await OpenFilex.open(att.file!.path);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'docx',
          'doc',
          'txt',
          'csv',
          'xlsx',
          'xls',
          'pptx',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final pf = result.files.first;
      if (pf.path == null) return;
      _setPendingAttachment(
        Attachment(
          label: pf.name,
          file: File(pf.path!),
          mimeType: lookupMimeType(pf.path!) ?? 'application/octet-stream',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File pick చేయడం సాధ్యపడలేదు'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xfile == null) return;
      _setPendingAttachment(
        Attachment(
          label: xfile.name,
          file: File(xfile.path),
          mimeType: lookupMimeType(xfile.path) ?? 'image/jpeg',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo select చేయడం సాధ్యపడలేదు'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? xfile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xfile == null) return;
      _setPendingAttachment(
        Attachment(
          label: 'Photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
          file: File(xfile.path),
          mimeType: lookupMimeType(xfile.path) ?? 'image/jpeg',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera తెరవడం సాధ్యపడలేదు'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openWebSearchSheet() {
    // Inherit the exact theme from the current context into the modal —
    // this guarantees dark/light tokens are preserved inside the sheet.
    final parentTheme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: parentTheme,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: _WebSearchSheet(
              onSearch: (query) {
                Navigator.pop(ctx);
                _setPendingAttachment(
                  Attachment(
                    label: 'Search: "\$query"',
                    isWebSearch: true,
                    searchQuery:
                        'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
                  ),
                );
              },
              onCancel: () => Navigator.pop(ctx),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && _pendingAttachment == null) return;
    if (_typing) return;
    final attachment = _pendingAttachment;
    final prompt = [
      if (trimmed.isNotEmpty) trimmed,
      if (attachment != null)
        attachment.isImage
            ? 'I attached an image named ${attachment.label}. Use it as visual context if available.'
            : 'I attached ${attachment.label}. Use it as context if available.',
    ].join('\n');
    _inputController.clear();
    setState(() {
      _chipsVisible = false;
      _typing = true;
      _pendingAttachment = null;
      if (trimmed.isNotEmpty) {
        _messages.add(_SheetMessage(text: trimmed, isUser: true));
        _chatHistory.add({'role': 'user', 'content': trimmed});
      }
      if (attachment != null) {
        _messages.add(
          _SheetMessage(
            text: attachment.isWebSearch
                ? '🔍 ${attachment.label}'
                : attachment.isImage
                ? '🖼 ${attachment.label}'
                : '📎 ${attachment.label}',
            isUser: true,
          ),
        );
      }
    });
    _scrollToBottom();

    try {
      final backend = Provider.of<BackendService>(context, listen: false);
      final query = prompt.isNotEmpty ? prompt : trimmed;
      final styleModules = {'style', 'wardrobe', 'daily_wear'};
      final response = styleModules.contains(widget.moduleContext)
          ? await backend.sendChatQuery(
              query,
              '',
              List<Map<String, String>>.from(_chatHistory),
              _runningMemory,
              moduleContext: widget.moduleContext == 'daily_wear'
                  ? 'style'
                  : widget.moduleContext,
            )
          : await backend.sendModuleChat(
              domain: widget.moduleContext,
              message: query,
              chatHistory: List<Map<String, String>>.from(_chatHistory),
              context: widget.contextData,
            );
      if (!mounted) return;

      final rawMessage = response['message'];
      final message =
          (response['message_text'] ??
                  (rawMessage is Map ? rawMessage['content'] : rawMessage) ??
                  '')
              .toString()
              .trim();
      final aiText = message.isNotEmpty
          ? message
          : 'AHVI returned an empty response. Please try again.';

      final updatedMemory = response['updated_memory'];
      if (updatedMemory != null) _runningMemory = updatedMemory.toString();
      final boardPayload = _StyleBoardPayload.fromResponse(response);
      final gapPayload = _WardrobeGapPayload.fromResponse(response);

      setState(() {
        _typing = false;
        _messages.add(
          _SheetMessage(
            text: gapPayload.active && gapPayload.message.trim().isNotEmpty
                ? gapPayload.message.trim()
                : aiText,
            isUser: false,
            boardPayload: boardPayload.hasBoards && !gapPayload.hasContent
                ? boardPayload
                : null,
            wardrobeGapPayload: gapPayload.hasContent ? gapPayload : null,
          ),
        );
        _chatHistory.add({
          'role': 'assistant',
          'content': gapPayload.active && gapPayload.message.trim().isNotEmpty
              ? gapPayload.message.trim()
              : aiText,
        });
      });
      _scrollToBottom();
      _saveCurrentSession();
    } catch (err) {
      if (!mounted) return;
      final fallback = 'AHVI request failed: $err';
      setState(() {
        _typing = false;
        _messages.add(_SheetMessage(text: fallback, isUser: false));
        _chatHistory.add({'role': 'assistant', 'content': fallback});
      });
      _scrollToBottom();
      _saveCurrentSession();
    }
  }

  /// Module context బట్టి reply customize చేయండి.
  /// Backend connect అయినప్పుడు ఇక్కడ API call చేయండి.
  String _buildReply(BuildContext context, String query) {
    final q = query.toLowerCase();
    final module = widget.moduleContext;

    // Module-specific replies
    if (module == 'bills') {
      if (q.contains('pending') || q.contains('bill')) {
        return 'You have 3 pending bills this month. Total: ₹13,248. Want details?';
      }
      if (q.contains('scan') || q.contains('receipt')) {
        return 'Tap the + button → Scan Receipt to capture your bill with the camera!';
      }
      if (q.contains('add')) {
        return 'Tap the + button → Camera or Files to add a new bill!';
      }
      return 'I can help you track bills, scan receipts, and manage spending. What would you like?';
    }

    if (module == 'skincare') {
      if (q.contains('morning') || q.contains('routine')) {
        return 'Your morning routine: Cleanser → Vitamin C serum → Moisturiser → SPF 50. Takes about 5 minutes!';
      }
      if (q.contains('spf') || q.contains('sunscreen')) {
        return 'For Indian skin, SPF 50 PA+++ is ideal. Try Biore UV or Re\'equil Sun Protect.';
      }
      if (q.contains('acne')) {
        return 'For acne: Use salicylic acid cleanser, niacinamide serum, and avoid heavy moisturisers during the day.';
      }
      return 'I can guide your skincare routine, product picks, and skin concerns. Ask away!';
    }

    if (module == 'medi') {
      if (q.contains('today') || q.contains('medicine') || q.contains('dose')) {
        return 'Today\'s medicines: Vitamin D3 (08:00 ✓), Iron Supplement (13:00 ✓), Omega-3 (20:00 pending).';
      }
      if (q.contains('missed') || q.contains('forgot')) {
        return 'If you missed a dose, take it as soon as you remember — unless it\'s almost time for the next one. Never double dose.';
      }
      if (q.contains('reminder')) {
        return 'Tap the bell icon on any medicine to set a reminder. I\'ll notify you on time!';
      }
      return 'I can help with medicine tracking, reminders, and dose schedules. What do you need?';
    }

    if (module == 'diet') {
      if (q.contains('keto')) {
        return 'Keto plan: Keep carbs under 20g/day. Focus on eggs, meat, nuts, avocado, and leafy greens. Want a weekly plan?';
      }
      if (q.contains('protein') || q.contains('high protein')) {
        return 'High protein meals: Paneer bhurji, eggs, dal, chicken, and Greek yogurt. Aim for 1.6g per kg of body weight.';
      }
      if (q.contains('vegan')) {
        return 'Vegan plan: Lentils, chickpeas, tofu, quinoa, nuts, and seeds cover all essential nutrients!';
      }
      return 'I can build meal plans, track calories, and suggest recipes. What\'s your goal?';
    }

    if (module == 'fitness') {
      if (q.contains('today') || q.contains('workout')) {
        return 'Today\'s plan: Warm-up (10 min) → Squats 4×12 → Lunges 3×15 → Plank 3×45s. Ready to go?';
      }
      if (q.contains('beginner')) {
        return 'Beginner plan: Start with 3 days/week. Day 1: Upper body. Day 2: Lower body. Day 3: Full body or cardio.';
      }
      if (q.contains('home') || q.contains('no gym')) {
        return 'Home workout: Push-ups, squats, lunges, plank, and mountain climbers — no equipment needed!';
      }
      return 'I can design workout plans, track progress, and give exercise tips. What\'s your fitness goal?';
    }

    if (module == 'wardrobe') {
      if (q.contains('today') || q.contains('outfit')) {
        return AppLocalizations.t(context, 'ai_sug_4');
      }
      if (q.contains('capsule') || q.contains('minimal')) {
        return 'Capsule wardrobe: 5 whites, 3 neutrals, 2 black trousers, 1 blazer, 2 jeans. Mix and match 20+ looks!';
      }
      return AppLocalizations.t(context, 'ai_sug_4');
    }

    // Default / style fallback
    if (q.contains('wear') || q.contains('outfit')) {
      return AppLocalizations.t(context, 'ai_sug_4');
    }
    if (q.contains('routine') || q.contains('skin')) {
      return AppLocalizations.t(context, 'ai_sug_2');
    }
    if (q.contains('plan') || q.contains('meal') || q.contains('workout')) {
      return AppLocalizations.t(context, 'ai_sug_3');
    }
    return AppLocalizations.t(context, 'chat_greeting');
  }

  // ── History Panel (custom in-sheet slide-in, replaces Flutter Drawer) ──
  bool _drawerOpen = false;

  void _openDrawer() => setState(() => _drawerOpen = true);
  void _closeDrawer() => setState(() => _drawerOpen = false);

  Widget _historyPanel() {
    final t = context.themeTokens;
    return AnimatedSlide(
      offset: _drawerOpen ? Offset.zero : const Offset(-1, 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _drawerOpen ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.80,
          decoration: BoxDecoration(
            color: t.backgroundPrimary,
            border: Border(right: BorderSide(color: t.cardBorder, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header — aligned with chat header ────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.t(context, 'common_chats'),
                      style: GoogleFonts.anton(
                        fontSize: 22,
                        color: t.textPrimary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _startNewChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [t.accent.primary, t.accent.tertiary],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.t(context, 'common_new'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _closeDrawer,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: t.panel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.cardBorder),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: t.mutedText,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: t.cardBorder, height: 1),
              Expanded(
                child: _history.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.t(context, 'chat_no_history'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.mutedText, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _history.length,
                        separatorBuilder: (_, _) => Divider(
                          color: t.cardBorder,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (ctx, i) {
                          final session = _history[i];
                          final isActive = session.id == _currentSessionId;
                          return GestureDetector(
                            onTap: () {
                              _closeDrawer();
                              _loadSession(session);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color: isActive
                                  ? t.accent.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? t.accent.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : t.panel,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isActive
                                            ? t.accent.primary.withValues(
                                                alpha: 0.4,
                                              )
                                            : t.cardBorder,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '✦',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isActive
                                              ? t.accent.primary
                                              : t.mutedText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isActive
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isActive
                                                ? t.accent.primary
                                                : t.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${session.messages.length} messages',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: t.mutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: t.accent.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final quickPrompts = _config.quickPrompts(context);

    // Prompt bar estimated height for ListView bottom padding
    const double promptBarH = 72.0;
    final double chipsH = _chipsVisible ? 38.0 : 0.0;
    final double attachH = _pendingAttachment != null ? 52.0 : 0.0;
    final double inputAreaH = promptBarH + chipsH + attachH + 8.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          color: t.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: t.cardBorder),
        ),
        child: Stack(
          children: [
            // ── Handle + Header + Messages (scrollable) ────────────
            Column(
              children: [
                // ── Handle ─────────────────────────────────────────
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.panelBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // ── Header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: t.panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cardBorder, width: 1),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: t.textPrimary,
                            size: 15,
                          ),
                        ),
                      ),
                      AhviHomeText(
                        color: t.textPrimary,
                        fontSize: 30.0,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w400,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openDrawer,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: t.panel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.cardBorder, width: 1),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color: t.mutedText,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Messages — bottom pad clears the pinned input bar ─
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, inputAreaH + 12),
                    children: [
                      ..._messages.map(
                        (msg) => _Bubble(msg: msg, onPrompt: _sendMessage),
                      ),
                      if (_typing) _TypingBubble(color: t.accent.secondary),
                    ],
                  ),
                ),
              ],
            ),

            // ── Prompt bar — pinned to sheet bottom (sheet itself rises with keyboard) ────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: t.phoneShellInner,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Quick Prompts ───────────────────────────────
                    if (_chipsVisible) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 28,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: quickPrompts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => _sendMessage(quickPrompts[i]),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: t.panel,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: t.cardBorder),
                              ),
                              child: Text(
                                quickPrompts[i],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: t.accent.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    // ── Pending Attachment Chip ─────────────────────
                    if (_pendingAttachment != null)
                      _PendingAttachmentChip(
                        attachment: _pendingAttachment!,
                        onRemove: _clearPendingAttachment,
                        onTap: () => _openAttachment(_pendingAttachment!),
                        accent: context.themeTokens.accent.primary,
                        panel: context.themeTokens.panel,
                        cardBorder: context.themeTokens.cardBorder,
                        textPrimary: context.themeTokens.textPrimary,
                        mutedText: context.themeTokens.mutedText,
                      ),
                    // ── Input Bar ───────────────────────────────────
                    AhviChatPromptBar(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      hintText: AppLocalizations.t(
                        context,
                        _config.hintTextKey,
                      ),
                      hasText: _chatHasText,
                      surface: t.phoneShellInner,
                      border: t.cardBorder,
                      accent: t.accent.primary,
                      accentSecondary: t.accent.secondary,
                      textHeading: t.textPrimary,
                      textMuted: t.mutedText,
                      shadowMedium: t.backgroundPrimary.withValues(alpha: 0.20),
                      onAccent: Colors.white,
                      themeTokens: t,
                      onSendMessage: (message) => _sendMessage(message),
                      onVisualSearch: null,
                      onFindSimilar: null,
                      onAddToWardrobe: null,
                    ),
                  ],
                ),
              ),
            ),

            // ── Scrim — dismiss panel on outside tap ─────────────
            if (_drawerOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDrawer,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    color: Colors.black.withValues(
                      alpha: _drawerOpen ? 0.32 : 0.0,
                    ),
                  ),
                ),
              ),

            // ── History panel — slides in from left ───────────────
            Positioned(top: 0, bottom: 0, left: 0, child: _historyPanel()),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BUBBLE WIDGETS  — same as before
// ════════════════════════════════════════════════════════════════════

class _SheetMessage {
  final String? text;
  final String? textKey;
  final bool isUser;
  final _StyleBoardPayload? boardPayload;
  final _WardrobeGapPayload? wardrobeGapPayload;

  _SheetMessage({
    this.text,
    this.textKey,
    required this.isUser,
    this.boardPayload,
    this.wardrobeGapPayload,
  }) : assert(text != null || textKey != null);

  String resolve(BuildContext context) {
    if (textKey != null) return AppLocalizations.t(context, textKey!);
    return text ?? '';
  }
}

class _StyleBoardPayload {
  final List<Map<String, dynamic>> cards;
  final List<Map<String, dynamic>> renderedBoards;
  final List<Map<String, dynamic>> outfits;
  final String? boardId;

  const _StyleBoardPayload({
    required this.cards,
    required this.renderedBoards,
    required this.outfits,
    this.boardId,
  });

  bool get hasBoards =>
      renderedBoards.isNotEmpty || cards.isNotEmpty || outfits.isNotEmpty;

  static _StyleBoardPayload fromResponse(Map<String, dynamic> response) {
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    return _StyleBoardPayload(
      cards: _mapList(response['cards']),
      renderedBoards: _mapList(data['rendered_boards']),
      outfits: _mapList(data['outfits']),
      boardId: response['board_ids']?.toString(),
    );
  }
}

class _WardrobeGapPayload {
  final bool active;
  final String type;
  final String message;
  final List<Map<String, dynamic>> missingItems;
  final List<Map<String, dynamic>> chips;
  final String closestSafeBrief;

  const _WardrobeGapPayload({
    required this.active,
    required this.type,
    required this.message,
    required this.missingItems,
    required this.chips,
    required this.closestSafeBrief,
  });

  bool get hasContent =>
      active &&
      (message.trim().isNotEmpty ||
          missingItems.isNotEmpty ||
          closestSafeBrief.trim().isNotEmpty ||
          chips.isNotEmpty);

  static _WardrobeGapPayload fromResponse(Map<String, dynamic> response) {
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};

    final type = response['type']?.toString() ?? '';
    final isBackendGap =
        type == 'missing_occasion_wardrobe' ||
        type == 'missing_core_wardrobe_slots';

    final missing = _mapList(
      data['missing_items'] ?? data['find_this_recommendations'],
    );

    final rawMessage = response['message'];
    var backendMessage =
        (response['message_text'] ??
                (rawMessage is Map ? rawMessage['content'] : rawMessage) ??
                data['message'] ??
                '')
            .toString()
            .trim();

    final lowerMessage = backendMessage.toLowerCase();
    final isCoreSlotCopy =
        lowerMessage.contains('top, bottom, and footwear') ||
        lowerMessage.contains('complete style board from your wardrobe');

    final occasionRaw =
        (data['occasion'] ??
                (data['wardrobe_gap'] is Map
                    ? (data['wardrobe_gap'] as Map)['occasion']
                    : null) ??
                '')
            .toString()
            .toLowerCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_');

    if (type == 'missing_occasion_wardrobe' &&
        (backendMessage.isEmpty || isCoreSlotCopy)) {
      if (occasionRaw == 'date' ||
          occasionRaw == 'date_night' ||
          occasionRaw == 'datenight') {
        backendMessage =
            "I don't see enough strong date-night options yet. I'd avoid forcing office styling into an evening brief.";
      } else if (occasionRaw == 'beach' ||
          occasionRaw == 'beach_wear' ||
          occasionRaw == 'beachwear' ||
          occasionRaw == 'coastal') {
        backendMessage =
            "I don't see enough beach-ready pieces yet. I'd rather not force formal trousers or loafers into a beach brief.";
      } else {
        backendMessage =
            "I don't see enough occasion-ready options yet. I'd rather not force a weak look.";
      }
    }

    if (type == 'missing_core_wardrobe_slots' && backendMessage.isEmpty) {
      backendMessage =
          "I couldn't build a complete style board from your wardrobe yet. Please add at least one top, bottom, and footwear item.";
    }

    return _WardrobeGapPayload(
      active: isBackendGap,
      type: type,
      message: isBackendGap ? backendMessage : '',
      missingItems: isBackendGap ? missing : const [],
      chips: _mapList(response['chips']),
      closestSafeBrief: (data['closest_safe_brief'] ?? '').toString(),
    );
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class _Bubble extends StatelessWidget {
  final _SheetMessage msg;
  final ValueChanged<String> onPrompt;

  const _Bubble({required this.msg, required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: msg.isUser ? t.accent.primary.withValues(alpha: 0.12) : t.panel,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
          bottomRight: Radius.circular(msg.isUser ? 4 : 16),
        ),
        border: Border.all(
          color: msg.isUser
              ? t.accent.primary.withValues(alpha: 0.35)
              : t.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        msg.resolve(context),
        style: TextStyle(color: t.textPrimary, fontSize: 12, height: 1.45),
      ),
    );

    if (msg.isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    // AI bubble — sparkle icon to the left, aligned to top of bubble
    final aiContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        if (msg.wardrobeGapPayload != null)
          _WardrobeGapCard(
            payload: msg.wardrobeGapPayload!,
            onPrompt: onPrompt,
          ),
        if (msg.boardPayload != null)
          _StyleBoardCarousel(payload: msg.boardPayload!),
      ],
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 6),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.accent.secondary, t.accent.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '✦',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ),
          aiContent,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ADD MENU ROW  — list style matching design
// ════════════════════════════════════════════════════════════════════

class _WardrobeGapCard extends StatelessWidget {
  final _WardrobeGapPayload payload;
  final ValueChanged<String> onPrompt;

  const _WardrobeGapCard({required this.payload, required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return Container(
      width: 280,
      margin: const EdgeInsets.only(top: 4, bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: t.accent.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Find this instead',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your wardrobe is missing the pieces that would make this occasion read correctly.',
            style: TextStyle(color: t.mutedText, fontSize: 11.5, height: 1.35),
          ),
          if (payload.closestSafeBrief.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Closest safe brief: ${payload.closestSafeBrief}',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...payload.missingItems.take(4).map((item) {
            final label = (item['label'] ?? 'Occasion-ready piece').toString();
            final reason =
                (item['reason'] ?? 'Adds the missing occasion signal')
                    .toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: t.accent.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reason,
                          style: TextStyle(
                            color: t.mutedText,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (payload.chips.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: payload.chips.take(3).map((chip) {
                final label = (chip['label'] ?? chip['value'] ?? '').toString();
                final value = (chip['value'] ?? label).toString();
                return GestureDetector(
                  onTap: label.trim().isEmpty ? null : () => onPrompt(value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: t.accent.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: t.accent.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: t.accent.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StyleBoardCarousel extends StatelessWidget {
  final _StyleBoardPayload payload;

  const _StyleBoardCarousel({required this.payload});

  @override
  Widget build(BuildContext context) {
    final boards = _StyleBoardViewModel.fromPayload(payload);
    if (boards.isEmpty) return const SizedBox.shrink();

    final width = math.min(MediaQuery.sizeOf(context).width - 72, 318.0);
    final height = width * 1.72;

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(top: 4, bottom: 14),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: boards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final board = boards[index];

          debugPrint(
            'AHVI_RENDER using=pinterest_board '
            'title=${board.title} '
            'items=${board.items.length}',
          );

          return _PinterestStyleBoardCard(board: board, width: width);
        },
      ),
    );
  }
}

class _StyleBoardViewModel {
  final String title;
  final String? badge;
  final String? imageBase64;
  final String? imageUrl;
  final int? score;
  final String vibe;
  final String aesthetic;
  final List<Map<String, dynamic>> items;

  const _StyleBoardViewModel({
    required this.title,
    this.badge,
    this.imageBase64,
    this.imageUrl,
    this.score,
    required this.vibe,
    required this.aesthetic,
    required this.items,
  });

  static List<_StyleBoardViewModel> fromPayload(_StyleBoardPayload payload) {
    final boards = <_StyleBoardViewModel>[];
    final seen = <String>{};

    List<Map<String, dynamic>> mergedBoardItems(Map<String, dynamic> source) {
      final merged = <Map<String, dynamic>>[];
      final localSeen = <String>{};

      void addItems(Object? value) {
        for (final item in _mapList(value)) {
          final key = _text(
            item['id'] ??
                item[r'$id'] ??
                item['item_id'] ??
                item['name'] ??
                item['label'] ??
                item['title'],
            '',
          ).toLowerCase().trim();

          if (key.isEmpty || localSeen.add(key)) {
            merged.add(item);
          }
        }
      }

      addItems(
        source['items'] ??
            source['wardrobe_items'] ??
            source['wardrobeItems'] ??
            source['pieces'],
      );

      addItems(
        source['accessories'] ??
            source['accessory_items'] ??
            source['accessoryItems'] ??
            source['addons'] ??
            source['add_ons'] ??
            source['addOns'],
      );

      return merged;
    }

    String boardSignature(String title, List<Map<String, dynamic>> items) {
      final names =
          items
              .map(
                (item) => _text(
                  item['name'] ??
                      item['label'] ??
                      item['title'] ??
                      item['id'] ??
                      item[r'$id'],
                  '',
                ).toLowerCase().trim(),
              )
              .where((name) => name.isNotEmpty)
              .toList()
            ..sort();

      if (names.isNotEmpty) return names.join('|');
      return title.toLowerCase().trim();
    }

    void addBoard(_StyleBoardViewModel board) {
      final signature = boardSignature(board.title, board.items);
      if (signature.isEmpty || seen.add(signature)) {
        boards.add(board);
      }
    }

    // Prefer backend-rendered board layout when present. Fall back to live
    // cards/outfits only when the backend did not send board layout data.
    for (final board in payload.renderedBoards) {
      addBoard(
        _StyleBoardViewModel(
          title: _text(
            board['label'] ?? board['title'] ?? board['name'],
            'AHVI Style Board',
          ),
          badge: _nullableText(
            board['badge'] ?? board['occasion_label'] ?? board['occasion'],
          ),
          imageBase64: _nullableText(
            board['image_base64'] ??
                board['imageBase64'] ??
                board['board_image_base64'],
          ),
          imageUrl: _nullableText(
            board['image_url'] ??
                board['imageUrl'] ??
                board['board_image_url'] ??
                board['boardImageUrl'],
          ),
          score: _intOrNull(board['score']),
          vibe: _text(board['vibe'] ?? board['subtitle'], ''),
          aesthetic: _text(board['aesthetic'] ?? board['style'], ''),
          items: mergedBoardItems(board),
        ),
      );
    }

    if (boards.isEmpty) {
      for (final card in payload.cards) {
        addBoard(
          _StyleBoardViewModel(
            title: _text(
              card['title'] ?? card['name'] ?? card['label'],
              'Styled Look',
            ),
            badge: _nullableText(
              card['badge'] ?? card['occasion_label'] ?? card['occasion'],
            ),
            imageBase64: null,
            imageUrl: null,
            score: _intOrNull(card['score']),
            vibe: _text(card['vibe'] ?? card['subtitle'] ?? card['reason'], ''),
            aesthetic: _text(card['aesthetic'] ?? card['style'], ''),
            items: mergedBoardItems(card),
          ),
        );
      }

      for (final outfit in payload.outfits) {
        addBoard(
          _StyleBoardViewModel(
            title: _text(
              outfit['title'] ?? outfit['name'] ?? outfit['label'],
              'Styled Look',
            ),
            badge: _nullableText(
              outfit['badge'] ?? outfit['occasion_label'] ?? outfit['occasion'],
            ),
            imageBase64: null,
            imageUrl: null,
            score: _intOrNull(outfit['score']),
            vibe: _text(
              outfit['vibe'] ?? outfit['reason'] ?? outfit['subtitle'],
              '',
            ),
            aesthetic: _text(outfit['aesthetic'] ?? outfit['style'], ''),
            items: mergedBoardItems(outfit),
          ),
        );
      }
    }

    return boards;
  }
}

class _EditorialStyleBoardCard extends StatelessWidget {
  final _StyleBoardViewModel board;
  final double width;

  const _EditorialStyleBoardCard({required this.board, required this.width});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    final top = _firstItemByRole(board.items, const [
      'shirt',
      'top',
      't-shirt',
      'tee',
      'polo',
      'kurta',
      'hoodie',
      'sweater',
      'blazer',
      'jacket',
      'overshirt',
    ]);

    final bottom = _firstItemByRole(board.items, const [
      'trouser',
      'trousers',
      'pant',
      'pants',
      'jeans',
      'chinos',
      'shorts',
      'joggers',
      'bottom',
    ]);

    final footwear = _firstItemByRole(board.items, const [
      'shoe',
      'shoes',
      'sneaker',
      'sneakers',
      'loafer',
      'loafers',
      'boot',
      'boots',
      'footwear',
      'sandals',
      'formal shoes',
    ]);

    final accessories = _dedupEditorialAccessories(
      board.items.where((item) {
        if (identical(item, top) ||
            identical(item, bottom) ||
            identical(item, footwear)) {
          return false;
        }
        final role = _editorialItemText(item);
        return role.contains('watch') ||
            role.contains('bracelet') ||
            role.contains('belt') ||
            role.contains('cap') ||
            role.contains('bag') ||
            role.contains('sunglass') ||
            role.contains('eyewear') ||
            role.contains('jewel') ||
            role.contains('chain') ||
            role.contains('ring');
      }).toList(),
    );

    final lookName = _editorialLookName(board, top, bottom);
    final occasion = _editorialOccasion(board);
    final why = _editorialWhyItWorks(board, top, bottom, footwear);
    final chips = _chipsFor(board).take(3).toList();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.cardBorder.withValues(alpha: 0.70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditorialBoardHeader(
              lookName: lookName,
              occasion: occasion,
              score: board.score,
            ),
            const SizedBox(height: 10),
            _EditorialWhyBox(text: why),
            const SizedBox(height: 12),
            Expanded(
              child: _EditorialMainOutfitZone(top: top, bottom: bottom),
            ),
            const SizedBox(height: 10),
            _EditorialSectionLabel(label: 'ACCESSORIES'),
            const SizedBox(height: 7),
            SizedBox(
              height: 58,
              child: accessories.isEmpty
                  ? _EditorialEmptyHint(text: 'No accessory added')
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: math.min(accessories.length, 4),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        return _EditorialMiniItem(item: accessories[index]);
                      },
                    ),
            ),
            const SizedBox(height: 10),
            _EditorialSectionLabel(label: 'FOOTWEAR'),
            const SizedBox(height: 7),
            SizedBox(
              height: 70,
              child: footwear == null
                  ? _EditorialEmptyHint(text: 'Footwear not found')
                  : _EditorialFootwearItem(item: footwear),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final chip in chips) ...[
                  _BoardChip(label: chip, color: t.accent.secondary),
                  const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _BoardActionButton(
                    label: 'Save Board',
                    filled: true,
                    onTap: () => _toast(
                      context,
                      'Board ready to save after Appwrite sync.',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BoardActionButton(
                    label: 'Wear This',
                    filled: false,
                    onTap: () => _toast(context, 'Look selected for today.'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorialBoardHeader extends StatelessWidget {
  final String lookName;
  final String occasion;
  final int? score;

  const _EditorialBoardHeader({
    required this.lookName,
    required this.occasion,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOOK 01',
                style: TextStyle(
                  color: t.accent.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lookName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: t.accent.secondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: t.accent.secondary.withValues(alpha: 0.26),
                  ),
                ),
                child: Text(
                  occasion.toUpperCase(),
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (score != null)
          Container(
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: t.accent.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: t.accent.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Text(
              '$score%',
              style: TextStyle(
                color: t.accent.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _EditorialWhyBox extends StatelessWidget {
  final String text;

  const _EditorialWhyBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.cardBorder.withValues(alpha: 0.55)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Why it works: ',
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(text: text),
          ],
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: t.mutedText,
          fontSize: 11,
          height: 1.28,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditorialMainOutfitZone extends StatelessWidget {
  final Map<String, dynamic>? top;
  final Map<String, dynamic>? bottom;

  const _EditorialMainOutfitZone({required this.top, required this.bottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 44,
            child: top == null
                ? _EditorialEmptyHint(text: 'Top not found')
                : _EditorialWardrobeImage(item: top!, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 56,
            child: bottom == null
                ? _EditorialEmptyHint(text: 'Bottom not found')
                : _EditorialWardrobeImage(item: bottom!, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _EditorialSectionLabel extends StatelessWidget {
  final String label;

  const _EditorialSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: t.textPrimary.withValues(alpha: 0.74),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: t.cardBorder.withValues(alpha: 0.70),
          ),
        ),
      ],
    );
  }
}

class _EditorialMiniItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _EditorialMiniItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _EditorialWardrobeImage(item: item, fit: BoxFit.contain),
    );
  }
}

class _EditorialFootwearItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _EditorialFootwearItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
      ),
      child: _EditorialWardrobeImage(item: item, fit: BoxFit.contain),
    );
  }
}

class _EditorialWardrobeImage extends StatelessWidget {
  final Map<String, dynamic> item;
  final BoxFit fit;

  const _EditorialWardrobeImage({required this.item, required this.fit});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _nullableText(
      item['masked_url'] ??
          item['masked_image_url'] ??
          item['maskedUrl'] ??
          item['image_url'] ??
          item['imageUrl'] ??
          item['url'],
    );

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => _EditorialItemPlaceholder(item: item),
      );
    }

    return _EditorialItemPlaceholder(item: item);
  }
}

class _EditorialItemPlaceholder extends StatelessWidget {
  final Map<String, dynamic> item;

  const _EditorialItemPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final name = _text(
      item['name'] ?? item['label'] ?? item['title'] ?? item['category'],
      'Item',
    );

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.accent.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: t.textPrimary,
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EditorialEmptyHint extends StatelessWidget {
  final String text;

  const _EditorialEmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: t.mutedText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Map<String, dynamic>? _firstItemByRole(
  List<Map<String, dynamic>> items,
  List<String> tokens,
) {
  for (final item in items) {
    final text = _editorialItemText(item);
    for (final token in tokens) {
      if (text.contains(token)) return item;
    }
  }
  return null;
}

String _editorialItemText(Map<String, dynamic> item) {
  return [
    item['name'],
    item['label'],
    item['title'],
    item['category'],
    item['sub_category'],
    item['subcategory'],
    item['type'],
    item['color'],
  ].where((v) => v != null).join(' ').toLowerCase();
}

List<Map<String, dynamic>> _dedupEditorialAccessories(
  List<Map<String, dynamic>> items,
) {
  final seen = <String>{};
  final output = <Map<String, dynamic>>[];

  for (final item in items) {
    final key = _text(
      item['category'] ?? item['sub_category'] ?? item['name'] ?? item['label'],
      '',
    ).toLowerCase().trim();

    if (key.isEmpty || seen.add(key)) {
      output.add(item);
    }
  }

  return output;
}

String _editorialLookName(
  _StyleBoardViewModel board,
  Map<String, dynamic>? top,
  Map<String, dynamic>? bottom,
) {
  final existing = board.title.trim();
  if (existing.isNotEmpty && existing.toLowerCase() != 'styled look') {
    return existing;
  }

  final topColor = _text(
    top?['color'] ?? top?['dominant_color'],
    '',
  ).toLowerCase();
  final bottomColor = _text(
    bottom?['color'] ?? bottom?['dominant_color'],
    '',
  ).toLowerCase();

  String prettyColor(String value) {
    if (value.contains('green') || value.contains('emerald')) return 'Emerald';
    if (value.contains('beige') ||
        value.contains('cream') ||
        value.contains('tan'))
      return 'Sand';
    if (value.contains('black')) return 'Noir';
    if (value.contains('white')) return 'Ivory';
    if (value.contains('blue') || value.contains('denim')) return 'Denim';
    if (value.contains('pink')) return 'Rose';
    if (value.contains('brown')) return 'Cocoa';
    if (value.contains('navy')) return 'Navy';
    if (value.isEmpty) return '';
    return value[0].toUpperCase() + value.substring(1);
  }

  final a = prettyColor(topColor);
  final b = prettyColor(bottomColor);

  if (a.isNotEmpty && b.isNotEmpty && a != b) return '$a + $b';
  if (a.isNotEmpty) return '$a Edit';

  return 'Styled Look';
}

String _editorialOccasion(_StyleBoardViewModel board) {
  final text = '${board.vibe} ${board.aesthetic} ${board.title}'.toLowerCase();

  if (text.contains('date')) return 'Date Night';
  if (text.contains('office') || text.contains('business'))
    return 'Office Casual';
  if (text.contains('evening') || text.contains('dinner'))
    return 'Evening Casual';
  if (text.contains('brunch')) return 'Brunch';
  if (text.contains('street')) return 'Streetwear';

  return 'Smart Casual';
}

String _editorialWhyItWorks(
  _StyleBoardViewModel board,
  Map<String, dynamic>? top,
  Map<String, dynamic>? bottom,
  Map<String, dynamic>? footwear,
) {
  final existing = board.vibe.trim();
  if (existing.isNotEmpty && existing.toLowerCase() != 'wardrobe ready') {
    return existing;
  }

  final topName = _text(
    top?['name'] ?? top?['label'] ?? top?['category'],
    'top',
  );
  final bottomName = _text(
    bottom?['name'] ?? bottom?['label'] ?? bottom?['category'],
    'bottom',
  );
  final footwearName = _text(
    footwear?['name'] ?? footwear?['label'] ?? footwear?['category'],
    'footwear',
  );

  return 'The $topName creates the focal point, the $bottomName balances the silhouette, and the $footwearName finishes the look for a clean styled outfit.';
}

class _PinterestStyleBoardCard extends StatelessWidget {
  final _StyleBoardViewModel board;
  final double width;

  const _PinterestStyleBoardCard({required this.board, required this.width});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final itemLine = _itemLine(board.items);
    final chips = _chipsFor(board);
    final imageHeight = width * 1.34;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.backgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: imageHeight,
            color: const Color(0xFFFBFAF7),
            child: _BoardImageStage(board: board),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        board.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                        ),
                      ),
                    ),
                    if (board.badge != null && board.badge!.trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: t.accent.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: t.accent.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          board.badge!.toUpperCase(),
                          style: TextStyle(
                            color: t.accent.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  itemLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.mutedText,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (board.vibe.trim().isNotEmpty &&
                    board.vibe.trim().toLowerCase() != 'wardrobe ready' &&
                    board.vibe.trim().toLowerCase() != 'styled look') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Why it works · ${board.vibe.trim()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textPrimary.withValues(alpha: 0.78),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chips
                        .map(
                          (chip) => _BoardChip(
                            label: chip,
                            color: t.accent.secondary,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _BoardActionButton(
                        label: 'Save Look',
                        filled: true,
                        onTap: () =>
                            _toast(context, 'Look saved to your boards.'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BoardActionButton(
                        label: 'Share',
                        filled: false,
                        onTap: () =>
                            _toast(context, 'Share sheet coming soon.'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardImageStage extends StatelessWidget {
  final _StyleBoardViewModel board;

  const _BoardImageStage({required this.board});

  @override
  Widget build(BuildContext context) {
    // Demo-safe behavior:
    // If backend gives 4+ wardrobe pieces, prefer the live item collage so
    // accessories like watch, belt, cap, sunglasses, bag, jewelry are visible.
    // Some pre-rendered board images only contain the core 3-piece outfit.
    if (board.items.length >= 4) {
      return _FallbackFashionCollage(items: board.items);
    }

    final bytes = _decodeImage(board.imageBase64);
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    if (board.imageUrl != null && board.imageUrl!.isNotEmpty) {
      return Image.network(
        board.imageUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _FallbackFashionCollage(items: board.items),
      );
    }

    return _FallbackFashionCollage(items: board.items);
  }
}

class _FallbackFashionCollage extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _FallbackFashionCollage({required this.items});

  @override
  Widget build(BuildContext context) {
    // Production rule: no demo items. If backend gave us nothing, render
    // a neutral empty card instead of "Hero outfit / Gold hoops" mock data.
    if (items.isEmpty) {
      return const SizedBox.expand();
    }
    final normalized = items.take(6).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFFFFFFFF), const Color(0xFFFAF7F1)],
                  ),
                ),
              ),
            ),
            ...List.generate(normalized.length, (index) {
              final item = normalized[index];
              final slot = _slotFor(index, w, h);
              return Positioned(
                left: slot.left,
                top: slot.top,
                width: slot.width,
                height: slot.height,
                child: _CollageItem(item: item, hero: index == 0),
              );
            }),
          ],
        );
      },
    );
  }
}

class _CollageItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool hero;

  const _CollageItem({required this.item, required this.hero});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _nullableText(
      item['masked_url'] ??
          item['masked_image_url'] ??
          item['image_url'] ??
          item['imageUrl'],
    );
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _CollagePlaceholder(item: item, hero: hero),
      );
    }
    return _CollagePlaceholder(item: item, hero: hero);
  }
}

class _CollagePlaceholder extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool hero;

  const _CollagePlaceholder({required this.item, required this.hero});

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    final category = _text(item['category'] ?? item['type'], 'Item');
    final name = _text(item['name'] ?? item['label'], category);
    final color = _colorFromItem(
      item,
      hero ? const Color(0xFF202020) : t.accent.secondary,
    );

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: hero ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(hero ? 30 : 22),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(hero ? 18 : 10),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(category), color: color, size: hero ? 42 : 26),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: hero ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF1F1F1F),
              fontSize: hero ? 13 : 10,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BoardChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BoardActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _BoardActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? t.accent.primary : t.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? t.accent.primary : t.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : t.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

Rect _slotFor(int index, double w, double h) {
  final slots = <Rect>[
    Rect.fromLTWH(w * 0.13, h * 0.15, w * 0.42, h * 0.62),
    Rect.fromLTWH(w * 0.49, h * 0.56, w * 0.36, h * 0.27),
    Rect.fromLTWH(w * 0.62, h * 0.27, w * 0.27, h * 0.18),
    Rect.fromLTWH(w * 0.12, h * 0.06, w * 0.20, h * 0.14),
    Rect.fromLTWH(w * 0.64, h * 0.08, w * 0.24, h * 0.13),
    Rect.fromLTWH(w * 0.17, h * 0.77, w * 0.28, h * 0.16),
  ];
  return slots[index % slots.length];
}

Uint8List? _decodeImage(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  try {
    final clean = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(clean);
  } catch (_) {
    return null;
  }
}

String _text(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

String _itemLine(List<Map<String, dynamic>> items) {
  final names = items
      .map(
        (item) =>
            _text(item['name'] ?? item['type'] ?? item['category'], 'Item'),
      )
      .take(4)
      .toList();
  if (names.isEmpty) return '';
  return names.join(' · ');
}

List<String> _chipsFor(_StyleBoardViewModel board) {
  final chips = <String>[];
  for (final raw in [board.vibe, board.aesthetic, 'Wardrobe']) {
    final parts = raw
        .split(RegExp(r'[,/|]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p.length <= 24);
    for (final part in parts) {
      if (!chips.any((c) => c.toLowerCase() == part.toLowerCase())) {
        chips.add(part);
      }
      if (chips.length >= 3) return chips;
    }
  }
  return chips;
}

IconData _iconFor(String category) {
  final s = category.toLowerCase();
  if (s.contains('shoe') || s.contains('foot')) {
    return Icons.checkroom;
  }
  if (s.contains('bag') || s.contains('clutch')) {
    return Icons.shopping_bag_outlined;
  }
  if (s.contains('jewel') || s.contains('earring') || s.contains('watch')) {
    return Icons.diamond_outlined;
  }
  if (s.contains('dress') || s.contains('saree') || s.contains('kurta')) {
    return Icons.woman_2_outlined;
  }
  if (s.contains('bottom') || s.contains('jean') || s.contains('pant')) {
    return Icons.view_week_outlined;
  }
  return Icons.dry_cleaning_outlined;
}

Color _colorFromItem(Map<String, dynamic> item, Color fallback) {
  final raw = _nullableText(item['color_code'] ?? item['color']);
  if (raw == null) return fallback;
  final hex = raw.replaceFirst('#', '');
  if (hex.length != 6) return fallback;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return fallback;
  return Color(0xFF000000 | parsed);
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

class _AddMenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final Color accentSecondary;
  final Color panel;
  final Color cardBorder;
  final Color textPrimary;
  final Color mutedText;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _AddMenuRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.accentSecondary,
    required this.panel,
    required this.cardBorder,
    required this.textPrimary,
    required this.mutedText,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_AddMenuRow> createState() => _AddMenuRowState();
}

class _AddMenuRowState extends State<_AddMenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: widget.isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: widget.isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.accent.withValues(alpha: 0.18),
                          widget.accentSecondary.withValues(alpha: 0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.mutedText,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.isLast)
              Divider(
                height: 1,
                thickness: 1,
                color: widget.cardBorder,
                indent: 74,
                endIndent: 0,
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PENDING ATTACHMENT CHIP  — shows selected file/photo above input
// ════════════════════════════════════════════════════════════════════

class _PendingAttachmentChip extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final Color accent;
  final Color panel;
  final Color cardBorder;
  final Color textPrimary;
  final Color mutedText;

  const _PendingAttachmentChip({
    required this.attachment,
    required this.onRemove,
    required this.onTap,
    required this.accent,
    required this.panel,
    required this.cardBorder,
    required this.textPrimary,
    required this.mutedText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // Thumbnail or icon
            if (attachment.isImage && attachment.file != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: Image.file(
                  attachment.file!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Icon(attachment.icon, color: accent, size: 24),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attachment.isWebSearch
                        ? 'Tap to preview in browser'
                        : attachment.isImage
                        ? 'Image — tap to view'
                        : 'Tap to open',
                    style: TextStyle(fontSize: 10, color: mutedText),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: mutedText),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  WEB SEARCH SHEET  — themed to match Ahvi design
// ════════════════════════════════════════════════════════════════════

class _WebSearchSheet extends StatefulWidget {
  final void Function(String) onSearch;
  final VoidCallback onCancel;

  const _WebSearchSheet({required this.onSearch, required this.onCancel});

  @override
  State<_WebSearchSheet> createState() => _WebSearchSheetState();
}

class _WebSearchSheetState extends State<_WebSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();

  static const _suggestions = [
    'Outfit ideas today',
    'Skincare routine',
    'Diet plan this week',
    'Fitness tips',
    'Trending styles',
    'Hyderabad weather',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── All colors from themeTokens — auto dark/light ──────────────
    final t = context.themeTokens;
    final accent = t.accent.primary;
    final accentSec = t.accent.secondary;
    final panel = t.panel;
    final cardBorder = t.cardBorder;
    final textPrimary = t.textPrimary;
    final mutedText = t.mutedText;
    final bgColor = t.backgroundPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Web Search',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Search field ──────────────────────────────────────────
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ఏమి search చేయాలి?',
              hintStyle: TextStyle(color: mutedText, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: accent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              filled: true,
              fillColor: panel,
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: mutedText),
                      onPressed: () => setState(() => _ctrl.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: widget.onSearch,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 16),
          Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 11,
              color: mutedText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return GestureDetector(
                onTap: () => widget.onSearch(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ctrl.text.trim().isNotEmpty
                  ? () => widget.onSearch(_ctrl.text.trim())
                  : null,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Search చేయండి'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accentSec.withValues(alpha: 0.10),
                disabledForegroundColor: mutedText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final Color color;

  const _TypingBubble({required this.color});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.themeTokens.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.themeTokens.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final p = ((_controller.value + i * 0.2) % 1.0);
                final o = 0.35 + (0.65 * (1 - (p - 0.5).abs() * 2));
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: o),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
// ════════════════════════════════════════════════════════════════════
//  AhviPlusMenuButton  — Self-contained ChatGPT-style popup widget
//  Usage: AhviChatPromptBar(plusButton: AhviPlusMenuButton(...))
// ════════════════════════════════════════════════════════════════════

class AhviPlusMenuButton extends StatefulWidget {
  final Color accent;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onCapture;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final VoidCallback onSearch;
  final void Function(bool isOpen)? onMenuToggle;

  const AhviPlusMenuButton({
    super.key,
    required this.accent,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.onCapture,
    required this.onPickPhoto,
    required this.onPickFile,
    required this.onSearch,
    this.onMenuToggle,
  });

  @override
  State<AhviPlusMenuButton> createState() => _AhviPlusMenuButtonState();
}

class _AhviPlusMenuButtonState extends State<AhviPlusMenuButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  bool _isOpen = false;

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    setState(() => _isOpen = true);
    widget.onMenuToggle?.call(true);

    final items = [
      _MenuItem(
        Icons.camera_alt_rounded,
        'Camera',
        const Color(0xFFFF6B6B),
        widget.onCapture,
      ),
      _MenuItem(
        Icons.photo_library_rounded,
        'Photo Library',
        const Color(0xFF4ECDC4),
        widget.onPickPhoto,
      ),
      _MenuItem(
        Icons.insert_drive_file_rounded,
        'Files',
        const Color(0xFF45B7D1),
        widget.onPickFile,
      ),
      _MenuItem(
        Icons.travel_explore_rounded,
        'Search',
        const Color(0xFF96CEB4),
        widget.onSearch,
      ),
    ];

    _overlay = OverlayEntry(
      builder: (ctx) => _PlusPopupOverlay(
        link: _link,
        items: items,
        bgColor: widget.bgColor,
        borderColor: widget.borderColor,
        textColor: widget.textColor,
        onDismiss: _close,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) {
      setState(() => _isOpen = false);
      widget.onMenuToggle?.call(false);
    }
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _isOpen
                ? widget.accent.withValues(alpha: 0.20)
                : widget.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _isOpen
                  ? widget.accent.withValues(alpha: 0.45)
                  : widget.accent.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Center(
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(Icons.add_rounded, color: widget.accent, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Internal popup overlay ────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}

class _PlusPopupOverlay extends StatefulWidget {
  final LayerLink link;
  final List<_MenuItem> items;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onDismiss;

  const _PlusPopupOverlay({
    required this.link,
    required this.items,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.onDismiss,
  });

  @override
  State<_PlusPopupOverlay> createState() => _PlusPopupOverlayState();
}

class _PlusPopupOverlayState extends State<_PlusPopupOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Outside tap → dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        // Popup card — appears above the + button
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, -8),
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: widget.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.13),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.asMap().entries.map((e) {
                      final isLast = e.key == widget.items.length - 1;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              widget.onDismiss();
                              e.value.onTap();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: e.value.color,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(
                                      e.value.icon,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    e.value.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: widget.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 0,
                              thickness: 0.5,
                              color: widget.borderColor,
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
