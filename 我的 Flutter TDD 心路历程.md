# 我的 Flutter TDD 心路历程

> **导读：** **Test-driven development (TDD)** 在当前国内很多软件开发人员理解中比较模糊，大部分人也没有明确和有意识的去实施 `TDD`，因此很多人都有着不同的理解，包括我本人在实践 `TDD` 之前都比较排斥。不过有句话说得好：“实践是检验真理的唯一标准，任何没有经过实践就轻易下的结论都是耍流氓”（后半句话是我说的，没错）
>
> 因此，本文记录了我在 `Flutter` 中实践 `TDD` 的一些所思所考，全文根据真实经历，没有改编，仅供参考
>
> **阅读前提**：对 `Flutter`、`Dart`、`Flutter test` 以及 `TDD` 稍有了解



## 0. 怀疑和抗拒

- 感受不到 `TDD` 带来的价值，`TDD` 打破了常规的开发思路
- 觉得 `TDD` 繁琐，明明可以一口气实现的代码，为什么非要拆细
- 先写用例，但是无从下手，怎么设计用例
- 觉得写的用例有点傻，感觉没什么用
- 我写的代码逻辑很简单，肯定不会有问题，没必要写单测
- 写着写着发现之前的用例好像不太对，想改用例？
- 用例怎么拆？怎么控制粒度？
- 什么时候才重构？

## 1. 从无到有

案例：实现一个通用的支持上滑加载下拉刷新的 `Flutter` 列表

用例梳理：

- 加载过程显示 loading 动画
- 加载结果为空列表显示 empty 页面
- 加载结果失败显示 error 页面
- ...

一开始只梳理出三个用例，为了聚焦，没有考虑所有场景，理论上 `TDD` 是可以慢慢补充用例完善功能的，先聚焦这三个相对简单的用例

尝试一下 `TDD` 流程：先写单测用例 -> 用例失败 -> 编写最小可运行单测版本的实现

### 1.1 第一个用例：加载过程显示 loading 动画

**先写单测**

*思考：当前没有任何实现代码，意味着单测怎么写完全跳脱出具体实现，那肯定是怎么简单怎么来（不需要 mock），这里甚至不考虑合理性，先把用例需求用单测代码描述出来*

**Given：**首先我肯定需要准备一个 `Widget`，因为三个用例是不同加载状态对应不同显示 `Widget`，那我暂且设计成这个 `Widget` 需要一个 `Status` 入参，先不考虑合理性和扩展性，至少目前是可测的（后面会涉及重构）

**When：** 加载 `Widget`，并传入参数为 `loading` 表示加载中

**Then：**验证当前页面是否有 `loading widget` 出现

编码实现：

```dart
void main() {
  testWidgets("列表加载状态显示 loading", (tester) async {
    FeedList feedList = const FeedList(loadingStatus: LoadingStatus.loading);
    await tester.pumpWidget(MaterialApp(home: feedList));
    var loadingFinder = find.bySemanticsLabel("feed_loading");
    expect(loadingFinder, findsOneWidget, reason: "没有找到 loading 控件");
  });
}
```

**用例运行失败**

这个用例目前肯定是跑不过的

第一，根本没有 `FeedList` 这个 widget

第二，也不可能有 `feed_loading` 这个 semantics 的 widget

**编写最小可运行单测版本的实现**

```dart
enum LoadingStatus {
  loading,
}

class FeedList extends StatelessWidget {
  final LoadingStatus loadingStatus;

  const FeedList({
    Key? key,
    required this.loadingStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 注意：这里压根就没有判断状态，而是直接就显示一个 loading 态
    // 因为目前只有一个用例，这样的代码就已经能让用例通过了
    return Semantics(
      label: "feed_loading",
      child: Container(),
    );
  }
}
```

这样，之前的用例就能跑过了

