/// Which live overlay, if any, is shown over the active screen while screenshot protection is
/// engaged. FLAG_SECURE (Android) and the equivalent iOS secure-layer trick make the OS render
/// nothing at all into a screenshot or recording — there is no way to composite custom pixels
/// *into* a blocked capture. An overlay mode is a different mechanism: a real, non-secure view
/// shown over the app's own on-screen content, reactively, whenever a capture/recording is
/// detected — a branded placeholder instead of a plain black rectangle.
enum ScreenshotOverlayMode {
  /// No overlay — just the OS-level black-out from screenshot blocking alone.
  none,

  /// A blurred version of the screen content. Android requires API 31+ for a true blur; below
  /// that it degrades to a translucent scrim.
  blur,

  /// A solid color scrim, e.g. a brand color or plain black/white.
  color,

  /// A custom image, supplied as raw bytes.
  image,
}
