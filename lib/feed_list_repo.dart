import 'dart:async';

import 'package:flutter_tdd/feed_list.dart';

/// 列表加载的状态
enum LoadStatus {
  loading,
  failed,
  empty,
  succeed,
}

/// 列表加载的类型
enum LoadType {
  firstLoad,
  loadMore,
  refresh,
}

/// FeedList 数据类，用于描述页面当前状态需要渲染的数据
/// [listData] 是当前页的列表数据, 如果还有下一页 [hasNext] 为 true, 如果是最后一页 [hasNext] 为 false
/// 当加载更多/下拉刷新/重试失败的时候 [loadMoreError] 为 true
class FeedModel<T> {
  final List<T> listData;
  final bool hasNext;

  const FeedModel({
    this.hasNext = false,
    this.listData = const [],
  });

  @override
  String toString() {
    return 'FeedModel{listData: $listData, hasNext: $hasNext}';
  }
}

/// 用于内部描述列表当前 State
class FeedState {
  final LoadStatus status;
  final LoadType type;
  final FeedModel feedModel;

  const FeedState({
    required this.status,
    required this.type,
    this.feedModel = const FeedModel(),
  });

  @override
  String toString() {
    return 'FeedState{status: $status, type: $type, feedModel: $feedModel}';
  }

  const FeedState.firstLoading()
      : this(type: LoadType.firstLoad, status: LoadStatus.loading);

  const FeedState.firstLoadFailed()
      : this(type: LoadType.firstLoad, status: LoadStatus.failed);

  const FeedState.firstLoadEmpty()
      : this(type: LoadType.firstLoad, status: LoadStatus.empty);

  const FeedState.firstLoadSucceed(FeedModel feedModel)
      : this(
            type: LoadType.firstLoad,
            status: LoadStatus.succeed,
            feedModel: feedModel);

  const FeedState.loadMoreFailed(FeedModel feedModel)
      : this(
            type: LoadType.loadMore,
            status: LoadStatus.failed,
            feedModel: feedModel);

  const FeedState.loadMoreEmpty(FeedModel feedModel)
      : this(
            type: LoadType.loadMore,
            status: LoadStatus.empty,
            feedModel: feedModel);

  const FeedState.loadMoreSucceed(FeedModel feedModel)
      : this(
            type: LoadType.loadMore,
            status: LoadStatus.succeed,
            feedModel: feedModel);

  const FeedState.refreshing(FeedModel feedModel)
      : this(
            type: LoadType.refresh,
            status: LoadStatus.loading,
            feedModel: feedModel);

  const FeedState.refreshFailed(FeedModel feedModel)
      : this(
            type: LoadType.refresh,
            status: LoadStatus.failed,
            feedModel: feedModel);

  const FeedState.refreshEmpty(FeedModel feedModel)
      : this(
            type: LoadType.refresh,
            status: LoadStatus.empty,
            feedModel: feedModel);

  const FeedState.refreshSucceed(FeedModel feedModel)
      : this(
            type: LoadType.refresh,
            status: LoadStatus.succeed,
            feedModel: feedModel);
}

abstract class RefreshLoadMoreController {
  Future<void> firstLoad();

  Future<void> refresh();

  Future<void> loadMore(int curIndex);
}

class FeedListRepo with RefreshLoadMoreController {
  final OnLoadMoreCallback loadMoreCallback;
  final OnRefreshCallback? onRefreshCallback;

  FeedModel feedModel;

  FeedListRepo({
    required this.loadMoreCallback,
    this.onRefreshCallback,
  }) : feedModel = const FeedModel();

  final StreamController<FeedState> _streamController = StreamController();

  Stream<FeedState> stream() {
    return _streamController.stream;
  }

  @override
  firstLoad() async {
    _streamController.sink.add(const FeedState.firstLoading());
    try {
      feedModel = await loadMoreCallback.call(0);
      if (feedModel.listData.isEmpty) {
        _streamController.sink.add(const FeedState.firstLoadEmpty());
      } else {
        _streamController.sink.add(FeedState.firstLoadSucceed(feedModel));
      }
    } catch (error) {
      _streamController.sink.add(const FeedState.firstLoadFailed());
    }
  }

  @override
  loadMore(int curIndex) async {
    try {
      FeedModel newFeedModel = await loadMoreCallback.call(curIndex);
      if (newFeedModel.listData.isEmpty) {
        _streamController.sink.add(FeedState.loadMoreEmpty(
            FeedModel(hasNext: false, listData: feedModel.listData)));
      } else {
        _streamController.sink.add(FeedState.loadMoreSucceed(FeedModel(
            hasNext: newFeedModel.hasNext,
            listData: [...feedModel.listData, ...newFeedModel.listData])));
      }
    } catch (error) {
      _streamController.sink.add(FeedState.loadMoreFailed(
          FeedModel(hasNext: false, listData: feedModel.listData)));
    }
  }

  @override
  refresh() async {
    if (onRefreshCallback == null) {
      return;
    }
    try {
      FeedModel newFeedModel = await onRefreshCallback!.call();
      if (newFeedModel.listData.isEmpty) {
        _streamController.sink.add(FeedState.refreshEmpty(feedModel));
      } else {
        _streamController.sink.add(FeedState.refreshSucceed(newFeedModel));
      }
    } catch (error) {
      _streamController.sink.add(FeedState.refreshFailed(feedModel));
    }
  }
}
