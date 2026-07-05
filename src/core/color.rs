#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Rgb {
    pub r: u32,
    pub g: u32,
    pub b: u32,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum BasicColor {
    Black = 0,
    Red = 1,
    Green = 2,
    Yellow = 3,
    Blue = 4,
    Magenta = 5,
    Cyan = 6,
    White = 7,
}

impl BasicColor {
    pub const fn tmux_index(self) -> u8 {
        match self {
            Self::Black => 0,
            Self::Red => 1,
            Self::Green => 2,
            Self::Yellow => 3,
            Self::Blue => 4,
            Self::Magenta => 5,
            Self::Cyan => 6,
            Self::White => 7,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Color {
    Default,
    Rgb(Rgb),
    Basic(BasicColor),
    Palette(usize),
}

impl Color {
    pub const DEFAULT: Self = Self::Default;

    pub const fn hex(value: u32) -> Self {
        Self::Rgb(Rgb {
            r: (value >> 16) & 0xff,
            g: (value >> 8) & 0xff,
            b: value & 0xff,
        })
    }

    pub const fn is_default(self) -> bool {
        matches!(self, Self::Default)
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct Attrs {
    pub bold: bool,
    pub dim: bool,
    pub italic: bool,
    pub underline: bool,
    pub blink: bool,
    pub reverse: bool,
    pub strikethrough: bool,
    pub hidden: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Style {
    pub fg: Color,
    pub bg: Color,
    pub attrs: Attrs,
}

impl Style {
    pub const DEFAULT: Self = Self {
        fg: Color::Default,
        bg: Color::Default,
        attrs: Attrs {
            bold: false,
            dim: false,
            italic: false,
            underline: false,
            blink: false,
            reverse: false,
            strikethrough: false,
            hidden: false,
        },
    };

    pub const fn set_fg(self, fg: Color) -> Self {
        Self { fg, ..self }
    }

    pub const fn set_bg(self, bg: Color) -> Self {
        Self { bg, ..self }
    }

    pub const fn bold(self) -> Self {
        let mut attrs = self.attrs;
        attrs.bold = true;
        Self { attrs, ..self }
    }

    pub const fn dim(self) -> Self {
        let mut attrs = self.attrs;
        attrs.dim = true;
        Self { attrs, ..self }
    }

    pub const fn italic(self) -> Self {
        let mut attrs = self.attrs;
        attrs.italic = true;
        Self { attrs, ..self }
    }

    pub const fn underline(self) -> Self {
        let mut attrs = self.attrs;
        attrs.underline = true;
        Self { attrs, ..self }
    }

    pub const fn blink(self) -> Self {
        let mut attrs = self.attrs;
        attrs.blink = true;
        Self { attrs, ..self }
    }

    pub const fn reverse(self) -> Self {
        let mut attrs = self.attrs;
        attrs.reverse = true;
        Self { attrs, ..self }
    }

    pub const fn strikethrough(self) -> Self {
        let mut attrs = self.attrs;
        attrs.strikethrough = true;
        Self { attrs, ..self }
    }

    pub const fn hidden(self) -> Self {
        let mut attrs = self.attrs;
        attrs.hidden = true;
        Self { attrs, ..self }
    }
}
