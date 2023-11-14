library widget_visibility_checker;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:widget_visibility_checker/debounce.dart';

class WidgetVisibilityChecker extends StatefulWidget {
  const WidgetVisibilityChecker({
    super.key,
    required this.child,
    required this.childScrollDirection,
    this.mainAxisStartingEdgeDeflateRatio = 0.0,
    this.mainAxisEndingEdgeDeflateRatio = 0.0,
    this.crossAxisStartingEdgeDeflateRatio = 0.0,
    this.crossAxisEndingEdgeDeflateRatio = 0.0,
    this.drawDebugOverlay = false,
    this.defaultThrottleTime = 500,
    this.offScreenColor,
    this.enableAdvancedScrollDetectionMethod = false,
    required this.handler,
  });

  final Widget child;

  //sum of this two must not be bigger than 1.0
  final double mainAxisStartingEdgeDeflateRatio; //number between 0..1
  final double mainAxisEndingEdgeDeflateRatio; //number between 0..1
  final double crossAxisStartingEdgeDeflateRatio; //number between 0..1
  final double crossAxisEndingEdgeDeflateRatio; //number between 0..1
  final bool drawDebugOverlay;
  final int defaultThrottleTime;
  final Axis childScrollDirection;
  final Color? offScreenColor;
  final bool ignorePointer = true;
  /// Enable it to detect scroll events initiated by the scrollbar thumb when dragged by the user.
  /// Enabling This, slightly decrease performance
  final bool enableAdvancedScrollDetectionMethod;
  final VisibilityChangeHandler handler;

  @override
  State<WidgetVisibilityChecker> createState() =>
      WidgetVisibilityCheckerState();

  static WidgetVisibilityCheckerState watch(BuildContext context) {
    final WidgetVisibilityCheckerState? state =
    context.findAncestorStateOfType<WidgetVisibilityCheckerState>();
    if (state == null) {
      throw Exception(
          "Unable to find WidgetVisibilityChecker in the widget tree.");
    }
    state.addContext(context);
    return state;
  }

  static void inspectKey(VisibilityKey key) {
    var context = key.currentContext;
    if (context == null) {
      throw Exception("BuildContext is not available.");
    }
    final WidgetVisibilityCheckerState? state =
    context.findAncestorStateOfType<WidgetVisibilityCheckerState>();
    if (state == null) {
      throw Exception(
          "Unable to find WidgetVisibilityChecker in the widget tree.");
    }

    state.inspect(key);
  }

  static bool isKeyInspected(VisibilityKey key) {
    var context = key.currentContext;

    if (context == null) {
      return false;
    }
    final WidgetVisibilityCheckerState? state =
    context.findAncestorStateOfType<WidgetVisibilityCheckerState>();
    if (state == null) {
      throw Exception(
          "Unable to find WidgetVisibilityChecker in the widget tree.");
    }

    return state.isKeyInspected(key);
  }

  static void unwatch(BuildContext context, bool alsoRemoveKeyFromCollection) {
    final WidgetVisibilityCheckerState? state =
    context.findAncestorStateOfType<WidgetVisibilityCheckerState>();
    if (state == null) {
      throw Exception(
          "Unable to find WidgetVisibilityChecker in the widget tree.");
    }
    state.removeContext(context, alsoRemoveKeyFromCollection);
  }

  static void unwatchAll(BuildContext context,
      bool alsoRemoveKeyFromCollection) {
    final WidgetVisibilityCheckerState? state =
    context.findAncestorStateOfType<WidgetVisibilityCheckerState>();
    if (state == null) {
      throw Exception(
          "Unable to find WidgetVisibilityChecker in the widget tree.");
    }
    state.removeAllContext(alsoRemoveKeyFromCollection);
  }
}

class WidgetVisibilityCheckerState extends State<WidgetVisibilityChecker> {
  final Debounce throttle = Debounce();
  final Map<BuildContext, List<ScrollableState>> scrollablePerSubject = {};
  final List<BuildContext> contextList =
  List<BuildContext>.empty(growable: true);

  ScrollDirection currentScrollDirection = ScrollDirection
      .reverse; //content goes up//scroll goes down//vertical-position increases
  int previousMetricHash = 0;
  VisibilityKey? inspectionKey;
  bool duringComputationPhase = false;

  void addContext(BuildContext subjectContext) {
    if (contextList.contains(subjectContext)) return;
    if (!(subjectContext.mounted)) return;

    contextList.add(subjectContext);

    //put it in the cache if isn't already
    scrollablePerSubject.putIfAbsent(subjectContext,
            () => findAncestorScrollableList(subjectContext, context));
  }

  void removeContext(BuildContext subjectContext,
      bool alsoRemoveKeyFromCollection) {
    if (!contextList.contains(subjectContext)) return;
    contextList.remove(subjectContext);

    widget.handler.clearStateForKey(subjectContext.widget.key as VisibilityKey,
        alsoRemoveKeyFromCollection);
    if (scrollablePerSubject.keys.contains(subjectContext)) {
      scrollablePerSubject.remove(subjectContext);
    }
  }

  void removeAllContext(bool alsoRemoveKeyFromCollection) {
    contextList.clear();
    scrollablePerSubject.clear();
    widget.handler.clearStateForAllKeys(alsoRemoveKeyFromCollection);
  }

  void inspect(VisibilityKey key) {
    inspectionKey = key;
  }

  bool isKeyInspected(VisibilityKey key) {
    return inspectionKey == key;
  }

  bool isAncestorOf(BuildContext potentialAncestorContext,
      BuildContext childContext) {
    BuildContext? currentContext = childContext;

    while (currentContext != null) {
      if (currentContext == potentialAncestorContext) {
        return true;
      }
      // Move up the widget tree
      currentContext = currentContext
          .findAncestorStateOfType<WidgetVisibilityCheckerState>()
          ?.context;
    }
    // potentialAncestorContext is not found in the ancestor chain
    return false;
  }

