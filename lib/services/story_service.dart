import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloudinary_service.dart';

class StoryService {
  StoryService._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final FirebaseAuth _auth =
      FirebaseAuth.instance;

  /// Publishes one or more story items.
  ///
  /// [onProgress] returns a value from 0.0 to 1.0.
  /// This allows StoryStudioScreen to display real publishing progress.
  static Future<bool> publishStories({
    required List<File> files,
    required List<String> mediaTypes,
    required String caption,
    required String privacy,
    void Function(double progress)? onProgress,
    void Function(String status)? onStatus,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      onStatus?.call('You must be signed in.');
      return false;
    }

    if (files.isEmpty) {
      onStatus?.call('No story media selected.');
      return false;
    }

    if (files.length != mediaTypes.length) {
      onStatus?.call('Story media information is invalid.');
      return false;
    }

    try {
      onProgress?.call(0.0);
      onStatus?.call('Preparing your story...');

      // ------------------------------------------------------------
      // LOAD CURRENT USER PROFILE
      // ------------------------------------------------------------

      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> userData =
          userSnapshot.data() ?? <String, dynamic>{};

      final String displayName =
          (userData['displayName'] ??
                  userData['name'] ??
                  user.displayName ??
                  'User')
              .toString()
              .trim();

      final String photoUrl =
          (userData['photoUrl'] ??
                  userData['photoURL'] ??
                  user.photoURL ??
                  '')
              .toString()
              .trim();

      final bool verified =
          userData['verified'] == true ||
          userData['isVerified'] == true ||
          userData['verificationStatus'] == 'verified';

      // ------------------------------------------------------------
      // STORY GROUP
      // ------------------------------------------------------------

      final String groupId =
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final DateTime now = DateTime.now();

      final DateTime expiresAt =
          now.add(const Duration(hours: 24));

      final List<Map<String, dynamic>> uploadedStories =
          <Map<String, dynamic>>[];

      // ------------------------------------------------------------
      // UPLOAD MEDIA
      // ------------------------------------------------------------

      for (int index = 0; index < files.length; index++) {
        final File file = files[index];

        final String mediaType =
            mediaTypes[index].toLowerCase().trim();

        final int itemNumber = index + 1;

        onStatus?.call(
          'Uploading story $itemNumber of ${files.length}...',
        );

        String? mediaUrl;

        if (mediaType == 'video') {
          mediaUrl =
              await CloudinaryService.uploadStoryVideo(file);
        } else {
          mediaUrl =
              await CloudinaryService.uploadStoryImage(file);
        }

        if (mediaUrl == null ||
            mediaUrl.trim().isEmpty) {
          throw Exception(
            'Failed to upload story item $itemNumber.',
          );
        }

        uploadedStories.add(
          <String, dynamic>{
            // ------------------------------------------------------
            // OWNER
            // ------------------------------------------------------

            'userId': user.uid,
            'createdBy': user.uid,

            // ------------------------------------------------------
            // PROFILE
            // ------------------------------------------------------

            'displayName': displayName,
            'name': displayName,

            'userPhoto': photoUrl,
            'photoUrl': photoUrl,
            'photoURL': photoUrl,

            'verified': verified,

            // ------------------------------------------------------
            // MEDIA
            // ------------------------------------------------------

            'mediaUrl': mediaUrl,
            'mediaType': mediaType,

            // ------------------------------------------------------
            // STORY CONTENT
            // ------------------------------------------------------

            'caption': caption.trim(),
            'privacy': privacy,

            // ------------------------------------------------------
            // MULTI-STORY ORDERING
            // ------------------------------------------------------

            'sequence': index,
            'totalItems': files.length,
            'groupId': groupId,

            // ------------------------------------------------------
            // TIMING
            // ------------------------------------------------------

            'createdAt': Timestamp.fromDate(now),
            'expiresAt': Timestamp.fromDate(expiresAt),

            // ------------------------------------------------------
            // VIEW DATA
            // ------------------------------------------------------

            'viewCount': 0,
          },
        );

        // Upload progress.
        final double progress =
            (index + 1) / files.length;

        onProgress?.call(progress * 0.85);
      }

      // ------------------------------------------------------------
      // SAVE STORY DOCUMENTS
      // ------------------------------------------------------------

      onStatus?.call('Saving your story...');

      final WriteBatch batch =
          _firestore.batch();

      for (final Map<String, dynamic> story
          in uploadedStories) {
        final DocumentReference<Map<String, dynamic>> ref =
            _firestore
                .collection('stories')
                .doc();

        final Map<String, dynamic> storyWithId =
            <String, dynamic>{
          ...story,
          'storyId': ref.id,
        };

        batch.set(
          ref,
          storyWithId,
        );
      }

      await batch.commit();

      // ------------------------------------------------------------
      // COMPLETE
      // ------------------------------------------------------------

      onProgress?.call(1.0);
      onStatus?.call('Story published!');

      return true;
    } catch (e) {
      print(
        'ChattªX story publish error: $e',
      );

      onStatus?.call(
        'Something went wrong while publishing.',
      );

      return false;
    }
  }
}