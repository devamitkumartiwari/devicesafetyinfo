import Flutter
import UIKit
import XCTest

@testable import device_safety_info

/// Unit tests for the plugin's pure Swift logic (signal mapping and report building). They
/// don't need a jailbroken device: the IOSSecuritySuite results are passed in.
class RunnerTests: XCTestCase {

  func testCleanDeviceReportsNoJailbreakSignals() {
    let report = JailbreakSignals.report(jailbroken: false, failedChecks: ["fork"])
    XCTAssertTrue(report.signals.isEmpty)
    XCTAssertTrue(report.supported)
  }

  func testFailedJailbreakChecksAreHighRiskExceptUrlSchemes() {
    let report = JailbreakSignals.report(
      jailbroken: true, failedChecks: ["existenceOfSuspiciousFiles", "urlSchemes"])
    XCTAssertEqual(
      report.signals.map { $0.id },
      ["root.jailbreak_existenceOfSuspiciousFiles", "root.jailbreak_urlSchemes"])
    XCTAssertEqual(report.signals.map { $0.highRisk }, [true, false])
  }

  func testTeamIdIsReadFromProvisioningProfile() {
    // A provisioning profile is CMS-wrapped; the plist sits between binary bytes.
    let plist = """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
      <key>TeamIdentifier</key><array><string>ABCDE12345</string></array>
      </dict></plist>
      """
    var data = Data([0x30, 0x82, 0x01, 0x00])
    data.append(Data(plist.utf8))
    data.append(Data([0xa0, 0x82]))
    XCTAssertEqual(SigningInfoReader.teamId(inProfile: data), "ABCDE12345")
    XCTAssertNil(SigningInfoReader.teamId(inProfile: Data([0x30, 0x82])))
  }

  func testAppWithoutProfileReportsNone() {
    // The XCTest bundle has no embedded.mobileprovision.
    let info = SigningInfoReader.read(bundle: Bundle(for: RunnerTests.self))
    XCTAssertFalse(info.hasProvisioningProfile)
    XCTAssertNil(info.teamId)
  }

  func testJailbrokenWithoutDetailsStillReportsHighRisk() {
    let report = JailbreakSignals.report(jailbroken: true, failedChecks: [])
    XCTAssertEqual(report.signals.map { $0.id }, ["root.jailbreak"])
    XCTAssertTrue(report.signals[0].highRisk)
  }

  func testHookingChecksMapToHighRiskSignals() {
    XCTAssertTrue(
      HookingSignals.hookReport(reverseEngineered: false, failedChecks: ["fridaFound"])
        .signals.isEmpty)
    let report = HookingSignals.hookReport(reverseEngineered: true, failedChecks: ["fridaFound"])
    XCTAssertEqual(report.signals.map { $0.id }, ["hooking.fridaFound"])
    XCTAssertTrue(report.signals[0].highRisk)
    XCTAssertEqual(
      HookingSignals.hookReport(reverseEngineered: true, failedChecks: []).signals.map { $0.id },
      ["hooking.reverse_engineering"])
  }

  func testReportConvertsToPigeonMessage() {
    let msg = RiskReport(
      signals: [
        RiskSignal(id: "screen_lock.none", highRisk: true),
        RiskSignal(id: "vpn.active", highRisk: false),
      ]
    ).msg
    XCTAssertTrue(msg.supported)
    XCTAssertEqual(msg.signals.map { $0.id }, ["screen_lock.none", "vpn.active"])
    XCTAssertEqual(msg.signals.map { $0.level }, [.high, .low])
    XCTAssertFalse(RiskReport.unsupported.msg.supported)
  }

  func testReportOfBuildsAtMostOneSignal() {
    XCTAssertTrue(RiskReport.of(false, "screen_lock.none", highRisk: true).signals.isEmpty)
    XCTAssertEqual(
      RiskReport.of(true, "screen_lock.none", highRisk: true).signals.map { $0.id },
      ["screen_lock.none"])
  }

  func testArgbColorConversion() {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    PluginSupport.uiColor(fromARGB: 0x80FF0000).getRed(&r, green: &g, blue: &b, alpha: &a)
    XCTAssertEqual(r, 1, accuracy: 0.01)
    XCTAssertEqual(g, 0, accuracy: 0.01)
    XCTAssertEqual(a, 128.0 / 255.0, accuracy: 0.01)
  }
}
