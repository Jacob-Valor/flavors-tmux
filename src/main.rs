use std::io::Write;

use flavors_tmux::cli::args::{parse_args, Args, ParseArgsError};
use flavors_tmux::core::Theme;
use flavors_tmux::themes;
use flavors_tmux::tmux_renderer;
use flavors_tmux::widgets;

/// Write output to stdout or return a non-zero exit code on failure.
macro_rules! write_output {
    ($dst:expr, $bytes:expr) => {
        if $dst.write_all($bytes.as_bytes()).is_err() {
            return 1;
        }
    };
}

const USAGE: &str = "\
Usage: flavors-tmux <command> [options]

Commands:
  custom-number <id> <style>          Format a number with a glyph style
  datetime --theme <name> [opts]      Render datetime widget
  battery --theme <name> [opts]       Render battery widget
  git-status --theme <name> <path>    Render git status widget
  wb-git-status --theme <name> <path> Render GitHub/GitLab status widget
  hostname --theme <name>             Render hostname/SSH indicator widget
  cpu-memory --theme <name>           Render CPU and memory usage widget
  kubernetes --theme <name>           Render Kubernetes context widget
  cwd --theme <name> <path>           Render current working directory widget
  terraform --theme <name> <path>     Render Terraform workspace widget
  docker --theme <name>               Render Docker context widget
  yadm --theme <name>                 Render YADM dotfiles status widget
  gpg-ssh-agent --theme <name>       Render GPG/SSH agent status widget
  theme <name> <key>                  Look up a theme color
  theme-list                          List available themes

Options:
  --theme <name>                      Theme name (default: hard)
  --format <12H|24H|hide>             Time format (datetime)
  --name <battery-name>               Battery name (battery)
  --low-threshold <n>                 Low battery threshold (battery, default: 20)
  -c, --cache-ttl <seconds>           Forge widget cache TTL (default: 300)
  --transparent                       Use default terminal background
  --separator <style>                  Separator between widgets (space, pipe, chevron, none)

Styles for custom-number:
  arabic, fsquare, hsquare, dsquare, super, sub, earabic, hide
";

fn main() {
    let raw_args: Vec<String> = std::env::args().skip(1).collect();
    let raw_refs: Vec<&str> = raw_args.iter().map(|s| s.as_str()).collect();

    let code = run(&raw_refs);
    std::process::exit(code);
}

fn resolve_theme(args: &Args<'_>) -> Theme {
    themes::by_name(args.theme).with_transparent_background(args.transparent)
}

fn run(raw_args: &[&str]) -> i32 {
    let args = match parse_args(raw_args) {
        Ok(args) => args,
        Err(err) => {
            eprint!("{}", USAGE);
            return match err {
                ParseArgsError::Usage => 2,
                ParseArgsError::MissingValue => 6,
                ParseArgsError::InvalidFormat => 9,
                ParseArgsError::InvalidNumber => 8,
                ParseArgsError::UnknownOption => 7,
            };
        }
    };

    let stdout = std::io::stdout();
    let mut out = stdout.lock();

    match args.command {
        "custom-number" => match widgets::custom_number::run(&args.positional) {
            Ok(output) => {
                write_output!(out, output);
                0
            }
            Err(widgets::custom_number::CustomNumberError::Usage) => {
                eprint!("{}", USAGE);
                2
            }
            Err(widgets::custom_number::CustomNumberError::InvalidFormat) => 9,
        },

        "datetime" => {
            let theme = resolve_theme(&args);
            let output = widgets::datetime::run(theme, args.time_format);
            write_output!(out, output);
            0
        }

        "battery" => {
            let theme = resolve_theme(&args);
            let output = widgets::battery::run(theme, args.battery_name, args.low_threshold);
            write_output!(out, output);
            0
        }

        "git-status" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux git-status --theme <name> <repo-path>");
                return 2;
            }
            let theme = resolve_theme(&args);
            let output = widgets::git_status::run(theme, args.positional[0]);
            write_output!(out, output);
            0
        }

        "wb-git-status" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux wb-git-status --theme <name> <repo-path>");
                return 2;
            }
            let theme = resolve_theme(&args);
            let output = widgets::wb_git_status::run(theme, args.positional[0], args.cache_ttl);
            write_output!(out, output);
            0
        }

        "hostname" => {
            let theme = resolve_theme(&args);
            let output = widgets::hostname::run(theme);
            write_output!(out, output);
            0
        }

        "cpu-memory" => {
            let theme = resolve_theme(&args);
            let output = widgets::cpu_memory::run(theme);
            write_output!(out, output);
            0
        }

        "kubernetes" => {
            let theme = resolve_theme(&args);
            let output = widgets::kubernetes::run(theme);
            write_output!(out, output);
            0
        }

        "cwd" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux cwd --theme <name> <path>");
                return 2;
            }
            let theme = resolve_theme(&args);
            let output = widgets::cwd::run(theme, args.positional[0]);
            write_output!(out, output);
            0
        }

        "terraform" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux terraform --theme <name> <path>");
                return 2;
            }
            let theme = resolve_theme(&args);
            let output = widgets::terraform::run(theme, args.positional[0]);
            write_output!(out, output);
            0
        }

        "docker" => {
            let theme = resolve_theme(&args);
            let output = widgets::docker::run(theme);
            write_output!(out, output);
            0
        }

        "yadm" => {
            let theme = resolve_theme(&args);
            let output = widgets::yadm::run(theme);
            write_output!(out, output);
            0
        }

        "gpg-ssh-agent" => {
            let theme = resolve_theme(&args);
            let output = widgets::gpg_ssh_agent::run(theme);
            write_output!(out, output);
            0
        }

        "status" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux status --theme <name> --show <widgets> [--pane-path <path>]");
                return 2;
            }
            let show_str = args.positional[0];
            let show_names: Vec<&str> = show_str
                .split(',')
                .map(|s| s.trim())
                .filter(|s| !s.is_empty())
                .take(16)
                .collect();

            let resolved_theme = resolve_theme(&args);

            let status_cfg = widgets::status::WidgetConfig {
                theme: resolved_theme,
                pane_path: args.pane_path.unwrap_or("."),
                battery_name: args.battery_name,
                low_threshold: args.low_threshold,
                time_format: args.time_format,
                cache_ttl: args.cache_ttl,
                separator: args.separator_style,
            };
            let output = widgets::status::run(status_cfg, &show_names);
            write_output!(out, output);
            0
        }

        "theme" => {
            if args.positional.len() < 2 {
                eprintln!("Usage: flavors-tmux theme <name> <key>");
                return 2;
            }
            let theme = if let Some(t) = themes::builtin_by_name(args.positional[0]) {
                t
            } else {
                use flavors_tmux::core::theme_loader;
                match theme_loader::custom_theme_path(args.positional[0])
                    .and_then(|p| theme_loader::load_from_file(&p).ok())
                {
                    Some(t) => t,
                    None => {
                        eprintln!("Unknown theme: {}", args.positional[0]);
                        return 4;
                    }
                }
            };
            match theme.lookup(args.positional[1]) {
                Some(color) => {
                    if writeln!(out, "{}", tmux_renderer::color_hex_string(color)).is_err() {
                        return 1;
                    }
                    0
                }
                None => {
                    eprintln!("Unknown key: {}", args.positional[1]);
                    5
                }
            }
        }

        "theme-list" => {
            for name in themes::NAMES {
                if writeln!(out, "{}", name).is_err() {
                    return 1;
                }
            }
            0
        }

        _ => {
            eprintln!("Unknown command: {}\n{}", args.command, USAGE);
            3
        }
    }
}
