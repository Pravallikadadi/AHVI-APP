/// Deterministic catalog image URL helper.
///
/// The backend stores the clean centered product image at a fixed key
/// `catalog_{item_id}.jpg` in the wardrobe R2 bucket, and (because the Appwrite
/// `outfits` collection is at its attribute-size cap) does NOT persist a
/// `catalog_url` field. The client therefore derives the URL deterministically.
///
/// We avoid needing a separately-configured R2 base URL by reusing the bucket
/// base already present in any existing full image URL on the item
/// (normalized/masked/raw), which look like `{base}/wardrobe_{id}.png`.
library;

String _baseDirOf(String? sampleUrl) {
  final u = (sampleUrl ?? '').trim();
  if (!u.startsWith('http')) return '';
  final slash = u.lastIndexOf('/');
  if (slash <= 0) return '';
  return u.substring(0, slash); // strip the filename
}

/// Build the deterministic catalog URL for [itemId].
///
/// [sampleUrl] must be an existing full wardrobe image URL (normalized/masked/
/// raw) so the bucket base can be derived. Returns '' when it can't be built.
String buildCatalogUrl({String? itemId, String? sampleUrl}) {
  final id = (itemId ?? '').trim();
  if (id.isEmpty) return '';
  final base = _baseDirOf(sampleUrl);
  if (base.isEmpty) return '';
  return '$base/catalog_$id.jpg';
}

/// Resolve the best image URL for a wardrobe item, in priority order:
/// catalog (only when ready) -> normalized -> masked -> raw.
String? resolveWardrobeImageUrl({
  String? itemId,
  String? catalogStatus,
  String? normalizedUrl,
  String? maskedUrl,
  String? imageUrl,
}) {
  final sample = (normalizedUrl?.isNotEmpty == true)
      ? normalizedUrl
      : (maskedUrl?.isNotEmpty == true ? maskedUrl : imageUrl);
  if (catalogStatus == 'catalog_ready') {
    final catalog = buildCatalogUrl(itemId: itemId, sampleUrl: sample);
    if (catalog.isNotEmpty) return catalog;
  }
  if (normalizedUrl?.isNotEmpty == true) return normalizedUrl;
  if (maskedUrl?.isNotEmpty == true) return maskedUrl;
  return imageUrl;
}
