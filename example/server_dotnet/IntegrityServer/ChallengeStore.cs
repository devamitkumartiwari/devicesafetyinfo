using System.Buffers.Text;
using System.Collections.Concurrent;
using System.Security.Cryptography;

namespace IntegrityServer;

/// <summary>
/// Issues single-use, short-lived random challenges. A challenge binds a token to one specific
/// server request so a captured token can't be replayed.
///
/// In-memory for the sample; use a shared store (Redis, database) when running more than one
/// server instance.
/// </summary>
public sealed class ChallengeStore
{
    private static readonly TimeSpan Ttl = TimeSpan.FromMinutes(5);
    private readonly ConcurrentDictionary<string, DateTimeOffset> _issued = new();

    public string Issue()
    {
        PurgeExpired();
        var challenge = Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(32));
        _issued[challenge] = DateTimeOffset.UtcNow + Ttl;
        return challenge;
    }

    /// <summary>
    /// True exactly once per issued, unexpired challenge. TryRemove is atomic, so two concurrent
    /// requests can't both consume the same challenge.
    /// </summary>
    public bool Consume(string? challenge)
    {
        if (string.IsNullOrEmpty(challenge)) return false;
        return _issued.TryRemove(challenge, out var expires) && expires > DateTimeOffset.UtcNow;
    }

    private void PurgeExpired()
    {
        var now = DateTimeOffset.UtcNow;
        foreach (var (key, expires) in _issued)
        {
            if (expires <= now) _issued.TryRemove(key, out _);
        }
    }
}
