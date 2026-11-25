namespace IntegrityServer;

/// <summary>Bound from the "Integrity" section of appsettings.json.</summary>
public sealed class IntegrityOptions
{
    // ---- Android: Play Integrity ----

    /// <summary>Android applicationId the tokens must belong to.</summary>
    public string PackageName { get; set; } = "";

    /// <summary>Google Cloud service-account key (JSON) with access to the Play Integrity API.</summary>
    public string ServiceAccountJsonPath { get; set; } = "service-account.json";

    /// <summary>
    /// Optional: SHA-256 digests (base64url, as Play reports them) of your app-signing certificate.
    /// Empty = rely on PLAY_RECOGNIZED only.
    /// </summary>
    public List<string> AllowedCertificateSha256Digests { get; set; } = [];

    /// <summary>MEETS_BASIC_INTEGRITY, MEETS_DEVICE_INTEGRITY (default) or MEETS_STRONG_INTEGRITY.</summary>
    public string RequiredDeviceVerdict { get; set; } = "MEETS_DEVICE_INTEGRITY";

    /// <summary>Reject tokens whose request timestamp is older than this.</summary>
    public int TokenMaxAgeSeconds { get; set; } = 120;

    /// <summary>Require appLicensingVerdict == LICENSED (the user got the app from Play).</summary>
    public bool RequireLicensed { get; set; }

    /// <summary>
    /// playProtectVerdict values to reject, e.g. ["HIGH_RISK"] or ["HIGH_RISK", "POSSIBLE_RISK"].
    /// Only present when the Play Console opts in to environment details.
    /// </summary>
    public List<string> RejectedPlayProtectVerdicts { get; set; } = [];

    /// <summary>
    /// appAccessRiskVerdict.appsDetected values to reject, e.g. ["UNKNOWN_CONTROLLING",
    /// "UNKNOWN_CAPTURING"]: an app not from Play that can control or capture the screen.
    /// </summary>
    public List<string> RejectedAppAccessRisks { get; set; } = [];

    /// <summary>
    /// Highest recentDeviceActivity level allowed (LEVEL_1 lowest ... LEVEL_4 highest), or empty
    /// to ignore it. High levels mean this device requested unusually many tokens, typical of a
    /// device farm or token-replay setup.
    /// </summary>
    public string MaxDeviceActivityLevel { get; set; } = "";

    // ---- iOS: App Attest / DeviceCheck ----

    /// <summary>10-character Apple Developer Team ID.</summary>
    public string AppleTeamId { get; set; } = "";

    /// <summary>iOS bundle identifier.</summary>
    public string BundleId { get; set; } = "";

    /// <summary>
    /// "development" or "production". Must match the app's
    /// com.apple.developer.devicecheck.appattest-environment entitlement and selects the
    /// DeviceCheck API host.
    /// </summary>
    public string AppleEnvironment { get; set; } = "development";

    /// <summary>Apple App Attestation Root CA (PEM), from apple.com/certificateauthority.</summary>
    public string AppAttestRootCaPath { get; set; } = "AppleAppAttestRootCA.pem";

    /// <summary>Key ID of the DeviceCheck .p8 key from the Apple Developer portal.</summary>
    public string DeviceCheckKeyId { get; set; } = "";

    /// <summary>Path to the DeviceCheck .p8 private key.</summary>
    public string DeviceCheckPrivateKeyPath { get; set; } = "";

    public bool IsAppleProduction =>
        string.Equals(AppleEnvironment, "production", StringComparison.OrdinalIgnoreCase);

    /// <summary>App ID as App Attest hashes it into rpIdHash: "TEAMID.bundle.id".</summary>
    public string AppleAppId => $"{AppleTeamId}.{BundleId}";
}

/// <summary>Uniform result returned by every verification endpoint.</summary>
public sealed record VerificationResult(bool Ok, string? Reason = null, object? Details = null)
{
    public static VerificationResult Fail(string reason, object? details = null) => new(false, reason, details);
    public static VerificationResult Pass(object? details = null) => new(true, null, details);
}

public sealed record AndroidVerifyRequest(string Token, string Challenge);
public sealed record AttestRequest(string KeyId, string Attestation, string Challenge);
public sealed record AssertRequest(string KeyId, string Assertion, string ClientData);
public sealed record DeviceCheckRequest(string Token);
public sealed record DeviceCheckUpdateRequest(string Token, bool Bit0, bool Bit1);
