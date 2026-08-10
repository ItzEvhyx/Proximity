import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../../core/config/env.dart';
import '../../../../../core/supabase/supabase_client.dart';
import 'circle_crop_modal.dart';

/// Handles profile avatar picking, cropping, uploading to Cloudinary, and
/// persisting the URL in the Supabase `profiles` table.
class ProfileAvatarService {
  ProfileAvatarService._();

  static final ProfileAvatarService instance = ProfileAvatarService._();

  final ImagePicker _picker = ImagePicker();

  static const String _columnAvatarUrl = 'avatar_url';
  static const String _tableProfiles = 'profiles';

  /// Allowed image extensions for profile pictures.
  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png'];

  /// Opens the device gallery restricted to images and returns the picked
  /// [File], or null if the user cancelled or picked an unsupported format.
  Future<File?> pickImage(BuildContext context) async {
    final XFile? xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
      requestFullMetadata: true,
    );

    if (xFile == null) return null;

    // Validate file extension.
    final ext = xFile.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPG and PNG images are supported.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;
    }

    return File(xFile.path);
  }

  /// Uploads [imageBytes] (PNG) to Cloudinary using the unsigned upload preset.
  /// Returns the secure delivery URL on success.
  Future<String> uploadToCloudinary(Uint8List imageBytes) async {
    final cloudName = Env.cloudinaryCloudName;
    final uploadPreset = Env.cloudinaryUploadPreset;

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = 'profile_avatars'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'avatar.png',
      ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['secure_url'] as String;
  }

  /// Persists [avatarUrl] in the `profiles` row for the current user.
  Future<void> saveAvatarUrl(String avatarUrl) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('No authenticated user');

    await supabase
        .from(_tableProfiles)
        .update({_columnAvatarUrl: avatarUrl}).eq('id', userId);
  }

  /// Fetches the current avatar URL from the `profiles` table, or null if
  /// none has been set.
  Future<String?> fetchAvatarUrl() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await supabase
        .from(_tableProfiles)
        .select(_columnAvatarUrl)
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    final url = row[_columnAvatarUrl] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  /// End-to-end: pick → crop (circle) → upload → save.
  /// Returns the new URL, or null if the user cancelled at any step.
  Future<String?> pickCropAndUploadAvatar(BuildContext context) async {
    final file = await pickImage(context);
    if (file == null) return null;

    // Open circle crop modal.
    if (!context.mounted) return null;
    final croppedBytes = await showCircleCropModal(context, file);
    if (croppedBytes == null) return null;

    final url = await uploadToCloudinary(croppedBytes);
    await saveAvatarUrl(url);
    return url;
  }
}
