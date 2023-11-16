

# Widget Visibility Checker
Widget Visibility Tracking Across Nested Scrollable Containers.

## Overview
This guide highlights the capabilities of the `widget_visibility_checker` library, offering insights into its efficient use for monitoring widget visibility and metric changes. It demonstrates how to utilize the library effectively when users interact with scroll widgets within their respective parent widgets. Remarkably, the library is designed to facilitate right-to-left directionality and a hierarchical arrangement of scrolling containers, encompassing both vertical and horizontal scroll views. Additionally, it includes a debug overlay mechanism that can be enabled to examine changes in metrics.

## Key Features

-  **Visibility Monitoring:** Easily track the visibility state of widgets within scrollable containers.
-  **Detect Metrics Changes:** Detect and log metric changes for target widgets during scrolling.
-  **Directionality Support:** The library is designed to seamlessly handle right-to-left directionality, catering to diverse user interface requirements. 
-  **Orientation Flexibility:** Accommodate both vertical and horizontal scroll views with the library's support for a variety of scrolling orientations.
-  **Hierarchical Arrangement:** Library's ability to work with a hierarchical arrangement of scrolling containers, enhancing flexibility in widget organization. 
-  **Debug Overlay Mechanism:** Benefit from the included debug overlay mechanism, which can be enabled to examine changes in metrics for a deeper understanding of the widget behavior.

# Scenarios

The showcase covers various scenarios, including:
- Basic Scenario 
[Visibility monitoring in vertical and horizontal scroll views](#basic-scenario)

- Advanced Scenario
[Detect and log metric changes for target widgets during scrolling](#advanced-scenario)

- Real-World scenario
[Extends the functionality by introducing a `CustomScrollView` with support for multiple `SliverAppBar` widgets.](#real-world-scenario)


## Basic Scenario
> Visibility monitoring in vertical and horizontal scroll views.

[Static Demo (Video)](doc/1.webm){:target="_blank"}
[Interactive Demo (Preview Only)](https://zxiy061gxiz0.zapp.page){:target="_blank"}
[Interactive Demo (Preview and Edit)](https://zapp.run/edit/flutter-zxiy061gxiz0){:target="_blank"}
[Getting Started](./lib/first_entry.dart){:target="_blank"}

The library provides granular insights into widget positioning relative to their parent scroll views, categorizing them based on their location in the scrollable space. For both main-axis and cross-axis, widgets may be labeled as:

 `"within-vp"` Completely visible.
 `"across-vp"` Covered its viewport from both sides.
 `"touched-vp-end"` Touched the ending edge of the viewport.
 `"outside-vp-end"`  Scrolled out from the ending edge of the viewport.
 `"touched-vp-start"` Touched the starting edge of the viewport.
 `"outside-vp-start"` Scrolled out from the starting edge of the viewport.

This detailed visibility information empowers developers to make informed decisions about UI elements, ensuring a responsive and user-friendly experience across various scrolling scenarios.

## Advanced Scenario
> Detect and log metric changes for target widgets during scrolling.

[Static Demo (Video)](doc/2.webm){:target="_blank"}
[Interactive Demo (Preview Only)](https://zxiy061gxiz0.zapp.page){:target="_blank"}
[Interactive Demo (Preview and Edit)](https://zapp.run/edit/flutter-zxiy061gxiz0){:target="_blank"}
[Getting Started](./lib/first_entry.dart){:target="_blank"}

As users scroll through the interface, the system track and record various metrics associated with specific widgets. This includes detailed information such as the distances to the viewport edges. The logged metrics provide valuable insights into the dynamic behavior of widgets within different scrollable contexts. This feature is particularly useful for scenarios where precise monitoring of widget metrics is essential for responsive and data-driven user interfaces.

## Real World Scenario

> Extends the functionality by introducing a `CustomScrollView` with support for multiple `SliverAppBar` widgets.

[Static Demo (Video)](doc/3.webm){:target="_blank"}
[Interactive Demo (Preview Only)](https://z91e06f291f0.zapp.page){:target="_blank"}
[Interactive Demo (Preview and Edit)](https://zapp.run/edit/flutter-z91e06f291f0){:target="_blank"}
[Getting Started](./lib/second_entry.dart){:target="_blank"}

Building upon the visibility monitoring concept, this scenario introduces a multi-zone `SliverAppBar` layout. Leveraging the `multi_sliver_appbar_helper`, the application seamlessly transitions between zones, each characterized by its `SliverAppBar`, `SliverList`, or `SliverGrid`.  The transition between zones is smooth and is triggered by the visibility states of specific widgets.

## License

This project is licensed under the MIT License. Refer to the [LICENSE](./LICENSE){:target="_blank"} file for more details.
