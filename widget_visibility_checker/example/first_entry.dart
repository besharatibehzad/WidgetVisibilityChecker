import 'dart:convert';

import 'package:flutter/material.dart';

/// Step 1: Import the necessary modules.
import 'package:widget_visibility_checker/widget_visibility_checker.dart';

/// Step 2: Set up the main structure and theme.
void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void Function()? resetCallback;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Widget Visibility Check'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: () => resetCallback?.call(),
            ),
          ],
        ),
        body: SafeArea(
          child: FirstShowCase(
            registerResetCallback: (void Function() callback) {
              resetCallback = callback;
            },
          ),
        ),
      ),
    );
  }
}

/// Step 3: Declare unique identifiers for widgets that require monitoring of visibility state
/// and metrics changes during scrolling within their parent widgets.
enum VisibilityIds {
  cardA,
  cardB,
  cardC,
}

/// Step 4: Essential boilerplate code for the showcase scenario.
class FirstShowCase extends StatefulWidget {
  const FirstShowCase({
    super.key,
    required this.registerResetCallback,
  });

  final Function(VoidCallback) registerResetCallback;

  @override
  State<FirstShowCase> createState() => _FirstShowCaseState();
}

/// Step 5: Implement the VisibilityChangeHandler mixin in the State class for the widget.
class _FirstShowCaseState extends State<FirstShowCase>
    with VisibilityChangeHandler {
  bool? enableInspectionMode = false;
  bool? enableRtlLayout = false;
  double deflateRatio = 0.0;
  final ScrollController _controller = ScrollController();
  static const bool enableLog = false;

  @override
  void initState() {
    super.initState();
    widget.registerResetCallback(() {
      setState(() {
        deflateRatio = 0;
      });
    });

    /// Step 6: Registering enum values in the collection to ensure the library is aware of them.
    for (var it in VisibilityIds.values) {
      addNewVisibilityKeyToCollection(it.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['First', 'Second', 'Third'];
    const double defaultPadding = 18.0;
    const double defaultElevation = 10.0;
    return Directionality(
      textDirection:
          (enableRtlLayout ?? false) ? TextDirection.rtl : TextDirection.ltr,

      /// Step 7: Enclose your scrollable container (e.g., SingleChildScrollView) with the WidgetVisibilityChecker widget.
      child: WidgetVisibilityChecker(
        childScrollDirection: Axis.vertical,
        drawDebugOverlay: (enableInspectionMode ?? false),
        mainAxisStartingEdgeDeflateRatio: deflateRatio,
        mainAxisEndingEdgeDeflateRatio: deflateRatio,
        crossAxisStartingEdgeDeflateRatio: deflateRatio,
        crossAxisEndingEdgeDeflateRatio: deflateRatio,
        // Enable it to detect scroll events initiated by the scrollbar thumb when dragged by the user.
        enableAdvancedScrollDetectionMethod: true,
        defaultThrottleTime: 40,
        handler: this,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            children: [
              buildSimpleCardWidget(defaultElevation),
              ...buildControlSectionWidgetCollection(
                  defaultElevation, defaultPadding),
              buildHorizontalLayout(defaultPadding, defaultElevation,
                  child: SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24, top: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildSimpleSquareShapeImageWidget(
                              defaultElevation, defaultPadding),
                          buildSimpleHorizontalGap(),
                          buildAdvancedTargetBox(defaultElevation,
                              defaultPadding, VisibilityIds.cardA),
                          buildSimpleHorizontalGap(),
                          buildRectangularImageWidget(
                              defaultElevation, defaultPadding),
                          buildSimpleHorizontalGap(),
                          buildAdvancedTargetBox(defaultElevation,
                              defaultPadding, VisibilityIds.cardB),
                          buildSimpleHorizontalGap(),
                          buildAnotherRectangularImageWidget(
                              defaultElevation, defaultPadding),
                          buildSimpleHorizontalGap(),

                          /// Step 8: Build a Widget that needs to be observed for visibility state changes.
                          buildSimpleTargetBox(defaultElevation, defaultPadding,
                              VisibilityIds.cardC),

                          buildSimpleHorizontalGap(),
                          buildYetAnotherRectangularImageWidget(
                              defaultElevation, defaultPadding),
                        ],
                      ),
                    ),
                  )),
              buildSimpleVerticalGap(defaultPadding),
              ...buildSimpleCardWidgetCollection(defaultElevation, titles),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 9: Implement `visibilityStatesChanged` to detect changes in target widgets visibility.
  @override
  void visibilityStatesChanged() {
    if (currentVisibilityStates.isEmpty) {
      return;
    }

    /// triggers build method on state change
    needRepaint();

    if (!enableLog) {
      debugPrint('Logging is disabled!');
      return;
    }

    /// log visibility state for each target widget
    (VisibilityIds visibilityId) {
      debugPrint('${visibilityId.name} visibility changed!');

      /// relative to external scroll-view
      debugPrint(
          "vertical-view main-axis: ${mainPositionByKeyAt(visibilityId.index, 1 /*scroll-view depth*/)}");
      debugPrint(
          "vertical-view cross-axis: ${crossPositionByKeyAt(visibilityId.index, 1 /*scroll-view depth*/)}");

      /// relative to internal scroll-view
      debugPrint(
          "horizontal-view main-axis: ${mainPositionByKeyAt(visibilityId.index, 0 /*scroll-view depth*/)}");
      debugPrint(
          "horizontal-view cross-axis: ${crossPositionByKeyAt(visibilityId.index, 0 /*scroll-view depth*/)}");
    }
      ..call(VisibilityIds.cardA)
      ..call(VisibilityIds.cardB)
      ..call(VisibilityIds.cardC);
  }

  /// Step 9: Implement `scrollMetricsChanged` to detect metric changes in target widgets.
  @override
  void scrollMetricsChanged() {
    if (currentVisibilityStates.isEmpty) {
      return;
    }

    if (!enableLog) {
      return;
    }

    /// Log detailed visibility states, including metrics, for each target widget.
    (VisibilityIds visibilityId) {
      debugPrint('${visibilityId.name} metrics changed!');
      debugPrint(json.encode(visibilityStateByKey(visibilityId.index)));
    }
      ..call(VisibilityIds.cardA)
      ..call(VisibilityIds.cardB)
      ..call(VisibilityIds.cardC);

    debugPrint("Log the fully detailed state for each tracked widget");
    for (var key in currentVisibilityStates.keys) {
      debugPrint('widget #${key.id} metrics changed!');
      debugPrint(json.encode(currentVisibilityStates[key]));
    }

    /// Step 10: Interpret the log output.
    ///
    /// Each tracked widget has the following visibility state properties, which you can see in the log output.
    ///
    /// ["depth"] : int
    ///     Number of ascendant scrollable containers enclosing the target widget.
    ///
    /// ["head"] : Map<String,dynamic>?
    ///     Visibility state of the target widget relative to the top-most scrollable container.
    ///     This property is null when the target widget goes off-screen.
    ///
    /// ["layers"] : List<Map<String,dynamic>>
    ///     Visibility state of the target widget relative to all scrollable containers, from innermost to outermost scope.
    ///     Each layer consists of the following sub-properties:
    ///
    ///           ["index"] : int (Index of scrollable container from innermost to outermost scope)
    ///           ["flow"] : String (direction of scrollable container : vertical-flow, horizontal-flow)
    ///
    ///           ["offScreen"] : bool (is the target widget scrolled out of view?)
    ///           ["topMostLayer"] : bool (is this scrollable container, the top most of others?)
    ///           ["viewPortDeflated"] : bool (is view-port clipped?)
    ///
    ///           ["mainPosition"] : String (position of the target widget relative to main-axis of the scrollable container)
    ///                 Possible Values are:
    ///                      "within-vp" --> within view-port (completely visible)
    ///                      "across-vp" --> across view-port from both side (partially visible)
    ///                      "touched-vp-end" --> touched view-port ending edge
    ///                      "outside-vp-end" --> scrolled-out from ending edge of the view-port
    ///                      "touched-vp-start" --> touched view-port starting edge
    ///                      "outside-vp-start" --> scrolled-out from starting edge of the view-port
    ///           ["subjectMainAxisStartViewPortStart"] : double (distance between main-axis starting edge of target widget and starting edge of viewport)
    ///           ["subjectMainAxisStartViewPortEnd"] : double (distance between main-axis starting edge of target widget and ending edge of viewport)
    ///           ["subjectMainAxisEndViewPortStart"] : double (distance between main-axis ending edge of target widget and starting edge of viewport)
    ///           ["subjectMainAxisEndViewPortEnd"] : double (distance between main-axis ending edge of target widget and ending edge of viewport)
    ///           ["viewPortMainLength"] : double
    ///
    ///           ["crossPosition"] : String (position of the target widget relative to cross-axis of the scrollable container)
    ///                 Possible Values are:
    ///                      "within-vp" --> within view-port (completely visible)
    ///                      "across-vp" --> across view-port from both side (partially visible)
    ///                      "touched-vp-end" --> touched view-port ending edge
    ///                      "outside-vp-end" --> scrolled-out from ending edge of the view-port
    ///                      "touched-vp-start" --> touched view-port starting edge
    ///                      "outside-vp-start" --> scrolled-out from starting edge of the view-port
    ///           ["subjectCrossAxisStartViewPortStart"] : (distance between cross-axis starting edge of target widget and starting edge of viewport)
    ///           ["subjectCrossAxisStartViewPortEnd"] : (distance between cross-axis starting edge of target widget and ending edge of viewport)
    ///           ["subjectCrossAxisEndViewPortStart"] : (distance between cross-axis ending edge of target widget and starting edge of viewport)
    ///           ["subjectCrossAxisEndViewPortEnd"] : (distance between cross-axis ending edge of target widget and ending edge of viewport)
    ///           ["viewPortCrossLength"] : double
    ///
    /// ["summary"] : String
    ///     Summarized state for the target widget, describing the most essential properties.
    ///     From innermost to outermost scope.
    ///     Format: "mainPosition/crossPosition:flow|mainPosition/crossPosition:flow|..."
  }

  void needRepaint() {
    setState(() {});
  }

  SizedBox buildSimpleTargetBox(
      double defaultElevation, double defaultPadding, VisibilityIds cardId) {
    return SizedBox(
      width: 300,
      height: 150,
      child: Card(
        /// Step A: Assign the predefined visibility key to the target widget.
        key: getKeyById(cardId.index),

        margin: EdgeInsets.zero,
        elevation: defaultElevation / 2,
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Relative to Vertical scroll-view'),

                /// Step B: Obtain the human-readable text representation of the target widget's visibility state.
                /// In relation to the root scroll view
                Text(
                    positionLabelByKey(
                      cardId.index,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                    )),

                const Divider(
                  height: 3.0,
                ),
                const Text('Relative to Horizontal scroll-view'),

                /// Step C: Obtain the human-readable text representation of the target widget's visibility state.
                /// with respect to the internal (horizontal) scroll view.
                Text(positionLabelByKeyAt(cardId.index, 0),
                    style: const TextStyle(
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        ),

        /// Step D: Monitor the visibility state of the target widget.
      )..watchVisibility(this),
    );
  }

  /// Rest of boilerplate codes ...

  // builders ...

  SizedBox buildAdvancedTargetBox(
      double defaultElevation, double defaultPadding, VisibilityIds cardId) {
    return SizedBox(
      width: 200,
      height: 150,
      child: Card(
        key: getKeyById(cardId.index),
        margin: EdgeInsets.zero,
        elevation: defaultElevation / 2,
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child: Container(
            alignment: Alignment.center,
            child: !WidgetVisibilityChecker.isKeyInspected(
                    getKeyById(cardId.index))
                ? OutlinedButton(
                    child: const Text('Inspect'),
                    onPressed: () {
                      setState(() {
                        WidgetVisibilityChecker.inspectKey(
                            getKeyById(cardId.index));
                      });
                    },
                  )
                : Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                        positionLabelByKey(
                          cardId.index,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                        )),
                  ),
          ),
        ),
      )..watchVisibility(this),
    );
  }

  List<Widget> buildControlSectionWidgetCollection(
      double defaultElevation, double defaultPadding) {
    return [
      Card(
        elevation: defaultElevation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 8,
            ),
            ListTile(
              dense: true,
              leading: Checkbox(
                value: enableInspectionMode,
                onChanged: onInspectionModeChanged,
              ),
              title: const Text('Enable Inspection Mode'),
              onTap: () =>
                  onInspectionModeChanged(!(enableInspectionMode ?? false)),
            ),
            ListTile(
              dense: true,
              leading: Checkbox(
                value: enableRtlLayout,
                onChanged: onRtlModeChanged,
              ),
              title: const Text('Enable RTL Layout'),
              onTap: () => onRtlModeChanged(!(enableRtlLayout ?? false)),
            ),
            const SizedBox(
              height: 8,
            ),
          ],
        ),
      ),
      Card(
        elevation: defaultElevation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 8,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 24.0, top: 12),
              child: Text(
                  'View-Port Deflate Ratio: ${deflateRatio.toStringAsFixed(2)}'),
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(
                  start: deflateRatio == 0 ? 8.0 : 0.0),
              child: Slider(
                value: deflateRatio,
                onChanged: (enableInspectionMode ?? false)
                    ? (double value) {
                        setState(() {
                          deflateRatio = value;
                        });
                      }
                    : null,
                min: 0.0,
                max: 0.3,
                divisions: 30,
                label: deflateRatio.toStringAsFixed(2),
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: defaultPadding,
      ),
    ];
  }

  SizedBox buildRectangularImageWidget(
      double defaultElevation, double defaultPadding) {
    return SizedBox(
      width: 250,
      height: 150,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: defaultElevation / 2,
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child:
              Image.network('https://picsum.photos/250/150', fit: BoxFit.cover),
        ),
      ),
    );
  }

  SizedBox buildAnotherRectangularImageWidget(
      double defaultElevation, double defaultPadding) {
    return SizedBox(
      width: 300,
      height: 150,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: defaultElevation / 2,
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child:
              Image.network('https://picsum.photos/300/150', fit: BoxFit.cover),
        ),
      ),
    );
  }

  SizedBox buildYetAnotherRectangularImageWidget(
      double defaultElevation, double defaultPadding) {
    return SizedBox(
      width: 320,
      height: 150,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: defaultElevation / 2,
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child:
              Image.network('https://picsum.photos/320/150', fit: BoxFit.cover),
        ),
      ),
    );
  }

  SizedBox buildSimpleSquareShapeImageWidget(
      double defaultElevation, double defaultPadding) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: defaultElevation / 2,
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child: Image.network('https://picsum.photos/150', fit: BoxFit.cover),
        ),
      ),
    );
  }

  SizedBox buildSimpleVerticalGap(double defaultPadding) {
    return SizedBox(
      height: defaultPadding,
    );
  }

  SizedBox buildSimpleHorizontalGap() {
    return const SizedBox(
      width: 8,
    );
  }

  Padding buildHorizontalLayout(double defaultPadding, double defaultElevation,
      {required SingleChildScrollView child}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 4,
        end: 4,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.teal[100]),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.only(
              left: defaultPadding,
              right: defaultPadding,
              bottom: 8,
            ),
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Card buildSimpleCardWidget(double defaultElevation) {
    return Card(
      elevation: defaultElevation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.center,
            height: 200,
            width: double.infinity,
            child: Text(
              'EMPTY',
              style: TextStyle(
                fontSize: 30.0,
                color: Colors.teal[100],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> buildSimpleCardWidgetCollection(
      double defaultElevation, List<String> titles) {
    return List<Widget>.generate(
      3,
      (index) => Card(
        elevation: defaultElevation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              alignment: Alignment.center,
              height: 200,
              width: double.infinity,
              child: Text(
                titles[index],
                style: TextStyle(
                  fontSize: 30.0,
                  color: Colors.teal[100],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // event listeners ...

  void onInspectionModeChanged(bool? value) {
    setState(() {
      enableInspectionMode = value;
      if (enableInspectionMode != true) {
        deflateRatio = 0;
      }
    });
  }

  void onRtlModeChanged(bool? value) {
    setState(() {
      enableRtlLayout = value;
    });
  }
}
