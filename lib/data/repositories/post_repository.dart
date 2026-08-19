import '../../core/errors/app_exception.dart';
import '../database/schema/core_schema.dart';
import '../database/schema/community_schema.dart';
import '../models/community_post.dart';
import 'base_repository.dart';

///NiS
/// Data access for the community feed.
class PostRepository extends BaseRepository {
  const PostRepository();

  /// Loads the feed of a neighbourhood, newest first.
  /// When [category] is given, only posts of that category are returned —
  /// this powers the filter chips above the feed.
  Future<List<CommunityPost>> loadFeed(
    int neighborhoodId, {
    PostCategory? category,
  }) {
    return guard('loadFeed($neighborhoodId, ${category?.storageValue})', () async {
      final database = await db;

      final whereClauses = <String>['p.neighborhood_id = ?'];
      final arguments = <Object?>[neighborhoodId];
      if (category != null) {
        whereClauses.add('p.category = ?');
        arguments.add(category.storageValue);
      }

      final rows = await database.rawQuery('''
        SELECT p.*, u.full_name AS author_name
          FROM ${CommunitySchema.tablePosts} p
          JOIN ${CoreSchema.tableUsers} u ON u.id = p.author_id
         WHERE ${whereClauses.join(' AND ')}
      ORDER BY p.created_at DESC, p.id DESC
      ''', arguments);

      return mapRows(rows, CommunityPost.fromMap);
    });
  }

  /// Creates a post and returns its new id.
  Future<int> createPost({
    required int neighborhoodId,
    required int authorId,
    required String title,
    required String description,
    required PostCategory category,
  }) {
    return guard('createPost($title)', () async {
      if (title.trim().isEmpty || description.trim().isEmpty) {
        throw const ValidationException(
          'Titel und Beschreibung dürfen nicht leer sein.',
        );
      }

      final database = await db;
      return database.insert(CommunitySchema.tablePosts, <String, Object?>{
        'neighborhood_id': neighborhoodId,
        'author_id': authorId,
        'title': title.trim(),
        'description': description.trim(),
        'category': category.storageValue,
        'created_at': nowAsIso,
      });
    });
  }

  /// Deletes a post. Only the author may do this — the check lives in the
  /// WHERE clause so it cannot be bypassed from the UI.
  Future<void> deletePost({required int postId, required int authorId}) {
    return guard('deletePost(#$postId)', () async {
      final database = await db;
      final affectedRows = await database.delete(
        CommunitySchema.tablePosts,
        where: 'id = ? AND author_id = ?',
        whereArgs: <Object?>[postId, authorId],
      );
      if (affectedRows == 0) {
        throw const BusinessRuleException(
          'Nur die Autorin oder der Autor kann diesen Beitrag löschen.',
        );
      }
    });
  }

  /// Number of posts per category — used by the filter bar badges.
  Future<Map<PostCategory, int>> countByCategory(int neighborhoodId) {
    return guard('countByCategory($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        '''
        SELECT category, COUNT(*) AS total
          FROM ${CommunitySchema.tablePosts}
         WHERE neighborhood_id = ?
      GROUP BY category
        ''',
        <Object?>[neighborhoodId],
      );

      final counts = <PostCategory, int>{};
      for (final row in rows) {
        final category = PostCategory.fromStorage(row['category'] as String?);
        counts[category] = (row['total'] as int?) ?? 0;
      }
      return counts;
    });
  }

  /// Total number of posts in a neighbourhood (dashboard figure).
  Future<int> countAll(int neighborhoodId) {
    return guard('countAll($neighborhoodId)', () async {
      final database = await db;
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS total FROM ${CommunitySchema.tablePosts} '
        'WHERE neighborhood_id = ?',
        <Object?>[neighborhoodId],
      );
      return (rows.first['total'] as int?) ?? 0;
    });
  }
}
