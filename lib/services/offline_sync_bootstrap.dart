import 'package:appwrite/models.dart' as appwrite_models;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:myapp/services/appwrite_service.dart';
import 'package:myapp/services/connectivity_watcher.dart';
import 'package:myapp/services/offline_cache.dart';

class OfflineSyncBootstrap extends StatefulWidget {
  final Widget child;
  static const List<String> _occasions = ['Party', 'Office', 'Vacation'];

  const OfflineSyncBootstrap({super.key, required this.child});

  @override
  State<OfflineSyncBootstrap> createState() => _OfflineSyncBootstrapState();
}

class _OfflineSyncBootstrapState extends State<OfflineSyncBootstrap> {
  bool _initStarted = false;
  bool _syncInflight = false;
  String? _lastSyncedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_initStarted) return;
    _initStarted = true;
    final cache = context.read<OfflineCache>();
    final appwrite = context.read<AppwriteService>();
    final user = await appwrite.getCurrentUser();
    await cache.init(userId: user?.$id);
    appwrite.attachOfflineWriteThrough(
      onWardrobe: (items) => cache.setWardrobe(items),
      onSavedBoards: (occasion, docs) =>
          cache.setSavedBoardsFromDocs(occasion, docs),
    );
    await _maybeSync();
  }

  Future<void> _maybeSync() async {
    if (_syncInflight) return;
    if (!mounted) return;
    final connectivity = context.read<ConnectivityWatcher>();
    if (!connectivity.isOnline) return;
    final appwrite = context.read<AppwriteService>();
    final user = await appwrite.getCurrentUser();
    if (user == null) return;
    final cache = context.read<OfflineCache>();
    cache.setUser(user.$id);
    if (_lastSyncedUserId == user.$id) return;

    _syncInflight = true;
    try {
      await _runSync(cache, appwrite);
      _lastSyncedUserId = user.$id;
    } catch (e) {
      debugPrint('OfflineSyncBootstrap sync error: $e');
    } finally {
      _syncInflight = false;
    }
  }

  Future<void> _runSync(OfflineCache cache, AppwriteService appwrite) async {
    bool allOk = true;

    List<Map<String, dynamic>>? wardrobe;
    try {
      wardrobe = await appwrite.getWardrobeItems(forceRefresh: true);
      await cache.setWardrobe(wardrobe);
    } catch (e) {
      debugPrint('Sync wardrobe failed: $e');
      allOk = false;
    }

    final boardsByOcc = <String, List<appwrite_models.Document>>{};
    for (final occ in OfflineSyncBootstrap._occasions) {
      try {
        final docs = await appwrite.getSavedBoardsByOccasion(occ);
        boardsByOcc[occ] = docs;
        await cache.setSavedBoardsFromDocs(occ, docs);
      } catch (e) {
        debugPrint('Sync boards($occ) failed: $e');
        allOk = false;
      }
    }

    final urls = cache.collectAllUrls();
    try {
      await cache.syncImages(urls);
    } catch (e) {
      debugPrint('Sync images failed: $e');
      allOk = false;
    }

    if (allOk) {
      try {
        await cache.pruneOrphans(urls);
      } catch (e) {
        debugPrint('Prune orphans failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-run sync when connectivity flips back to online OR when the
    // authenticated user changes (login switch on the same device).
    return Consumer2<ConnectivityWatcher, AppwriteService>(
      builder: (_, conn, appwrite, child) {
        final cachedUser = appwrite.cachedUserProfileData;
        final uid =
            (cachedUser != null
                    ? (cachedUser['userId'] ?? cachedUser['\$id'] ?? '')
                    : '')
                .toString()
                .trim();
        final cache = context.read<OfflineCache>();
        if (uid.isEmpty) {
          // Logout: detach the cache from any user. _loadFromPrefs() resets
          // in-memory state so a subsequent build cannot show stale rows.
          if (_lastSyncedUserId != null) {
            cache.setUser(null);
            _lastSyncedUserId = null;
          }
        } else if (uid != _lastSyncedUserId) {
          // User switched — rebind cache keys to the new user before sync.
          cache.setUser(uid);
          _lastSyncedUserId = null; // force resync below
        }
        if (conn.isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSync());
        }
        return child!;
      },
      child: widget.child,
    );
  }
}
