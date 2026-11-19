import '../../../core/result/risk_signal.dart';

/// An enabled accessibility service.
final class AccessibilityService {
  /// Creates the entity.
  const AccessibilityService(this.id, {required this.canRetrieveWindowContent});

  /// Component name, e.g. `com.example/.MyService`.
  final String id;

  /// Whether the service can read other apps' window content (what screen-scraping banking
  /// trojans rely on).
  final bool canRetrieveWindowContent;

  /// The package part of [id].
  String get packageName => id.split('/').first;
}

/// Source of the enabled accessibility services.
abstract interface class AccessibilityRepository {
  /// Every enabled accessibility service (empty on iOS).
  Future<List<AccessibilityService>> enabledServices();
}

/// Turns enabled services into signals. Services on [allowlist] (matched by component name
/// or package name) are ignored. A non-allowlisted service that can read window content is
/// high risk; any other non-allowlisted service is low risk.
List<RiskSignal> accessibilitySignals(
  List<AccessibilityService> services,
  Set<String> allowlist,
) => [
  for (final s in services)
    if (!allowlist.contains(s.id) && !allowlist.contains(s.packageName))
      s.canRetrieveWindowContent
          ? RiskSignal('accessibility.window_reader:${s.id}', RiskLevel.high)
          : RiskSignal('accessibility.service:${s.id}', RiskLevel.low),
];
