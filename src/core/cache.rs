use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};

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
        Some(extra) => format!("{}/flavors-tmux-{name}-{uh:x}-{:x}", cache_base(), hash_key(extra)),
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

pub(crate) fn cache_base() -> String {
    if let Some(xdg) = env::var_os("XDG_CACHE_HOME") {
        let xdg_str = xdg.to_string_lossy().into_owned();
        if !xdg_str.is_empty() {
            return xdg_str;
        }
    }
    String::from("/tmp")
}

pub(crate) fn read_fresh_cache(path: &str, ttl_seconds: u64) -> Option<String> {
    if ttl_seconds == 0 {
        return None;
    }

    let metadata = fs::metadata(path).ok()?;
    let modified = metadata.modified().ok()?;
    let now = std::time::SystemTime::now();
    let age = now.duration_since(modified).ok()?;
    if age.as_secs() > ttl_seconds {
        return None;
    }

    let content = fs::read(path).ok()?;
    if content.len() > MAX_CACHE_BYTES {
        return None;
    }
    Some(String::from_utf8_lossy(&content).into_owned())
}

pub(crate) fn write_cache(path: &str, output: &str) {
    let tmp = format!("{path}.tmp");
    let _ = fs::write(&tmp, output);
    let _ = fs::rename(&tmp, path);
}
