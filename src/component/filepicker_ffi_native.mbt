///|
#borrow(path_buf)
extern "C" fn pippa_filepicker_scan_open(
  path_buf : Bytes,
  path_len : Int,
) -> Int = "pippa_filepicker_scan_open"

///|
extern "C" fn pippa_filepicker_scan_next_size(
  handle : Int,
  max_entries : Int,
) -> Int = "pippa_filepicker_scan_next_size"

///|
#borrow(out_buf)
extern "C" fn pippa_filepicker_scan_next_fill(
  handle : Int,
  max_entries : Int,
  out_buf : Bytes,
  out_len : Int,
) -> Int = "pippa_filepicker_scan_next_fill"

///|
extern "C" fn pippa_filepicker_scan_close(handle : Int) -> Unit = "pippa_filepicker_scan_close"

///|
fn filepicker_open_scan(path : String) -> Int? {
  let path_buf = @utf8.encode(path[:])
  let handle = pippa_filepicker_scan_open(path_buf, path_buf.length())
  if handle > 0 {
    Some(handle)
  } else {
    None
  }
}

///|
fn filepicker_scan_next(
  path : String,
  handle : Int,
  max_entries : Int,
) -> Result[Array[FileEntry]?, String] {
  let size = pippa_filepicker_scan_next_size(handle, max_entries)
  if size < 0 {
    Err("failed to continue scanning directory: " + path)
  } else if size == 0 {
    Ok(None)
  } else {
    let out = Bytes::new(size)
    let written = pippa_filepicker_scan_next_fill(
      handle,
      max_entries,
      out,
      out.length(),
    )
    if written < 0 || written != size {
      Err("failed to read directory chunk: " + path)
    } else {
      Ok(Some(filepicker_parse_entries(path, out)))
    }
  }
}

///|
fn filepicker_close_scan(handle : Int) -> Unit {
  pippa_filepicker_scan_close(handle)
}
