#[cfg(not(windows))]
compile_error!("herdr-fast-paste currently supports Windows only");

use std::ffi::c_void;
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

type Handle = *mut c_void;

#[link(name = "user32")]
unsafe extern "system" {
    fn OpenClipboard(owner: Handle) -> i32;
    fn CloseClipboard() -> i32;
    fn GetClipboardData(format: u32) -> Handle;
}

#[link(name = "kernel32")]
unsafe extern "system" {
    fn GlobalLock(memory: Handle) -> *mut c_void;
    fn GlobalUnlock(memory: Handle) -> i32;
}

const CF_UNICODETEXT: u32 = 13;

struct ClipboardGuard;

impl Drop for ClipboardGuard {
    fn drop(&mut self) {
        unsafe { CloseClipboard() };
    }
}

fn clipboard_text() -> Result<String, String> {
    for _ in 0..20 {
        if unsafe { OpenClipboard(std::ptr::null_mut()) } != 0 {
            let _guard = ClipboardGuard;
            return unsafe {
                let handle = GetClipboardData(CF_UNICODETEXT);
                if handle.is_null() {
                    return Err("clipboard does not contain Unicode text".into());
                }
                let ptr = GlobalLock(handle) as *const u16;
                if ptr.is_null() {
                    return Err("failed to lock clipboard data".into());
                }
                let mut len = 0usize;
                while *ptr.add(len) != 0 {
                    len += 1;
                }
                let text = String::from_utf16_lossy(std::slice::from_raw_parts(ptr, len));
                GlobalUnlock(handle);
                Ok(text)
            };
        }
        thread::sleep(Duration::from_millis(5));
    }
    Err("clipboard remained busy for 100 ms".into())
}

fn json_string_field(json: &str, field: &str) -> Option<String> {
    let marker = format!("\"{field}\":\"");
    let start = json.find(&marker)? + marker.len();
    let end = json[start..].find('"')? + start;
    Some(json[start..end].to_owned())
}

fn current_pane_id() -> Result<String, String> {
    let output = Command::new("herdr.exe")
        .args(["pane", "current"])
        .output()
        .map_err(|error| format!("failed to run `herdr pane current`: {error}"))?;
    if !output.status.success() {
        return Err(String::from_utf8_lossy(&output.stderr).trim().to_owned());
    }
    json_string_field(&String::from_utf8_lossy(&output.stdout), "pane_id")
        .ok_or_else(|| "pane_id missing from Herdr response".into())
}

fn run(check_only: bool) -> Result<(), String> {
    let clipboard = clipboard_text()?;
    let pane_id = current_pane_id()?;
    if check_only {
        println!("ok pane={pane_id} clipboard_utf8_bytes={}", clipboard.len());
        return Ok(());
    }

    if clipboard.encode_utf16().count() > 24_000 {
        return Err("clipboard text is too large for a safe Windows command-line transfer".into());
    }
    if !pane_id
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b':' | b'_' | b'-'))
    {
        return Err("Herdr returned an invalid pane_id".into());
    }

    // Tell the nested TUI that this is one paste, not a burst of key presses.
    let payload = format!("\x1b[200~{clipboard}\x1b[201~");
    let status = Command::new("herdr.exe")
        .args(["pane", "send-text", &pane_id, &payload])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|error| format!("failed to run `herdr pane send-text`: {error}"))?;
    status
        .success()
        .then_some(())
        .ok_or_else(|| format!("herdr pane send-text exited with {status}"))
}

fn main() {
    let check_only = std::env::args().any(|arg| arg == "--check");
    if let Err(error) = run(check_only) {
        eprintln!("herdr-fast-paste: {error}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::json_string_field;

    #[test]
    fn extracts_pane_id() {
        let json = r#"{"result":{"pane":{"pane_id":"wT:p2"}}}"#;
        assert_eq!(json_string_field(json, "pane_id").as_deref(), Some("wT:p2"));
    }

    #[test]
    fn missing_field_is_none() {
        assert_eq!(json_string_field("{}", "pane_id"), None);
    }
}