  List<ScrollableState> findAncestorScrollableList(BuildContext? subjectContext,
      BuildContext rootContext) {
    List<ScrollableState> scrollableList = [];

    void process(BuildContext? currentContext) {
      if (currentContext == null) return;

      final scrollableState =
      currentContext.findAncestorStateOfType<ScrollableState>();

      if (scrollableState == null) return;

      if (!isAncestorOf(
          rootContext /* rootContext is not ancestor of scrollableState context.
      it means that scrollableState level is way higher than it's limit (rootContext level)*/
          ,
          scrollableState.context)) return;

      scrollableList.add(scrollableState);

      process(scrollableState.context);
    }

    process(subjectContext);

    return scrollableList;
  }

  Future<void> _triggerDelayedNotification(_) async {
    if (duringComputationPhase) {
      return;
    }
    duringComputationPhase = true;

    Future breakIntoNextEventLoop() async {
      return Future.delayed(const Duration(milliseconds: 5));
    }

    Future<void> process() async {
      try {
        await breakIntoNextEventLoop();

        var rootRenderBox = () {
          if (!context.mounted) {
            return null;
          }
          return context.findRenderObject() as RenderBox?;
        }();

        /// Check precondition
        if (rootRenderBox == null || !rootRenderBox.attached) {
          return;
        }
        final Map<VisibilityKey, List<Map<String, dynamic>>>
        scrollableListPerSubjectId = {};


        for (var subjectContext in contextList) {
          await breakIntoNextEventLoop();

          RenderBox? subjectRenderBox = () {
            if (!subjectContext.mounted) {
              return null;
            }
            return subjectContext.findRenderObject() as RenderBox?;
          }();

          /// Check precondition
          if (!subjectContext.mounted) {
            continue;
          }
          if (subjectRenderBox == null ||
              !subjectRenderBox.attached) {
            continue;
          }

          scrollableListPerSubjectId[subjectContext.widget.key
          as VisibilityKey] = List.empty(growable: true);

          Rect intersectionRect = () {
            return subjectRenderBox.localToGlobal(Offset.zero,
                ancestor: rootRenderBox) &
            subjectRenderBox.size;
          }();

          for (var currentScrollableState
          in scrollablePerSubject[subjectContext]!) {
            var index = scrollablePerSubject[subjectContext]!
                .indexOf(currentScrollableState);

            var previousScrollableState = index > 0
                ? scrollablePerSubject[subjectContext]![index - 1]
                : null;

            final RenderBox? currentViewPortRenderBox = () {
              if (!currentScrollableState.context.mounted) {
                return null;
              }
              return currentScrollableState.context.findRenderObject()
              as RenderBox?;
            }();

            /// Precondition
            if (!subjectContext.mounted) {
              continue;
            }
            if (currentViewPortRenderBox ==
                null ||
                !currentViewPortRenderBox.attached
            ) {
              continue;
            }

            final currentViewPortRect = () {
              return currentViewPortRenderBox.localToGlobal(
                  Offset.zero,
                  ancestor: rootRenderBox) &
              currentViewPortRenderBox.size;
            }();

            var visibleAreaLengthInPreviousStage = () {
              return (previousScrollableState ??
                  currentScrollableState)
                  .position
                  .axis ==
                  Axis.vertical
                  ? intersectionRect.height
                  : intersectionRect.width;
            }();

            var viewPortMainLengthInThisStage = () {
              return currentScrollableState.position.axis ==
                  Axis.vertical
                  ? currentViewPortRect.height
                  : currentViewPortRect.width;
            }();

            var viewPortCrossLengthInThisStage = () {
              return currentScrollableState.position.axis ==
                  Axis.horizontal
                  ? currentViewPortRect.height
                  : currentViewPortRect.width;
            }();

            bool isLtr = () {
              return (Directionality.maybeOf(
                  currentScrollableState.context) ??
                  TextDirection.ltr) ==
                  TextDirection.ltr;
            }();

            scrollableListPerSubjectId[
            subjectContext.widget.key as VisibilityKey]!
                .add({
              "index": index,
              'visibleAreaLengthInPreviousStage':
              visibleAreaLengthInPreviousStage,
              "viewPortMainLengthInThisStage": viewPortMainLengthInThisStage,
              "viewPortCrossLengthInThisStage":
              viewPortCrossLengthInThisStage,
              "viewPort.topCenter.dy": currentViewPortRect.topCenter
                  .dy,
              "viewPort.bottomCenter.dy": currentViewPortRect
                  .bottomCenter
                  .dy,
              "viewPort.centerLeft.dx": currentViewPortRect.centerLeft
                  .dx,
              "viewPort.centerRight.dx": currentViewPortRect
                  .centerRight
                  .dx,
              'intersection.topCenter.dy': intersectionRect.topCenter
                  .dy,
              'intersection.bottomCenter.dy':
              intersectionRect.bottomCenter.dy,
              'intersection.centerLeft.dx': intersectionRect
                  .centerLeft
                  .dx,
              'intersection.centerRight.dx': intersectionRect
                  .centerRight
                  .dx,
              "isLtr": isLtr,
              "position.axis":
              currentScrollableState.position.axis == Axis.vertical
                  ? "Axis.vertical"
                  : "Axis.horizontal",
              "size.height": currentViewPortRect.size.height,
              "size.width": currentViewPortRect.size.width,
            });

            /// post calculation
            intersectionRect =
                intersectionRect.intersect(currentViewPortRect);
          }
        }


        var newStates = computeMetricsAndVisibilityStates(
            scrollableListPerSubjectId,
            widget.mainAxisStartingEdgeDeflateRatio,
            widget.mainAxisEndingEdgeDeflateRatio,
            widget.crossAxisStartingEdgeDeflateRatio,
            widget.crossAxisEndingEdgeDeflateRatio);

        int currentMetricHash = newStates.keys
            .map((key) {
          if (newStates[key]?["head"] == null) return '_';
          var head = (newStates[key]?["head"]) as Map<String,
              dynamic>?;
          return json.encode(head);
        })
            .join('#')
            .hashCode;

        await breakIntoNextEventLoop();

        if (currentMetricHash != previousMetricHash) {
          previousMetricHash = currentMetricHash;

          widget.handler.applyAndNotify(
              newStates, currentScrollDirection);
          if (widget.drawDebugOverlay) {
            if (mounted) {
              setState(() {}); // repaint debug overlay
            }
          }
        }
      } catch (e, s) {
        debugPrint("an error occurred during computation phase!");
        debugPrint('Exception details:\n $e');
        debugPrint('Stack trace:\n $s');
      }
    }

    throttle.throttle(
      Duration(milliseconds: widget.defaultThrottleTime),
          () async {
        await process();
        duringComputationPhase = false;
      },
      type: BehaviorType.leadingAndTrailing,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context /*root context*/) {
    var shouldDisplayClippedArea = widget.drawDebugOverlay &&
        ((widget.mainAxisStartingEdgeDeflateRatio +
            widget.mainAxisEndingEdgeDeflateRatio) >
            0.0 ||
            (widget.crossAxisStartingEdgeDeflateRatio +
                widget.crossAxisEndingEdgeDeflateRatio) >
                0.0);

    contextList.removeWhere((it) => !it.mounted);
    var validStateCollection = widget.handler.currentVisibilityStates.values
        .where((it) => it != null)
        .toList();
    if (inspectionKey != null) {
      validStateCollection = validStateCollection
          .where((it) =>
      it == widget.handler.visibilityStateByKey(inspectionKey!.id))
          .toList();
    } else {
      validStateCollection = [];
    }
    var shouldDisplayMetricBars = widget.drawDebugOverlay &&
        validStateCollection.isNotEmpty &&
        validStateCollection.first!["head"] != null &&
        validStateCollection.first!["head"]['topMostLayer'] &&
        !validStateCollection.first!["head"]['offScreen'];
    double subjectMainAxisEndViewPortEnd = 0.0;
    double subjectMainAxisEndViewPortStart = 0.0;
    double subjectMainAxisStartViewPortEnd = 0.0;
    double subjectMainAxisStartViewPortStart = 0.0;

    double subjectCrossAxisEndViewPortEnd = 0.0;
    double subjectCrossAxisEndViewPortStart = 0.0;
    double subjectCrossAxisStartViewPortEnd = 0.0;
    double subjectCrossAxisStartViewPortStart = 0.0;
    double viewPortMainLength = 0.0;
    double viewPortCrossLength = 0.0;

    if (shouldDisplayMetricBars) {
      var head = validStateCollection.first!["head"];

      // main
      viewPortMainLength = head['viewPortMainLength'];
      subjectMainAxisStartViewPortEnd = head['subjectMainAxisStartViewPortEnd'];
      subjectMainAxisStartViewPortStart =
      head['subjectMainAxisStartViewPortStart'];
      subjectMainAxisEndViewPortStart = head['subjectMainAxisEndViewPortStart'];
      subjectMainAxisEndViewPortEnd = head['subjectMainAxisEndViewPortEnd'];

      //cross
      viewPortCrossLength = head['viewPortCrossLength'];
      subjectCrossAxisStartViewPortEnd =
      head['subjectCrossAxisStartViewPortEnd'];
      subjectCrossAxisStartViewPortStart =
      head['subjectCrossAxisStartViewPortStart'];
      subjectCrossAxisEndViewPortStart =
      head['subjectCrossAxisEndViewPortStart'];
      subjectCrossAxisEndViewPortEnd = head['subjectCrossAxisEndViewPortEnd'];
    }

    return _SizeChangeDetector(
      onSizeChanged: (Size size) {
        //root container size changed
        _triggerDelayedNotification(size);
      },
      child: Stack(fit: StackFit.expand, children: [
        NotificationListener<SizeChangedLayoutNotification>(
          child: NotificationListener<ScrollNotification>(
            onNotification: (data) {
              if (widget.enableAdvancedScrollDetectionMethod) {
                _triggerDelayedNotification(data);
              }
              return true;
            },
            child: NotificationListener<UserScrollNotification>(
              child: widget.child,
              onNotification: (data) { // UserScroll
                // scroll change notification
                currentScrollDirection = () {
                  if (data.direction != ScrollDirection.idle) {
                    return data.direction;
                  } else {
                    return currentScrollDirection;
                  }
                }();

                if (data.direction == ScrollDirection.idle) {
                  _triggerDelayedNotification(data);
                }

                return true;
              },
            ),
          ),
          onNotification: (data) { // Size
            //any descendant size changed
            _triggerDelayedNotification(data);
            return true;
          },
        ),
        if (shouldDisplayMetricBars &&
            widget.childScrollDirection == Axis.vertical)
          ...createBars(
            ignorePointer: widget.ignorePointer,
            //vertical is main axis here
            context: context,
            rotate: false,
            subjectVerticalAxisEndViewPortEnd: subjectMainAxisEndViewPortEnd,
            subjectVerticalAxisEndViewPortStart:
            subjectMainAxisEndViewPortStart,
            subjectVerticalAxisStartViewPortEnd:
            subjectMainAxisStartViewPortEnd,
            subjectVerticalAxisStartViewPortStart:
            subjectMainAxisStartViewPortStart,
            verticalStartPadding:
            widget.mainAxisStartingEdgeDeflateRatio * viewPortMainLength,
            verticalEndPadding:
            widget.mainAxisEndingEdgeDeflateRatio * viewPortMainLength,
            subjectHorizontalAxisEndViewPortEnd: subjectCrossAxisEndViewPortEnd,
            subjectHorizontalAxisEndViewPortStart:
            subjectCrossAxisEndViewPortStart,
            subjectHorizontalAxisStartViewPortEnd:
            subjectCrossAxisStartViewPortEnd,
            subjectHorizontalAxisStartViewPortStart:
            subjectCrossAxisStartViewPortStart,
            horizontalStartPadding:
            widget.crossAxisStartingEdgeDeflateRatio * viewPortCrossLength,
            horizontalEndPadding:
            widget.crossAxisEndingEdgeDeflateRatio * viewPortCrossLength,
          ),
        if (shouldDisplayMetricBars &&
            widget.childScrollDirection == Axis.horizontal)
          ...createBars(
            ignorePointer: widget.ignorePointer,
            //horizontal is main axis here
            context: context,
            rotate: true,
            subjectHorizontalAxisEndViewPortEnd: subjectMainAxisEndViewPortEnd,
            subjectHorizontalAxisEndViewPortStart:
            subjectMainAxisEndViewPortStart,
            subjectHorizontalAxisStartViewPortEnd:
            subjectMainAxisStartViewPortEnd,
            subjectHorizontalAxisStartViewPortStart:
            subjectMainAxisStartViewPortStart,
            horizontalStartPadding:
            widget.mainAxisStartingEdgeDeflateRatio * viewPortMainLength,
            horizontalEndPadding:
            widget.mainAxisEndingEdgeDeflateRatio * viewPortMainLength,
            subjectVerticalAxisEndViewPortEnd: subjectCrossAxisEndViewPortEnd,
            subjectVerticalAxisEndViewPortStart:
            subjectCrossAxisEndViewPortStart,
            subjectVerticalAxisStartViewPortEnd:
            subjectCrossAxisStartViewPortEnd,
            subjectVerticalAxisStartViewPortStart:
            subjectCrossAxisStartViewPortStart,
            verticalStartPadding:
            widget.crossAxisStartingEdgeDeflateRatio * viewPortCrossLength,
            verticalEndPadding:
            widget.crossAxisEndingEdgeDeflateRatio * viewPortCrossLength,
          ),
        Visibility(
          visible: shouldDisplayClippedArea,
          child: IgnorePointer(
              ignoring: true,
              child: DebugOverlay(
                startingRatio: widget.mainAxisStartingEdgeDeflateRatio,
                endingRatio: widget.mainAxisEndingEdgeDeflateRatio,
                axis: widget.childScrollDirection,
                offScreenColor:
                widget.offScreenColor ?? Colors.black.withOpacity(0.5),
              )),
        ),
        Visibility(
          visible: shouldDisplayClippedArea,
          child: IgnorePointer(
              ignoring: true,
              child: DebugOverlay(
                startingRatio: widget.crossAxisStartingEdgeDeflateRatio,
                endingRatio: widget.crossAxisEndingEdgeDeflateRatio,
                axis: widget.childScrollDirection == Axis.vertical
                    ? Axis.horizontal
                    : Axis.vertical,
                offScreenColor:
                widget.offScreenColor ?? Colors.black.withOpacity(0.5),
              )),
        ),
      ]),
    );
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    _triggerDelayedNotification({});
  }
}

/// Computes new metrics and visibility states for each subject
Map<VisibilityKey, Map<String, dynamic>?> computeMetricsAndVisibilityStates(
    Map<VisibilityKey, List<Map<String, dynamic>>> scrollableListPerSubjectId,
    double mainAxisStartingEdgeDeflateRatio,
    double mainAxisEndingEdgeDeflateRatio,
    double crossAxisStartingEdgeDeflateRatio,
    double crossAxisEndingEdgeDeflateRatio,) {
  Map<VisibilityKey, Map<String, dynamic>?> newStates = {};

  void processSubject(VisibilityKey subjectKey) {
    List<Map<String, dynamic>> ancestorScrollableLayerStates =
    scrollableListPerSubjectId[subjectKey]!;

    Map<String, dynamic>? primaryMapper(
        Map<String, dynamic> currentScrollableState) {
      var index = currentScrollableState['index'];

      double visibleAreaLengthInPreviousStage =
      currentScrollableState["visibleAreaLengthInPreviousStage"];

      var noVisibleAreaDetectedInPreviousStage =
          visibleAreaLengthInPreviousStage <= 0;

      if (noVisibleAreaDetectedInPreviousStage) {
        return null;
      }

      var isTopMostScrollableLayer =
          index == ancestorScrollableLayerStates.length - 1;

      double viewPortMainLengthInThisStage =
      currentScrollableState["viewPortMainLengthInThisStage"];

      double viewPortCrossLengthInThisStage =
      currentScrollableState["viewPortCrossLengthInThisStage"];

      double mainAxisStartingEdgeDeflateOffset = isTopMostScrollableLayer
          ? mainAxisStartingEdgeDeflateRatio * viewPortMainLengthInThisStage
          : 0.0;
      double mainAxisEndingEdgeDeflateOffset = isTopMostScrollableLayer
          ? mainAxisEndingEdgeDeflateRatio * viewPortMainLengthInThisStage
          : 0.0;

      double crossAxisStartingEdgeDeflateOffset = isTopMostScrollableLayer
          ? crossAxisStartingEdgeDeflateRatio * viewPortCrossLengthInThisStage
          : 0.0;
      double crossAxisEndingEdgeDeflateOffset = isTopMostScrollableLayer
          ? crossAxisEndingEdgeDeflateRatio * viewPortCrossLengthInThisStage
          : 0.0;

      /// calculations...
      double subjectTopViewPortBottom =
          currentScrollableState["viewPort.bottomCenter.dy"] -
              currentScrollableState["intersection.topCenter.dy"];

      double subjectTopViewPortTop =
          currentScrollableState["intersection.topCenter.dy"] -
              currentScrollableState["viewPort.topCenter.dy"];

      double subjectBottomViewPortTop =
          currentScrollableState["intersection.bottomCenter.dy"] -
              currentScrollableState["viewPort.topCenter.dy"];

      double subjectBottomViewPortBottom =
          currentScrollableState["viewPort.bottomCenter.dy"] -
              currentScrollableState["intersection.bottomCenter.dy"];

      double subjectLeftViewPortRight =
          currentScrollableState["viewPort.centerRight.dx"] -
              currentScrollableState["intersection.centerLeft.dx"];

      double subjectLeftViewPortLeft =
          currentScrollableState["intersection.centerLeft.dx"] -
              currentScrollableState["viewPort.centerLeft.dx"];

      double subjectRightViewPortLeft =
          currentScrollableState["intersection.centerRight.dx"] -
              currentScrollableState["viewPort.centerLeft.dx"];

      double subjectRightViewPortRight =
          currentScrollableState["viewPort.centerRight.dx"] -
              currentScrollableState["intersection.centerRight.dx"];

      bool isLtr = currentScrollableState["isLtr"];

      if (currentScrollableState["position.axis"] == "Axis.vertical") {
        return {
          'flow': 'vertical-flow',
          'viewPortDeflated': (mainAxisStartingEdgeDeflateOffset +
              mainAxisEndingEdgeDeflateOffset) >
              0.0 ||
              (crossAxisStartingEdgeDeflateOffset +
                  crossAxisEndingEdgeDeflateOffset) >
                  0.0,
          'index': index,

          /// main axis
          'subjectMainAxisStartViewPortEnd':
          subjectTopViewPortBottom - mainAxisEndingEdgeDeflateOffset,
          'subjectMainAxisStartViewPortStart':
          subjectTopViewPortTop - mainAxisStartingEdgeDeflateOffset,
          'subjectMainAxisEndViewPortStart':
          subjectBottomViewPortTop - mainAxisStartingEdgeDeflateOffset,
          'subjectMainAxisEndViewPortEnd':
          subjectBottomViewPortBottom - mainAxisEndingEdgeDeflateOffset,
          'viewPortMainLength': currentScrollableState["size.height"],
          'viewPortMainLengthDeflated': currentScrollableState["size.height"] -
              mainAxisEndingEdgeDeflateOffset -
              mainAxisStartingEdgeDeflateOffset,

          /// cross axis
          'subjectCrossAxisStartViewPortEnd':
          (isLtr ? subjectLeftViewPortRight : subjectRightViewPortLeft) -
              crossAxisEndingEdgeDeflateOffset,
          'subjectCrossAxisStartViewPortStart':
          (isLtr ? subjectLeftViewPortLeft : subjectRightViewPortRight) -
              crossAxisStartingEdgeDeflateOffset,
          'subjectCrossAxisEndViewPortStart':
          (isLtr ? subjectRightViewPortLeft : subjectLeftViewPortRight) -
              crossAxisStartingEdgeDeflateOffset,
          'subjectCrossAxisEndViewPortEnd':
          (isLtr ? subjectRightViewPortRight : subjectLeftViewPortLeft) -
              crossAxisEndingEdgeDeflateOffset,
          'viewPortCrossLength': currentScrollableState["size.width"],
          'viewPortCrossLengthDeflated': currentScrollableState["size.width"] -
              crossAxisEndingEdgeDeflateOffset -
              crossAxisStartingEdgeDeflateOffset,
        };
      } else {
        return {
          'flow': 'horizontal-flow',
          'viewPortDeflated': (mainAxisStartingEdgeDeflateOffset +
              mainAxisEndingEdgeDeflateOffset) >
              0.0 ||
              (crossAxisStartingEdgeDeflateOffset +
                  crossAxisEndingEdgeDeflateOffset) >
                  0.0,
          'index': index,

          /// main axis
          'subjectMainAxisStartViewPortEnd':
          (isLtr ? subjectLeftViewPortRight : subjectRightViewPortLeft) -
              mainAxisEndingEdgeDeflateOffset,
          'subjectMainAxisStartViewPortStart':
          (isLtr ? subjectLeftViewPortLeft : subjectRightViewPortRight) -
              mainAxisStartingEdgeDeflateOffset,
          'subjectMainAxisEndViewPortStart':
          (isLtr ? subjectRightViewPortLeft : subjectLeftViewPortRight) -
              mainAxisStartingEdgeDeflateOffset,
          'subjectMainAxisEndViewPortEnd':
          (isLtr ? subjectRightViewPortRight : subjectLeftViewPortLeft) -
              mainAxisEndingEdgeDeflateOffset,
          'viewPortMainLength': currentScrollableState["size.width"],
          'viewPortMainLengthDeflated': currentScrollableState["size.width"] -
              mainAxisEndingEdgeDeflateOffset -
              mainAxisStartingEdgeDeflateOffset,

          /// cross axis
          'subjectCrossAxisStartViewPortEnd':
          subjectTopViewPortBottom - crossAxisEndingEdgeDeflateOffset,
          'subjectCrossAxisStartViewPortStart':
          subjectTopViewPortTop - crossAxisStartingEdgeDeflateOffset,
          'subjectCrossAxisEndViewPortStart':
          subjectBottomViewPortTop - crossAxisStartingEdgeDeflateOffset,
          'subjectCrossAxisEndViewPortEnd':
          subjectBottomViewPortBottom - crossAxisEndingEdgeDeflateOffset,
          'viewPortCrossLength': currentScrollableState["size.height"],
          'viewPortCrossLengthDeflated': currentScrollableState["size.height"] -
              crossAxisEndingEdgeDeflateOffset -
              crossAxisStartingEdgeDeflateOffset,
        };
      }
    }

    Map<String, dynamic> secondaryMapper(Map<String, dynamic>? it) {
      /// extra computation ..
      int index = it!['index']!;

      ///main
      String mainPosition = '';
      double subjectMainAxisStartViewPortEnd =
      it['subjectMainAxisStartViewPortEnd']!;
      double subjectMainAxisStartViewPortStart =
      it['subjectMainAxisStartViewPortStart']!;
      double subjectMainAxisEndViewPortStart =
      it['subjectMainAxisEndViewPortStart']!;
      double subjectMainAxisEndViewPortEnd =
      it['subjectMainAxisEndViewPortEnd']!;
      double viewPortMainLength = it['viewPortMainLength']!;

      if (subjectMainAxisStartViewPortStart >= 0 &&
          subjectMainAxisEndViewPortEnd >= 0) {
        mainPosition = 'within-vp';
      } else if (subjectMainAxisStartViewPortStart < 0 &&
          subjectMainAxisEndViewPortEnd < 0) {
        mainPosition = 'across-vp';
      } else if (subjectMainAxisStartViewPortStart >= 0 &&
          subjectMainAxisEndViewPortEnd < 0) {
        mainPosition = subjectMainAxisStartViewPortEnd > 0
            ? 'touched-vp-end'
            : 'outside-vp-end';
      } else if (subjectMainAxisStartViewPortStart < 0 &&
          subjectMainAxisEndViewPortEnd >= 0) {
        mainPosition = subjectMainAxisEndViewPortStart > 0
            ? 'touched-vp-start'
            : 'outside-vp-start';
      } else {
        throw Exception("Invalid mainPosition State.");
      }

      ///cross
      String crossPosition = '';
      double subjectCrossAxisStartViewPortEnd =
      it['subjectCrossAxisStartViewPortEnd']!;
      double subjectCrossAxisStartViewPortStart =
      it['subjectCrossAxisStartViewPortStart']!;
      double subjectCrossAxisEndViewPortStart =
      it['subjectCrossAxisEndViewPortStart']!;
      double subjectCrossAxisEndViewPortEnd =
      it['subjectCrossAxisEndViewPortEnd']!;
      double viewPortCrossLength = it['viewPortCrossLength']!;
      if (subjectCrossAxisStartViewPortStart >= 0 &&
          subjectCrossAxisEndViewPortEnd >= 0) {
        crossPosition = 'within-vp';
      } else if (subjectCrossAxisStartViewPortStart < 0 &&
          subjectCrossAxisEndViewPortEnd < 0) {
        crossPosition = 'across-vp';
      } else if (subjectCrossAxisStartViewPortStart >= 0 &&
          subjectCrossAxisEndViewPortEnd < 0) {
        crossPosition = subjectCrossAxisStartViewPortEnd > 0
            ? 'touched-vp-end'
            : 'outside-vp-end';
      } else if (subjectCrossAxisStartViewPortStart < 0 &&
          subjectCrossAxisEndViewPortEnd >= 0) {
        crossPosition = subjectCrossAxisEndViewPortStart > 0
            ? 'touched-vp-start'
            : 'outside-vp-start';
      } else {
        throw Exception("Invalid crossPosition State.");
      }

      bool viewPortDeflated = it['viewPortDeflated']! as bool;
      String flow = it['flow'];

      return {
        'index': index,
        'flow': flow,
        'offScreen': mainPosition.contains('outside') ||
            crossPosition.contains('outside'),
        'topMostLayer': index == ancestorScrollableLayerStates.length - 1,
        'viewPortDeflated': viewPortDeflated,

        /// main
        'mainPosition': mainPosition,
        'subjectMainAxisStartViewPortEnd': subjectMainAxisStartViewPortEnd,
        'subjectMainAxisStartViewPortStart': subjectMainAxisStartViewPortStart,
        'subjectMainAxisEndViewPortStart': subjectMainAxisEndViewPortStart,
        'subjectMainAxisEndViewPortEnd': subjectMainAxisEndViewPortEnd,
        'viewPortMainLength': viewPortMainLength,

        ///cross
        'crossPosition': crossPosition,
        'subjectCrossAxisStartViewPortEnd': subjectCrossAxisStartViewPortEnd,
        'subjectCrossAxisStartViewPortStart':
        subjectCrossAxisStartViewPortStart,
        'subjectCrossAxisEndViewPortStart': subjectCrossAxisEndViewPortStart,
        'subjectCrossAxisEndViewPortEnd': subjectCrossAxisEndViewPortEnd,
        'viewPortCrossLength': viewPortCrossLength,
      };
    }

    List<Map<String, dynamic>> visibilityStateLayers =
    ancestorScrollableLayerStates
        .map(primaryMapper)
        .where((it) => it != null)
        .map(secondaryMapper)
        .toList();

    if (visibilityStateLayers.isEmpty) return;

    newStates[subjectKey] = {
      'depth': ancestorScrollableLayerStates.length,
      'head': visibilityStateLayers.isNotEmpty &&
          visibilityStateLayers.length ==
              ancestorScrollableLayerStates.length
          ? visibilityStateLayers.last
          : null,
      'layers': visibilityStateLayers,
      'summary': visibilityStateLayers
          .map((it) =>
      '${it['mainPosition'] as String}/${it['crossPosition'] as String}:${it['flow'] as String}')
          .join("|")
    };
  }

  scrollableListPerSubjectId.keys.forEach(processSubject);

  return newStates;
}

class DebugOverlay extends StatelessWidget {
  final double startingRatio;
  final double endingRatio;
  final Axis axis;
  final Color offScreenColor;

