#[cfg(target_os = "linux")]
use std::fs;
#[cfg(target_os = "macos")]
use std::process::Command;

use crate::core::{Color, Theme};
use crate::themes;
use crate::tmux_renderer;

const DISCHARGING_ICONS: [&str; 10] = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
const CHARGING_ICONS: [&str; 10] = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
const NOT_CHARGING_ICON: &str = "󰚥";
const NO_BATTERY_ICON: &str = "󱉝";

struct BatteryInfo {
    status: String,
    percentage: u8,
}

fn battery_icon(status: &str, percentage: u8) -> &'static str {
    let idx = usize::min(percentage as usize / 10, 9);
    let s = status.trim();

    if s == "Charging" || s == "Charged" || s == "charging" {
        return CHARGING_ICONS[idx];
    }
    if s == "Discharging" || s == "discharging" {
        return DISCHARGING_ICONS[idx];
    }
    if s == "Full" || s == "charged" || s == "full" || s == "AC" {
        return NOT_CHARGING_ICON;
    }
    NO_BATTERY_ICON
}

fn battery_color(theme: Theme, percentage: u8, low_threshold: u8) -> Color {
    if percentage < low_threshold {
        theme.danger
    } else if percentage >= 100 {
        theme.success
    } else {
        theme.warning
    }
}

#[cfg(target_os = "linux")]
fn read_linux_battery(name: &str) -> Option<BatteryInfo> {
    let status_path = format!("/sys/class/power_supply/{}/status", name);
    let capacity_path = format!("/sys/class/power_supply/{}/capacity", name);

    let status = fs::read_to_string(&status_path).ok()?;
    let capacity = fs::read_to_string(&capacity_path).ok()?;

    let pct = capacity.trim().parse::<u8>().unwrap_or(0);

    Some(BatteryInfo {
        status: status.trim().to_owned(),
        percentage: pct,
    })
}

#[cfg(target_os = "macos")]
fn read_darwin_battery(name: &str) -> Option<BatteryInfo> {
    let output = Command::new("pmset").args(["-g", "batt"]).output().ok()?;

    if !output.status.success() {
        return None;
    }

    let stdout = String::from_utf8_lossy(&output.stdout);

    for line in stdout.lines() {
        if !line.contains(name) {
            continue;
        }

        let mut pct: u8 = 0;
        let mut status_slice = String::from("Unknown");

        for token in line.split([' ', ';']) {
            let trimmed = token.trim();
            if trimmed.len() > 1 && trimmed.ends_with('%') {
                pct = trimmed[..trimmed.len() - 1].parse::<u8>().unwrap_or(0);
            } else if matches!(trimmed, "charging" | "discharging" | "charged" | "full") {
                status_slice = trimmed.to_owned();
            }
        }

        return Some(BatteryInfo {
            status: status_slice,
            percentage: pct,
        });
    }

    None
}

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn read_battery(_name: &str) -> Option<BatteryInfo> {
    None
}

#[cfg(target_os = "linux")]
fn read_battery(name: &str) -> Option<BatteryInfo> {
    read_linux_battery(name)
}

#[cfg(target_os = "macos")]
fn read_battery(name: &str) -> Option<BatteryInfo> {
    read_darwin_battery(name)
}

#[cfg(target_os = "linux")]
fn auto_detect_battery_name() -> Option<&'static str> {
    for &name in &["BAT0", "BAT1", "BAT2"] {
        let path = format!("/sys/class/power_supply/{}/capacity", name);
        if fs::metadata(&path).is_ok() {
            return Some(name);
        }
    }
    None
}

#[cfg(not(target_os = "linux"))]
fn auto_detect_battery_name() -> Option<&'static str> {
    None
}

/// Render the battery widget.
/// Shows `▒ {icon} {pct}% ` with color-coded threshold.
/// Silently returns empty if no battery is present.
pub fn run(
    theme_name: &str,
    transparent: bool,
    battery_name: Option<&str>,
    low_threshold: u8,
) -> String {
    let theme = themes::by_name(theme_name).with_transparent_background(transparent);

    let name: &str = match battery_name {
        Some(name) => name,
        None => match auto_detect_battery_name() {
            Some(detected) => detected,
            None => {
                if cfg!(target_os = "macos") {
                    "InternalBattery-0"
                } else {
                    "BAT0"
                }
            }
        },
    };

    let info = match read_battery(name) {
        Some(info) => info,
        None => return String::new(),
    };

    let icon = battery_icon(&info.status, info.percentage);
    let color = battery_color(theme, info.percentage, low_threshold);

    let bold = if info.percentage < low_threshold {
        ",bold"
    } else {
        ""
    };

    format!(
        "#[fg={}{}}}▒ {} {}% ",
        tmux_renderer::color_hex_string(color),
        bold,
        icon,
        info.percentage,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn battery_icon_charging() {
        assert_eq!(CHARGING_ICONS[5], battery_icon("Charging", 50));
    }

    #[test]
    fn battery_icon_discharging() {
        assert_eq!(DISCHARGING_ICONS[7], battery_icon("Discharging", 75));
    }

    #[test]
    fn battery_icon_full() {
        assert_eq!(NOT_CHARGING_ICON, battery_icon("Full", 0));
    }

    #[test]
    fn battery_color_selection() {
        let theme = themes::hard::THEME;
        assert_eq!(theme.danger, battery_color(theme, 10, 20));
        assert_eq!(theme.warning, battery_color(theme, 50, 20));
        assert_eq!(theme.success, battery_color(theme, 100, 20));
    }
}
