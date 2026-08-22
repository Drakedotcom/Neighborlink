import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/logging/app_logger.dart';
import '../data/models/app_notification.dart';
import '../data/models/community_post.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/post_repository.dart';
import 'auth_controller.dart' show ViewState;

///NiS
/// State of the community feed including the category filter.
class FeedController extends ChangeNotifier {
  FeedController({
    PostRepository postRepository = const PostRepository(),
    NotificationRepository notificationRepository = const NotificationRepository(),
  }) : _postRepository = postRepository,
       _notificationRepository = notificationRepository;

  static const String _logTag = 'FeedController';

  final PostRepository _postRepository;
  final NotificationRepository _notificationRepository;

  List<CommunityPost> _posts = const <CommunityPost>[];
  Map<PostCategory, int> _categoryCounts = const <PostCategory, int>{};
  PostCategory? _activeFilter;
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  int? _neighborhoodId;

  List<CommunityPost> get posts => _posts;
  Map<PostCategory, int> get categoryCounts => _categoryCounts;
  PostCategory? get activeFilter => _activeFilter;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _state == ViewState.busy;
  int get totalPostCount =>
      _categoryCounts.values.fold(0, (sum, count) => sum + count);

  /// Loads the feed for a neighbourhood, honouring the active filter.
  Future<void> load(int neighborhoodId) async {
    _neighborhoodId = neighborhoodId;
    _state = ViewState.busy;
    notifyListeners();

    try {
      _posts = await _postRepository.loadFeed(
        neighborhoodId,
        category: _activeFilter,
      );
      _categoryCounts = await _postRepository.countByCategory(neighborhoodId);
      _state = ViewState.idle;
      _errorMessage = null;
    } on AppException catch (error) {
      _errorMessage = error.message;
      _state = ViewState.failure;
      AppLogger.instance.warning(_logTag, 'Feed could not be loaded.', error);
    }
    notifyListeners();
  }

  /// Switches the category filter. Passing `null` shows all categories.
  Future<void> applyFilter(PostCategory? category) async {
    if (_activeFilter == category) return;
    _activeFilter = category;
    final neighborhoodId = _neighborhoodId;
    if (neighborhoodId != null) {
      await load(neighborhoodId);
    } else {
      notifyListeners();
    }
  }

  /// Creates a post and notifies every other member of the neighbourhood.
  Future<bool> createPost({
    required int neighborhoodId,
    required int authorId,
    required String authorName,
    required String title,
    required String description,
    required PostCategory category,
    required List<int> neighborIds,
  }) async {
    try {
      await _postRepository.createPost(
        neighborhoodId: neighborhoodId,
        authorId: authorId,
        title: title,
        description: description,
        category: category,
      );

      // Team interface: notifications are written through Developer A's
      // repository so the inbox stays consistent across all modules.
      await _notificationRepository.pushToMany(
        recipientIds: neighborIds,
        title: 'Neuer Beitrag: ${category.label}',
        message: '$authorName hat "$title" im Feed veröffentlicht.',
        category: NotificationCategory.system,
        triggeredByUserId: authorId,
      );

      await load(neighborhoodId);
      AppLogger.instance.info(_logTag, 'Post created by user #$authorId.');
      return true;
    } on AppException catch (error) {
      _fail(error);
      return false;
    }
  }

  Future<bool> deletePost({
    required int postId,
    required int authorId,
    required int neighborhoodId,
  }) async {
    try {
      await _postRepository.deletePost(postId: postId, authorId: authorId);
      await load(neighborhoodId);
      return true;
    } on AppException catch (error) {
      _fail(error);
      return false;
    }
  }

  void reset() {
    _posts = const <CommunityPost>[];
    _categoryCounts = const <PostCategory, int>{};
    _activeFilter = null;
    _neighborhoodId = null;
    _state = ViewState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void _fail(AppException error) {
    _errorMessage = error.message;
    _state = ViewState.failure;
    AppLogger.instance.warning(_logTag, 'Feed action failed.', error);
    notifyListeners();
  }
}
