import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tdd/feed_list_repo.dart';

/// 扩展自官方的 [IndexedWidgetBuilder], 这里增加一个参数 [data] 表述当前 item 的数据
typedef IndexWithDataWidgetBuilder<T> = Widget Function(
    BuildContext context, int index, T data);

/// 需要返回一个 [Future], 列表会根据 [Future] 的状态来加载数据或处理错误, 其中参数代表当前加载的列表 offset
/// 例如第一页如果有 5 个数据，在触发加载更多的时候 offset 为 5, 首次加载 offset 为 0
typedef OnLoadMoreCallback<T> = Future<FeedModel<T>> Function(int);

/// 需要返回一个 [Future], 列表会根据 [Future] 的状态来加载数据或处理错误
typedef OnRefreshCallback<T> = Future<FeedModel<T>> Function();

/// 参数 [index] 表示当前列表的 offset, 例如第一页如果有 5 个数据，offset 为 5, 首次加载 offset 为 0;
/// 参数 [state.type] 表示加载类型, [state.status] 表示加载状态
/// 方法可返回一个 Widget, 用于 在不同状态下显示不同的自定义 Widget
/// 可利用回调参数中的 [controller] 进行重试
typedef OnLoadMoreStatusChanged = Widget? Function(
    FeedState state, int index, RefreshLoadMoreController controller);

/// 参数 [loadStatus] 加载失败的状态
typedef OnRefreshFailedCallback = void Function(LoadStatus loadStatus);

/// 一个通用的 Feed 列表 Widget, 包含以下功能:
///
/// ## 首次加载，根据 [onLoadMore] 不同状态显示不同 Widget
/// 1. 加载过程中显示 loading 状态
/// 2. 加载失败显示 failed 状态
/// 3. 加载结束空列表展示 empty 状态
/// 4. 加载结束非空列表展示 list 列表, 列表通过 [builder] 加载 item
///
/// ## 上滑加载更多
/// 1. 滑动到最后一个 item 的时候如果还有下一页，回调 [onLoadMore] 并显示加载更多 widget
/// 2. 滑动到最后一个 item 的时候如果没有下一页，不显示加载更多 widget
/// 3. [onLoadMore] 加载结束之后，加载更多 widget 消失，且将新列表添加到列表尾部
/// 4. [onLoadMore] 加载结束之后，如果加载失败，回调加载失败函数 [onLoadMoreStatusChanged]
///
/// ## 下拉刷新
/// 1. 当列表中没有任何数据、或者没有提供 [onRefresh] 函数的时候，列表不支持下拉刷新
/// 2. 下拉刷新时会回调 [onRefresh] 函数，如果刷新失败，会回调 [onRefreshFailed]
/// 3. 当 [onRefresh] 刷新成功之后，新列表将替代旧列表数据
///

class FeedList<T> extends StatelessWidget {
  static const keyFeedLoading = ValueKey("feed_loading");
  static const keyFeedLoadFailed = ValueKey("feed_load_failed");
  static const keyFeedEmpty = ValueKey("feed_empty");
  static const keyFeedLoaded = ValueKey("feed_loaded");
  static const keyFeedLoadMore = ValueKey("feed_load_more");
  static const keyFeedLoadMoreFailed = ValueKey("feed_load_more_failed");

  /// 用于列表加载每个 item 时回调
  final IndexWithDataWidgetBuilder<T> builder;

  /// 上滑加载更多的时候回调该函数
  final OnLoadMoreCallback<T> onLoadMore;

  /// 下拉刷新的时候回调该函数，如果不指定该函数，则列表不支持下拉刷新
  final OnRefreshCallback<T>? onRefresh;

  /// 上滑加载/首次加载状态发生变化，回调该函数
  final OnLoadMoreStatusChanged? onLoadMoreStatusChanged;

  /// 下拉刷新的时候如果刷新失败，回调该函数
  final OnRefreshFailedCallback? onRefreshFailed;

  final FeedListRepo feedListRepo;

