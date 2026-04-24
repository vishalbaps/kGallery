import 'package:json_annotation/json_annotation.dart';

part 'gallery_item.g.dart';

enum GalleryItemType { image, video, audio }

@JsonSerializable()
class GalleryItem {
  final String url;
  @JsonKey(defaultValue: GalleryItemType.image)
  final GalleryItemType type;
  final String? thumbnailUrl;
  final String? title;
  final String? description;

  const GalleryItem({
    required this.url,
    this.type = GalleryItemType.image,
    this.thumbnailUrl,
    this.title,
    this.description,
  });

  factory GalleryItem.fromJson(Map<String, dynamic> json) =>
      _$GalleryItemFromJson(json);

  Map<String, dynamic> toJson() => _$GalleryItemToJson(this);
}
