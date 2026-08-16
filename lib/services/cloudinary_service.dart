import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // ============================================================
  // CLOUDINARY
  // ============================================================

  static final CloudinaryPublic cloudinary = CloudinaryPublic(
    'xlgd3ark',
    'chattax',
    cache: false,
  );

  // ============================================================
  // IMAGE
  //
  // Used for:
  // - Profile pictures
  // - Chat images
  // - Story photos
  // - Other images
  // ============================================================

  static Future<String?> uploadImage(
    File file, {
    String folder = 'chattax_images',
  }) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print('ChattªX image upload error: $e');
      return null;
    }
  }

  // ============================================================
  // STORY IMAGE
  //
  // Specifically for ChattªX Stories.
  // ============================================================

  static Future<String?> uploadStoryImage(File file) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'chattax_stories/images',
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print('ChattªX story image upload error: $e');
      return null;
    }
  }

  // ============================================================
  // VIDEO
  //
  // Used for:
  // - Chat videos
  // - Story videos
  // - Reels
  // ============================================================

  static Future<String?> uploadVideo(
    File file, {
    String folder = 'chat_videos',
  }) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Video,
          folder: folder,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print('ChattªX video upload error: $e');
      return null;
    }
  }

  // ============================================================
  // STORY VIDEO
  //
  // Specifically for ChattªX Stories.
  // ============================================================

  static Future<String?> uploadStoryVideo(File file) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'chattax_stories/videos',
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print('ChattªX story video upload error: $e');
      return null;
    }
  }

  // ============================================================
  // DOCUMENT
  // ============================================================

  static Future<String?> uploadDocument(File file) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Raw,
          folder: 'chat_documents',
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print('ChattªX document upload error: $e');
      return null;
    }
  }

  // ============================================================
  // VOICE
  // ============================================================

  static Future<String?> uploadVoice(File file) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'voice_messages',
        ),
      );

      return response.secureUrl;
    } catch (e) {
      print('ChattªX voice upload error: $e');
      return null;
    }
  }
}