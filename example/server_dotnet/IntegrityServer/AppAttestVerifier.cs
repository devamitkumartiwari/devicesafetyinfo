using System.Buffers.Binary;
using System.Formats.Asn1;
using System.Formats.Cbor;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using Microsoft.Extensions.Options;

namespace IntegrityServer;

/// <summary>
/// Verifies App Attest attestation objects (once per key) and assertions (per request), following
/// Apple's "Validating apps that connect to your server" steps.
///
/// The Flutter plugin computes clientDataHash = SHA256(UTF-8(challenge | clientData)); this class
/// recomputes it from the same string.
/// </summary>
public sealed class AppAttestVerifier
{
    private const string NonceExtensionOid = "1.2.840.113635.100.8.2";

    // AAGUID identifying the attestation environment (16 bytes).
    private static readonly byte[] AaguidDevelopment = "appattestdevelop"u8.ToArray();
    private static readonly byte[] AaguidProduction = [.. "appattest"u8, 0, 0, 0, 0, 0, 0, 0];

    private readonly IntegrityOptions _opts;
    private readonly AttestedKeyStore _store;
    private readonly X509Certificate2 _appleRoot;
    private readonly byte[] _rpIdHash;

    public AppAttestVerifier(IOptions<IntegrityOptions> options, AttestedKeyStore store)
    {
        _opts = options.Value;
        _store = store;
        _appleRoot = X509Certificate2.CreateFromPem(File.ReadAllText(_opts.AppAttestRootCaPath));
        _rpIdHash = SHA256.HashData(Encoding.UTF8.GetBytes(_opts.AppleAppId));
    }

    // ---------------------------------------------------------------------------------------------
    // Attestation (once per key)
    // ---------------------------------------------------------------------------------------------

    public VerificationResult VerifyAttestation(string keyIdB64, string attestationB64, string challenge)
    {
        byte[] keyId, attestation;
        try
        {
            keyId = Convert.FromBase64String(keyIdB64);
            attestation = Convert.FromBase64String(attestationB64);
        }
        catch (FormatException)
        {
            return VerificationResult.Fail("keyId / attestation is not base64");
        }

        string? fmt = null;
        byte[]? authData = null, receipt = null;
        var x5c = new List<byte[]>();
        try
        {
            var reader = new CborReader(attestation, CborConformanceMode.Lax);
            reader.ReadStartMap();
            while (reader.PeekState() != CborReaderState.EndMap)
            {
                switch (reader.ReadTextString())
                {
                    case "fmt": fmt = reader.ReadTextString(); break;
                    case "authData": authData = reader.ReadByteString(); break;
                    case "attStmt":
                        reader.ReadStartMap();
                        while (reader.PeekState() != CborReaderState.EndMap)
                        {
                            switch (reader.ReadTextString())
                            {
                                case "x5c":
                                    reader.ReadStartArray();
                                    while (reader.PeekState() != CborReaderState.EndArray)
                                        x5c.Add(reader.ReadByteString());
                                    reader.ReadEndArray();
                                    break;
                                case "receipt": receipt = reader.ReadByteString(); break;
                                default: reader.SkipValue(); break;
                            }
                        }
                        reader.ReadEndMap();
                        break;
                    default: reader.SkipValue(); break;
                }
            }
            reader.ReadEndMap();
        }
        catch (Exception e) when (e is CborContentException or InvalidOperationException)
        {
            return VerificationResult.Fail($"malformed attestation CBOR: {e.Message}");
        }

        // 1. Format.
        if (fmt != "apple-appattest") return VerificationResult.Fail($"unexpected fmt '{fmt}'");
        if (authData is null || authData.Length < 55 || x5c.Count < 2 || receipt is null)
            return VerificationResult.Fail("attestation missing authData / x5c / receipt");

        using var leaf = X509CertificateLoader.LoadCertificate(x5c[0]);

        // 2. Certificate chain: leaf → intermediate(s) → Apple App Attestation Root CA.
        using (var chain = new X509Chain())
        {
            chain.ChainPolicy.TrustMode = X509ChainTrustMode.CustomRootTrust;
            chain.ChainPolicy.CustomTrustStore.Add(_appleRoot);
            chain.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
            foreach (var der in x5c.Skip(1))
                chain.ChainPolicy.ExtraStore.Add(X509CertificateLoader.LoadCertificate(der));
            if (!chain.Build(leaf))
            {
                var status = string.Join(", ", chain.ChainStatus.Select(s => s.Status));
                return VerificationResult.Fail($"certificate chain invalid: {status}");
            }
        }

        // 3. nonce = SHA256(authData || SHA256(challenge)).
        var clientDataHash = SHA256.HashData(Encoding.UTF8.GetBytes(challenge));
        var nonce = SHA256.HashData([.. authData, .. clientDataHash]);

        // 4. nonce must equal the leaf's 1.2.840.113635.100.8.2 extension: SEQUENCE { [1] OCTET STRING }.
        var ext = leaf.Extensions[NonceExtensionOid];
        if (ext is null) return VerificationResult.Fail("nonce extension missing");
        byte[] certNonce;
        try
        {
            var seq = new AsnReader(ext.RawData, AsnEncodingRules.DER).ReadSequence();
            var tagged = seq.ReadSequence(new Asn1Tag(TagClass.ContextSpecific, 1, isConstructed: true));
            certNonce = tagged.ReadOctetString();
        }
        catch (AsnContentException e)
        {
            return VerificationResult.Fail($"nonce extension malformed: {e.Message}");
        }
        if (!CryptographicOperations.FixedTimeEquals(certNonce, nonce))
            return VerificationResult.Fail("nonce mismatch (challenge not bound)");

        // 5. keyId == SHA256(uncompressed EC public key point 0x04 || X || Y).
        using var ecKey = leaf.GetECDsaPublicKey();
        if (ecKey is null) return VerificationResult.Fail("leaf certificate has no EC key");
        var q = ecKey.ExportParameters(false).Q;
        var publicKeyHash = SHA256.HashData([0x04, .. q.X!, .. q.Y!]);
        if (!publicKeyHash.AsSpan().SequenceEqual(keyId))
            return VerificationResult.Fail("keyId does not match certificate public key");

        // 6. rpIdHash == SHA256("TEAMID.bundle.id").
        if (!authData.AsSpan(0, 32).SequenceEqual(_rpIdHash))
            return VerificationResult.Fail("rpIdHash mismatch (wrong Team ID / bundle ID)");

        // 7. counter == 0 for a fresh attestation.
        if (BinaryPrimitives.ReadUInt32BigEndian(authData.AsSpan(33, 4)) != 0)
            return VerificationResult.Fail("counter is not 0");

        // 8. AAGUID matches the expected environment.
        var expectedAaguid = _opts.IsAppleProduction ? AaguidProduction : AaguidDevelopment;
        if (!authData.AsSpan(37, 16).SequenceEqual(expectedAaguid))
            return VerificationResult.Fail($"aaguid mismatch (expected {_opts.AppleEnvironment})");

        // 9. credentialId == keyId.
        var credIdLength = BinaryPrimitives.ReadUInt16BigEndian(authData.AsSpan(53, 2));
        if (authData.Length < 55 + credIdLength ||
            !authData.AsSpan(55, credIdLength).SequenceEqual(keyId))
            return VerificationResult.Fail("credentialId does not match keyId");

        _store.Add(keyIdB64, new AttestedKey(ecKey.ExportSubjectPublicKeyInfo(), 0, receipt));
        return VerificationResult.Pass(new { keyId = keyIdB64, environment = _opts.AppleEnvironment });
    }

