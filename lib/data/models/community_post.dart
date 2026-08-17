import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';

/// The seven categories of the community feed, exactly as defined in the
/// project brief. [storageValue] is what ends up in the `category` column.
enum PostCategory {
  foodSharing('food_sharing', 'Food Sharing', Icons.restaurant_outlined),
  furniture('furniture', 'Möbel', Icons.chair_outlined),
  rideSharing('ride_sharing', 'Fahrgemeinschaft', Icons.directions_car_outlined),
  childCare('child_care', 'Kinderbetreuung', Icons.child_care_outlined),
  petCare('pet_care', 'Tierbetreuung', Icons.pets_outlined),
  events('events', 'Events', Icons.celebration_outlined),
  general('general', 'Allgemein', Icons.forum_outlined);

  const PostCategory(this.storageValue, this.label, this.icon);

  final String storageValue;
  final String label;
  final IconData icon;

  /// Accent colour of the category chip in the feed.
  Color get color => switch (this) {
    PostCategory.foodSharing => AppColors.categoryFood,
    PostCategory.furniture => AppColors.categoryFurniture,
    PostCategory.rideSharing => AppColors.categoryRide,
    PostCategory.childCare => AppColors.categoryChildCare,
    PostCategory.petCare => AppColors.categoryPetCare,
    PostCategory.events => AppColors.categoryEvent,
    PostCategory.general => AppColors.categoryGeneral,
  };

  /// Tolerant lookup: unknown values become [PostCategory.general] so that a
  /// row written by a future version cannot break the feed.
  static PostCategory fromStorage(String? value) => PostCategory.values
      .firstWhere(
        (category) => category.storageValue == value,
        orElse: () => PostCategory.general,
      );
}

/// A single entry of the neighbourhood feed.
@immutable
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.neighborhoodId,
    required this.authorId,
    required this.title,
    required this.description,
    required this.category,
    required this.createdAt,
    this.authorName = '',
  });

  final int id;
  final int neighborhoodId;
  final int authorId;
  final String title;
  final String description;
  final PostCategory category;
  final DateTime createdAt;

  /// Filled by the JOIN in [PostRepository]; not a column of `posts`.
  final String authorName;

  factory CommunityPost.fromMap(Map<String, Object?> row) => CommunityPost(
    id: row['id']! as int,
    neighborhoodId: row['neighborhood_id']! as int,
    authorId: row['author_id']! as int,
    title: row['title']! as String,
    description: row['description']! as String,
    category: PostCategory.fromStorage(row['category'] as String?),
    createdAt: DateTime.parse(row['created_at']! as String),
    authorName: (row['author_name'] as String?) ?? '',
  );

  Map<String, Object?> toMap() => <String, Object?>{
    if (id > 0) 'id': id,
    'neighborhood_id': neighborhoodId,
    'author_id': authorId,
    'title': title,
    'description': description,
    'category': category.storageValue,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'CommunityPost(#$id, ${category.storageValue}, $title)';
}
