use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::sync::OnceLock;

const MAX_CACHE_BYTES: usize = 8192;

fn hash_key(value: &str) -> u64 {
    let mut hasher = DefaultHasher::new();
    value.hash(&mut hasher);
    hasher.finish()
}

/// Cache file path scoped to the current user (and optionally a second key,
/// e.g. a repo path, for widgets whose output varies by directory).
pub(crate) fn scoped_cache_path(name: &str, extra_key: Option<&str>) -> String {
    let user = env::var("HOME").unwrap_or_default();
    let uh = hash_key(&user);
    match extra_key {
        Some(extra) => format!(
            "{}/flavors-tmux-{name}-{uh:x}-{:x}",
            cache_base(),
            hash_key(extra)
        ),
        None => format!("{}/flavors-tmux-{name}-{uh:x}", cache_base()),
    }
}

/// Read a fresh cache entry, or compute + write it via `compute` on a miss.
pub(crate) fn cached_or_compute(
    cache_path: &str,
    ttl_seconds: u64,
    compute: impl FnOnce() -> String,
) -> String {
    if let Some(cached) = read_fresh_cache(cache_path, ttl_seconds) {
        return cached;
    }
    let output = compute();
    write_cache(cache_path, &output);
    output
}

fn resolve_cache_base() -> &'static str {
    if let Some(xdg) = env::var_os("XDG_CACHE_HOME") {
        let s = xdg.to_string_lossy();
        if !s.is_empty() {
            // Leak the XDG path so we can return a &str. This is called at
            // most once per process — a 1× leak of a few dozen bytes.
            return Box::leak(s.into_owned().into_boxed_str());
        }
    }
    "/tmp"
}

pub(crate) fn cache_base() -> &'static str {
    static BASE: OnceLock<&str> = OnceLock::new();
    BASE.get_or_init(resolve_cache_base)
}

/// Read a fresh cache entry, returning the content only when it was written
/// within `ttl_seconds`. Reads are one `stat` + one `read` syscall — the
/// common case for the per-refresh widget checks (every other TTL is >= 2s).
pub(crate) fn read_fresh_cache(path: &str, ttl_seconds: u64) -> Option<String> {
    if ttl_seconds == 0 {
        return None;
    }

    // Single `open` — then both the mtime and content come from the same
    // inode, which is also more correct under a concurrent writer than a
    // separate `stat` + `read` pair.
    let file = fs::File::open(path).ok()?;
    let modified = file.metadata().ok()?.modified().ok()?;
    let now = std::time::SystemTime::now();
    let age = now.duration_since(modified).ok()?;
    if age.as_secs() > ttl_seconds {
        return None;
    }

    use std::io::Read;
    let mut content = Vec::with_capacity(256);
    file.take(MAX_CACHE_BYTES as u64 + 1)
        .read_to_end(&mut content)
        .ok()?;
    if content.len() > MAX_CACHE_BYTES {
        return None;
    }
    // Cache files are always written as UTF-8 by write_cache, so this is
    // zero-copy for the common case — from_utf8 moves the Vec into the
    // String without re-allocating when valid.
    String::from_utf8(content).ok()
}

pub(crate) fn write_cache(path: &str, output: &str) {
    let tmp = format!("{path}.tmp");
    let _ = fs::write(&tmp, output);
    let _ = fs::rename(&tmp, path);
}

/// Read a cache entry regardless of age. Returns `(content, age_secs)` when
/// the file exists and is readable — used by stale-while-revalidate callers
/// that want the stale content so they can render it while a background
/// refresh runs.
pub(crate) fn read_cache_any_age(path: &str) -> Option<(String, u64)> {
    let file = fs::File::open(path).ok()?;
    let modified = file.metadata().ok()?.modified().ok()?;
    let now = std::time::SystemTime::now();
    let age = now.duration_since(modified).ok()?.as_secs();

    use std::io::Read;
    let mut content = Vec::with_capacity(256);
    file.take(MAX_CACHE_BYTES as u64 + 1)
        .read_to_end(&mut content)
        .ok()?;
    if content.len() > MAX_CACHE_BYTES {
        return None;
    }
    String::from_utf8(content).ok().map(|s| (s, age))
}
