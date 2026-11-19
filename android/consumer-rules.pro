# R8 rules applied to apps that depend on device_safety_info.

# Play Integrity is compileOnly: apps that don't add it must not fail minification because the
# plugin references it. The plugin checks for the class at runtime.
-dontwarn com.google.android.play.core.integrity.**
