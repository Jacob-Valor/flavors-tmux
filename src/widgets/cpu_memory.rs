use std::fs;
#[cfg(target_os = "macos")]
use std::process::Command;
use std::time::SystemTime;

use crate::core::{Color, Theme};
use crate::themes;
use crate::tmux_renderer;

struct CpuMemStats {
    cpu_percent: u8,
    mem_percent: u8,
}

fn parse_line_value(content: &str, prefix: &str) -> usize {
    for line in content.lines() {
        if line.starts_with(prefix) {
            for token in line.split([' ', '\t']) {
                let trimmed = token.trim();
                if !trimmed.is_empty() {
                    if let Ok(val) = trimmed.parse::<usize>() {
                        return val;
                    }
                }
            }
        }
    }
    0
}

struct CpuStat {
    total: usize,
    idle: usize,
}

fn parse_cpu_stat_line(line: &str) -> CpuStat {
    let mut total = 0usize;
    let mut idle = 0usize;
    let mut field_idx = 0usize;

    for token in line.split([' ', '\t']) {
        let trimmed = token.trim();
        if trimmed.is_empty() {
            continue;
        }
        if let Ok(val) = trimmed.parse::<usize>() {
            total += val;
            if field_idx == 3 {
                idle = val;
            }
            if field_idx == 4 {
                idle += val;
            }
            field_idx += 1;
        }
    }

    CpuStat { total, idle }
}

#[cfg(target_os = "linux")]
unsafe extern "C" {
    fn getuid() -> u32;
}

#[cfg(target_os = "linux")]
fn get_cache_path() -> String {
    let uid = unsafe { getuid() };
    format!("/tmp/flavors-tmux-cpu-cache-{}", uid)
}

#[cfg(target_os = "linux")]
fn read_linux_stats() -> CpuMemStats {
    let cache_path = get_cache_path();

    let cpu_content = match fs::read_to_string("/proc/stat") {
        Ok(s) => s,
        Err(_) => {
            return CpuMemStats {
                cpu_percent: 0,
                mem_percent: 0,
            }
        }
    };
    let first_line = match cpu_content.lines().next() {
        Some(l) if l.starts_with("cpu ") => &l[4..],
        _ => {
            return CpuMemStats {
                cpu_percent: 0,
                mem_percent: 0,
            }
        }
    };
    let current = parse_cpu_stat_line(first_line);
    let now_ns = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .map(|d| d.as_nanos() as i128)
        .unwrap_or(0);

    let mut cpu_percent: u8 = 0;

    if let Ok(cache_content) = fs::read_to_string(&cache_path) {
        let mut it = cache_content.split(' ');
        let prev_ns: i128 = it.next().and_then(|s| s.trim().parse().ok()).unwrap_or(0);
        let prev_total: usize = it.next().and_then(|s| s.trim().parse().ok()).unwrap_or(0);
        let prev_idle: usize = it.next().and_then(|s| s.trim().parse().ok()).unwrap_or(0);

        let age_ns = now_ns - prev_ns;
        if prev_ns > 0 && age_ns > 0 && age_ns < 5_000_000_000 {
            let total_delta = current.total.saturating_sub(prev_total);
            let idle_delta = current.idle.saturating_sub(prev_idle);
            #[allow(clippy::manual_checked_ops)]
            if total_delta > 0 {
                cpu_percent =
                    ((total_delta.saturating_sub(idle_delta)) * 100 / total_delta).min(100) as u8;
            }
        }
    }

    // Write to temp file then rename for atomic update
    let cache_line = format!("{} {} {}\n", now_ns, current.total, current.idle);
    let tmp_path = format!("{}.tmp", cache_path);
    let _ = fs::write(&tmp_path, &cache_line);
    let _ = fs::rename(&tmp_path, &cache_path);

    let mem_content = match fs::read_to_string("/proc/meminfo") {
        Ok(s) => s,
        Err(_) => {
            return CpuMemStats {
                cpu_percent,
                mem_percent: 0,
            }
        }
    };

    let mem_total = parse_line_value(&mem_content, "MemTotal:");
    let mem_available = {
        let val = parse_line_value(&mem_content, "MemAvailable:");
        if val > 0 {
            val
        } else {
            parse_line_value(&mem_content, "MemFree:")
        }
    };

    #[allow(clippy::manual_checked_ops)]
    let mem_percent: u8 = if mem_total > 0 {
        ((mem_total.saturating_sub(mem_available)) * 100 / mem_total).min(100) as u8
    } else {
        0
    };

    CpuMemStats {
        cpu_percent,
        mem_percent,
    }
}

