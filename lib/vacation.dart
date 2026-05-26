import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/services/connectivity_watcher.dart';
import 'package:myapp/services/offline_cache.dart';
import 'package:myapp/app_localizations.dart';
import 'package:myapp/style_board/saved_board_card.dart';

class VacationScreen extends StatefulWidget {
  const VacationScreen({super.key});

  @override
  State<VacationScreen> createState() => _VacationScreenState();
}

class _VacationScreenState extends State<VacationScreen> {
  bool _isLoading = true;
  List<dynamic> _boards = const [];
  Map<String, Map<String, dynamic>> _wardrobeById = const {};

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    final cache = Provider.of<OfflineCache>(context, listen: false);
    final connectivity = Provider.of<ConnectivityWatcher>(
      context,
      listen: false,
    );

    _applyFromCache(cache);

    if (!connectivity.isOnline) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final results = await Future.wait([
        appwrite.getSavedBoardsByOccasion('Vacation'),
        appwrite.getWardrobeItems(),
      ]);
      final boards = results[0] as List;
      final wardrobe = results[1] as List<Map<String, dynamic>>;
      _wardrobeById = _buildIdMap(wardrobe);
      if (mounted) {
        setState(() {
          _boards = boards;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching vacation boards: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFromCache(OfflineCache cache) {
    final boards = cache.getSavedBoards('Vacation');
    _boards = boards;
    _wardrobeById = _buildIdMap(cache.getWardrobe());
    if (mounted) {
      setState(() => _isLoading = boards.isEmpty);
    }
  }

  Map<String, Map<String, dynamic>> _buildIdMap(
    List<Map<String, dynamic>> items,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final item in items) {
      for (final rawId in [
        item[r'$id'],
        item['id'],
        item['item_id'],
        item['itemId'],
        item['image_id'],
        item['imageId'],
      ]) {
        final id = (rawId ?? '').toString();
        if (id.isNotEmpty) byId[id] = item;
      }
    }
    return byId;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Scaffold(
      backgroundColor: t.backgroundPrimary,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 12,
              20,
              14,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: t.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.cardBorder),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: t.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${context.tr('boards_vacation')} ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: context.tr('boards_vacation_sub'),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w300,
                          color: t.accent.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Body ──
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: t.accent.primary),
                  )
                : _boards.isEmpty
                ? _buildEmptyState(t)
                : _buildBoardsGrid(t),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppThemeTokens t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.panel,
              shape: BoxShape.circle,
              border: Border.all(color: t.cardBorder),
            ),
            child: Icon(
              Icons.beach_access_rounded,
              size: 48,
              color: const Color(0xFFFFC956),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('boards_vacation'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No vacation looks saved yet. Build one in AHVI chat and tap Save.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.mutedText, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardsGrid(AppThemeTokens t) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemCount: _boards.length,
      itemBuilder: (context, index) {
        final board = _boards[index];
        return SavedBoardCard(
          source: board,
          wardrobeById: _wardrobeById,
          onTap: () {
            // TODO: Fullscreen image viewer
          },
        );
      },
    );
  }
}
