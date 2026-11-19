using System.Buffers.Text;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace IntegrityServer;

/// <summary>
/// Calls Apple's DeviceCheck server API with an ES256 JWT signed by your .p8 key:
/// validate_device_token, query_two_bits, update_two_bits.
/// </summary>
public sealed class DeviceCheckClient(HttpClient http, IOptions<IntegrityOptions> options)
{
    private readonly IntegrityOptions _opts = options.Value;

    private string BaseUrl => _opts.IsAppleProduction
        ? "https://api.devicecheck.apple.com/v1"
        : "https://api.development.devicecheck.apple.com/v1";

    public async Task<VerificationResult> ValidateAsync(string deviceToken)
    {
        using var res = await PostAsync("validate_device_token", Body(deviceToken));
        return res.IsSuccessStatusCode
            ? VerificationResult.Pass(new { status = (int)res.StatusCode })
            : VerificationResult.Fail($"Apple returned {(int)res.StatusCode}: {await res.Content.ReadAsStringAsync()}");
    }

    public async Task<VerificationResult> QueryTwoBitsAsync(string deviceToken)
    {
        using var res = await PostAsync("query_two_bits", Body(deviceToken));
        var text = await res.Content.ReadAsStringAsync();
        if (!res.IsSuccessStatusCode)
            return VerificationResult.Fail($"Apple returned {(int)res.StatusCode}: {text}");
        // 200 with plain text "Failed to find bit state" when the bits were never set.
        return text.TrimStart().StartsWith('{')
            ? VerificationResult.Pass(JsonSerializer.Deserialize<JsonElement>(text))
            : VerificationResult.Pass(new { bit0 = false, bit1 = false, note = text });
    }

    public async Task<VerificationResult> UpdateTwoBitsAsync(string deviceToken, bool bit0, bool bit1)
    {
        var body = Body(deviceToken);
        body["bit0"] = bit0;
        body["bit1"] = bit1;
        using var res = await PostAsync("update_two_bits", body);
        return res.IsSuccessStatusCode
            ? VerificationResult.Pass(new { bit0, bit1 })
            : VerificationResult.Fail($"Apple returned {(int)res.StatusCode}: {await res.Content.ReadAsStringAsync()}");
    }

    private static Dictionary<string, object> Body(string deviceToken) => new()
    {
        ["device_token"] = deviceToken,
        ["transaction_id"] = Guid.NewGuid().ToString(),
        ["timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
    };

    private Task<HttpResponseMessage> PostAsync(string path, object body)
    {
        var req = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrl}/{path}")
        {
            Content = JsonContent.Create(body),
        };
        req.Headers.Authorization = new("Bearer", CreateJwt());
        return http.SendAsync(req);
    }

    /// <summary>ES256 JWT: header {alg, kid}, claims {iss = Team ID, iat}.</summary>
    private string CreateJwt()
    {
        static string B64(ReadOnlySpan<byte> bytes) => Base64Url.EncodeToString(bytes);

        var header = B64(JsonSerializer.SerializeToUtf8Bytes(new { alg = "ES256", kid = _opts.DeviceCheckKeyId }));
        var claims = B64(JsonSerializer.SerializeToUtf8Bytes(new
        {
            iss = _opts.AppleTeamId,
            iat = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
        }));
        var signingInput = Encoding.ASCII.GetBytes($"{header}.{claims}");

        using var key = ECDsa.Create();
        key.ImportFromPem(File.ReadAllText(_opts.DeviceCheckPrivateKeyPath));
        // JWS ES256 uses the raw r||s (IEEE P1363) signature format — .NET's default.
        var signature = key.SignData(signingInput, HashAlgorithmName.SHA256);
        return $"{header}.{claims}.{B64(signature)}";
    }
}
