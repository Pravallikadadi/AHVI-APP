import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite/enums.dart';
import 'package:myapp/config/env.dart';
import 'package:myapp/services/notification_service.dart';

class AppwriteService extends ChangeNotifier {
  late Client client;
  late Account account;
  late Databases databases;
  late Avatars avatars;

  // Cached user — avoid repeated network calls
  User? _cachedUser;

  AppwriteService() {
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

  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    try {
      _cachedUser = await account.get();
      return _cachedUser;
    } catch (e) {
      debugPrint("No active session or error: $e");
      return null;
    }
  }

  // Call this after login to pre-cache user
  Future<void> cacheCurrentUser() async {
    try {
      _cachedUser = await account.get();
    } catch (_) {}
  }

  // Clear cache on logout
  void clearUserCache() {
    _cachedUser = null;
  }

  Future<Session?> loginEmailPassword(String email, String password) async {
    try {
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
    await ensureCurrentUserProfile();
      notifyListeners();
      return session;
    } catch (e) {
      debugPrint("Login error: $e");
      rethrow;
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      await account.createOAuth2Session(provider: OAuthProvider.google);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Google login error: $e");
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    try {
      await account.createOAuth2Session(provider: OAuthProvider.apple);
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
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      return user;
    } catch (e) {
      debugPrint("Register error: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await AhviNotificationService.instance.unregisterForCurrentUser(this);
      await account.deleteSession(sessionId: 'current');
      clearUserCache();
      notifyListeners();
    } catch (e) {
      debugPrint("Logout error: $e");
    }
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
    final raw = (user.name.toString().trim().isNotEmpty
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

  Future<void> ensureCurrentUserProfile() async {
    if (_userProfileSyncInFlight) return;

    final usersCollectionId = Env.usersCollection.trim();
    if (usersCollectionId.isEmpty) {
      debugPrint('⚠️ Users collection env is empty. Skipping user profile sync.');
      return;
    }

    _userProfileSyncInFlight = true;

    try {
      final user = await account.get();

      final displayName = user.name.toString().trim().isNotEmpty
          ? user.name.toString().trim()
          : user.email.toString().split('@').first;

      final data = <String, dynamic>{
        'name': displayName,
        'username': _safeUsernameFromUser(user),
        'email': user.email,
        // Existing users collection supports this attribute.
        // Keep it empty for new users until onboarding/profile updates it.
        'stylePreferences': <String>[],
      };

      try {
        await databases.getDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: usersCollectionId,
          documentId: user.$id,
        );

        await databases.updateDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: usersCollectionId,
          documentId: user.$id,
          data: {
            'name': data['name'],
            'username': data['username'],
            'email': data['email'],
          },
        );

        debugPrint('✅ User profile synced: ${user.$id}');
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          await databases.createDocument(
            databaseId: Env.appwriteDatabaseId,
            collectionId: usersCollectionId,
            documentId: user.$id,
            data: data,
            permissions: [
              Permission.read(Role.user(user.$id)),
              Permission.update(Role.user(user.$id)),
              Permission.delete(Role.user(user.$id)),
            ],
          );

          debugPrint('✅ User profile created: ${user.$id}');
          return;
        }

        debugPrint(
          '❌ User profile sync AppwriteException: code=${e.code}, type=${e.type}, message=${e.message}',
        );
      }
    } catch (e) {
      debugPrint('❌ User profile sync failed: $e');
    } finally {
      _userProfileSyncInFlight = false;
    }
  }


// 👔 WARDROBE (OUTFITS) DB METHODS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getWardrobeItems() async {
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

      return result.documents.map((doc) {
        return {
          "id": doc.$id,
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

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.equal('occasion', occasion),
          Query.orderDesc('\$createdAt'),
        ],
      );
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
    Map<String, dynamic>? extra,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        documentId: ID.unique(),
        data: {
          'userId': user.$id,
          'occasion': occasion,
          'outfitDescription': outfitDescription,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          'emoji': emoji ?? '✨',
          if (extra != null) ...extra,
        },
      );
    } catch (e) {
      debugPrint('Error saving board: $e');
      return null;
    }
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

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medLogsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating med log: $e");
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
