///|
#cfg(not(any(target="native", target="llvm")))
fn filepicker_open_scan(_path : String) -> Int? {
  None
}

///|
#cfg(not(any(target="native", target="llvm")))
fn filepicker_scan_next(
  _path : String,
  _handle : Int,
  _max_entries : Int,
) -> Result[Array[FileEntry]?, String] {
  Err("filepicker scanning is unavailable on this target")
}

///|
#cfg(not(any(target="native", target="llvm")))
fn filepicker_close_scan(_handle : Int) -> Unit {

}
