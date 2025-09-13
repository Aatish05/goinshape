import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'safe_flags.dart';

/// Run after one full frame (plus ~1 vsync) to avoid pointer-update assertions.
void runAfterInput(VoidCallback fn) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(milliseconds: 16), fn);
  });
}

void showSnackBarAfterInput(BuildContext context, SnackBar bar) {
  if (desktopSafeMode) return; // avoid overlays on desktop
  runAfterInput(() {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(bar);
  });
}

void showBannerAfterInput(BuildContext context, MaterialBanner banner) {
  if (desktopSafeMode) return; // avoid overlays on desktop
  runAfterInput(() {
    if (!context.mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearMaterialBanners();
    m.showMaterialBanner(banner);
  });
}

void clearBannersAfterInput(BuildContext context) {
  if (desktopSafeMode) return;
  runAfterInput(() {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearMaterialBanners();
  });
}
