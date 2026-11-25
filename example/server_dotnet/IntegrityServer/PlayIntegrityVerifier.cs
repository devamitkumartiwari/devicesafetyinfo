using Google.Apis.Auth.OAuth2;
using Google.Apis.PlayIntegrity.v1;
using Google.Apis.PlayIntegrity.v1.Data;
using Google.Apis.Services;
using Microsoft.Extensions.Options;

namespace IntegrityServer;

/// <summary>
/// Decodes a Play Integrity token through Google's server API and applies a policy to the verdict.
/// Google decrypts and verifies the token signature; this class checks that the verdict is
/// (a) for this request, (b) for this app, (c) fresh, and (d) good enough.
/// </summary>
public sealed class PlayIntegrityVerifier
{
    private readonly IntegrityOptions _opts;
    private readonly PlayIntegrityService _service;

    public PlayIntegrityVerifier(IOptions<IntegrityOptions> options)
    {
        _opts = options.Value;
        var credential = CredentialFactory
            .FromFile<ServiceAccountCredential>(_opts.ServiceAccountJsonPath)
            .ToGoogleCredential()
            .CreateScoped(PlayIntegrityService.Scope.Playintegrity);
        _service = new PlayIntegrityService(new BaseClientService.Initializer
        {
            HttpClientInitializer = credential,
            ApplicationName = "IntegrityServerSample",
        });
    }

    public async Task<VerificationResult> VerifyAsync(string token, string expectedRequestHash)
    {
        DecodeIntegrityTokenResponse response;
        try
        {
            response = await _service.V1
                .DecodeIntegrityToken(new DecodeIntegrityTokenRequest { IntegrityToken = token }, _opts.PackageName)
                .ExecuteAsync();
        }
        catch (Google.GoogleApiException e)
        {
            return VerificationResult.Fail($"decodeIntegrityToken failed: {e.Message}");
        }

        var p = response.TokenPayloadExternal;
        var request = p.RequestDetails;
        var app = p.AppIntegrity;
        var device = p.DeviceIntegrity?.DeviceRecognitionVerdict ?? [];

        var details = new
        {
            requestPackageName = request?.RequestPackageName,
            appRecognitionVerdict = app?.AppRecognitionVerdict,
            deviceRecognitionVerdict = device,
            appLicensingVerdict = p.AccountDetails?.AppLicensingVerdict,
            playProtectVerdict = p.EnvironmentDetails?.PlayProtectVerdict,
            appsDetected = p.EnvironmentDetails?.AppAccessRiskVerdict?.AppsDetected,
            deviceActivityLevel = p.DeviceIntegrity?.RecentDeviceActivity?.DeviceActivityLevel,
        };

        // (a) Bound to the challenge this server issued for this request.
        if (request?.RequestHash != expectedRequestHash)
            return VerificationResult.Fail("requestHash mismatch", details);

        // (b) For this app.
        if (request.RequestPackageName != _opts.PackageName || app?.PackageName is { } pkg && pkg != _opts.PackageName)
            return VerificationResult.Fail("package name mismatch", details);

        // (c) Fresh.
        var ageMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() - (request.TimestampMillis ?? 0);
        if (ageMs < -30_000 || ageMs > _opts.TokenMaxAgeSeconds * 1000L)
            return VerificationResult.Fail("token too old", details);

        // (d) Policy: genuine Play-distributed binary on a device meeting the required integrity.
        if (app?.AppRecognitionVerdict != "PLAY_RECOGNIZED")
            return VerificationResult.Fail($"app not recognized ({app?.AppRecognitionVerdict})", details);

        if (_opts.AllowedCertificateSha256Digests.Count > 0 &&
            !(app.CertificateSha256Digest ?? []).Any(_opts.AllowedCertificateSha256Digests.Contains))
            return VerificationResult.Fail("signing certificate not allowed", details);

        if (!device.Contains(_opts.RequiredDeviceVerdict))
            return VerificationResult.Fail($"device verdict lacks {_opts.RequiredDeviceVerdict}", details);

        // (e) Optional environment policies.
        if (_opts.RequireLicensed && p.AccountDetails?.AppLicensingVerdict != "LICENSED")
            return VerificationResult.Fail($"not licensed ({p.AccountDetails?.AppLicensingVerdict})", details);

        if (p.EnvironmentDetails?.PlayProtectVerdict is { } protect &&
            _opts.RejectedPlayProtectVerdicts.Contains(protect))
            return VerificationResult.Fail($"Play Protect verdict {protect}", details);

        var risky = (p.EnvironmentDetails?.AppAccessRiskVerdict?.AppsDetected ?? [])
            .Intersect(_opts.RejectedAppAccessRisks)
            .ToList();
        if (risky.Count > 0)
            return VerificationResult.Fail($"risky apps detected ({string.Join(", ", risky)})", details);

        if (_opts.MaxDeviceActivityLevel.Length > 0 &&
            p.DeviceIntegrity?.RecentDeviceActivity?.DeviceActivityLevel is { } level &&
            level.StartsWith("LEVEL_") &&
            string.CompareOrdinal(level, _opts.MaxDeviceActivityLevel) > 0)
            return VerificationResult.Fail($"device activity {level} above {_opts.MaxDeviceActivityLevel}", details);

        return VerificationResult.Pass(details);
    }
}