    // ---------------------------------------------------------------------------------------------
    // Assertion (per request)
    // ---------------------------------------------------------------------------------------------

    public VerificationResult VerifyAssertion(string keyIdB64, string assertionB64, string clientData)
    {
        var key = _store.Get(keyIdB64);
        if (key is null) return VerificationResult.Fail("unknown keyId — attest first");

        byte[]? signature = null, authData = null;
        try
        {
            var reader = new CborReader(Convert.FromBase64String(assertionB64), CborConformanceMode.Lax);
            reader.ReadStartMap();
            while (reader.PeekState() != CborReaderState.EndMap)
            {
                switch (reader.ReadTextString())
                {
                    case "signature": signature = reader.ReadByteString(); break;
                    case "authenticatorData": authData = reader.ReadByteString(); break;
                    default: reader.SkipValue(); break;
                }
            }
            reader.ReadEndMap();
        }
        catch (Exception e) when (e is FormatException or CborContentException or InvalidOperationException)
        {
            return VerificationResult.Fail($"malformed assertion: {e.Message}");
        }
        if (signature is null || authData is null || authData.Length < 37)
            return VerificationResult.Fail("assertion missing signature / authenticatorData");

        // 1–3. Signature over nonce = SHA256(authenticatorData || SHA256(clientData)).
        var clientDataHash = SHA256.HashData(Encoding.UTF8.GetBytes(clientData));
        var nonce = SHA256.HashData([.. authData, .. clientDataHash]);
        using var ecdsa = ECDsa.Create();
        ecdsa.ImportSubjectPublicKeyInfo(key.PublicKeySpki, out _);
        if (!ecdsa.VerifyData(nonce, signature, HashAlgorithmName.SHA256, DSASignatureFormat.Rfc3279DerSequence))
            return VerificationResult.Fail("signature invalid");

        // 4. rpIdHash.
        if (!authData.AsSpan(0, 32).SequenceEqual(_rpIdHash))
            return VerificationResult.Fail("rpIdHash mismatch");

        // 5. Counter strictly increases (replay protection).
        var counter = BinaryPrimitives.ReadUInt32BigEndian(authData.AsSpan(33, 4));
        if (!_store.TryAdvanceCounter(keyIdB64, counter))
            return VerificationResult.Fail("counter did not increase (replayed assertion)");

        return VerificationResult.Pass(new { counter });
    }
}
