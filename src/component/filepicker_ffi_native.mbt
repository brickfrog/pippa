///|
#borrow(path_buf)
extern "C" fn pippa_filepicker_read_dir_size(
  path_buf : Bytes,
  path_len : Int,
) -> Int = "pippa_filepicker_read_dir_size"

///|
#borrow(path_buf, out_buf)
extern "C" fn pippa_filepicker_read_dir_fill(
  path_buf : Bytes,
  path_len : Int,
  out_buf : Bytes,
  out_len : Int,
) -> Int = "pippa_filepicker_read_dir_fill"

///|
fn filepicker_read_dir_bytes(path : String) -> Bytes? {
  let path_buf = @utf8.encode(path[:])
  let size = pippa_filepicker_read_dir_size(path_buf, path_buf.length())
  if size < 0 {
    return None
  }
  let out = Bytes::new(size)
  if size == 0 {
    return Some(out)
  }
  let written = pippa_filepicker_read_dir_fill(
    path_buf,
    path_buf.length(),
    out,
    out.length(),
  )
  if written < 0 || written != size {
    None
  } else {
    Some(out)
  }
}
