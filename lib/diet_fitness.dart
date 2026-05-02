import 'package:flutter/material.dart';
import 'package:myapp/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:myapp/theme/theme_tokens.dart';
import 'package:myapp/diet_page.dart' as diet;
import 'package:myapp/fitness_page.dart' as fitness;

class DietAndFitnessScreen extends StatefulWidget {
  const DietAndFitnessScreen({super.key});

  @override
  State<DietAndFitnessScreen> createState() => _DietAndFitnessScreenState();
}

class _DietAndFitnessScreenState extends State<DietAndFitnessScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _tabsFade;
  late final Animation<Offset> _tabsSlide;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      } else if (mounted) {
        setState(() {});
      }
    });

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    _tabsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _tabsSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.themeTokens;

    return Scaffold(
      backgroundColor: t.backgroundPrimary,
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (context, child) => FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(position: _headerSlide, child: child),
            ),
            child: _buildHeader(t),
          ),
          AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (context, child) => FadeTransition(
              opacity: _tabsFade,
              child: SlideTransition(position: _tabsSlide, child: child),
            ),
            child: _buildTabBar(t),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                RepaintBoundary(child: diet.MainScreen()),
                RepaintBoundary(child: fitness.WorkoutStudioScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeTokens t) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 8,
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
              child: Icon(Icons.chevron_left_rounded, color: t.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${AppLocalizations.t(context, 'diet_and')} ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: AppLocalizations.t(context, 'fitness'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppThemeTokens t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.accent.primary, t.accent.tertiary],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: t.accent.primary.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: t.tileText,
        unselectedLabelColor: t.mutedText,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          Tab(text: AppLocalizations.t(context, 'diet')),
          Tab(text: AppLocalizations.t(context, 'fitness')),
        ],
      ),
    );
  }
}