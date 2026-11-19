using System.Text.Json;
using IntegrityServer;

// Sample verifier for device_safety_info's AppIntegrity API.
// Reference only — merge these checks into your real API and gate sensitive endpoints on them.

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<IntegrityOptions>(builder.Configuration.GetSection("Integrity"));
builder.Services.AddSingleton<ChallengeStore>();
builder.Services.AddSingleton<AttestedKeyStore>();
// Constructed lazily on first use, so the server still starts when only one platform's
// credentials are configured.
builder.Services.AddSingleton<PlayIntegrityVerifier>();
builder.Services.AddSingleton<AppAttestVerifier>();
builder.Services.AddHttpClient<DeviceCheckClient>();

var app = builder.Build();

app.MapGet("/", () => "IntegrityServer sample is running.");

// 1. Every attestation starts with a one-time challenge from the server.
app.MapGet("/challenge", (ChallengeStore challenges) => new { challenge = challenges.Issue() });

// 2a. Android: Play Integrity token bound to a challenge (passed as requestHash).
app.MapPost("/android/verify", async (AndroidVerifyRequest req, ChallengeStore challenges, PlayIntegrityVerifier verifier) =>
{
    if (!challenges.Consume(req.Challenge))
        return Results.BadRequest(VerificationResult.Fail("unknown, expired or reused challenge"));
    var result = await verifier.VerifyAsync(req.Token, req.Challenge);
    return result.Ok ? Results.Ok(result) : Results.Json(result, statusCode: StatusCodes.Status403Forbidden);
});

// 2b. iOS: one-time App Attest key attestation.
app.MapPost("/ios/attest", (AttestRequest req, ChallengeStore challenges, AppAttestVerifier verifier) =>
{
    if (!challenges.Consume(req.Challenge))
        return Results.BadRequest(VerificationResult.Fail("unknown, expired or reused challenge"));
    var result = verifier.VerifyAttestation(req.KeyId, req.Attestation, req.Challenge);
    return result.Ok ? Results.Ok(result) : Results.Json(result, statusCode: StatusCodes.Status403Forbidden);
});

// 2c. iOS: per-request App Attest assertion. clientData is the exact signed string and must embed
//     a server-issued "nonce" so the assertion can't be replayed against another request.
app.MapPost("/ios/assert", (AssertRequest req, ChallengeStore challenges, AppAttestVerifier verifier) =>
{
    var result = verifier.VerifyAssertion(req.KeyId, req.Assertion, req.ClientData);
    if (!result.Ok) return Results.Json(result, statusCode: StatusCodes.Status403Forbidden);

    string? nonce = null;
    try
    {
        using var doc = JsonDocument.Parse(req.ClientData);
        if (doc.RootElement.TryGetProperty("nonce", out var n)) nonce = n.GetString();
    }
    catch (JsonException) { }
    if (!challenges.Consume(nonce))
        return Results.BadRequest(VerificationResult.Fail("clientData.nonce unknown, expired or reused"));

    return Results.Ok(result);
});

// 2d. iOS: DeviceCheck.
app.MapPost("/ios/devicecheck", async (DeviceCheckRequest req, DeviceCheckClient client) =>
    Results.Ok(await client.ValidateAsync(req.Token)));
app.MapPost("/ios/devicecheck/query", async (DeviceCheckRequest req, DeviceCheckClient client) =>
    Results.Ok(await client.QueryTwoBitsAsync(req.Token)));
app.MapPost("/ios/devicecheck/update", async (DeviceCheckUpdateRequest req, DeviceCheckClient client) =>
    Results.Ok(await client.UpdateTwoBitsAsync(req.Token, req.Bit0, req.Bit1)));

app.Run();
