///|
extern "C" fn pippa_enter_raw_mode() = "pippa_enter_raw_mode"

///|
extern "C" fn pippa_check_resize() -> Int = "pippa_check_resize"

///|
extern "C" fn pippa_exit_raw_mode() = "pippa_exit_raw_mode"

///|
extern "C" fn pippa_read_byte() -> Int = "pippa_read_byte"

///|
extern "C" fn pippa_init_wakeup() -> Unit = "pippa_init_wakeup"

///|
extern "C" fn pippa_close_wakeup() -> Unit = "pippa_close_wakeup"

///|
extern "C" fn pippa_signal_wakeup() -> Unit = "pippa_signal_wakeup"

///|
extern "C" fn pippa_drain_wakeup() -> Unit = "pippa_drain_wakeup"

///|
extern "C" fn pippa_poll_events(timeout_ms : Int, include_stdin : Int) -> Int = "pippa_poll_events"

///|
extern "C" fn pippa_now_ms() -> Int64 = "pippa_now_ms"

///|
#borrow(buf)
extern "C" fn pippa_write_bytes(buf : Bytes, len : Int) -> Unit = "pippa_write_bytes"

///|
extern "C" fn pippa_get_rows() -> Int = "pippa_get_rows"

///|
extern "C" fn pippa_get_cols() -> Int = "pippa_get_cols"
