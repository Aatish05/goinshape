import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Force true to always use desktop-safe UI (no SnackBars/Banners).
/// Set to false if you want overlays on desktop after you confirm they're stable.
const bool kForceDesktopSafeMode = true;

/// True for Windows/macOS/Linux (not web) when safe mode is forced.
bool get desktopSafeMode =>
    kForceDesktopSafeMode && !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
