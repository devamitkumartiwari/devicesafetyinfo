// Builds src/dsi.c for the target platform (Android .so, iOS framework) as a native code
// asset. The Dart side binds to it with @Native in dsi_bindings.g.dart; no DynamicLibrary.open.
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // The checks only exist for Android and iOS. Building nothing elsewhere keeps host-side
    // `flutter test` working without a C toolchain; the Dart side reports "unsupported".
    if (!input.config.buildCodeAssets) return;
    final os = input.config.code.targetOS;
    if (os != OS.android && os != OS.iOS) return;

    final builder = CBuilder.library(
      // Not named after the package: on iOS a `device_safety_info` framework would clash with
      // the plugin's own SwiftPM module.
      name: 'dsi',
      assetName: 'src/core/platform/generated/dsi_bindings.g.dart',
      sources: ['src/dsi.c'],
      flags: [
        '-fvisibility=hidden',
        '-O2',
        '-fstack-protector-strong',
        '-D_FORTIFY_SOURCE=2',
        '-ffunction-sections',
        '-fdata-sections',
        if (os == OS.android) ...[
          // Drop the local symbol table (exported dsi_* symbols stay in .dynsym), unused
          // sections, and make the GOT read-only after load.
          '-Wl,--strip-all',
          '-Wl,--gc-sections',
          '-Wl,-z,relro,-z,now',
        ],
      ],
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.WARNING
        // ignore: avoid_print
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}
