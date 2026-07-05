use std::io::Write;

use flavors_tmux::cli::args::{parse_args, ParseArgsError};
use flavors_tmux::themes;
use flavors_tmux::tmux_renderer;
use flavors_tmux::widgets;

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

Styles for custom-number:
  arabic, fsquare, hsquare, dsquare, super, sub, earabic, hide
";

fn main() {
    let raw_args: Vec<String> = std::env::args().skip(1).collect();
    let raw_refs: Vec<&str> = raw_args.iter().map(|s| s.as_str()).collect();

    let code = run(&raw_refs);
    std::process::exit(code);
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
        "custom-number" => {
            match widgets::custom_number::run(&args.positional) {
                Ok(output) => {
                    let _ = out.write_all(output.as_bytes());
                    0
                }
                Err(widgets::custom_number::CustomNumberError::Usage) => {
                    eprint!("{}", USAGE);
                    2
                }
                Err(widgets::custom_number::CustomNumberError::InvalidFormat) => 9,
            }
        }

        "datetime" => {
            let output = widgets::datetime::run(args.theme, args.time_format, args.transparent);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "battery" => {
            let output = widgets::battery::run(
                args.theme,
                args.transparent,
                args.battery_name,
                args.low_threshold,
            );
            let _ = out.write_all(output.as_bytes());
            0
        }

        "git-status" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux git-status --theme <name> <repo-path>");
                return 2;
            }
            let output = widgets::git_status::run(args.theme, args.transparent, args.positional[0]);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "wb-git-status" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux wb-git-status --theme <name> <repo-path>");
                return 2;
            }
            let output =
                widgets::wb_git_status::run(args.theme, args.transparent, args.positional[0], args.cache_ttl);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "hostname" => {
            let output = widgets::hostname::run(args.theme, args.transparent);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "cpu-memory" => {
            let output = widgets::cpu_memory::run(args.theme, args.transparent);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "kubernetes" => {
            let output = widgets::kubernetes::run(args.theme, args.transparent);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "cwd" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux cwd --theme <name> <path>");
                return 2;
            }
            let output = widgets::cwd::run(args.theme, args.transparent, args.positional[0]);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "terraform" => {
            if args.positional.is_empty() {
                eprintln!("Usage: flavors-tmux terraform --theme <name> <path>");
                return 2;
            }
            let output = widgets::terraform::run(args.theme, args.transparent, args.positional[0]);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "docker" => {
            let output = widgets::docker::run(args.theme, args.transparent);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "yadm" => {
            let output = widgets::yadm::run(args.theme, args.transparent);
            let _ = out.write_all(output.as_bytes());
            0
        }

        "gpg-ssh-agent" => {
            let output = widgets::gpg_ssh_agent::run(args.theme, args.transparent);
            let _ = out.write_all(output.as_bytes());
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

            let output = widgets::status::run(
                args.theme,
                args.transparent,
                args.pane_path,
                &show_names,
                args.battery_name,
                args.low_threshold,
                args.time_format,
                args.cache_ttl,
            );
            let _ = out.write_all(output.as_bytes());
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
                    let _ = writeln!(out, "{}", tmux_renderer::color_hex_string(color));
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
                let _ = writeln!(out, "{}", name);
            }
            0
        }

        _ => {
            eprintln!("Unknown command: {}\n{}", args.command, USAGE);
            3
        }
    }
}
