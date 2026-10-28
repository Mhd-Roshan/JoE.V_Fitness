import 'package:flutter/widgets.dart';

/// Bottom margin for the floating pill navigation bars.
///
/// On Android the app draws edge-to-edge, so a fixed margin makes the bar sit
/// on top of the phone's own navigation bar / gesture handle. This lifts the
/// bar above the system inset with a comfortable gap, and falls back to the
/// original 24 when the device has no bottom inset.
double navBarBottomMargin(BuildContext context) {
  final double systemInset = MediaQuery.viewPaddingOf(context).bottom;
  return systemInset > 0 ? systemInset + 12 : 24;
}

