use std::env;
use std::process::Command;

use crate::core::widget::WidgetContext;
use crate::tmux_renderer;

/// Check whether the SSH agent is running and count loaded keys.
/// Returns `None` when the agent socket is absent or the command fails,
/// `Some(0)` when the agent is running with no identities, and `Some(n)` for the key count.
fn check_ssh_agent() -> Option<usize> {
    env::var_os("SSH_AUTH_SOCK")?;

    let output = Command::new("ssh-add").arg("-l").output().ok()?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let trimmed = stdout.trim();

    if trimmed.is_empty() {
        return Some(0);
    }
    // ssh-add -l prints "The agent has no identities." when empty.
    if trimmed.contains("no identities") {
        return Some(0);
    }

    Some(trimmed.lines().filter(|line| !line.is_empty()).count())
}

/// Check whether the GPG agent is running by attempting a connection.
fn check_gpg_agent() -> bool {
    Command::new("gpg-connect-agent")
        .args(["--quiet", "/bye"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Render the GPG/SSH agent status widget.
/// Shows ` <count>` and/or `` segments with color-coded status.
pub fn run(theme_name: &str, transparent: bool) -> String {
    let ctx = WidgetContext::new(theme_name, transparent);
    let theme = ctx.theme;

    let ssh_count = check_ssh_agent();
    let gpg_running = check_gpg_agent();

    if ssh_count.is_none() && !gpg_running {
        return String::new();
    }

    let bg = tmux_renderer::color_hex_string(theme.background);
    let mut result = String::new();
    let mut first = true;

    if let Some(count) = ssh_count {
        let color = if count > 0 {
            theme.success
        } else {
            theme.warning
        };
        result.push_str(&format!(
            "{}#[fg={},bg={},bold] {}",
            ctx.reset,
            tmux_renderer::color_hex_string(color),
            bg,
            count,
        ));
        first = false;
    }

    if gpg_running {
        if !first {
            result.push(' ');
        }
        result.push_str(&format!(
            "{}#[fg={},bg={},bold]",
            ctx.reset,
            tmux_renderer::color_hex_string(theme.success),
            bg,
        ));
    }

    result
}