  const DebugOverlay({
    super.key,
    required this.startingRatio,
    required this.endingRatio,
    required this.axis,
    required this.offScreenColor,
  });

  @override
  Widget build(BuildContext context) {
    if (startingRatio + endingRatio == 0.0) return const SizedBox.shrink();
    return (axis == Axis.vertical)
        ? Column(
      children: <Widget>[
        Expanded(
          flex: (startingRatio * 100).toInt(),
          child: Container(
            color: offScreenColor,
          ),
        ),
        Flexible(
          flex: ((1 - startingRatio - endingRatio) * 100).toInt(),
          child: Container(),
        ),
        Expanded(
          flex: (endingRatio * 100).toInt(),
          child: Container(
            color: offScreenColor,
          ),
        ),
      ],
    )
        : Row(
      children: <Widget>[
        Expanded(
          flex: (startingRatio * 100).toInt(),
          child: Container(
            color: offScreenColor,
          ),
        ),
        Flexible(
          flex: ((1 - startingRatio - endingRatio) * 100).toInt(),
          child: Container(),
        ),
        Expanded(
          flex: (endingRatio * 100).toInt(),
          child: Container(
            color: offScreenColor,
          ),
        ),
      ],
    );
  }
}

class VisibilityKey<T extends State<StatefulWidget>> extends GlobalKey<T> {
  const VisibilityKey(this.id) : super.constructor();
  final int id;
}

abstract mixin class VisibilityChangeHandler {
  ScrollDirection currentScrollDirection = ScrollDirection
      .reverse; //content goes up//scroll goes down//vertical-position increases
  Map<VisibilityKey, Map<String, dynamic>?> currentVisibilityStates = {};
  int previousVisibilityHash = 0;

  VisibilityKey addNewVisibilityKeyToCollection(int id) {
    if (currentVisibilityStates.keys.any((it) => it.id == id)) {
      throw Exception('Duplicate VisibilityKey where found in the collection');
    }
    var key = VisibilityKey(id);
    currentVisibilityStates[key] = null;
    return key;
  }

  VisibilityKey getKeyById(int id) {
    var filtered = currentVisibilityStates.keys.where((it) => it.id == id);
    if (filtered.isEmpty) {
      throw Exception('VisibilityKey where not found in the collection');
    }
    return filtered.single;
  }

  Map<String, dynamic>? visibilityStateByKey(int id) {
    return currentVisibilityStates[getKeyById(id)];
  }

  String mainPositionByKey(int id) {
    return currentVisibilityStates[getKeyById(id)]?["head"]?["mainPosition"]
    as String? ??
        "";
  }

  String crossPositionByKey(int id) {
    return currentVisibilityStates[getKeyById(id)]?["head"]?["crossPosition"]
    as String? ??
        "";
  }

  String mainPositionByKeyAt(int id, int index) {
    if (currentVisibilityStates[getKeyById(id)]?["layers"] == null) return '';
    var layers = currentVisibilityStates[getKeyById(id)]?["layers"]
    as List<Map<String, dynamic>>;
    if (layers.length <= index) return '';
    var current = layers[index];
    return current["mainPosition"] as String? ?? "";
  }

  String crossPositionByKeyAt(int id, int index) {
    if (currentVisibilityStates[getKeyById(id)]?["layers"] == null) return '';
    var layers = currentVisibilityStates[getKeyById(id)]?["layers"]
    as List<Map<String, dynamic>>;
    if (layers.length <= index) return '';
    var current = layers[index];
    return current["crossPosition"] as String? ?? "";
  }

  String positionLabelByKey(int id) {
    return '''
[main] ${mainPositionByKey(id)}
[cross] ${crossPositionByKey(id)}''';
  }

  String positionLabelByKeyAt(int id, int index) {
    return '''
[main] ${mainPositionByKeyAt(id, index)}
[cross] ${crossPositionByKeyAt(id, index)}''';
  }

  void removeVisibilityKeyFromCollection(int id) {
    currentVisibilityStates.removeWhere((it, _) => it.id == id);
  }

  void visibilityStatesChanged();

  void scrollMetricsChanged();

  /// Update [currentScrollDirection]
  ///
  /// Apply new state
  ///
  /// Dispatch [scrollMetricsChanged] unconditionally
  ///
  /// Computes a new visibility hash for the current states and compares it to the previous hash.
  ///
  /// If the hash changes, dispatch [visibilityStatesChanged].
  ///
  /// @[newStates] --> newStates to be applied
  ///
  /// @[currentScrollDirection] --> forward|idle|reverse
  bool applyAndNotify(Map<VisibilityKey, Map<String, dynamic>?> newStates,
      ScrollDirection currentScrollDirection) {
    this.currentScrollDirection = currentScrollDirection;

    //Replace old states with new ones
    currentVisibilityStates.forEach((key, value) {
      if (currentVisibilityStates.keys.contains(key)) {
        currentVisibilityStates[key] =
        newStates.containsKey(key) ? newStates[key] : null;
      }
    });

    // dispatch metric change notification firstly
    scrollMetricsChanged();

    int currentVisibilityHash = newStates.keys
        .map((key) {
      return '${key.id}/${(newStates[key]?["summary"] ?? "")}';
    })
        .join('#')
        .hashCode;

    if (currentVisibilityHash == previousVisibilityHash) return false;
    previousVisibilityHash = currentVisibilityHash;

    // dispatch visibility state change notifications later on
    visibilityStatesChanged();

    return true;
  }

  void clearStateForKey(Key key, bool alsoRemoveKeyFromCollection) {
    var vKey = key as VisibilityKey;
    if (!currentVisibilityStates.containsKey(vKey)) return;

    currentVisibilityStates[vKey] = null;
    if (alsoRemoveKeyFromCollection) currentVisibilityStates.remove(vKey);
  }

  void clearStateForAllKeys(bool alsoRemoveKeyFromCollection) {
    for (var key in currentVisibilityStates.keys) {
      currentVisibilityStates[key] = null;
    }

    if (!alsoRemoveKeyFromCollection) return;

    currentVisibilityStates.clear();
  }
}

extension CheckWidgetVisibilityExtension on Widget {
  void watchVisibility(VisibilityChangeHandler handler) {
    if (key is! VisibilityKey) {
      throw Exception(
          'watchVisibility can not accept widget without keys or key types other than VisibilityKey');
    }

    VisibilityKey visibilityKey = key as VisibilityKey;

    WidgetsBinding.instance.addPostFrameCallback((elapsedTime) {
      if (!(visibilityKey.currentContext?.mounted ?? false)) {
        throw Exception(
            'watchVisibility can not accept null or deactivated contexts');
      }

      WidgetVisibilityChecker.watch(visibilityKey.currentContext!);
    });
  }
}

class _SizeChangeDetector extends StatefulWidget {
  final Widget child;
  final Function(Size) onSizeChanged;

