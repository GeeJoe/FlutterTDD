import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tdd/feed_list.dart';
import 'package:flutter_tdd/feed_list_repo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("首次加载", () {
    Future<Completer<FeedModel>> _pumpFeedListWithCompleter(WidgetTester tester,
        {Function(dynamic)? builder,
        OnLoadMoreStatusChanged? onLoadMoreStatusChanged}) async {
      Completer<FeedModel> firstLoadCompleter = Completer();

      FeedList feedList = FeedList(
        onLoadMore: (_) => firstLoadCompleter.future,
        onLoadMoreStatusChanged: onLoadMoreStatusChanged,
        builder: (BuildContext context, int index, data) {
          builder?.call(data);
          return const SizedBox();
        },
      );

      await tester.pumpWidget(MaterialApp(home: feedList));

      return firstLoadCompleter;
    }

    testWidgets("列表加载状态显示 loading", (tester) async {
      var firstLoadCompleter = await _pumpFeedListWithCompleter(tester);

      await tester.pumpAndSettle();

      var loadingFinder = find.byKey(FeedList.keyFeedLoading);
      expect(loadingFinder, findsOneWidget, reason: "没有找到 loading 控件");
      // 单测结束之后才让 Future 结束
      firstLoadCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();
    });

    testWidgets("列表加载状态显示定制 loading", (tester) async {
      var customLoadingKey = const Key("custom loading key");
      var firstLoadCompleter = await _pumpFeedListWithCompleter(tester,
          onLoadMoreStatusChanged: (state, _, __) {
        if (state == const FeedState.firstLoading()) {
          return Text("自定义 loading", key: customLoadingKey);
        }
      });

      await tester.pumpAndSettle();

      var loadingFinder = find.byKey(customLoadingKey);
      expect(loadingFinder, findsOneWidget, reason: "没有找到自定义 loading 控件");
      // 单测结束之后才让 Future 结束
      firstLoadCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();
    });

    testWidgets("加载结束之后失败状态显示失败 widget", (tester) async {
      var firstLoadCompleter = await _pumpFeedListWithCompleter(tester);

      // mock a Future.error
      firstLoadCompleter.completeError("mock load error");
      await tester.pumpAndSettle();

      var loadingFinder = find.byKey(FeedList.keyFeedLoadFailed);
      expect(loadingFinder, findsOneWidget, reason: "没有找到加载失败控件");
    });

    testWidgets("加载成功之后空列表状态显示空列表 widget", (tester) async {
      var firstLoadCompleter = await _pumpFeedListWithCompleter(tester);

      // mock a empty result
      firstLoadCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();

      var loadingFinder = find.byKey(FeedList.keyFeedEmpty);
      expect(loadingFinder, findsOneWidget, reason: "没有找到空列表控件");
    });

    testWidgets("加载成功之后如果列表不为空，展示列表 widget", (tester) async {
      var firstLoadCompleter = await _pumpFeedListWithCompleter(tester);

      // mock a not empty result
      firstLoadCompleter.complete(const FeedModel(listData: ["1", "2", "3"]));
      await tester.pumpAndSettle();

      var loadingFinder = find.byKey(FeedList.keyFeedLoaded);
      expect(loadingFinder, findsOneWidget, reason: "没有找到列表 widget");
    });

    testWidgets("加载成功且数据不为空，列表展示对应数据的 item", (tester) async {
      List expectList = ["1", "2", "3", "4"];
      List actualList = [];

      var firstLoadCompleter = await _pumpFeedListWithCompleter(
        tester,
        builder: (data) => actualList.add(data),
      );

      // mock a result with expectList
      firstLoadCompleter.complete(FeedModel(listData: expectList));
      await tester.pumpAndSettle();

      expect(actualList.length, expectList.length, reason: "实际数据长度和预期数据长度不一致");
      actualList.asMap().forEach((index, actualData) {
        expect(actualData, expectList[index], reason: "实际数据和预期数据不符");
      });
    });

    testWidgets("首次加载失败，点击重试", (tester) async {
      Completer<FeedModel> loadCompleter = Completer();

      FeedList feedList = FeedList(
        onLoadMore: (_) {
          loadCompleter = Completer();
          return loadCompleter.future;
        },
        builder: (BuildContext context, int index, data) {
          return SizedBox(height: 50, key: Key(data));
        },
      );

      await tester.pumpWidget(MaterialApp(home: feedList));
      // mock first load error
      loadCompleter.completeError("mock load error");
      await tester.pumpAndSettle();

      // tap error widget
      var errorFinder = find.byKey(FeedList.keyFeedLoadFailed);
      await tester.tap(errorFinder);
      await tester.pumpAndSettle();

      // mock reload succeed
      loadCompleter.complete(const FeedModel(listData: ["hello"]));
      await tester.pumpAndSettle();

      var helloItemFinder = find.byKey(const Key("hello"));
      expect(helloItemFinder, findsOneWidget, reason: "首次加载失败，点击没有触发重试");
    });

    testWidgets("首次加载空列表，点击重试", (tester) async {
      Completer<FeedModel> loadCompleter = Completer();

      FeedList feedList = FeedList(
        onLoadMore: (_) {
          loadCompleter = Completer();
          return loadCompleter.future;
        },
        builder: (BuildContext context, int index, data) {
          return SizedBox(height: 50, key: Key(data));
        },
      );

      await tester.pumpWidget(MaterialApp(home: feedList));
      // mock first load empty
      loadCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();

      // tap empty widget
      var emptyPageFinder = find.byKey(FeedList.keyFeedEmpty);
      await tester.tap(emptyPageFinder);
      await tester.pumpAndSettle();

      // mock reload succeed
      loadCompleter.complete(const FeedModel(listData: ["hello"]));
      await tester.pumpAndSettle();

      var helloItemFinder = find.byKey(const Key("hello"));
      expect(helloItemFinder, findsOneWidget, reason: "首次加载空列表，点击没有触发重试");
    });

    testWidgets("首次加载失败, 出现定制 error widget", (tester) async {
      Completer<FeedModel> firstLoadCompleter = Completer();
      var customFailedWidgetKey = const Key("custom failed widget");
      FeedList feedList = FeedList(
        onLoadMore: (_) => firstLoadCompleter.future,
        builder: (BuildContext context, int index, data) {
          return const SizedBox();
        },
        onLoadMoreStatusChanged: (
          state,
          __,
          ___,
        ) {
          if (state == const FeedState.firstLoadFailed()) {
            return SizedBox(key: customFailedWidgetKey);
          }
        },
      );

      await tester.pumpWidget(MaterialApp(home: feedList));

      // mock a Future.error
      firstLoadCompleter.completeError("mock load error");
      await tester.pumpAndSettle();

      var customFailedWidgetFinder = find.byKey(customFailedWidgetKey);
      expect(customFailedWidgetFinder, findsOneWidget,
          reason: "没有找到定制的 failed widget");
    });

    testWidgets("首次加载失败, 出现定制 error widget, 且支持点击 reload", (tester) async {
      Completer<FeedModel> firstLoadCompleter = Completer();
      var customFailedWidgetKey = const Key("custom failed widget");
      int onLoadMoreInvokeTimes = 0;
      FeedList feedList = FeedList(
        onLoadMore: (_) {
          onLoadMoreInvokeTimes++;
          firstLoadCompleter = Completer();
          return firstLoadCompleter.future;
        },
        builder: (BuildContext context, int index, data) {
          return const SizedBox();
        },
        onLoadMoreStatusChanged: (state, __, controller) {
          if (state == const FeedState.firstLoadFailed()) {
            return TextButton(
              key: customFailedWidgetKey,
              onPressed: () {
                controller.firstLoad();
              },
              child: const Text("error"),
            );
          }
        },
      );

      await tester.pumpWidget(MaterialApp(home: feedList));

      // mock a Future.error
      firstLoadCompleter.completeError("mock load error");
      await tester.pumpAndSettle();

      var customFailedWidgetFinder = find.byKey(customFailedWidgetKey);
      await tester.tap(customFailedWidgetFinder);
      await tester.pumpAndSettle();

      expect(onLoadMoreInvokeTimes, 2, reason: "点击自定义 error widget，没有触发重试");

      // 单测结束前记得让 Future 结束
      firstLoadCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();
    });

    testWidgets("首次加载为空, 出现定制 empty widget, 且支持点击 reload", (tester) async {
      Completer<FeedModel> firstLoadCompleter = Completer();
      var customEmptyWidgetKey = const Key("custom empty widget");
      int onLoadMoreInvokeTimes = 0;
      FeedList feedList = FeedList(
        onLoadMore: (_) {
          onLoadMoreInvokeTimes++;
          firstLoadCompleter = Completer();
          return firstLoadCompleter.future;
        },
        builder: (BuildContext context, int index, data) {
          return const SizedBox();
        },
        onLoadMoreStatusChanged: (state, __, controller) {
          if (state == const FeedState.firstLoadEmpty()) {
            return TextButton(
              key: customEmptyWidgetKey,
              onPressed: () {
                controller.firstLoad();
              },
              child: const Text("empty"),
            );
          }
        },
      );

      await tester.pumpWidget(MaterialApp(home: feedList));

      // mock a empty list
      firstLoadCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();

      var customEmptyWidgetFinder = find.byKey(customEmptyWidgetKey);
      await tester.tap(customEmptyWidgetFinder);
      await tester.pumpAndSettle();

      expect(onLoadMoreInvokeTimes, 2, reason: "点击自定义 empty widget，没有触发重试");

      // 单测结束前记得让 Future 结束
      firstLoadCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();
    });
  });

  group("上滑加载更多", () {
    Future<Completer<FeedModel>> _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
      WidgetTester tester, {
      required bool firstPageHasNext,
      List<String> firstPageList = const ["1", "2", "3", "4", "5"],
      Completer<FeedModel>? Function(int)? onLoadMore,
      Widget? Function(FeedState, int, RefreshLoadMoreController)?
          onLoadMoreFailed,
      Function(int, dynamic)? onBuild,
    }) async {
      Completer<FeedModel> loadMoreCompleter = Completer();
      FeedList feedList = FeedList(
        onLoadMore: (curIndex) {
          // 这里每次 load 都需要 new 一个 completer
          // 否则第二次 load 的时候会立马返回 complete 状态，与预期不符
          loadMoreCompleter = onLoadMore?.call(curIndex) ?? Completer();
          return loadMoreCompleter.future;
        },
        onLoadMoreStatusChanged: onLoadMoreFailed,
        builder: (context, index, data) {
          onBuild?.call(index, data);
          // set height 500 to make sure list can scroll
          return SizedBox(height: 500, key: Key(data));
        },
      );
      await tester.pumpWidget(MaterialApp(home: feedList));

      // mock first page result
      loadMoreCompleter.complete(
          FeedModel(hasNext: firstPageHasNext, listData: firstPageList));
      await tester.pumpAndSettle();

      // scroll to the end
      var listFinder = find.byType(Scrollable);
      var lastItemFinder = firstPageHasNext
          ? find.byKey(FeedList.keyFeedLoadMore)
          : find.byKey(const Key("5"));
      await tester.scrollUntilVisible(lastItemFinder, 80,
          scrollable: listFinder);

      return loadMoreCompleter;
    }

    testWidgets("滑动到最后一个 item 的时候，如果还有下一页，显示加载更多 widget", (tester) async {
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(tester,
              firstPageHasNext: true);

      // should show load more widget
      var loadMoreFinder = find.byKey(FeedList.keyFeedLoadMore);
      expect(loadMoreFinder, findsOneWidget, reason: "没有找到加载更多 widget");

      // 单测结束之后，让加载更多的 future 结束
      loadMoreCompleter.complete(const FeedModel());
    });

    testWidgets("滑动到最后一个 item 的时候，如果没有下一页，不显示加载更多 widget", (tester) async {
      await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(tester,
          firstPageHasNext: false);

      // should not show load more widget
      var loadMoreFinder = find.byKey(FeedList.keyFeedLoadMore);
      expect(loadMoreFinder, findsNothing, reason: "没有下一页，不应该显示加载更多 widget");
    });

    testWidgets("滑动到最后一个 item 的时候，如果还有下一页，触发加载更多回调", (tester) async {
      int loadNextIndex = 0;
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
        firstPageList: ["1", "2", "3", "4"],
        onLoadMore: (index) {
          loadNextIndex = index;
        },
      );

      // mock next page result
      loadMoreCompleter.complete(const FeedModel(
          listData: ["6", "7", "8", "9", "10"], hasNext: false));
      await tester.pumpAndSettle();

      // should call onLoadMore
      expect(loadNextIndex, 4, reason: "滑动到最后的时候没有回调 onLoadMore");
    });

    testWidgets("滑动到最后一个 item 的时候，如果没有下一页，不应该触发加载更多回调", (tester) async {
      int loadNextIndex = 0;
      await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: false,
        onLoadMore: (index) {
          loadNextIndex = index;
        },
      );

      await tester.pumpAndSettle();

      // should not call onLoadMore
      expect(loadNextIndex, 0, reason: "滑动到最后的时候不应回调 onLoadMore");
    });

    testWidgets("加载更多结束之后, loading 消失", (tester) async {
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
      );

      // mock next page result
      loadMoreCompleter.complete(const FeedModel(
          listData: ["6", "7", "8", "9", "10"], hasNext: false));
      await tester.pumpAndSettle();

      // should not show loadMoreWidget
      expect(find.byKey(FeedList.keyFeedLoadMore), findsNothing,
          reason: " 加载结束之后不应该显示 loadMore widget");
    });

    testWidgets("加载更多结束之后, 新列表应该插入旧列表尾部", (tester) async {
      List<String> firstPageList = const ["1", "2", "3", "4", "5"];
      List<String> nextPageList = const ["6", "7", "8", "9", "10"];

      Map<int, String> actualItemInListView = {};
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
        firstPageList: firstPageList,
        onBuild: (index, data) => actualItemInListView[index] = data,
      );

      // mock next page result
      loadMoreCompleter
          .complete(FeedModel(listData: nextPageList, hasNext: false));
      await tester.pumpAndSettle();

      var listFinder = find.byType(Scrollable);
      var firstItemFinder = find.byKey(const Key("1"));
      var lastItemFinder = find.byKey(const Key("10"));
      // scroll to top
      await tester.scrollUntilVisible(firstItemFinder, -80,
          scrollable: listFinder);
      // scroll to end
      await tester.scrollUntilVisible(lastItemFinder, 80,
          scrollable: listFinder);

      var expectList = [...firstPageList, ...nextPageList];
      var actualList = actualItemInListView;
      expect(actualList.length, expectList.length, reason: "最终的列表 item 数量不对");
      expectList.asMap().forEach((index, expected) {
        expect(actualList[index], expected, reason: "新列表没有按顺序插入旧列表尾部");
      });
    });

    testWidgets("加载更多失败, 回调失败函数", (tester) async {
      FeedState? loadMoreModel;
      int index = -1;
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
        firstPageList: ["1", "2", "3", "4", "5"],
        onLoadMoreFailed: (state, curIndex, ___) {
          loadMoreModel = state;
          index = curIndex;
        },
      );

      // mock next page result
      loadMoreCompleter.completeError("mock load more error");
      await tester.pumpAndSettle();

      expect(loadMoreModel?.type, LoadType.loadMore,
          reason: "加载更多失败之后应该回调加载更多失败函数");
      expect(loadMoreModel?.status, LoadStatus.failed,
          reason: "加载更多失败之后应该回调加载更多失败函数");
      expect(index, 5, reason: "加载更多失败之后回调的 index 不对");
    });

    testWidgets("加载更多为空, 回调失败函数", (tester) async {
      FeedState? loadMoreModel;
      int index = -1;
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
        firstPageList: ["1", "2", "3", "4", "5"],
        onLoadMoreFailed: (state, curIndex, ___) {
          loadMoreModel = state;
          index = curIndex;
        },
      );

      // mock next page result
      loadMoreCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();

      expect(loadMoreModel?.type, LoadType.loadMore,
          reason: "加载更多失败之后应该回调加载更多失败函数");
      expect(loadMoreModel?.status, LoadStatus.empty,
          reason: "加载更多失败之后应该回调加载更多失败函数");
      expect(index, 5, reason: "加载更多为空之后回调的 index 不对");
    });

    testWidgets("加载更多失败, 不再显示 loading, 而是显示 loadMore failed widget",
        (tester) async {
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
      );

      // mock next page result
      loadMoreCompleter.completeError("mock load more error");
      await tester.pumpAndSettle();

      expect(find.byKey(FeedList.keyFeedLoadMore), findsNothing,
          reason: "加载结束之后不应该显示 loadMore widget");
      expect(find.byKey(FeedList.keyFeedLoadMoreFailed), findsOneWidget,
          reason: "加载结束之后应该显示 loadMore error widget");
    });

    testWidgets("加载更多为空, 不再显示 loading", (tester) async {
      var loadMoreCompleter =
          await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
      );

      // mock next page result
      loadMoreCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();

      expect(find.byKey(FeedList.keyFeedLoadMore), findsNothing,
          reason: "加载结束之后不应该显示 loadMore widget");
    });

    testWidgets("加载更多失败，点击重试", (tester) async {
      int callLoadMore = 0;
      int loadMoreIndex = 0;
      Completer<FeedModel> loadMoreCompleter = Completer();
      await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
        firstPageList: ["1", "2", "3", "4", "5"],
        onLoadMore: (curIndex) {
          callLoadMore++;
          loadMoreIndex = curIndex;
          loadMoreCompleter = Completer();
          return loadMoreCompleter;
        },
      );

      // mock next page result
      loadMoreCompleter.completeError("mock load more error");
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(FeedList.keyFeedLoadMoreFailed));
      await tester.pumpAndSettle();

      expect(callLoadMore, 3, reason: "点击应该重试");
      expect(loadMoreIndex, 5, reason: "重试的时候 index 不对");

      // 单测结束前记得结束 Future
      loadMoreCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();
    });

    testWidgets("加载更多失败, 显示自定义 error widget, 且支持点击重试", (tester) async {
      Key customLoadMoreFailedKey = const Key("custom load more failed widget");
      int callLoadMore = 0;
      int loadMoreIndex = 0;
      Completer<FeedModel> loadMoreCompleter = Completer();
      await _pumpFeedListWithFirstPageLoadedAndScrollToEnd(
        tester,
        firstPageHasNext: true,
        firstPageList: ["1", "2", "3", "4", "5"],
        onLoadMore: (curIndex) {
          callLoadMore++;
          loadMoreIndex = curIndex;
          loadMoreCompleter = Completer();
          return loadMoreCompleter;
        },
        onLoadMoreFailed: (_, index, controller) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          key: customLoadMoreFailedKey,
          onTap: () {
            controller.loadMore(index);
          },
          child: const SizedBox(
            height: 20,
            width: double.infinity,
            child: Center(
                child: Text("哎呀加载失败了，点我重试...", style: TextStyle(fontSize: 14))),
          ),
        ),
      );

      // mock next page result
      loadMoreCompleter.completeError("mock load more error");
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(customLoadMoreFailedKey));
      await tester.pumpAndSettle();

      expect(callLoadMore, 3, reason: "点击应该重试");
      expect(loadMoreIndex, 5, reason: "重试的时候 index 不对");

      // 单测结束前记得结束 Future
      loadMoreCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();
    });
  });

  group("下拉刷新", () {
    Future<Completer<FeedModel>> _swipeToRefreshAfterWaitForFirstPageLoaded(
      WidgetTester tester, {
      FeedModel firstPageModel =
          const FeedModel(listData: ["1", "2", "3", "4", "5"]),
      bool shouldProvideOnRefresh = true,
      Completer<FeedModel>? Function()? callWhenOnRefresh,
      Function(LoadStatus)? callWhenOnRefreshFailed,
      Function(int, dynamic)? callOnBuild,
    }) async {
      Completer<FeedModel> firstPageCompleter = Completer();
      Completer<FeedModel> refreshCompleter = Completer();

      FeedList feedList = FeedList(
        onLoadMore: (_) => firstPageCompleter.future,
        onRefresh: !shouldProvideOnRefresh
            ? null
            : () {
                refreshCompleter = callWhenOnRefresh?.call() ?? Completer();
                return refreshCompleter.future;
              },
        onRefreshFailed: callWhenOnRefreshFailed,
        builder: (BuildContext context, int index, data) {
          callOnBuild?.call(index, data);
          return SizedBox(
            key: Key(data),
            height: 500,
          );
        },
      );
      await tester.pumpWidget(MaterialApp(home: feedList));
      // wait for first page loaded
      firstPageCompleter.complete(firstPageModel);
      await tester.pumpAndSettle();

      // try scroll to refresh and wait for settle
      await tester.dragFrom(const Offset(0, 50), const Offset(0, 100));

      return refreshCompleter;
    }

    testWidgets("当列表中没有数据的时候，不会触发下拉刷新", (tester) async {
      bool callOnRefresh = false;
      await _swipeToRefreshAfterWaitForFirstPageLoaded(
        tester,
        firstPageModel: const FeedModel(),
        callWhenOnRefresh: () {
          callOnRefresh = true;
        },
      );

      expect(callOnRefresh, false, reason: "没有数据的时候不应该触发下拉刷新");
    });

    testWidgets("当列表中有数据的时候，下拉会触发下拉刷新", (tester) async {
      bool callOnRefresh = false;
      var refreshCompleter = await _swipeToRefreshAfterWaitForFirstPageLoaded(
        tester,
        callWhenOnRefresh: () {
          callOnRefresh = true;
        },
      );

      expect(callOnRefresh, true, reason: "有数据的时候下拉应该触发下拉刷新");
      // 单测结束之后让拉下刷新 Future 结束
      refreshCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();
    });

    testWidgets("下拉刷新结束，如果刷新失败，回调失败函数", (tester) async {
      LoadStatus? loadStatus;
      var refreshCompleter = await _swipeToRefreshAfterWaitForFirstPageLoaded(
        tester,
        callWhenOnRefreshFailed: (status) => loadStatus = status,
      );
      // mock a refresh error
      refreshCompleter.completeError("mock fresh error");
      await tester.pumpAndSettle();

      expect(loadStatus, LoadStatus.failed, reason: "刷新失败应该触发回调函数");
    });

    testWidgets("下拉刷新结束，如果刷新为空列表，回调失败函数", (tester) async {
      LoadStatus? loadStatus;
      var refreshCompleter = await _swipeToRefreshAfterWaitForFirstPageLoaded(
        tester,
        callWhenOnRefreshFailed: (status) => loadStatus = status,
      );
      // mock a refresh empty
      refreshCompleter.complete(const FeedModel());
      await tester.pumpAndSettle();

      expect(loadStatus, LoadStatus.empty, reason: "刷新空列表应该触发回调函数");
    });

    testWidgets("下拉刷新结束，成功之后新列表替换旧列表", (tester) async {
      var expectedList = ["6", "7", "8", "9", "10"];
      var actualVisibleItemInList = {};
      var refreshCompleter = await _swipeToRefreshAfterWaitForFirstPageLoaded(
        tester,
        callOnBuild: (index, data) => actualVisibleItemInList[index] = data,
      );
      // mock a refresh result with expected list
      refreshCompleter
          .complete(FeedModel(hasNext: false, listData: expectedList));
      await tester.pumpAndSettle();

      var listFinder = find.byType(Scrollable);
      var lastItemFinder = find.byKey(const Key("10"));
      // scroll to end
      await tester.scrollUntilVisible(lastItemFinder, 80,
          scrollable: listFinder);

      expect(actualVisibleItemInList.length, expectedList.length,
          reason: "刷新结束后列表长度与预期不符");
      expectedList.asMap().forEach((index, expected) {
        expect(actualVisibleItemInList[index], expected,
            reason: "刷新结束后列表内容与预期不符");
      });
    });

    testWidgets("当没有提供 onRefresh 函数时，不支持下拉刷新", (tester) async {
      var actualVisibleItemInList = {};
      bool callOnRefreshFailed = false;
      bool callOnRefresh = false;
      var refreshCompleter = await _swipeToRefreshAfterWaitForFirstPageLoaded(
        tester,
        callOnBuild: (index, data) => actualVisibleItemInList[index] = data,
        callWhenOnRefreshFailed: (_) => callOnRefreshFailed = true,
        callWhenOnRefresh: () {
          callOnRefresh = true;
        },
        shouldProvideOnRefresh: false,
      );

      // mock a refresh result with expected list
      refreshCompleter
          .complete(const FeedModel(hasNext: false, listData: ["6"]));
      await tester.pumpAndSettle();

      var lastItemFinder = find.byKey(const Key("6"));

      expect(callOnRefreshFailed, false,
          reason: "没有提供 onRefresh 不应该支持下拉刷新, 但是却调用了 onRefreshFailed");
      expect(callOnRefresh, false,
          reason: "没有提供 onRefresh 不应该支持下拉刷新, 但是却调用了 onRefresh");
      expect(lastItemFinder, findsNothing,
          reason: "没有提供 onRefresh 不应该支持下拉刷新, 但是却发现刷出新列表了");
    });
  });
}
