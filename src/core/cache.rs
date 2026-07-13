use std::env;
use std::fs;

const MAX_CACHE_BYTES: usize = 8192;

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