  const _SizeChangeDetector({required this.child, required this.onSizeChanged});

  @override
  _SizeChangeDetectorState createState() => _SizeChangeDetectorState();
}

class _SizeChangeDetectorState extends State<_SizeChangeDetector> {
  late Size _oldSize;

  @override
  void initState() {
    super.initState();
    _oldSize = const Size(0, 0); // Initialize with an empty size
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newSize = constraints.biggest;
        if (newSize != _oldSize) {
          _oldSize = newSize;
          widget.onSizeChanged(newSize);
        }
        return widget.child;
      },
    );
  }
}

List<Widget> createBars({
  required BuildContext context,
  required bool ignorePointer,
  required bool rotate,
  required double subjectVerticalAxisEndViewPortStart,
  required double subjectVerticalAxisStartViewPortStart,
  required double subjectVerticalAxisStartViewPortEnd,
  required double subjectVerticalAxisEndViewPortEnd,
  required double subjectHorizontalAxisEndViewPortStart,
  required double subjectHorizontalAxisStartViewPortStart,
  required double subjectHorizontalAxisStartViewPortEnd,
  required double subjectHorizontalAxisEndViewPortEnd,
  required double verticalStartPadding,
  required double verticalEndPadding,
  required double horizontalStartPadding,
  required double horizontalEndPadding,
}) {
  const defaultCrossLength = 20.0;
  const defaultShiftOffset = 22.0;
  const animate = 300;
  verticalStartFull(String orientation) =>
      AnimatedPositionedDirectional(
        top: 0.0 + verticalStartPadding,
        start: subjectHorizontalAxisStartViewPortStart + horizontalStartPadding,
        width: defaultCrossLength,
        height: subjectVerticalAxisEndViewPortStart,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            alignment: Alignment.topCenter,
            color: Colors.black.withOpacity(0.5),
            child: buildInnerText(
                1,
                'subject${orientation}AxisEndViewPortStart',
                subjectVerticalAxisEndViewPortStart),
          ),
        ),
      );
  verticalStartHalf(String orientation) =>
      AnimatedPositionedDirectional(
        top: 0.0 + verticalStartPadding,
        start: subjectHorizontalAxisStartViewPortStart +
            defaultShiftOffset +
            horizontalStartPadding,
        width: defaultCrossLength,
        height: subjectVerticalAxisStartViewPortStart,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            alignment: Alignment.topCenter,
            child: buildInnerText(
                1,
                'subject${orientation}AxisStartViewPortStart',
                subjectVerticalAxisStartViewPortStart),
          ),
        ),
      );
  verticalEndFull(String orientation) =>
      AnimatedPositionedDirectional(
        bottom: 0.0 + verticalEndPadding,
        end: subjectHorizontalAxisEndViewPortEnd + horizontalEndPadding,
        width: defaultCrossLength,
        height: subjectVerticalAxisStartViewPortEnd,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            alignment: Alignment.bottomCenter,
            child: buildInnerText(
                1,
                'subject${orientation}AxisStartViewPortEnd',
                subjectVerticalAxisStartViewPortEnd),
          ),
        ),
      );
  verticalEndHalf(String orientation) =>
      AnimatedPositionedDirectional(
        bottom: 0.0 + verticalEndPadding,
        end: subjectHorizontalAxisEndViewPortEnd +
            defaultShiftOffset +
            horizontalEndPadding,
        width: defaultCrossLength,
        height: subjectVerticalAxisEndViewPortEnd,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            alignment: Alignment.bottomCenter,
            child: buildInnerText(1, 'subject${orientation}AxisEndViewPortEnd',
                subjectVerticalAxisEndViewPortEnd),
          ),
        ),
      );

  horizontalStartFull(String orientation) =>
      AnimatedPositionedDirectional(
        start: 0.0 + horizontalStartPadding,
        top: subjectVerticalAxisStartViewPortStart + verticalStartPadding,
        height: defaultCrossLength,
        width: subjectHorizontalAxisEndViewPortStart,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            color: Colors.indigo.withOpacity(0.7),
            alignment: AlignmentDirectional.centerStart,
            child: buildInnerText(
                0,
                'subject${orientation}AxisEndViewPortStart',
                subjectHorizontalAxisEndViewPortStart),
          ),
        ),
      );
  horizontalStartHalf(String orientation) =>
      AnimatedPositionedDirectional(
        start: 0.0 + horizontalStartPadding,
        top: subjectVerticalAxisStartViewPortStart +
            defaultShiftOffset +
            verticalStartPadding,
        height: defaultCrossLength,
        width: subjectHorizontalAxisStartViewPortStart,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            color: Colors.indigo.withOpacity(0.7),
            alignment: AlignmentDirectional.centerStart,
            child: buildInnerText(
                0,
                'subject${orientation}AxisStartViewPortStart',
                subjectHorizontalAxisStartViewPortStart),
          ),
        ),
      );
  horizontalEndFull(String orientation) =>
      AnimatedPositionedDirectional(
        end: 0.0 + horizontalEndPadding,
        bottom: subjectVerticalAxisEndViewPortEnd + verticalEndPadding,
        height: defaultCrossLength,
        width: subjectHorizontalAxisStartViewPortEnd,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            color: Colors.indigo.withOpacity(0.7),
            alignment: AlignmentDirectional.centerEnd,
            child: buildInnerText(
                0,
                'subject${orientation}AxisStartViewPortEnd',
                subjectHorizontalAxisStartViewPortEnd),
          ),
        ),
      );
  horizontalEndHalf(String orientation) =>
      AnimatedPositionedDirectional(
        end: 0.0 + horizontalEndPadding,
        bottom: subjectVerticalAxisEndViewPortEnd +
            defaultShiftOffset +
            verticalEndPadding,
        height: defaultCrossLength,
        width: subjectHorizontalAxisEndViewPortEnd,
        duration: const Duration(milliseconds: animate),
        child: IgnorePointer(
          ignoring: ignorePointer,
          child: Container(
            color: Colors.indigo.withOpacity(0.7),
            alignment: AlignmentDirectional.centerEnd,
            child: buildInnerText(0, 'subject${orientation}AxisEndViewPortEnd',
                subjectHorizontalAxisEndViewPortEnd),
          ),
        ),
      );

  return [
    verticalStartFull(!rotate ? "Main" : "Cross"),
    verticalStartHalf(!rotate ? "Main" : "Cross"),
    verticalEndFull(!rotate ? "Main" : "Cross"),
    verticalEndHalf(!rotate ? "Main" : "Cross"),
    horizontalStartFull(rotate ? "Main" : "Cross"),
    horizontalStartHalf(rotate ? "Main" : "Cross"),
    horizontalEndFull(rotate ? "Main" : "Cross"),
    horizontalEndHalf(rotate ? "Main" : "Cross"),
  ];
}

Widget buildInnerText(int rotate, String tooltipMessage, double metric) {
  return Container(
    color: rotate == 1
        ? Colors.black.withOpacity(0.5)
        : Colors.indigo.withOpacity(1),
    padding: const EdgeInsetsDirectional.all(3.0),
    child: RotatedBox(
      quarterTurns: rotate,
      child: Text(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.0,
          ),
          metric > 20.0 ? metric.toStringAsFixed(0) : ''),
    ),
  );
}
