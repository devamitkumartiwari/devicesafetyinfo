using System.Collections.Concurrent;

namespace IntegrityServer;

/// <summary>An App Attest key that passed attestation.</summary>
/// <param name="PublicKeySpki">The key's P-256 public key (SubjectPublicKeyInfo DER).</param>
/// <param name="Counter">Highest assertion counter seen so far (replay protection).</param>
/// <param name="Receipt">Apple receipt from the attestation; can be exchanged for a fraud-risk metric.</param>
public sealed record AttestedKey(byte[] PublicKeySpki, uint Counter, byte[] Receipt);

/// <summary>
/// keyId → attested key. In-memory for the sample — in production persist this in your database,
/// associated with the user/install, since assertions must be checked against it for the life of
/// the install.
/// </summary>
public sealed class AttestedKeyStore
{
    private readonly ConcurrentDictionary<string, AttestedKey> _keys = new();

    public void Add(string keyId, AttestedKey key) => _keys[keyId] = key;

    public AttestedKey? Get(string keyId) => _keys.TryGetValue(keyId, out var key) ? key : null;

    /// <summary>
    /// Atomically advances the counter if <paramref name="newCounter"/> is strictly greater than the
    /// stored one. Returns false on a replayed or out-of-order assertion.
    /// </summary>
    public bool TryAdvanceCounter(string keyId, uint newCounter)
    {
        while (_keys.TryGetValue(keyId, out var current))
        {
            if (newCounter <= current.Counter) return false;
            if (_keys.TryUpdate(keyId, current with { Counter = newCounter }, current)) return true;
        }
        return false;
    }
}