![image-20211201170151990](https://tva1.sinaimg.cn/large/008i3skNgy1gwyfvqr2saj31dq05ygm9.jpg)

*思考：可以看到当前的实现很挫，是不符合我们功能的预期的，而是仅仅能够让用例通过的实现版本。按照我们常规的开发流程或者习惯，我们在实现的时候可能会忍不住想去优化代码，去想各种边界条件，然后写出一个比较完善的实现版本。例如这里我们可能习惯性定义好各种状态的枚举，然后在 `build` 的时候判断各种状态，实现各个状态的处理逻辑。这个看来很顺手的事情，我们现在暂且不做，按照 `TDD` 的开发流程，到这一步我们是坚决不能过早地去优化代码，去编写用例以外的实现的。先记住一个原则：我们所写的每一行代码，都尽可能**先**编写好测试用例来覆盖，即**先写测试用例，再写实现***

这里我们先忍着不着急去优化或者重构，我们继续往下

### 1.2 第二个用例：加载结果为空列表显示 empty 页面

**先写单测**

有了之前的代码，第二个用例自然而然就是换个状态入参即可，这也说明我们之前的设计到目前为止还是比较可测的，代码如下

```dart
  testWidgets("加载结束之后空列表状态显示空列表 widget", (tester) async {
      FeedList feedList = const FeedList(loadingStatus: LoadingStatus.empty);
      await tester.pumpWidget(MaterialApp(home: feedList));
      var loadingFinder = find.bySemanticsLabel(FeedList.semanticsFeedEmpty);
      expect(loadingFinder, findsOneWidget, reason: "没有找到空列表控件");
    });
```

**用例运行失败**

增加这个用例之后，现在跑一下单测：第一个用例成功，第二个用例失败

![image-20211203111955018](https://tva1.sinaimg.cn/large/008i3skNgy1gx0h8iv7kpj31fs07uta4.jpg)

显而易见，之前我们只实现了 loading 状态，甚至都没有判断入参，因此第二个用例肯定是失败的

**编写最小可运行单测版本的实现**

为了让两个用例都能够通过，现在我们就不得不加载判断逻辑了

```dart
enum LoadingStatus {
  loading,
  empty,
}

class FeedList extends StatelessWidget {
  static const semanticsFeedLoading = "feed_loading";
  static const semanticsFeedEmpty = "feed_empty";

  final LoadingStatus loadingStatus;

  const FeedList({
    Key? key,
    required this.loadingStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 增加判断逻辑
    switch (loadingStatus) {
      case LoadingStatus.loading:
        return Semantics(
          label: semanticsFeedLoading,
          child: Container(),
        );
      case LoadingStatus.empty:
        return Semantics(
          label: semanticsFeedEmpty,
          child: Container(),
        );
      default:
        return const SizedBox();
    }
  }
}
```

这样，两个用例就都能通过了

![image-20211203112249359](https://tva1.sinaimg.cn/large/008i3skNgy1gx0hbhpogkj31co068aaq.jpg)

### 1.3 第三个用例：加载结果失败显示 error 页面

有了前两个用例和实现铺垫，第三个用例就没有什么可讲了，增加一个判断逻辑即可，最终的单测代码和实现如下

```dart
void main() {
  group("feed 不同加载状态显示不同 widget", () {
    testWidgets("列表加载状态显示 loading", (tester) async {
      FeedList feedList = const FeedList(loadingStatus: LoadingStatus.loading);
      await tester.pumpWidget(MaterialApp(home: feedList));
      var loadingFinder = find.bySemanticsLabel(FeedList.semanticsFeedLoading);
      expect(loadingFinder, findsOneWidget, reason: "没有找到 loading 控件");
    });

    testWidgets("加载结束之后空列表状态显示空列表 widget", (tester) async {
      FeedList feedList = const FeedList(loadingStatus: LoadingStatus.empty);
      await tester.pumpWidget(MaterialApp(home: feedList));
      var loadingFinder = find.bySemanticsLabel(FeedList.semanticsFeedEmpty);
      expect(loadingFinder, findsOneWidget, reason: "没有找到空列表控件");
    });

    testWidgets("加载结束之后失败状态显示失败 widget", (tester) async {
      FeedList feedList = const FeedList(loadingStatus: LoadingStatus.failed);
      await tester.pumpWidget(MaterialApp(home: feedList));
      var loadingFinder =
          find.bySemanticsLabel(FeedList.semanticsFeedLoadFailed);
      expect(loadingFinder, findsOneWidget, reason: "没有找到加载失败控件");
    });
  });
}
```

```dart
import 'package:flutter/widgets.dart';

enum LoadingStatus {
  loading,
  empty,
  failed,
  loaded,
}

class FeedList extends StatelessWidget {
  static const semanticsFeedLoading = "feed_loading";
  static const semanticsFeedEmpty = "feed_empty";
  static const semanticsFeedLoadFailed = "feed_load_failed";

  final LoadingStatus loadingStatus;

  const FeedList({
    Key? key,
    required this.loadingStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (loadingStatus) {
      case LoadingStatus.loading:
        return Semantics(
          label: semanticsFeedLoading,
          child: Container(),
        );
      case LoadingStatus.empty:
        return Semantics(
          label: semanticsFeedEmpty,
          child: Container(),
        );
      case LoadingStatus.failed:
        return Semantics(
          label: semanticsFeedLoadFailed,
          child: Container(),
        );
      case LoadingStatus.loaded:
        return const SizedBox();
      default:
        return const SizedBox();
    }
  }
}
```

> 这里补充一点 `Flutter` 单测小知识：用 `group` 可以把一组相关的用例组合起来，这样有助于归类问题。

## 2. 初体验后的思考

*思考：可不可以一开始就把三个用例都写好，然后统一编写实现一次性让三个用例都通过？*

这里目前用例比较简单，且三种状态具有很强的相关性，只是状态不同，因此完全是可以的先编写好这三个用例的。拆分的粒度怎么控制？我觉得秉承一个原则：**拆分出来任务是足够聚焦的，不容易发散的。**

例如，这里举的三个用例，状态是有限的，因此足够聚焦；而假设我们一次性把上滑加载、下拉刷新等单测都一并写了，首先这样凭空写用例是很难写的（大家可以自己尝试一下），其次当我们想要实现让所有单测通过，我们要考虑的边界就变得很复杂，很容易造成 A 单测通过，B 单测都失败的情况。

继续完善功能，增加用例：加载成功且数据不为空，列表展示对应数据的 item

**编写单测**

*思考：我们期望传入 A，B，C 三个数据，在加载成功之后，页面中能够显示 A，B，C 三个 item。此时，之前设计的入参 `Status` 已经不够用了，我们还需要传入一个列表，这里我们暂且设计成一个数据类 `FeedModel`，里面包含一个状态和一个列表。同时因为我们需要验证页面是否展示对应的 item，还需要一个列表 item 构建的回调函数*

单测代码如下

```dart 
 testWidgets("加载成功且数据不为空，列表展示对应数据的 item", (tester) async {
    List<String> expectList = ["hello", "hi", "good", "bad"];
    List<String> actualList = [];
    FeedList feedList = FeedList<String>(
      feedModel: FeedModel(
        loadingStatus: LoadingStatus.loaded,
        listData: expectList,
      ),
      builder: (context, index, data) {
        actualList.add(data);
        return Container();
      },
    );
    await tester.pumpWidget(MaterialApp(home: feedList));

    expect(actualList.length, expectList.length, reason: "实际数据长度和预期数据长度不一致");
    actualList.asMap().forEach((index, actualData) {
      expect(actualData, expectList[index], reason: "实际数据和预期数据不符");
    });
  });
```

**单测运行失败**

**编写让单测通过的最小实现版本**

为了让单测通过，这个应该不难实现，只需要一个 `ListView`，使用传入的数据作为入参，然后把 `builder` 回调出来即可。

```dart
class FeedModel<T> {
  final LoadingStatus loadingStatus;
  final List<T> listData;

  const FeedModel({
    required this.loadingStatus,
    this.listData = const [],
  });
}
```

```dart
ListView.builder(
   itemBuilder: (context, index) {
      return builder!.call(context, index, feedModel.listData[index]);
    }
  },
   	itemCount: feedModel.listData.length,
  )
```

## 3. 首次尝到甜头

增加用例：如果还有下一页，滑动到最后一个 item 的时候，显示加载更多 widget

**用例**

```dart
testWidgets("滑动到最后一个 item 的时候，如果还有下一页，显示加载更多 widget", (tester) async {
    List<String> expectList = ["hello", "hi", "good", "bad", "last"];
    FeedList feedList = FeedList<String>(
      feedModel: FeedModel(
        loadingStatus: LoadingStatus.loaded,
        listData: expectList,
        hasNext: true,
      ),
      builder: (context, index, data) {
        // set height 100 to make sure list can scroll
        return SizedBox(height: 100, key: ValueKey(data));
      },
    );
    await tester.pumpWidget(MaterialApp(home: feedList));

    // scroll to the end
    var listFinder = find.byType(Scrollable);
    var lastItemFinder = find.byKey(const ValueKey("last"));
    await tester.scrollUntilVisible(lastItemFinder, 80, scrollable: listFinder);

    // should show load more widget
    var loadMoreFinder = find.bySemanticsLabel(FeedList.semanticsFeedLoadMore);
    expect(loadMoreFinder, findsOneWidget, reason: "没有找到加载更多 widget");
  });
```

**单测失败**

**编写让单测通过的最小实现版本**

*思考：入参需要增加一个字段，代表是否还有下一页；同时当列表滑动到最后一个 item 的时候，返回一个 loading Widget*

参数

```dart
class FeedModel<T> {
  final LoadingStatus loadingStatus;
  final List<T> listData;
  final bool hasNext;

  const FeedModel({
    required this.loadingStatus,
    this.hasNext = false,
    this.listData = const [],
  });
}
```

loading widget 是一个假数据，因此我们需要在原始数据基础上 + 1；如果没有下一页，也就不需要假数据和 loading widget，因此 `count` 的计算规则如下

```dart
var count = 0;
if (feedModel.listData.isEmpty) {
	count = 0;
} else if (feedModel.hasNext) {
	count = feedModel.listData.length + 1;
} else {
	count = feedModel.listData.length;
}
```

而 `ListView` 的 `Builder` 实现代码如下

```dart
ListView.builder(
   itemBuilder: (context, index) {
   	// 当滑动到最后一个 item 的时候，显示 Loading widget
   	if (index == count - 1) {
       return Semantics(
         label: semanticsFeedLoadMore,
         child: const SizedBox(height: 20),
         );
    } else {
      // 否则回调 builder 函数，构建普通 item
      return builder!.call(context, index, feedModel.listData[index]);
    }
  },
   	itemCount: count,
  )
```

这样，刚刚写的用例就通过了。

但是我们发现，之前的用例「加载成功且数据不为空，列表展示对应数据的 item」失败了

![image-20211205212734339](https://tva1.sinaimg.cn/large/008i3skNgy1gx3a1dses5j31ie0dktat.jpg)

可以看到，之前的这个用例，我们期望 build item 数量为 4，但是实际却只有 3 个，这个是为什么呢？

在这之前单测一直都是通过的，说明我们刚刚的实现，破坏了之前的用例，由于之前的用例，我们没有传入 `hasNext`，而 `hasNext` 默认参数是 `false`，当 `hasNext` 为 `false` 的时候，`count = feedModel.listData.length`，在用例中即为 4，而 `ListView` ` builder` 实现中，我们判断了当 `index == count - 1` 的时候，返回 loading widget 而不是回调传入的 `builder` 参数，因此，`builder` 只回调了三次，这也就导致之前的用例失败了。

那么我们只需要增加一个判断就可以了

![image-20211205213512628](https://tva1.sinaimg.cn/large/008i3skNgy1gx3a9an91bj31q807y769.jpg)



这个情况在我们日常开发中是很容易出现的，当我们开发新功能时，很容易忽略掉一些边界或者把之前的逻辑改坏，这时候单测就能够发挥其价值，而且，如果我们严格遵循 `TDD` 的开发流程，就可以把这种 bad case 扼杀在开发过程中，可以让我们交付出更有质量保障的代码

*思考：刚刚出现的问题，code review 能够轻易的发现吗？*

## 4. 开始增加复杂性

持续增加功能：

- 上滑加载结束之后，不应该展示 loading more widget
- 上滑加载结束之后，新列表插入旧列表尾部

从这里开始，有了一定的复杂性，之前的用例，基本上都是静态的（Stateless），状态通过参数传入，即状态一开始就确定了，不存在发生变化的可能。而现在，我们需要知道什么时候加载结束，引入了可变的状态（Stateful）并且需要在加载结束之后做一些验证。

*思考：由于「加载更多」是由列表内部触发的，如果我们想知道加载什么时候结束，我们就必须拿到加载的句柄，在 Dart 中，一般我们用 `Future` 来表示，于是我们能想到：我们可以从外部传入一个返回 `Future` 的方法，由列表内部获取并触发 `Future`，这样我们就可以从外部判断 `Future` 何时结束了*

> 这个思考过程，其实是可测性的构造过程，`TDD` 有助于我们写出更加可测的代码，更可测的代码往往意味着设计更加合理

单测代码这里忽略（这里不是重点），直接看下实现：

入参增加一个 `onLoadMore` 函数，返回一个 `Future`

```dart
final Future<FeedModel<T>> Function()? onLoadMore;
```

判断当列表滑动到最后一个 item 的时候，触发这个 `Future`

![image-20211205221336995](https://tva1.sinaimg.cn/large/008i3skNgy1gx3bd90mrsj30r4088t9j.jpg)

```dart
 _loadMore() async {
    if (widget.onLoadMore == null) {
      return;
    }
    var newFeedModel = await widget.onLoadMore!();
    setState(() {
      feedModel = newFeedModel;
    });
  }
```

可以看到，这里有一个 `setState`，为了能够让加载结束之后更新状态，这里要把之前的设计成 `Stateless` 的 FeedList 改成 `StatefuleWidget` 

## 5. 第一次重构

到这里，发现当前的 `FeedList` 越来越挫了，使用的时候要传入第一页数据，然后还要提供加载更多的 `Future`，第一页的数据明明也是一个 `Future`，但是交给外部处理，第二页之后的数据却又自己处理，总之这个设计对使用方是和不友好的

之前我们说，不用过早重构。之前我们想要重构或者优化的，是一些不够优雅的实现，这这次我们要重构的代码会让整个框架发生大的变化，具体来说就是构造函数会发生大的变化。因此如果到了现在这个阶段，如果还不做出一些改变，那么后续写的很多用例，包括先前写的一些用例可能都要废弃。

那么现在，就是一个较为合适的重构时机

重构：简化构造函数，统一首次加载和加载更多，加载时机都交给内部处理

入参重构为两个：

```dart
final DataWidgetBuilder<T>? builder; // 构建 item 的回调
final Future<FeedModel<T>> Function(int) onLoadMore; // 首次加载和加载更多的 Future 函数，参数表示当前列表 offset，可用于区分第几次加载
```

代码实现

```dart
// ... 省略无关代码
class FeedList<T> extends StatefulWidget {
 // ... 省略无关代码
  final DataWidgetBuilder<T>? builder;
  final Future<FeedModel<T>> Function(int) onLoadMore;
// ... 省略无关代码
}

class _FeedListState<T> extends State<FeedList<T>> {
  bool isFirstLoad = true;
  late FeedModel feedModel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      	// 注释1：如果是加载第一页，直接触发 onLoadMore, 并将返回的 Future 传给 FutureBuilder; 如果不是第一页，将 null 返回给 FutureBuilder，此时代码就会走入到 else 分支，注释2处
        future: isFirstLoad ? widget.onLoadMore(0) : null,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
           // ... 省略无关代码
          } else if (snapshot.hasError) {
           // ... 省略无关代码
          } else {
            // 注释2：当不是加载第一页，由于将 null 传给了 FutureBuilder，因此代码会走到这里来
            
            // 注释 3：如果是加载第一页，使用 snapshot 中的值，否则使用 state 的值
            if (isFirstLoad && snapshot.data != null) {
              feedModel = snapshot.data as FeedModel;
            }
            // ... 省略无关代码
            if (feedModel.listData.isEmpty) {
              // ... 省略无关代码
            } else {
              return Semantics(
                label: FeedList.semanticsFeedLoaded,
                child: widget.builder != null
                    ? ListView.builder(
                        itemBuilder: (context, index) {
                          // has next and reach to end, show loading more widget
                          if (feedModel.hasNext && index == count - 1) {
                            _loadMore(index);
                            return Semantics(
                              label: FeedList.semanticsFeedLoadMore,
                              child: const SizedBox(
                                height: 500,
                              ),
                            );
                          }
                          return widget.builder!
                              .call(context, index, feedModel.listData[index]);
                        },
                        itemCount: count,
                      )
                    : const SizedBox(),
              );
            }
          }
        });
  }

  _loadMore(int curIndex) async {
    var newFeedModel = await widget.onLoadMore(curIndex);
    setState(() {
      // 注释 4：加载更多的时候，更新 feedModel 值
      feedModel = FeedModel(
        hasNext: newFeedModel.hasNext,
        listData: [...feedModel.listData, ...newFeedModel.listData],
      );
      isFirstLoad = false;
    });
  }
}
```

这里使用 `FutureBuilder` 来加载第一页数据（见注释 1），用 `isFirstLoad` 来表示是否加载第一页。当触发加载更多时，`isFirstLoad` 设置为 `false`，且更新新的 `feedModel`，此时列表使用新的数据渲染列表（见注释 4）

可以看到，重构后相比之前是合理了许多，但是仍然不够优雅，比如每次加载更多的时候都是重建整个 widget，这带来很多不必要的重建，但这里我们也不再着急继续重构，我们本次的目的是为了让构造函数简化，后续的重构只是修改实现，并不会造成构造方式的大变化，因此完全可以放在后面再处理

由于本次重构修改了构造参数，因此之前的单测也要做比较大的重构才能够重新跑过。

![image-20211205231401908](https://tva1.sinaimg.cn/large/008i3skNgy1gx3d43sa0xj31wo070gnu.jpg)

## 6. 第二次重构 -- 再次感受到 TDD 的好处

之后用例的编写，基本都比较顺利，这里就不一一列举，在所有功能都基本完成的时候，我又做了一次重构，这一次，我用 `StreamBuilder` 来代替了 `FutureBuilder`，目的是为了减少不必要的重绘，以及让代码逻辑更加统一；由于这一次我只重构了具体实现，因此可以看到，我对实现代码改动比较大，但是单侧代码基本上没有动过

重构的部分 diff 截图

![image-20211205225145322](https://tva1.sinaimg.cn/large/008i3skNgy1gx3cgycavfj31eu0u0jze.jpg)

单测基本没改

![image-20211205225112651](https://tva1.sinaimg.cn/large/008i3skNgy1gx3cgdn83ij31xa0aa0vk.jpg)

改造完成之后，之前的所有用例都通过

![image-20211205225234897](https://tva1.sinaimg.cn/large/008i3skNgy1gx3chsvs1fj313c04udgd.jpg)

虽然重构改动代码量很大，但是单测结果让我感到很安心

## 7. 排疑解惑

- 感受不到 `TDD` 带来的价值，`TDD` 打破了常规的开发思路

  1. 价值很明显，先有单测，才有实现，让每一次的代码都有单测保障
  2. `TDD` 的开发流程帮助我们设计出更加合理的代码，让我们聚焦每次只做一件事

- 觉得 `TDD` 繁琐，明明可以一口气实现的代码，为什么非要拆细

  1. 同上，`TDD` 引导我们合理拆分任务
  2. 拆解任务有助于我们聚焦每次只做一件事

- 先写用例，但是无从下手，怎么设计用例

  不要急着编码，先思考、拆解任务，设计用例的过程就是拆解任务的过程，同时要思考代码如何设计才更加可测，而往往具有可测性的代码，其结构、职责更加清晰

- 觉得写的用例有点傻，感觉没什么用

  需要思考是不是需要写这个用例，不是所有代码都需要写单测，比如我们不需要验证一个传入了 “Hello” 的  Text widget 是否真的显示了 “Hello” 字样；比如我们不需要验证一个没有任何逻辑分支的代码段等等。

- 我写的代码逻辑很简单，肯定不会有问题，没必要写单测

  有时候当前逻辑可能比较简单，但是随着业务发展，将来可能会扩展很多功能，加入更复杂的逻辑判断，这个时候，之前写的不那么有价值的单测就能够发挥其作用

- 写着写着发现之前的用例好像不太对，想改用例？

  1. 单测代码也是代码，也会经历重构，这个是合理的；
  2. 但被测代码如果没有发生比较大的重构下，单测代码应该是比较稳定的，否则需要思考之前的单测是否写的合理
  3. 单测尽量少用 mock，尽量避免过于依赖具体实现，如果严格执行 `TDD` 流程，即先写单测，再写实现，基本都能避开上述问题

- 用例怎么拆？怎么控制粒度？

  拆分任务应遵循：足够聚焦，不易发散

- 什么时候才重构？

  1. `TDD` 过程不宜过早重构，当我们发现代码不便于扩展，需要对其结构做较大调整，比如构造函数发生变化时，可以开始重构，此时的重构一般也伴随对单测代码的重构。
  2. 当我们功能开发到较为稳定的阶段，想对具体实现，比如性能优化、代码逻辑优化等重构时，此时不需要修改单测，这个时候单测可以帮助我们验证重构是否安全和稳健

## 8. 成品展示

所有用例梳理：

![image-20211206142104099](https://tva1.sinaimg.cn/large/008i3skNgy1gx43bvvd1pj30ed0mj40b.jpg)

实现代码： [feed_list.dart](https://github.com/GeeJoe/FlutterTDD/blob/master/lib/feed_list.dart)

单测代码：[feed_test.dart](https://github.com/GeeJoe/FlutterTDD/blob/master/test/feed_test.dart)

覆盖率情况：![image-20211206121652380](https://tva1.sinaimg.cn/large/008i3skNgy1gx3zqsf7vyj30nr01fwem.jpg)