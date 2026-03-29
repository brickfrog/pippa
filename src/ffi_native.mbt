///|
extern "C" fn pippa_enter_raw_mode() = "pippa_enter_raw_mode"

///|
extern "C" fn pippa_exit_raw_mode() = "pippa_exit_raw_mode"

///|
extern "C" fn pippa_read_byte() -> Int = "pippa_read_byte"

///|
extern "C" fn pippa_write_byte(b : Int) = "pippa_write_byte"

///|


///|
extern "C" fn pippa_get_rows() -> Int = "pippa_get_rows"

///|
extern "C" fn pippa_get_cols() -> Int = "pippa_get_cols"
