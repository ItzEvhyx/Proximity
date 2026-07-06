import '../config/env.dart';

/// Thin wrapper around Cloudinary's URL-based image delivery.
///
/// We don't pull in the full Cloudinary SDK — for read-only delivery all we
/// need is the cloud name and each asset's public ID. This service just
/// builds optimized delivery URLs so images are streamed from Cloudinary's
/// CDN instead of being bundled into the app.
///
/// Call [init] once at start-up (after `Env.load()`), then read URLs via
/// [imageUrl] or the named train-photo getters.
class CloudinaryService {
  CloudinaryService._();

  static final CloudinaryService instance = CloudinaryService._();

  /// The cloud name is a public identifier (visible in every delivery URL
  /// anyway), so we keep a compile-time fallback to avoid silent failures
  /// when the .env.local asset cache is stale.
  static const String _fallbackCloudName = 'dcss9u5od';

  late final String _cloudName;

  /// Reads the cloud name from [Env]. Falls back to the compile-time
  /// constant if the env key is missing (stale asset cache).
  void init() {
    try {
      final name = Env.cloudinaryCloudName;
      _cloudName = name.isNotEmpty ? name : _fallbackCloudName;
    } catch (_) {
      _cloudName = _fallbackCloudName;
    }
  }

  bool get isInitialized => _cloudName.isNotEmpty;

  // ── Known asset public IDs ─────────────────────────────────────────────
  static const String lrt1TrainPublicId = 'lrt1_train_img_vsoz9g';
  static const String lrt2TrainPublicId = 'lrt2_train_img_mca45c';
  static const String mrtTrainPublicId = 'mrt_train_img_rnolzz';
  static const String trainRoutesPublicId = 'train_routes_img_grswoy';
  static const String finderMapPublicId = 'finder_map_img_eckw2n';

  /// Delivery URL for the LRT-1 train photo.
  String get lrt1TrainUrl => imageUrl(lrt1TrainPublicId, width: 400);

  /// Delivery URL for the LRT-2 train photo.
  String get lrt2TrainUrl => imageUrl(lrt2TrainPublicId, width: 400);

  /// Delivery URL for the MRT train photo.
  String get mrtTrainUrl => imageUrl(mrtTrainPublicId, width: 400);

  /// Delivery URL for the rail transit route map.
  String get trainRoutesUrl => imageUrl(trainRoutesPublicId, width: 600);

  /// Delivery URL for the Way Finder map image.
  String get finderMapUrl => imageUrl(finderMapPublicId, width: 300);

  /// Builds an optimized delivery URL for [publicId].
  ///
  /// Applies `f_auto` (best format), `q_auto` (automatic quality), and
  /// optional `w_/h_/c_fill` resize so Cloudinary ships a small, device-
  /// optimized payload.
  String imageUrl(String publicId, {int? width, int? height}) {
    final transforms = <String>['f_auto', 'q_auto'];
    if (width != null) transforms.add('w_$width');
    if (height != null) transforms.add('h_$height');
    if (width != null || height != null) transforms.add('c_fill');

    final t = transforms.join(',');
    return 'https://res.cloudinary.com/$_cloudName/image/upload/$t/$publicId';
  }
}
