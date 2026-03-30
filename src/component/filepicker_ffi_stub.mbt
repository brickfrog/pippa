///|
#cfg(not(any(target="native", target="llvm")))
fn filepicker_read_dir_bytes(_path : String) -> Bytes? {
  None
}
