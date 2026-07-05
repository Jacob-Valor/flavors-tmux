use std::borrow::Cow;
use std::path::Path;
use std::process::Command;

#[derive(Debug)]
pub enum GitCommandError {
    Io(std::io::Error),
    NonZeroExit,
}

impl From<std::io::Error> for GitCommandError {
    fn from(value: std::io::Error) -> Self {
        Self::Io(value)
    }
}

pub fn run_git_command(argv: &[&str], cwd: Option<&Path>) -> Result<Vec<u8>, GitCommandError> {
    let Some((program, args)) = argv.split_first() else {
        return Err(GitCommandError::NonZeroExit);
    };
    let mut command = Command::new(program);
    command.args(args);
    if let Some(path) = cwd {
        command.current_dir(path);
    }
    let output = command.output()?;
    if !output.status.success() {
        return Err(GitCommandError::NonZeroExit);
    }
    Ok(output.stdout)
}

pub fn trim_branch_name(branch: &str) -> Cow<'_, str> {
    if branch.len() <= 25 {
        Cow::Borrowed(branch)
    } else {
        Cow::Owned(format!("{}...", &branch[..25]))
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct PorcelainStatus {
    pub changed: usize,
    pub untracked: usize,
}

pub fn parse_porcelain(stdout: &str) -> PorcelainStatus {
    let mut changed = 0;
    let mut untracked = 0;

    for line in stdout.lines() {
        let bytes = line.as_bytes();
        if bytes.len() < 2 {
            continue;
        }
        match (bytes[0], bytes[1]) {
            (b'?', b'?') | (b' ', b'?') => untracked += 1,
            (b'M' | b'A' | b'D' | b'R' | b'C' | b'U', _) | (_, b'M' | b'A' | b'D') => changed += 1,
            _ => {}
        }
    }

    PorcelainStatus { changed, untracked }
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct ParsedStatusV2 {
    pub branch: Option<String>,
    pub ahead: usize,
    pub behind: usize,
    pub changed: usize,
    pub untracked: usize,
    pub conflicts: usize,
    pub stashes: usize,
}

fn parse_signed_count(rest: &str, marker: char) -> usize {
    let Some(start) = rest.find(marker) else {
        return 0;
    };
    // Parse digits directly from bytes — no intermediate String allocation.
    rest[start + marker.len_utf8()..]
        .bytes()
        .take_while(|b| b.is_ascii_digit())
        .fold(0usize, |acc, d| acc.wrapping_mul(10).wrapping_add((d - b'0') as usize))
}

pub fn parse_porcelain_v2(stdout: &str) -> ParsedStatusV2 {
    let mut result = ParsedStatusV2::default();

    for line in stdout.lines().filter(|line| !line.is_empty()) {
        if let Some(name) = line.strip_prefix("# branch.head ") {
            if name != "(detached)" {
                result.branch = Some(name.to_owned());
            }
        } else if let Some(rest) = line.strip_prefix("# branch.ab ") {
            result.ahead = parse_signed_count(rest, '+');
            result.behind = parse_signed_count(rest, '-');
        } else if let Some(rest) = line.strip_prefix("# stash ") {
            result.stashes = rest.trim().parse::<usize>().unwrap_or(0);
        } else if line.starts_with('1') || line.starts_with('2') {
            if line.len() >= 4 && &line[2..4] != ".." {
                result.changed += 1;
            }
        } else if line.starts_with('?') {
            result.untracked += 1;
        } else if line.starts_with('u') {
            result.conflicts += 1;
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_porcelain_counts_changed_and_untracked() {
        let output = " M src/main.rs\n?? build.rs\nA  src/new.rs\n?? README.md\n D src/old.rs\n";
        let result = parse_porcelain(output);
        assert_eq!(3, result.changed);
        assert_eq!(2, result.untracked);
    }

    #[test]
    fn parse_porcelain_ignores_empty_and_short_lines() {
        let output = "\nM\n ?? file.txt\n\n";
        let result = parse_porcelain(output);
        assert_eq!(0, result.changed);
        assert_eq!(1, result.untracked);
    }

    #[test]
    fn parse_porcelain_returns_zero_for_clean_repo() {
        let result = parse_porcelain("");
        assert_eq!(0, result.changed);
        assert_eq!(0, result.untracked);
    }

    #[test]
    fn parse_porcelain_v2_extracts_branch_and_counts() {
        let output = "# branch.oid deadbeef\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +2 -1\n1 .M N... 100644 100644 100644 abc def src/main.rs\n1 M. N... 100644 100644 100644 abc def src/lib.rs\n? new_file.txt\n? another.txt\nu UU N... 100644 100644 100644 abc def conflict.rs\n";
        let result = parse_porcelain_v2(output);
        assert_eq!(Some("main".to_owned()), result.branch);
        assert_eq!(2, result.ahead);
        assert_eq!(1, result.behind);
        assert_eq!(2, result.changed);
        assert_eq!(2, result.untracked);
        assert_eq!(1, result.conflicts);
    }

    #[test]
    fn parse_porcelain_v2_handles_detached_head() {
        let result = parse_porcelain_v2("# branch.head (detached)\n# branch.ab +0 -0\n");
        assert_eq!(None, result.branch);
    }

    #[test]
    fn parse_porcelain_v2_handles_clean_repo() {
        let result = parse_porcelain_v2("# branch.head dev\n# branch.ab +0 -0\n");
        assert_eq!(Some("dev".to_owned()), result.branch);
        assert_eq!(0, result.ahead);
        assert_eq!(0, result.changed);
        assert_eq!(0, result.untracked);
    }

    #[test]
    fn parse_porcelain_v2_extracts_stash_count_from_header() {
        let output = "# branch.head main\n# branch.ab +0 -0\n# stash 5\n1 .M N... 100644 100644 100644 abc def src/main.rs\n1 M. N... 100644 100644 100644 abc def src/lib.rs\n";
        let result = parse_porcelain_v2(output);
        assert_eq!(Some("main".to_owned()), result.branch);
        assert_eq!(0, result.ahead);
        assert_eq!(0, result.behind);
        assert_eq!(2, result.changed);
        assert_eq!(0, result.untracked);
        assert_eq!(0, result.conflicts);
        assert_eq!(5, result.stashes);
    }

    #[test]
    fn parse_porcelain_v2_handles_empty_stash_count() {
        let result = parse_porcelain_v2("# branch.head main\n# branch.ab +0 -0\n");
        assert_eq!(Some("main".to_owned()), result.branch);
        assert_eq!(0, result.ahead);
        assert_eq!(0, result.behind);
        assert_eq!(0, result.changed);
        assert_eq!(0, result.untracked);
        assert_eq!(0, result.conflicts);
        assert_eq!(0, result.stashes);
    }

    #[test]
    fn parse_porcelain_v2_ignores_no_change_entries() {
        let output = "# branch.head main\n# branch.ab +0 -0\n1 .. N... 100644 100644 100644 abc def unchanged.rs\n1 .M N... 100644 100644 100644 abc def changed.rs\n";
        let result = parse_porcelain_v2(output);
        assert_eq!(1, result.changed);
    }
}