#[cfg(target_os = "macos")]
fn read_darwin_stats() -> CpuMemStats {
    let mut cpu_percent: u8 = 0;

    if let Ok(top_output) = Command::new("top").args(["-l", "1", "-n", "0"]).output() {
        if top_output.status.success() {
            let stdout = String::from_utf8_lossy(&top_output.stdout);
            for line in stdout.lines() {
                if line.starts_with("CPU usage:") {
                    let mut user_val: f64 = 0.0;
                    let mut sys_val: f64 = 0.0;
                    let mut found_user = false;
                    let mut found_sys = false;
                    for token in line.split([' ', ',', '%']) {
                        let trimmed = token.trim();
                        if trimmed == "user" {
                            found_user = true;
                        } else if trimmed == "sys" {
                            found_sys = true;
                        } else if found_user && user_val == 0.0 {
                            user_val = trimmed.parse().unwrap_or(0.0);
                            found_user = false;
                        } else if found_sys && sys_val == 0.0 {
                            sys_val = trimmed.parse().unwrap_or(0.0);
                            found_sys = false;
                        }
                    }
                    cpu_percent = (user_val + sys_val).min(100.0) as u8;
                    break;
                }
            }
        }
    }

    let mut mem_percent: u8 = 0;

    if let Ok(vm_output) = Command::new("vm_stat").output() {
        if vm_output.status.success() {
            let stdout = String::from_utf8_lossy(&vm_output.stdout);
            let mut pages_free: usize = 0;
            let mut pages_active: usize = 0;
            let mut pages_inactive: usize = 0;
            let mut pages_wired: usize = 0;

            for line in stdout.lines() {
                if line.starts_with("Pages free:") {
                    pages_free = parse_vm_stat_value(line);
                } else if line.starts_with("Pages active:") {
                    pages_active = parse_vm_stat_value(line);
                } else if line.starts_with("Pages inactive:") {
                    pages_inactive = parse_vm_stat_value(line);
                } else if line.starts_with("Pages wired down:") {
                    pages_wired = parse_vm_stat_value(line);
                }
            }

            let total_pages = pages_free + pages_active + pages_inactive + pages_wired;
            let used_pages = pages_active + pages_inactive + pages_wired;
            if total_pages > 0 {
                mem_percent = (used_pages * 100 / total_pages).min(100) as u8;
            }
        }
    }

    CpuMemStats {
        cpu_percent,
        mem_percent,
    }
}

#[cfg(target_os = "macos")]
fn parse_vm_stat_value(line: &str) -> usize {
    for token in line.split(' ') {
        let trimmed = token.trim_matches(|c: char| c == ' ' || c == '\t' || c == '.');
        if !trimmed.is_empty() {
            if let Ok(val) = trimmed.parse::<usize>() {
                return val;
            }
        }
    }
    0
}

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn read_stats() -> CpuMemStats {
    CpuMemStats {
        cpu_percent: 0,
        mem_percent: 0,
    }
}

#[cfg(target_os = "linux")]
fn read_stats() -> CpuMemStats {
    read_linux_stats()
}

#[cfg(target_os = "macos")]
fn read_stats() -> CpuMemStats {
    read_darwin_stats()
}

fn get_usage_color(percent: u8, theme: Theme) -> Color {
    if percent >= 80 {
        theme.danger
    } else if percent >= 50 {
        theme.warning
    } else {
        theme.success
    }
}

/// Render the CPU and memory usage widget.
/// Shows `▒ 󰍛 {cpu}% 󰘚 {mem}%` with color-coded thresholds.
pub fn run(theme_name: &str, transparent: bool) -> String {
    let theme = themes::by_name(theme_name).with_transparent_background(transparent);

    let stats = read_stats();

    let cpu_color = get_usage_color(stats.cpu_percent, theme);
    let mem_color = get_usage_color(stats.mem_percent, theme);
    let bg = tmux_renderer::color_hex_string(theme.background);

    format!(
        "#[fg={},bg={},bold]▒ 󰍛 {}% #[fg={},bg={},bold]󰘚 {}%",
        tmux_renderer::color_hex_string(cpu_color),
        bg,
        stats.cpu_percent,
        tmux_renderer::color_hex_string(mem_color),
        bg,
        stats.mem_percent,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_cpu_stat_line_calculates_total_and_idle_correctly() {
        let result = parse_cpu_stat_line("  100 50 25 200 10 5 3 2");
        assert_eq!(395, result.total);
        assert_eq!(210, result.idle);
    }

    #[test]
    fn parse_line_value_finds_value_in_content() {
        let content = "MemTotal:    16384000 kB\nMemAvailable: 8192000 kB\n";
        assert_eq!(16384000, parse_line_value(content, "MemTotal:"));
        assert_eq!(8192000, parse_line_value(content, "MemAvailable:"));
    }

    #[test]
    fn parse_line_value_returns_zero_for_missing_key() {
        let content = "MemTotal: 1000 kB\n";
        assert_eq!(0, parse_line_value(content, "MissingKey:"));
    }

    #[test]
    fn get_usage_color_returns_correct_thresholds() {
        let theme = themes::hard::THEME;
        assert_eq!(theme.danger, get_usage_color(80, theme));
        assert_eq!(theme.danger, get_usage_color(100, theme));
        assert_eq!(theme.warning, get_usage_color(50, theme));
        assert_eq!(theme.warning, get_usage_color(79, theme));
        assert_eq!(theme.success, get_usage_color(49, theme));
        assert_eq!(theme.success, get_usage_color(0, theme));
    }
}
