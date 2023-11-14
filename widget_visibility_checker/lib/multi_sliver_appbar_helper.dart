library widget_visibility_checker;

import 'package:flutter/material.dart';
import 'package:widget_visibility_checker/widget_visibility_checker.dart';

abstract mixin class MultiSliverAppBarHelper {
  // finals
  late final int animationRefusePeriod; //ms
  late final int animatedScrollBackwardDuration; //ms
  late final int animatedScrollForwardDuration; //ms
  late final double appBarExpandedHeight;
  late final double listViewItemHeight;
  late final double appBarCollapsedHeight;
  late final double defaultExitOffset;

  /*Enter-ViewPort*/
  late final double autoMoveBackwardByExtent;

  /*Scroll-Out*/
  late final double autoMoveForwardByExtent;

  late final dynamic self = this;

  //  mutable fields...

  int minVisibleZoneIndex = 0;
  int previousZoneIndex = -1;
  late List<bool> pinnedStates =
  List<bool>.generate(numberOfZones, (it) => true);
  int lastFwdAnimTimestamp = 0;
  int lastBwdAnimTimestamp = 0;
  bool animatingPhase = false;

  //  controllers...
  late final fadeAnimationControllers =
  List<MapEntry<AnimationController, Animation<double>>>.generate(
      numberOfZones, (index) {
    AnimationController ctrl = AnimationController(
      vsync: self,
    );
    return MapEntry(ctrl, Tween<double>(begin: 0.0, end: 1.0).animate(ctrl));
  });
  final ScrollController customScrollViewCtrl = ScrollController();

  // must be overridden
  int get numberOfZones;

  String getEnterLinePositionByIndex(int index);

  String getExitLinePositionByIndex(int index);

  bool get forwardMoveIsActive;

  void needRepaint(void Function() fn);

  // getters...

  bool enterLineIsBelowViewPortTopEdge(int index) =>
      getEnterLinePositionByIndex(index) != 'outside-vp-start';

  bool exitLineIsScrolledOutOfViewPortTopEdge(int index) =>
      getExitLinePositionByIndex(index) == 'outside-vp-start';

  int get currentMilliseconds =>
      DateTime
          .now()
          .millisecondsSinceEpoch;

  bool isForwardAnimationAllowedAtThisTime() =>
      currentMilliseconds - lastBwdAnimTimestamp >
          animatedScrollBackwardDuration + animationRefusePeriod;

  bool isBackwardAnimationAllowedAtThisTime() =>
      currentMilliseconds - lastFwdAnimTimestamp >
          animatedScrollForwardDuration + animationRefusePeriod;

//initializer
  void initMultiSliverAppBarHelper({
    int animationRefusePeriod = 500, //ms
    int animatedScrollBackwardDuration = 500 * 2, //ms
    int animatedScrollForwardDuration = 500 * 2, //ms
    double appBarExpandedHeight = 200.0,
    double listViewItemHeight = 48.0,
    double appBarCollapsedHeight = 56.0,
  }) {
    this.animationRefusePeriod = animationRefusePeriod;
    this.animatedScrollBackwardDuration = animatedScrollBackwardDuration;
    this.animatedScrollForwardDuration = animatedScrollForwardDuration;
    this.appBarExpandedHeight = appBarExpandedHeight;
    this.listViewItemHeight = listViewItemHeight;
    this.appBarCollapsedHeight = appBarCollapsedHeight;
    for (var it in fadeAnimationControllers) {
      it.key.value = 1;
    }
    /*Enter-ViewPort*/
    autoMoveBackwardByExtent = appBarExpandedHeight + (listViewItemHeight * 3);
    /*Scroll-Out*/
    autoMoveForwardByExtent = appBarCollapsedHeight + listViewItemHeight * 3;

    defaultExitOffset = -1 * (appBarCollapsedHeight + listViewItemHeight);
  }

  // methods with side-effect ...
  bool updateMinVisibleZoneIndex() {
    var futureZoneIndex = minVisibleZoneIndex;

    //content is moving up in vertical direction, scrollbar goes down
    if (forwardMoveIsActive) {
      for (int i = 0; i < numberOfZones; i++) {
        if (!exitLineIsScrolledOutOfViewPortTopEdge(i)) {
          // prove that current state is still valid
          // if not exited then it's minimum index visible zone
          futureZoneIndex = i;
          break;
        }
      }
    } else {
      // backwardMoveIsActive
      //content is moving down in vertical direction, scrollbar goes up
      for (int i = numberOfZones - 1; i >= -1; i--) {
        if (i == -1 || !enterLineIsBelowViewPortTopEdge(i)) {
          // prove that current state is not valid anymore
          futureZoneIndex = i + 1;
          break;
        }
      }
    }

    if (futureZoneIndex < 0) {
      futureZoneIndex = 0; // normalize out of range index
    }

    if (futureZoneIndex > numberOfZones - 1) {
      futureZoneIndex = numberOfZones - 1; // normalize out of range index
    }

    if (futureZoneIndex != minVisibleZoneIndex) {
      previousZoneIndex = minVisibleZoneIndex;
      minVisibleZoneIndex = futureZoneIndex;
      return true; //  needs update
    }

    return false; //doesn't need update
  }

  void applyTransitionState() async {
    if (animatingPhase) {
      return;
    }
    animatingPhase = true;
    bool dirty = false;

    void updatePinnedAndFloating() {
      for (int i = numberOfZones - 1; i >= minVisibleZoneIndex; i--) {
        pinnedStates[i] = true;
      }
      for (int i = minVisibleZoneIndex - 1; i >= 0; i--) {
        pinnedStates[i] = false;
      }
    }

    Future<void> breakIntoNextEventLoop(int milliseconds) async {
      return Future.delayed(Duration(milliseconds: milliseconds));
    }

    void updateFadeTransitionStates() {
      for (int i = numberOfZones - 1; i >= minVisibleZoneIndex; i--) {
        if (fadeAnimationControllers[i].value.value == 0.0) {
          fadeAnimationControllers[i].key.animateTo(1.0,
              duration: Duration(
                  milliseconds:
                  (animatedScrollBackwardDuration.toDouble() ~/ 1.5)),
              curve: Curves.easeIn);
        }
      }
      for (int i = minVisibleZoneIndex - 1; i >= 0; i--) {
        if (fadeAnimationControllers[i].value.value == 1.0) {
          fadeAnimationControllers[i].key.animateTo(0.0,
              duration: Duration(
                  milliseconds: animatedScrollForwardDuration.toDouble() ~/
                      1.5),
              curve: Curves.easeIn);
        }
      }
    }

    Future<void> animateEnter() async {
      updateFadeTransitionStates();
      //backward move (content moves down)
      customScrollViewCtrl.animateTo(
          customScrollViewCtrl.offset - autoMoveBackwardByExtent,
          duration: Duration(milliseconds: animatedScrollBackwardDuration),
          curve: Curves.easeInOut);
    }

    Future<void> animateOut() async {
      updateFadeTransitionStates();

      await breakIntoNextEventLoop(200);
      //forward move (content moves up)
      customScrollViewCtrl.animateTo(
          customScrollViewCtrl.offset + autoMoveForwardByExtent,
          duration: Duration(milliseconds: animatedScrollForwardDuration),
          curve: Curves.easeIn);
    }


    try {
      if /*Enter*/ (!forwardMoveIsActive) {
        //backward move (content moves down)
        if (!isBackwardAnimationAllowedAtThisTime()) {
          Future.delayed(
              const Duration(milliseconds: 1000), updateFadeTransitionStates);
          return;
        }
      } else
        /*Out*/ {
        //forward move (content moves up)
        if (!isForwardAnimationAllowedAtThisTime()) {
          Future.delayed(
              const Duration(milliseconds: 1000), updateFadeTransitionStates);
          return;
        }
      }

      if (!updateMinVisibleZoneIndex()) {
        return;
      }

      if /*Entering Viewport From Top Side*/ (!forwardMoveIsActive) {
        lastBwdAnimTimestamp = currentMilliseconds;
        updatePinnedAndFloating();
        dirty = true;
        animateEnter();

      } else
        /*Out-Scroll Viewport*/ {
        lastFwdAnimTimestamp = currentMilliseconds;
        animateOut();
        await breakIntoNextEventLoop(animatedScrollForwardDuration+500);
        updatePinnedAndFloating();
        dirty = true;
      }
    }
    catch (e, s) {
      debugPrint('An error occurred during applyTransitionState phase!');
      debugPrint('exception: $e');
      debugPrint('stacktrace: $s');
    }
    finally {
      animatingPhase = false;
      if (dirty) {
        dirty = false;
        needRepaint(() {});
      }
    }
  }

  //builders...
  SliverToBoxAdapter buildEnterAndExitLinesForZone({required Key exitIndexKey,
    required Key enterIndexKey,
    required double exitOffset,
    required double enterOffset}) =>
      SliverToBoxAdapter(
        child: SizedBox(
          height: 1.0,
          child: Stack(
            children: [
              Positioned(
                top: exitOffset,
                child: Container(
                  key: exitIndexKey,
                  height: 1,
                  color: Colors.red,
                )
                  ..watchVisibility(self),
              ),
              Positioned(
                top: enterOffset,
                child: Container(
                  key: enterIndexKey,
                  height: 1,
                  color: Colors.black,
                )
                  ..watchVisibility(self),
              ),
            ],
          ),
        ),
      );
}
