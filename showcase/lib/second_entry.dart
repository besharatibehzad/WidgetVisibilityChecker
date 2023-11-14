import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Step 1: Import the necessary modules.
import 'package:widget_visibility_checker/multi_sliver_appbar_helper.dart';
import 'package:widget_visibility_checker/widget_visibility_checker.dart';

/// Step 2: Set up the main method.
void main(List<String> args) {
  runApp(const SecondShowCase());
}

/// Step 3: Declare unique identifiers for tracking widgets.
enum CheckVisibilityIds {
  firstZoneExitLine,
  firstZoneEnterLine,
  secondZoneExitLine,
  secondZoneEnterLine,
  thirdZoneExitLine,
  thirdZoneEnterLine,
}

/// Step 4: Essential boilerplate code for the showcase scenario.
class SecondShowCase extends StatefulWidget {
  const SecondShowCase({super.key});

  @override
  State<SecondShowCase> createState() => _SecondShowCaseState();
}

/// Step 5: Implement the VisibilityChangeHandler,TickerProviderStateMixin,MultiSliverAppBarHelper mixins.
class _SecondShowCaseState extends State<SecondShowCase>
    with
        VisibilityChangeHandler,
        TickerProviderStateMixin,
        MultiSliverAppBarHelper {
  @override
  void initState() {
    super.initState();

    /// Step 6: Initialize
    initMultiSliverAppBarHelper();

    /// Registering enum values in the collection to ensure the library is aware of them.
    for (var it in CheckVisibilityIds.values) {
      addNewVisibilityKeyToCollection(it.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: Scaffold(
        /// Step 7: Enclose your scrollable container (e.g., CustomScrollView,SingleChildScrollView,...) with the WidgetVisibilityChecker widget.
        body: WidgetVisibilityChecker(
            childScrollDirection: Axis.vertical,
            handler: this,
            child: NotificationListener<ScrollNotification>(
              onNotification: (data) {
                /// prevent ScrollNotification, bubbling up during animating phase
                return animatingPhase;
              },
              child: NotificationListener<UserScrollNotification>(
                onNotification: (data) {
                  /// prevent UserScrollNotification, bubbling up during animating phase
                  return animatingPhase;
                },
                child: CustomScrollView(
                  controller: customScrollViewCtrl,
                  slivers: [
                    /// Zone A
                    /// Step 8: Build a SliverAppBar Widget bound to important transition states.
                    buildPrimarySliverAppBar(0),
                    buildSliverList(),

                    /// Step 9: Build a Widget that needs to be observed for visibility state changes.
                    buildEnterAndExitLinesForZone(
                      exitIndexKey: getKeyById(
                          CheckVisibilityIds.firstZoneExitLine.index),
                      enterIndexKey: getKeyById(
                          CheckVisibilityIds.firstZoneEnterLine.index),
                      exitOffset: defaultExitOffset,
                      enterOffset: 0,
                    ),

                    /// Zone B
                    /// Step 8 Continuation: Build a SliverAppBar Widget bound to important transition states.
                    buildSliverAppBar('Second', 1),
                    buildSliverGrid(),

                    /// Step 9 Continuation: Build a Widget that needs to be observed for visibility state changes.
                    buildEnterAndExitLinesForZone(
                      exitIndexKey: getKeyById(
                          CheckVisibilityIds.secondZoneExitLine.index),
                      enterIndexKey: getKeyById(
                          CheckVisibilityIds.secondZoneEnterLine.index),
                      exitOffset: defaultExitOffset,
                      enterOffset: 0,
                    ),

                    /// Zone C
                    /// Step 8 Continuation: Build a SliverAppBar Widget bound to important transition states.
                    buildSliverAppBar('Third', 2),

                    buildSliverGrid(),

                    /// Step 9 Continuation: Build a Widget that needs to be observed for visibility state changes.
                    buildEnterAndExitLinesForZone(
                      exitIndexKey: getKeyById(
                          CheckVisibilityIds.thirdZoneExitLine.index),
                      enterIndexKey: getKeyById(
                          CheckVisibilityIds.thirdZoneEnterLine.index),
                      exitOffset: defaultExitOffset,
                      enterOffset: 0,
                    ),
                  ],
                ),
              ),
            )),
      ),
    );
  }

  /// Step 10: Implement `visibilityStatesChanged` to detect changes in target widgets visibility.
  @override
  void visibilityStatesChanged() {
    if (currentVisibilityStates.isEmpty) {
      return;
    }
    if (animatingPhase) {
      return;
    }

    /// Smoothly trigger the attachment/detachment of the SliverAppBar.
    applyTransitionState();
  }

  /// Step 11: Override other important methods.

  @override
  void scrollMetricsChanged() /*Ignored*/ {
    if (currentVisibilityStates.isEmpty) {
      return;
    }
  }

  @override
  void needRepaint(void Function() fn) /*Invoked by parent mixins.*/ {
    if (animatingPhase) {
      return;
    }
    setState(fn);
  }

  @override
  int get numberOfZones => CheckVisibilityIds.values.length ~/ 2;

  @override
  /*Possible Values: within-vp, across-vp, touched-vp-end, outside-vp-end, touched-vp-start, outside-vp-start*/
  String getEnterLinePositionByIndex(int index) =>
      mainPositionByKey((index * 2) + 1);

  @override
  /*Possible Values: within-vp, across-vp, touched-vp-end, outside-vp-end, touched-vp-start, outside-vp-start*/
  String getExitLinePositionByIndex(int index) =>
      mainPositionByKey((index * 2) + 0);

  @override
  bool get forwardMoveIsActive =>
      currentScrollDirection == ScrollDirection.reverse;

  /// Step 12: Important builders...

  Widget buildSliverAppBar(var title, int index,
      {double expandedHeight = 120}) {
    return SliverFadeTransition(
      // Important Property ***
      opacity: fadeAnimationControllers[index].value,

      sliver: SliverAppBar(
        // Important Properties ***
        primary: true,
        floating: pinnedStates[index],
        pinned: pinnedStates[index],
        // ***

        centerTitle: false,
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        expandedHeight: expandedHeight,
        flexibleSpace: FlexibleSpaceBar(
          centerTitle: false,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.yellow,
            ),
          ),
          titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
          background: DecoratedBox(
            decoration: BoxDecoration(color: Colors.primaries[index]),
          ),
          expandedTitleScale: 2,
        ),
      ),
    );
  }

  SliverFadeTransition buildPrimarySliverAppBar(int index) {
    return SliverFadeTransition(
      // Important Property ***
      opacity: fadeAnimationControllers[index].value,

      sliver: SliverAppBar(
        centerTitle: false,
        title: const Text('First'),

        // Important Properties ***
        primary: true,
        floating: pinnedStates[index],
        pinned: pinnedStates[index],
        // ***

        expandedHeight: appBarExpandedHeight,
        flexibleSpace: FlexibleSpaceBar(
          titlePadding:
              const EdgeInsetsDirectional.only(start: 90.0, bottom: 14.7),
          background: Image.network(
            'https://picsum.photos/600/300',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // Less important builders...

  SliverList buildSliverList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return ListTile(
            title: Text('Item $index'),
          );
        },
        childCount: 30,
      ),
    );
  }

  SliverGrid buildSliverGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return Card(
            color: Colors.primaries[index],
            elevation: 3,
            child: Center(
              child: Text('Grid Item $index'),
            ),
          );
        },
        childCount: 18, // Replace with the desired number of items
      ),
    );
  }
}
