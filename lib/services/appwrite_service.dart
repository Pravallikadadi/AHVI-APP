import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite/enums.dart';
import 'package:myapp/config/env.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppwriteService extends ChangeNotifier {
  static final AppwriteService _shared = AppwriteService._internal();

  factory AppwriteService() => _shared;

  late Client client;
  late Account account;
  late Databases databases;
  late Avatars avatars;

  // Cached user — avoid repeated network calls
  User? _cachedUser;
  Map<String, dynamic>? _cachedUserProfileData;

  Map<String, dynamic>? get cachedUserProfileData => _cachedUserProfileData;

  // Wardrobe TTL cache — cuts redundant listDocuments calls from planner pages.
  List<Map<String, dynamic>>? _wardrobeCache;
  DateTime? _wardrobeCacheAt;
  Future<List<Map<String, dynamic>>>? _wardrobeInflight;
  static const Duration _wardrobeTtl = Duration(seconds: 60);

  // Optional write-through to offline cache.
  void Function(List<Map<String, dynamic>>)? _onWardrobeFetched;
  void Function(String occasion, List<Document>)? _onSavedBoardsFetched;

  void attachOfflineWriteThrough({
    void Function(List<Map<String, dynamic>>)? onWardrobe,
    void Function(String occasion, List<Document>)? onSavedBoards,
  }) {
    _onWardrobeFetched = onWardrobe;
    _onSavedBoardsFetched = onSavedBoards;
  }

  void invalidateWardrobeCache() {
    _wardrobeCache = null;
    _wardrobeCacheAt = null;
    _wardrobeInflight = null;
  }

  AppwriteService._internal() {
    client = Client()
      ..setEndpoint(Env.appwriteEndpoint)
      ..setProject(Env.appwriteProjectId);

    account = Account(client);
    databases = Databases(client);
    avatars = Avatars(client);
  }

  // =========================================================================
  // AUTHENTICATION METHODS
  // =========================================================================

  // ================= AHVI AUTH SESSION GUARD V1 =================

  // ================= AHVI PERSISTED USER SESSION V2 BEGIN =================
  static const String _ahviCachedUserIdKey = 'ahvi_current_appwrite_user_id';
  static const String _ahviCachedUserEmailKey =
      'ahvi_current_appwrite_user_email';

  Future<void> _persistCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ahviCachedUserIdKey, user.$id);
    await prefs.setString(_ahviCachedUserEmailKey, user.email);
  }

  Future<String?> getCachedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_ahviCachedUserIdKey);
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  Future<void> clearCachedUserIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ahviCachedUserIdKey);
    await prefs.remove(_ahviCachedUserEmailKey);
  }
  // ================= AHVI PERSISTED USER SESSION V2 END =================

  Future<User?> getCurrentUser() async {
    try {
      _cachedUser = await account.get();

      // Canonical source of truth is Appwrite Auth account id.
      await _persistCurrentUser(_cachedUser!);

      return _cachedUser;
    } catch (e) {
      _cachedUser = null;

      // Important:
      // No active Appwrite session. Do not create a new account/profile here.
      // Caller should route to sign-in/onboarding.
      return null;
    }
  }

  // Call this after login to pre-cache user
  Future<void> cacheCurrentUser() async {
    try {
      _cachedUser = await account.get();
      await _persistCurrentUser(_cachedUser!);
    } catch (e) {
      _cachedUser = null;
    }
  }

  // Clear all per-user state. Called on logout AND on every successful
  // login so a freshly authed user never sees the previous user's data.
  void clearUserCache() {
    _cachedUser = null;
    _cachedUserProfileData = null;
    invalidateWardrobeCache();
  }

  Future<void> _deleteExistingSessionsForAuthSwitch() async {
    try {
      await account.deleteSessions();
    } catch (_) {
      try {
        await account.deleteSession(sessionId: 'current');
      } catch (_) {}
    }
  }

  Future<Session?> loginEmailPassword(String email, String password) async {
    try {
      // Wipe any previous user's in-memory state before authenticating
      // the new user. Prevents wardrobe/profile data from one account
      // leaking into the next account on the same device.
      clearUserCache();

      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      await cacheCurrentUser();
      await ensureCurrentUserProfile();
      await refreshCurrentUserProfile();

      notifyListeners();
      return session;
    } catch (e) {
      debugPrint("Login error: $e");
      rethrow;
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      clearUserCache();
      await account.createOAuth2Session(provider: OAuthProvider.google);
      await cacheCurrentUser();
      await ensureCurrentUserProfile();
      await refreshCurrentUserProfile();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Google login error: $e");
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    try {
      clearUserCache();
      await account.createOAuth2Session(provider: OAuthProvider.apple);
      await cacheCurrentUser();
      await ensureCurrentUserProfile();
      await refreshCurrentUserProfile();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Apple login error: $e");
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await account.createRecovery(
        email: email,
        url: '${Env.appwriteEndpoint}/reset-password',
      );
    } catch (e) {
      debugPrint("Password reset error: $e");
      rethrow;
    }
  }

  Future<User> registerEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();
    try {
      debugPrint("AHVI_EMAIL_SIGNUP_CREATE_START email=$cleanEmail");
      clearUserCache();
      await clearCachedUserIdentity();
      await _deleteExistingSessionsForAuthSwitch();

      final user = await account.create(
        userId: ID.unique(),
        email: cleanEmail,
        password: password,
        name: cleanName,
      );

      debugPrint("AHVI_EMAIL_SIGNUP_ACCOUNT_CREATED userId=${user.$id}");

      await account.createEmailPasswordSession(
        email: cleanEmail,
        password: password,
      );

      debugPrint("AHVI_EMAIL_SIGNUP_SESSION_CREATED");

      await cacheCurrentUser();
      await ensureCurrentUserProfile();
      await refreshCurrentUserProfile();

      debugPrint("AHVI_EMAIL_SIGNUP_PROFILE_READY");

      notifyListeners();
      return user;
    } catch (e, st) {
      debugPrint("AHVI_EMAIL_SIGNUP_FAILED error=$e");
      debugPrint("$st");
      rethrow;
    }
  }

  Future<void> logout() async {
    // Clear local identity first so any race between the SDK call and a
    // subsequent UI rebuild can never see the previous user.
    await clearCachedUserIdentity();
    try {
      await AhviNotificationService.instance.unregisterForCurrentUser(this);
    } catch (e) {
      debugPrint("Push unregister error: $e");
    }
    // Tear down EVERY session for this user, not just the current one.
    // Prevents the next sign-in on the same device from inheriting an
    // orphan session that still resolves account.get() to the previous
    // user before the new login completes.
    try {
      await account.deleteSessions();
    } catch (e) {
      debugPrint("deleteSessions failed, falling back to current: $e");
      try {
        await account.deleteSession(sessionId: 'current');
      } catch (e2) {
        debugPrint("deleteSession('current') also failed: $e2");
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboardingComplete');
    await prefs.remove('user_id');
    await prefs.remove('user_profile');
    clearUserCache();
    notifyListeners();
  }

  // Deletes all active sessions — effectively signs the user out everywhere.
  // Note: Appwrite SDK v22 does not support client-side account deletion.
  // Full account deletion requires an Appwrite Function (server-side).
  Future<void> deleteAccount() async {
    try {
      await AhviNotificationService.instance.unregisterForCurrentUser(this);
      // Delete all sessions so the user is fully signed out on all devices
      await account.deleteSessions();
      notifyListeners();
    } catch (e) {
      debugPrint("Delete account error: $e");
      // Fallback: delete only current session
      try {
        await account.deleteSession(sessionId: 'current');
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<Uint8List?> getUserAvatar(String name) async {
    try {
      return await avatars.getInitials(name: name);
    } catch (e) {
      debugPrint("Avatar error: $e");
      return null;
    }
  }

  // =========================================================================

  bool _userProfileSyncInFlight = false;

  String _safeUsernameFromUser(dynamic user) {
    final emailPrefix = user.email.toString().split('@').first;
    final raw =
        (user.name.toString().trim().isNotEmpty
                ? user.name.toString()
                : emailPrefix)
            .toLowerCase();

    final cleaned = raw
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (cleaned.isNotEmpty) return cleaned;
    return 'user_${user.$id.toString().substring(0, 8)}';
  }

  Future<Document?> getCurrentUserProfileDocument({
    bool createIfMissing = true,
  }) async {
    try {
      final usersCollectionId = Env.usersCollection.trim();
      if (usersCollectionId.isEmpty) {
        debugPrint(
          '⚠️ Users collection env is empty. Cannot load user profile.',
        );
        return null;
      }

      final user = await account.get();
      if (createIfMissing) {
        await ensureCurrentUserProfile();
      }

      final document = await databases.getDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: usersCollectionId,
        documentId: user.$id,
      );

      _cachedUserProfileData = Map<String, dynamic>.from(document.data);
      return document;
    } catch (e) {
      debugPrint('❌ Failed to load current user profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> refreshCurrentUserProfile() async {
    final document = await getCurrentUserProfileDocument(createIfMissing: true);
    if (document == null) return null;
    _cachedUserProfileData = Map<String, dynamic>.from(document.data);
    return _cachedUserProfileData;
  }

  bool isOnboardingCompleteFromProfile(Map<String, dynamic>? profile) {
    final gender = (profile?['gender'] ?? '').toString().trim();

    final done =
        profile?['onboarding1'] == true &&
        profile?['onboarding2'] == true &&
        profile?['onboarding3'] == true &&
        gender.isNotEmpty;

    debugPrint(
      'AHVI_ONBOARDING_PROFILE '
      'gender=${profile?['gender']} '
      'onboarding1=${profile?['onboarding1']} '
      'onboarding2=${profile?['onboarding2']} '
      'onboarding3=${profile?['onboarding3']} '
      'done=$done',
    );

    return done;
  }

  Future<bool> isCurrentUserOnboardingComplete() async {
    final profile = await refreshCurrentUserProfile();
    final done = isOnboardingCompleteFromProfile(profile);

    // Keep SharedPreferences as a local cache only.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', done);

    return done;
  }

  Map<String, dynamic> _cleanProfilePayload(Map<String, dynamic> data) {
    return Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> _coreProfilePayload(Map<String, dynamic> data) {
    const coreKeys = {
      'name',
      'username',
      'email',
      'gender',
      'onboarding1',
      'onboarding2',
      'onboarding3',
      'stylePreferences',
    };
    final out = <String, dynamic>{};
    for (final entry in data.entries) {
      if (coreKeys.contains(entry.key) && entry.value != null) {
        out[entry.key] = entry.value;
      }
    }
    return out;
  }

  Future<Document> _updateProfileDocumentWithFallback({
    required String usersCollectionId,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final cleaned = _cleanProfilePayload(payload);
    try {
      return await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: usersCollectionId,
        documentId: documentId,
        data: cleaned,
      );
    } on AppwriteException catch (e) {
      final fallback = _coreProfilePayload(cleaned);
      if (fallback.isEmpty || fallback.length == cleaned.length) rethrow;
      debugPrint(
        'AHVI_PROFILE_UPDATE_SCHEMA_RETRY error=${e.message} keys=${fallback.keys.toList()}',
      );
      return await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: usersCollectionId,
        documentId: documentId,
        data: fallback,
      );
    }
  }

  Future<Document> _createProfileDocumentWithFallback({
    required String usersCollectionId,
    required String documentId,
    required Map<String, dynamic> payload,
  }) async {
    final cleaned = _cleanProfilePayload(payload);
    try {
      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: usersCollectionId,
        documentId: documentId,
        data: cleaned,
        permissions: [
          Permission.read(Role.user(documentId)),
          Permission.update(Role.user(documentId)),
          Permission.delete(Role.user(documentId)),
        ],
      );
    } on AppwriteException catch (e) {
      final fallback = _coreProfilePayload(cleaned);
      if (fallback.isEmpty || fallback.length == cleaned.length) rethrow;
      debugPrint(
        'AHVI_PROFILE_CREATE_SCHEMA_RETRY error=${e.message} keys=${fallback.keys.toList()}',
      );
      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: usersCollectionId,
        documentId: documentId,
        data: fallback,
        permissions: [
          Permission.read(Role.user(documentId)),
          Permission.update(Role.user(documentId)),
          Permission.delete(Role.user(documentId)),
        ],
      );
    }
  }

  Future<void> updateCurrentUserProfileFields(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      final usersCollectionId = Env.usersCollection.trim();
      if (usersCollectionId.isEmpty) {
        throw Exception('Users collection env is empty');
      }

      debugPrint('AHVI_PROFILE_UPDATE_START fields=${data.keys.toList()}');

      await ensureCurrentUserProfile();

      final updated = await _updateProfileDocumentWithFallback(
        usersCollectionId: usersCollectionId,
        documentId: user.$id,
        payload: {...data, 'updatedAt': DateTime.now().toIso8601String()},
      );

      _cachedUserProfileData = Map<String, dynamic>.from(updated.data);
      await refreshCurrentUserProfile();
      debugPrint('AHVI_PROFILE_UPDATE_SUCCESS userId=${user.$id}');
      notifyListeners();
    } catch (e, st) {
      debugPrint('AHVI_PROFILE_UPDATE_FAILED error=$e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<Document?> ensureCurrentUserProfile() async {
    if (_userProfileSyncInFlight) return null;

    final usersCollectionId = Env.usersCollection.trim();
    if (usersCollectionId.isEmpty) {
      debugPrint(
        '⚠️ Users collection env is empty. Skipping user profile sync.',
      );
      return null;
    }

    _userProfileSyncInFlight = true;

    try {
      final user = await account.get();
      debugPrint('AHVI_PROFILE_ENSURE_START userId=${user.$id}');

      final displayName = user.name.toString().trim().isNotEmpty
          ? user.name.toString().trim()
          : user.email.toString().split('@').first;
      final now = DateTime.now().toIso8601String();

      final createData = <String, dynamic>{
        'userId': user.$id,
        'name': displayName,
        'username': _safeUsernameFromUser(user),
        'email': user.email,
        // Keep onboarding/profile fields persistent in Appwrite.
        // These are defaults only for first-time users; existing users are never reset.
        'gender': '',
        'onboarding1': false,
        'onboarding2': false,
        'onboarding3': false,
        'stylePreferences': <String>[],
        'skinTone': '',
        'bodyShape': '',
        'shopPrefs': <String>[],
        'dob': '',
        'phone': '',
        'createdAt': now,
        'updatedAt': now,
      };

      try {
        final existing = await databases.getDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: usersCollectionId,
          documentId: user.$id,
        );
        debugPrint('AHVI_PROFILE_EXISTS userId=${user.$id}');

        // IMPORTANT: Do not overwrite onboarding/profile answers on relogin.
        // Only refresh identity fields that come from Appwrite Auth.
        final updated = await _updateProfileDocumentWithFallback(
          usersCollectionId: usersCollectionId,
          documentId: user.$id,
          payload: {
            'userId': user.$id,
            'name': displayName,
            'username': _safeUsernameFromUser(user),
            'email': user.email,
            'updatedAt': now,
          },
        );

        _cachedUserProfileData = Map<String, dynamic>.from({
          ...existing.data,
          ...updated.data,
        });

        debugPrint('✅ User profile synced: ${user.$id}');
        return updated;
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          debugPrint('AHVI_PROFILE_CREATE_START userId=${user.$id}');
          final created = await _createProfileDocumentWithFallback(
            usersCollectionId: usersCollectionId,
            documentId: user.$id,
            payload: createData,
          );

          _cachedUserProfileData = Map<String, dynamic>.from(created.data);
          debugPrint('✅ User profile created: ${user.$id}');
          debugPrint('AHVI_PROFILE_CREATE_SUCCESS userId=${user.$id}');
          return created;
        }

        debugPrint(
          '❌ User profile sync AppwriteException: code=${e.code}, type=${e.type}, message=${e.message}',
        );
        debugPrint('AHVI_PROFILE_CREATE_FAILED error=${e.message}');
        rethrow;
      }
    } catch (e, st) {
      debugPrint('❌ User profile sync failed: $e');
      debugPrint('AHVI_PROFILE_CREATE_FAILED error=$e');
      debugPrint('$st');
      rethrow;
    } finally {
      _userProfileSyncInFlight = false;
    }
  }

  // 👔 WARDROBE (OUTFITS) DB METHODS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getWardrobeItems({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _wardrobeCache;
      final at = _wardrobeCacheAt;
      if (cached != null &&
          at != null &&
          DateTime.now().difference(at) < _wardrobeTtl) {
        return cached;
      }
      final inflight = _wardrobeInflight;
      if (inflight != null) return inflight;
    }

    final fetch = _fetchWardrobeItems();
    _wardrobeInflight = fetch;
    try {
      final items = await fetch;
      _wardrobeCache = items;
      _wardrobeCacheAt = DateTime.now();
      _onWardrobeFetched?.call(items);
      return items;
    } finally {
      _wardrobeInflight = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWardrobeItems() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      dynamic result;
      try {
        result = await databases.listDocuments(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.outfitsCollection,
          queries: [
            Query.equal('userId', user.$id),
            Query.orderDesc('\$createdAt'),
          ],
        );
      } catch (_) {
        result = null;
      }

      if (result == null || result.documents.isEmpty) {
        result = await databases.listDocuments(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.outfitsCollection,
          queries: [
            Query.equal('user_id', user.$id),
            Query.orderDesc('\$createdAt'),
          ],
        );
      }

      return result.documents.map<Map<String, dynamic>>((doc) {
        return <String, dynamic>{
          "id": doc.$id,
          r"$id": doc.$id,
          "name": doc.data['name'],
          "category": doc.data['category'],
          "sub_category": doc.data['sub_category'],
          "color_code": doc.data['color_code'],
          "pattern": doc.data['pattern'],
          "occasions": doc.data['occasions'],
          "image_url":
              doc.data['image_url'] ??
              doc.data['masked_url'] ??
              doc.data['raw_url'],
          "masked_url": doc.data['masked_url'],
          "raw_url": doc.data['raw_url'],
        };
      }).toList();
    } catch (e) {
      debugPrint("👕 Error fetching wardrobe items: $e");
      return [];
    }
  }

  // =========================================================================
  // CALENDAR PLANS DB METHODS
  // =========================================================================

  Future<Document> createPlan(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating plan: $e");
      rethrow;
    }
  }

  Future<List<Document>> getUserPlans() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching plans: $e");
      return [];
    }
  }

  Future<void> deletePlan(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting plan: $e");
      rethrow;
    }
  }

  Future<void> updatePlanReminder(String documentId, bool reminder) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: documentId,
        data: {'reminder': reminder},
      );
    } catch (e) {
      debugPrint("Error updating plan reminder: $e");
      rethrow;
    }
  }

  // =========================================================================
  // SAVED BOARDS DB METHODS
  // =========================================================================

  Future<List<Document>> getSavedBoardsByOccasion(String occasion) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      final normalizedOccasion = _savedBoardOccasionLabel(occasion);

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.equal('occasion', normalizedOccasion),
          Query.orderDesc('\$createdAt'),
        ],
      );
      _onSavedBoardsFetched?.call(occasion, result.documents);
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching $occasion boards: $e");
      return [];
    }
  }

  Future<List<Document>> getAllSavedBoards() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching all boards: $e");
      return [];
    }
  }

  // Persist a chat-generated style board to Appwrite so it shows up in the
  // planner pages (occasion / office / party / vacation / everything_else).
  // Schema fields the planner reads:
  //   userId, occasion, outfitDescription, emoji, imageUrl, $createdAt.
  Future<Document?> saveBoardToCollection({
    required String occasion,
    required String outfitDescription,
    String? imageUrl,
    String? emoji,
    String? boardCategory,
    String? boardCategoryLabel,
    String? title,
    String? prompt,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      final cleanImageUrl = (imageUrl ?? '').trim();
      if (cleanImageUrl.isEmpty) {
        throw Exception('Cannot save board without imageUrl');
      }

      final rawItemIds = extra?['itemIds'] ?? extra?['item_ids'] ?? <dynamic>[];
      final itemIds = rawItemIds is Iterable
          ? rawItemIds
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];
      final outfitItems = _savedBoardItemList(extra?['outfitItems']);
      final items = _savedBoardItemList(extra?['items']);
      final boardPayload = _savedBoardPayload(extra?['board_payload']);
      final boardPayloadCamel = _savedBoardPayload(extra?['boardPayload']);

      final storageOccasion = _savedBoardOccasionLabel(occasion);
      final categoryLabel = boardCategoryLabel?.trim().isNotEmpty == true
          ? boardCategoryLabel!.trim()
          : storageOccasion;
      final categoryKey = boardCategory?.trim().isNotEmpty == true
          ? boardCategory!.trim()
          : _savedBoardCategoryKey(categoryLabel);
      final nowIso = DateTime.now().toIso8601String();

      final richData = <String, dynamic>{
        'userId': user.$id,
        'occasion': storageOccasion,
        'imageUrl': cleanImageUrl,
        'itemIds': itemIds,
        'boardCategory': categoryKey,
        'boardCategoryLabel': categoryLabel,
        'title': (title ?? '').trim().isEmpty
            ? _fallbackSavedBoardTitle(categoryLabel, outfitDescription)
            : title!.trim(),
        'prompt': (prompt ?? '').trim(),
        'outfitDescription': outfitDescription.trim(),
        'thumbnailUrl': cleanImageUrl,
        'emoji': (emoji ?? '').trim().isEmpty ? '✨' : emoji!.trim(),
        'createdAt': nowIso,
      };
      if (outfitItems.isNotEmpty) richData['outfitItems'] = outfitItems;
      if (items.isNotEmpty) richData['items'] = items;
      if (boardPayload.isNotEmpty) richData['board_payload'] = boardPayload;
      if (boardPayloadCamel.isNotEmpty) {
        richData['boardPayload'] = boardPayloadCamel;
      }

      try {
        return await databases.createDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.savedBoardsCollection,
          documentId: ID.unique(),
          data: richData,
        );
      } catch (e) {
        debugPrint(
          'Rich saved board write failed, retrying JSON payload schema: $e',
        );
      }

      if (outfitItems.isNotEmpty || items.isNotEmpty) {
        final payloadItems = outfitItems.isNotEmpty ? outfitItems : items;
        final jsonPayload = jsonEncode({
          'title': richData['title'],
          'occasion': storageOccasion,
          'items': payloadItems,
        });
        try {
          return await databases.createDocument(
            databaseId: Env.appwriteDatabaseId,
            collectionId: Env.savedBoardsCollection,
            documentId: ID.unique(),
            data: {
              'userId': user.$id,
              'occasion': storageOccasion,
              'imageUrl': cleanImageUrl,
              'thumbnailUrl': cleanImageUrl,
              'itemIds': itemIds,
              'boardCategory': categoryKey,
              'boardCategoryLabel': categoryLabel,
              'title': richData['title'],
              'prompt': richData['prompt'],
              'outfitDescription': richData['outfitDescription'],
              'emoji': richData['emoji'],
              'createdAt': nowIso,
              'board_payload': jsonPayload,
            },
          );
        } catch (e) {
          debugPrint(
            'JSON saved board write failed, retrying minimal schema: $e',
          );
        }
      }

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        documentId: ID.unique(),
        data: {
          'userId': user.$id,
          'occasion': storageOccasion,
          'imageUrl': cleanImageUrl,
          'itemIds': itemIds,
        },
      );
    } catch (e) {
      debugPrint('Error saving board: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> _savedBoardItemList(Object? raw) {
    if (raw is! Iterable) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
          final url =
              (item['imageUrl'] ??
                      item['image_url'] ??
                      item['masked_url'] ??
                      item['maskedUrl'] ??
                      item['url'] ??
                      item['thumbnailUrl'])
                  ?.toString()
                  .trim() ??
              '';
          return url.isNotEmpty;
        })
        .toList();
  }

  Map<String, dynamic> _savedBoardPayload(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _savedBoardOccasionLabel(String value) {
    final raw = value.trim();
    final key = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    switch (key) {
      case 'party':
      case 'party_looks':
      case 'date':
      case 'date_night':
        return 'Party';
      case 'office':
      case 'office_fit':
      case 'office_fits':
      case 'work':
        return 'Office';
      case 'vacation':
      case 'travel':
      case 'airport':
      case 'holiday':
        return 'Vacation';
      case 'occasion':
      case 'wedding':
      case 'event':
      case 'festival':
        return 'Occasion';
      case 'everything_else':
      case 'everything':
      case 'other':
      case 'unclear':
        return 'Everything Else';
      default:
        return raw.isEmpty ? 'Everything Else' : raw;
    }
  }

  String _savedBoardCategoryKey(String label) {
    switch (_savedBoardOccasionLabel(label).toLowerCase()) {
      case 'party':
        return 'party_looks';
      case 'office':
        return 'office_fits';
      case 'vacation':
        return 'vacation';
      case 'occasion':
        return 'occasion';
      default:
        return 'everything_else';
    }
  }

  String _fallbackSavedBoardTitle(String categoryLabel, String desc) {
    final cleanDesc = desc
        .split('+')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .join(' ');
    final stem = cleanDesc.isEmpty ? categoryLabel : cleanDesc;
    return '$stem Look';
  }

  Future<void> deleteSavedBoard(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting board: $e");
      throw Exception("Failed to delete board");
    }
  }

  // =========================================================================
  // SKINCARE DB METHODS
  // =========================================================================

  Future<Document?> getSkincareProfile() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return null;

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.skincareCollection,
        queries: [Query.equal('userId', user.$id)], // FIXED to userId
      );

      if (result.documents.isEmpty) {
        return await databases.createDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.skincareCollection,
          documentId: ID.unique(),
          data: {
            'userId': user.$id, // FIXED to userId
            'skinType': '',
            'concerns': [],
            'daySteps': [],
            'nightSteps': [],
            'lastUpdated': DateTime.now().toIso8601String(),
          },
        );
      }
      return result.documents.first;
    } catch (e) {
      debugPrint("Error fetching skincare profile: $e");
      return null;
    }
  }

  Future<void> updateSkincareProfile({
    required String documentId,
    String? skinType,
    List<String>? concerns,
    List<int>? daySteps,
    List<int>? nightSteps,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      if (skinType != null) updateData['skinType'] = skinType;
      if (concerns != null) updateData['concerns'] = concerns;
      if (daySteps != null) updateData['daySteps'] = daySteps;
      if (nightSteps != null) updateData['nightSteps'] = nightSteps;
      updateData['lastUpdated'] = DateTime.now().toIso8601String();

      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.skincareCollection,
        documentId: documentId,
        data: updateData,
      );
    } catch (e) {
      debugPrint("Error updating skincare profile: $e");
    }
  }

  // =========================================================================
  // WORKOUT OUTFITS DB METHODS
  // =========================================================================

  Future<List<Document>> getWorkoutOutfits() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching workout outfits: $e");
      return [];
    }
  }

  Future<Document> createWorkoutOutfit(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating workout outfit: $e");
      rethrow;
    }
  }

  Future<void> deleteWorkoutOutfit(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting workout outfit: $e");
      rethrow;
    }
  }

  // =========================================================================
  // BILLS & COUPONS DB METHODS
  // =========================================================================

  Future<List<Document>> getBills() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching bills: $e");
      return [];
    }
  }

  Future<Document> createBill(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating bill: $e");
      rethrow;
    }
  }

  Future<void> deleteBill(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting bill: $e");
      rethrow;
    }
  }

  Future<List<Document>> getCoupons() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
      return [];
    }
  }

  Future<Document> createCoupon(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating coupon: $e");
      rethrow;
    }
  }

  Future<void> deleteCoupon(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting coupon: $e");
      rethrow;
    }
  }

  // =========================================================================
  // MEDI TRACKER DB METHODS
  // =========================================================================

  Future<List<Document>> getMeds() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching meds: $e");
      return [];
    }
  }

  Future<Document> createMed(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating med: $e");
      rethrow;
    }
  }

  Future<void> updateMed(String documentId, Map<String, dynamic> data) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: documentId,
        data: data,
      );
    } catch (e) {
      debugPrint("Error updating med: $e");
      rethrow;
    }
  }

  Future<void> deleteMed(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting med: $e");
      rethrow;
    }
  }

  Future<List<Document>> getMedLogs() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medLogsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('time'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching med logs: $e");
      return [];
    }
  }

  Future<Document> createMedLog(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      debugPrint(
        'AHVI_MEDLOG_CREATE userId=${user.$id} '
        'medId=${data['medId']} status=${data['status']} '
        'collection=${Env.medLogsCollection}',
      );

      final doc = await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medLogsCollection,
        documentId: ID.unique(),
        data: data,
      );
      debugPrint('AHVI_MEDLOG_OK id=${doc.$id}');
      return doc;
    } catch (e, st) {
      // Appwrite errors usually carry a `.code` + `.message`. Stringify
      // so adb logcat shows EXACTLY why the write failed — most common
      // case is collection permission (Users role lacks create).
      debugPrint('AHVI_MEDLOG_FAIL err=$e');
      debugPrint('AHVI_MEDLOG_FAIL stack=$st');
      rethrow;
    }
  }

  // =========================================================================
  // MEAL PLANNER DB METHODS
  // =========================================================================

  Future<List<Document>> getMealPlans() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching meal plans: $e");
      return [];
    }
  }

  Future<Document> createMealPlan(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating meal plan: $e");
      rethrow;
    }
  }

  Future<void> deleteMealPlan(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting meal plan: $e");
      rethrow;
    }
  }

  // =========================================================================
  // LIFE GOALS DB METHODS
  // =========================================================================

  Future<List<Document>> getLifeGoals() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching life goals: $e");
      return [];
    }
  }

  Future<Document> createLifeGoal(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating life goal: $e");
      rethrow;
    }
  }

  Future<void> updateLifeGoalProgress(String documentId, int progress) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: documentId,
        data: {'progress': progress},
      );
    } catch (e) {
      debugPrint("Error updating life goal progress: $e");
      rethrow;
    }
  }

  Future<void> deleteLifeGoal(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting life goal: $e");
      rethrow;
    }
  }
}
