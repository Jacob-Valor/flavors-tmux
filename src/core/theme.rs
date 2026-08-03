use crate::core::Color;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub struct Theme {
    pub background: Color,
    pub foreground: Color,
    pub surface: Color,
    pub surface_alt: Color,
    pub primary: Color,
    pub primary_bright: Color,
    pub on_primary: Color,
    pub on_primary_bright: Color,
    pub success: Color,
    pub success_bright: Color,
    pub danger: Color,
    pub danger_bright: Color,
    pub warning: Color,
    pub info: Color,
    pub info_bright: Color,
    pub accent: Color,
    pub accent_bright: Color,
    pub emphasis: Color,
    pub muted: Color,
    pub forge_github: Color,
    pub forge_gitlab: Color,
    pub forge_codeberg: Color,
}

impl Theme {
    pub const fn with_transparent_background(self, enabled: bool) -> Self {
        if enabled {
            Self {
                background: Color::Default,
                surface_alt: Color::Default,
                ..self
            }
        } else {
            self
        }
    }

    pub const fn lookup(self, key: &str) -> Option<Color> {
        match key.as_bytes() {
            b"background" => Some(self.background),
            b"foreground" => Some(self.foreground),
            b"surface" => Some(self.surface),
            b"surface_alt" => Some(self.surface_alt),
            b"primary" => Some(self.primary),
            b"primary_bright" => Some(self.primary_bright),
            b"on_primary" => Some(self.on_primary),
            b"on_primary_bright" => Some(self.on_primary_bright),
            b"success" => Some(self.success),
            b"success_bright" => Some(self.success_bright),
            b"danger" => Some(self.danger),
            b"danger_bright" => Some(self.danger_bright),
            b"warning" => Some(self.warning),
            b"info" => Some(self.info),
            b"info_bright" => Some(self.info_bright),
            b"accent" => Some(self.accent),
            b"accent_bright" => Some(self.accent_bright),
            b"emphasis" => Some(self.emphasis),
            b"muted" => Some(self.muted),
            b"forge_github" => Some(self.forge_github),
            b"forge_gitlab" => Some(self.forge_gitlab),
            b"forge_codeberg" => Some(self.forge_codeberg),
            _ => None,
        }
    }
}
