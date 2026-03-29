///|
extern "C" fn pippa_enter_raw_mode() = "pippa_enter_raw_mode"

///|
extern "C" fn pippa_install_sigwinch() -> Unit = "pippa_install_sigwinch"

///|
extern "C" fn pippa_check_resize() -> Int = "pippa_check_resize"

///|
extern "C" fn pippa_exit_raw_mode() = "pippa_exit_raw_mode"

///|
extern "C" fn pippa_read_byte() -> Int = "pippa_read_byte"

///|
extern "C" fn pippa_poll_stdin(timeout_ms : Int) -> Int = "pippa_poll_stdin"

///|
extern "C" fn pippa_now_ms() -> Int64 = "pippa_now_ms"

///|
extern "C" fn pippa_write_byte(b : Int) = "pippa_write_byte"

///|
extern "C" fn pippa_get_rows() -> Int = "pippa_get_rows"

///|
extern "C" fn pippa_get_cols() -> Int = "pippa_get_cols"
