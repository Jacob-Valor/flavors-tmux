use std::env;
use std::fs;
use std::path::Path;

use flavors_tmux::core::Color;
use flavors_tmux::themes;
use flavors_tmux::core::Theme;

const FIELD_NAMES: &[&str] = &[
    "background",
    "foreground",
    "surface",
    "surface_alt",
    "primary",
    "primary_bright",
    "on_primary",
    "on_primary_bright",
    "success",
    "success_bright",
    "danger",
    "danger_bright",
    "warning",
    "info",
    "info_bright",
    "accent",
    "accent_bright",
    "emphasis",
    "muted",
    "forge_github",
    "forge_gitlab",
    "forge_codeberg",
];

fn color_to_hex(color: Color) -> String {
    match color {
        Color::Rgb(rgb) => format!("#{:06x}", (rgb.r << 16) | (rgb.g << 8) | rgb.b),
        Color::Default => String::from("default"),
        _ => String::from("default"),
    }
}

fn get_field(theme: Theme, field_name: &str) -> Color {
    match field_name {
        "background" => theme.background,
        "foreground" => theme.foreground,
        "surface" => theme.surface,
        "surface_alt" => theme.surface_alt,
        "primary" => theme.primary,
        "primary_bright" => theme.primary_bright,
        "on_primary" => theme.on_primary,
        "on_primary_bright" => theme.on_primary_bright,
        "success" => theme.success,
        "success_bright" => theme.success_bright,
        "danger" => theme.danger,
        "danger_bright" => theme.danger_bright,
        "warning" => theme.warning,
        "info" => theme.info,
        "info_bright" => theme.info_bright,
        "accent" => theme.accent,
        "accent_bright" => theme.accent_bright,
        "emphasis" => theme.emphasis,
        "muted" => theme.muted,
        "forge_github" => theme.forge_github,
        "forge_gitlab" => theme.forge_gitlab,
        "forge_codeberg" => theme.forge_codeberg,
        _ => Color::Default,
    }
}

fn generate_bash_case_block() -> String {
    let mut result = String::with_capacity(8192);

    result.push_str("    case \"$theme_name\" in\n");

    for &name in themes::NAMES {
        let theme = themes::by_name(name);
        result.push_str(&format!("        {})\n", name));

        for &field in FIELD_NAMES {
            let hex = color_to_hex(get_field(theme, field));
            result.push_str(&format!(
                "            THEMES[{}_{}]=\"{}\"\n",
                name, field, hex
            ));
        }

        result.push_str("            ;;\n");
    }

    result.push_str("    esac\n");

    result
}

fn generate_valid_themes_line() -> String {
    let mut result = String::with_capacity(256);
    result.push_str("VALID_THEMES=(");

    for (i, &name) in themes::NAMES.iter().enumerate() {
        if i > 0 {
            result.push(' ');
        }
        result.push_str(&format!("\"{}\"", name));
    }

    result.push_str(")\n");
    result
}

fn replace_between_markers(
    content: &str,
    begin_marker: &str,
    end_marker: &str,
    replacement: &str,
) -> Option<String> {
    let begin_idx = content.find(begin_marker)?;
    let end_idx = content[begin_idx + begin_marker.len()..].find(end_marker)?;
    let end_idx = begin_idx + begin_marker.len() + end_idx;

    let mut result = String::with_capacity(content.len() + replacement.len());
    result.push_str(&content[..begin_idx + begin_marker.len()]);
    result.push('\n');
    result.push_str(replacement);
    result.push_str(&content[end_idx..]);
    Some(result)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: codegen <project-root>");
        std::process::exit(1);
    }

    let project_root = Path::new(&args[1]);

    let bash_block = generate_bash_case_block();
    let valid_line = generate_valid_themes_line();

    let themes_sh_path = project_root.join("scripts/themes.sh");
    if let Ok(themes_sh_content) = fs::read_to_string(&themes_sh_path) {
        if let Some(updated) = replace_between_markers(
            &themes_sh_content,
            "# BEGIN_CODEGEN_CASE_BLOCK",
            "# END_CODEGEN_CASE_BLOCK",
            &bash_block,
        ) {
            let _ = fs::write(&themes_sh_path, &updated);
            println!("Updated {}", themes_sh_path.display());
        }
    }

    let flavors_path = project_root.join("flavors.tmux");
    if let Ok(flavors_content) = fs::read_to_string(&flavors_path) {
        if let Some(updated) = replace_between_markers(
            &flavors_content,
            "# BEGIN_CODEGEN_VALID_THEMES",
            "# END_CODEGEN_VALID_THEMES",
            &valid_line,
        ) {
            let _ = fs::write(&flavors_path, &updated);
            println!("Updated {}", flavors_path.display());
        }
    }
}