  FeedList({
    Key? key,
    required this.onLoadMore,
    required this.builder,
    this.onRefresh,
    this.onLoadMoreStatusChanged,
    this.onRefreshFailed,
  })  : feedListRepo = FeedListRepo(
            loadMoreCallback: onLoadMore, onRefreshCallback: onRefresh)
          ..firstLoad(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: feedListRepo.stream(),
      initialData: const FeedState.firstLoading(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        FeedState state = snapshot.data as FeedState;
        debugPrint("state=$state");
        if (state == const FeedState.firstLoading()) {
          Widget? loadingWidget =
              onLoadMoreStatusChanged?.call(state, 0, feedListRepo);
          return KeyedSubtree(
            key: FeedList.keyFeedLoading,
            child: loadingWidget ??
                const Center(
                  child: Text("正在奋力加载中...", style: TextStyle(fontSize: 14)),
                ),
          );
        }
        if (state == const FeedState.firstLoadFailed()) {
          Widget? failedWidget =
              onLoadMoreStatusChanged?.call(state, 0, feedListRepo);
          return KeyedSubtree(
            key: FeedList.keyFeedLoadFailed,
            child: failedWidget ??
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => feedListRepo.firstLoad(),
                  child: const Center(
                    child: Text("哎呀... 加载失败啦...o(╥﹏╥)o",
                        style: TextStyle(fontSize: 14)),
                  ),
                ),
          );
        }
        if (state == const FeedState.firstLoadEmpty()) {
          Widget? emptyWidget =
              onLoadMoreStatusChanged?.call(state, 0, feedListRepo);
          return KeyedSubtree(
            key: FeedList.keyFeedEmpty,
            child: emptyWidget ??
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => feedListRepo.firstLoad(),
                  child: const Center(
                    child: Text("Oo...没有数据呀...~╮(╯▽╰)╭",
                        style: TextStyle(fontSize: 14)),
                  ),
                ),
          );
        }
        return KeyedSubtree(
            key: FeedList.keyFeedLoaded, child: _listView(state));
      },
    );
  }

  Widget _listView(FeedState state) {
    if (state.type == LoadType.refresh) {
      if (state.status == LoadStatus.empty) {
        onRefreshFailed?.call(LoadStatus.empty);
      } else if (state.status == LoadStatus.failed) {
        onRefreshFailed?.call(LoadStatus.failed);
      }
    }

    FeedModel feedModel = state.feedModel;
    bool isLoadMoreFailedOrEmpty = (state.type == LoadType.loadMore &&
        (state.status == LoadStatus.failed ||
            state.status == LoadStatus.empty));
    var count = 0;
    if (feedModel.hasNext || isLoadMoreFailedOrEmpty) {
      count = feedModel.listData.length + 1;
    } else {
      count = feedModel.listData.length;
    }

    ListView listView = ListView.builder(
      itemBuilder: (context, index) {
        // has next and reach to end, show loading more widget
        if (feedModel.hasNext && index == count - 1) {
          debugPrint("show loading widget");
          feedListRepo.loadMore(index);
          return const KeyedSubtree(
            key: FeedList.keyFeedLoadMore,
            child: SizedBox(
              height: 20,
              width: double.infinity,
              child: Center(
                  child: Text("正在奋力加载中...", style: TextStyle(fontSize: 14))),
            ),
          );
        }
        if (isLoadMoreFailedOrEmpty && index == count - 1) {
          debugPrint("show load more error widget");
          var customLoadMoreFailedWidget =
              onLoadMoreStatusChanged?.call(state, index, feedListRepo);
          return customLoadMoreFailedWidget ??
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                key: FeedList.keyFeedLoadMoreFailed,
                onTap: () {
                  feedListRepo.loadMore(feedModel.listData.length);
                },
                child: const SizedBox(
                  height: 20,
                  width: double.infinity,
                  child: Center(
                      child: Text("哎呀加载失败了，点我重试...",
                          style: TextStyle(fontSize: 14))),
                ),
              );
        }
        debugPrint("show item widget = ${feedModel.listData[index]}");
        return builder.call(context, index, feedModel.listData[index]);
      },
      itemCount: count,
    );
    return onRefresh == null
        ? listView
        : RefreshIndicator(
            onRefresh: () => feedListRepo.refresh(),
            child: listView,
          );
  }
}
