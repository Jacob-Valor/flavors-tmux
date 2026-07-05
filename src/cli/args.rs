#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TimeFormat {
    H12,
    H24,
    Hide,
}

impl TimeFormat {
    pub const fn from_str(value: &str) -> Option<Self> {
        match value.as_bytes() {
            b"12H" => Some(Self::H12),
            b"24H" => Some(Self::H24),
            b"hide" => Some(Self::Hide),
            _ => None,
        }
    }

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::H12 => "12H",
            Self::H24 => "24H",
            Self::Hide => "hide",
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Args<'a> {
    pub command: &'a str,
    pub positional: Vec<&'a str>,
    pub theme: &'a str,
    pub time_format: TimeFormat,
    pub battery_name: Option<&'a str>,
    pub low_threshold: u8,
    pub cache_ttl: u64,
    pub transparent: bool,
    pub pane_path: Option<&'a str>,
}

impl<'a> Args<'a> {
    pub const fn new() -> Self {
        Self {
            command: "",
            positional: Vec::new(),
            theme: "hard",
            time_format: TimeFormat::H24,
            battery_name: None,
            low_threshold: 20,
            cache_ttl: 300,
            transparent: false,
            pane_path: None,
        }
    }
}

impl Default for Args<'_> {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ParseArgsError {
    Usage,
    MissingValue,
    InvalidFormat,
    InvalidNumber,
    UnknownOption,
}

pub fn parse_args<'a>(raw_args: &'a [&'a str]) -> Result<Args<'a>, ParseArgsError> {
    let Some((command, rest)) = raw_args.split_first() else {
        return Err(ParseArgsError::Usage);
    };

    let mut args = Args::new();
    args.command = command;

    let mut index = 0;
    while index < rest.len() {
        let arg = rest[index];
        match arg {
            "--theme" => {
                index += 1;
                args.theme = rest
                    .get(index)
                    .copied()
                    .ok_or(ParseArgsError::MissingValue)?;
            }
            "--format" => {
                index += 1;
                let value = rest
                    .get(index)
                    .copied()
                    .ok_or(ParseArgsError::MissingValue)?;
                args.time_format =
                    TimeFormat::from_str(value).ok_or(ParseArgsError::InvalidFormat)?;
            }
            "--name" => {
                index += 1;
                args.battery_name = Some(
                    rest.get(index)
                        .copied()
                        .ok_or(ParseArgsError::MissingValue)?,
                );
            }
            "--low-threshold" => {
                index += 1;
                let value = rest
                    .get(index)
                    .copied()
                    .ok_or(ParseArgsError::MissingValue)?;
                args.low_threshold = value
                    .parse::<u8>()
                    .map_err(|_| ParseArgsError::InvalidNumber)?;
            }
            "-c" | "--cache-ttl" => {
                index += 1;
                let value = rest
                    .get(index)
                    .copied()
                    .ok_or(ParseArgsError::MissingValue)?;
                args.cache_ttl = value
                    .parse::<u64>()
                    .map_err(|_| ParseArgsError::InvalidNumber)?;
            }
            "--transparent" => {
                args.transparent = true;
            }
            "--pane-path" => {
                index += 1;
                args.pane_path = Some(
                    rest.get(index)
                        .copied()
                        .ok_or(ParseArgsError::MissingValue)?,
                );
            }
            option if option.starts_with('-') => return Err(ParseArgsError::UnknownOption),
            positional => args.positional.push(positional),
        }
        index += 1;
    }

    Ok(args)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn time_format_from_str_valid_values() {
        assert_eq!(Some(TimeFormat::H12), TimeFormat::from_str("12H"));
        assert_eq!(Some(TimeFormat::H24), TimeFormat::from_str("24H"));
        assert_eq!(Some(TimeFormat::Hide), TimeFormat::from_str("hide"));
        assert_eq!(None, TimeFormat::from_str("invalid"));
        assert_eq!(None, TimeFormat::from_str(""));
    }

    #[test]
    fn time_format_to_string() {
        assert_eq!("12H", TimeFormat::H12.as_str());
        assert_eq!("24H", TimeFormat::H24.as_str());
        assert_eq!("hide", TimeFormat::Hide.as_str());
    }

    #[test]
    fn parse_args_validates_time_format() {
        let valid_args = ["datetime", "--format", "12H"];
        let args = parse_args(&valid_args);
        assert_eq!(Ok(TimeFormat::H12), args.map(|args| args.time_format));

        let invalid_args = ["datetime", "--format", "invalid"];
        assert_eq!(
            Err(ParseArgsError::InvalidFormat),
            parse_args(&invalid_args)
        );
    }

    #[test]
    fn parse_args_default_time_format_is_24h() {
        let raw_args = ["datetime"];
        let args = parse_args(&raw_args);
        assert_eq!(Ok(TimeFormat::H24), args.map(|args| args.time_format));
    }
}
