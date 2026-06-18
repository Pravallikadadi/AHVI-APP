/// Wardrobe image URL priority helper.
///
/// Appwrite column budget is tight, so the premium catalog PNG is stored in the
/// existing `normalized_url` column. `image_url` remains the original upload and
/// `masked_url` remains the RMBG/cutout PNG.
library;

/// Resolve the best image URL for a wardrobe item, in priority order:
/// normalized catalog PNG -> masked cutout PNG -> original/raw.
String? resolveWardrobeImageUrl({
  String? normalizedUrl,
  String? maskedUrl,
  String? imageUrl,
}) {
  if (normalizedUrl?.isNotEmpty == true) return normalizedUrl;
  if (maskedUrl?.isNotEmpty == true) return maskedUrl;
  return imageUrl;
}
