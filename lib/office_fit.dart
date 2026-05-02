import 'package:flutter/material.dart';
import 'package:appwrite/models.dart' hide Row;
import 'package:provider/provider.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/app_localizations.dart';

class OfficeFitScreen extends StatefulWidget {
  const OfficeFitScreen({super.key});

  @override
  State<OfficeFitScreen> createState() => _OfficeFitScreenState();
}

class _OfficeFitScreenState extends State<OfficeFitScreen> {
  bool _isLoading = true;
  List<Document> _boards = [];

  @override
  void initState() {
    super.initState();
    _fetchOfficeBoards();
  }

  Future<void> _fetchOfficeBoards() async {
    try {
      final appwrite = Provider.of<AppwriteService>(context, listen: false);
      final boards = await appwrite.getSavedBoardsByOccasion('Office');
      if (mounted) {
        setState(() {
          _boards = boards;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching office boards: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
                20, MediaQuery.of(context).padding.top + 12, 20, 14),
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
                    child: Icon(Icons.chevron_left_rounded,
                        color: t.textPrimary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        // "Office" word
                        text: '${context.tr('calendar_occasion_office')} ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        // "Fits" word
                        text: context.tr('boards_office_fits_sub'),
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
                    child: CircularProgressIndicator(color: t.accent.primary))
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
            child: Icon(Icons.business_center_rounded,
                size: 48, color: const Color(0xFFFFC956)),
          ),
          const SizedBox(height: 24),
          Text(
            // "No Office Fits Yet!"
            context.tr('boards_office_fits'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('wardrobe_insight_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: t.mutedText,
              height: 1.5,
            ),
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
        childAspectRatio: 0.65,
      ),
      itemCount: _boards.length,
      itemBuilder: (context, index) {
        final board = _boards[index];
        final imageUrl = board.data['imageUrl'] ?? '';

        return GestureDetector(
          onTap: () {
            // TODO: Fullscreen image viewer
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.cardBorder),
              color: t.panel,
              image: imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: imageUrl.isEmpty
                ? Center(
                    child: Icon(Icons.image_not_supported, color: t.mutedText))
                : null,
          ),
        );
      },
    );
  }
}