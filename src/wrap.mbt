///|
/// ANSI- and grapheme-aware word wrapping utilities.

///|
fn wrap_write_chars(
  buf : StringBuilder,
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> Unit {
  for i in start..<end_index {
    buf.write_char(chars[i])
  }
}

///|
fn wrap_chars_to_string(
  chars : Array[Char],
  start : Int,
  end_index : Int,
) -> String {
  let n = chars.length()
  let from = start.max(0).min(n)
  let to = end_index.max(from).min(n)
  let buf = StringBuilder::new(size_hint=to - from)
  wrap_write_chars(buf, chars, from, to)
  buf.to_string()
}

///|
fn wrap_is_csi_terminator(ch : Char) -> Bool {
  ch >= '@' && ch <= '~'
}

///|
fn wrap_skip_ansi_sequence(chars : Array[Char], start : Int) -> Int {
  let n = chars.length()
  let mut i = start + 1
  if i < n {
    let next = chars[i]
    i = i + 1
    if next == '[' {
      while i < n && !wrap_is_csi_terminator(chars[i]) {
        i = i + 1
      }
      if i < n {
        i = i + 1
      }
    }
  }
  i
}

///|
fn wrap_cluster_first_text_char(cluster : String) -> Char? {
  let chars = cluster.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\u001b' {
      i = wrap_skip_ansi_sequence(chars, i)
    } else {
      return Some(chars[i])
    }
  }
  None
}

///|
fn wrap_is_space_cluster(cluster : String) -> Bool {
  match wrap_cluster_first_text_char(cluster) {
    Some(ch) => ch == ' '
    None => false
  }
}

///|
fn wrap_clusters(line : String) -> (Array[String], Array[Int], Array[Bool]) {
  let chars = line.to_array()
  let boundaries = @internal.grapheme_boundaries(line)
  let clusters : Array[String] = []
  let widths : Array[Int] = []
  let spaces : Array[Bool] = []
  for i in 0..<(boundaries.length() - 1) {
    let cluster = wrap_chars_to_string(chars, boundaries[i], boundaries[i + 1])
    clusters.push(cluster)
    widths.push(visible_width(cluster))
    spaces.push(wrap_is_space_cluster(cluster))
  }
  let last_boundary = boundaries[boundaries.length() - 1]
  if last_boundary < chars.length() {
    clusters.push(wrap_chars_to_string(chars, last_boundary, chars.length()))
    widths.push(0)
    spaces.push(false)
  }
  (clusters, widths, spaces)
}

///|
fn wrap_write_clusters(
  buf : StringBuilder,
  clusters : Array[String],
  start : Int,
  end_index : Int,
) -> Unit {
  for i in start..<end_index {
    buf.write_string(clusters[i])
  }
}

///|
fn wrap_write_ansi_sequences(buf : StringBuilder, cluster : String) -> Unit {
  let chars = cluster.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\u001b' {
      let next = wrap_skip_ansi_sequence(chars, i)
      wrap_write_chars(buf, chars, i, next)
      i = next
    } else {
      i = i + 1
    }
  }
}

///|
fn wrap_write_ansi_sequences_from_clusters(
  buf : StringBuilder,
  clusters : Array[String],
  start : Int,
  end_index : Int,
) -> Unit {
  for i in start..<end_index {
    wrap_write_ansi_sequences(buf, clusters[i])
  }
}

///|
fn wrap_new_line(
  lines : Array[String],
  current : StringBuilder,
) -> StringBuilder {
  lines.push(current.to_string())
  StringBuilder::new()
}

///|
fn wrap_line_by_words(line : String, width : Int) -> String {
  let (clusters, widths, spaces) = wrap_clusters(line)
  if clusters.length() == 0 {
    return line
  }
  let lines : Array[String] = []
  let mut current = StringBuilder::new(size_hint=line.to_array().length())
  let mut current_width = 0
  let mut index = 0
  while index < clusters.length() {
    let space_start = index
    let mut space_width = 0
    while index < clusters.length() && spaces[index] {
      space_width = space_width + widths[index]
      index = index + 1
    }
    let word_start = index
    let mut word_width = 0
    while index < clusters.length() && !spaces[index] {
      word_width = word_width + widths[index]
      index = index + 1
    }
    if word_start == index {
      if current_width + space_width <= width {
        wrap_write_clusters(current, clusters, space_start, index)
        current_width = current_width + space_width
      } else {
        wrap_write_ansi_sequences_from_clusters(
          current, clusters, space_start, index,
        )
      }
      continue
    }
    if space_start < word_start {
      if current_width == 0 {
        if space_width + word_width <= width {
          wrap_write_clusters(current, clusters, space_start, word_start)
          current_width = current_width + space_width
        } else {
          wrap_write_ansi_sequences_from_clusters(
            current, clusters, space_start, word_start,
          )
        }
      } else if current_width + space_width + word_width <= width {
        wrap_write_clusters(current, clusters, space_start, word_start)
        current_width = current_width + space_width
      } else {
        wrap_write_ansi_sequences_from_clusters(
          current, clusters, space_start, word_start,
        )
        current = wrap_new_line(lines, current)
        current_width = 0
      }
    }
    if word_width <= width - current_width {
      wrap_write_clusters(current, clusters, word_start, index)
      current_width = current_width + word_width
    } else {
      if current_width > 0 {
        current = wrap_new_line(lines, current)
        current_width = 0
      }
      let mut word_index = word_start
      while word_index < index {
        let cluster_width = widths[word_index]
        if current_width >= width && cluster_width > 0 {
          current = wrap_new_line(lines, current)
          current_width = 0
        } else if current_width > 0 &&
          cluster_width > 0 &&
          current_width + cluster_width > width {
          current = wrap_new_line(lines, current)
          current_width = 0
        }
        current.write_string(clusters[word_index])
        current_width = current_width + cluster_width
        word_index = word_index + 1
        if current_width >= width && word_index < index {
          current = wrap_new_line(lines, current)
          current_width = 0
        }
      }
    }
  }
  lines.push(current.to_string())
  @internal.join_lines(lines)
}

///|
/// Wrap text to `width` visible terminal cells at word boundaries.
///
/// CSI and bare two-byte ESC sequences follow `visible_width`'s zero-width
/// escape handling, and printable text is walked on
/// `@internal.grapheme_boundaries`, so hard breaks never split a grapheme
/// cluster. Newlines already present in `text` delimit independent paragraphs.
/// A non-positive `width` returns `text` unchanged.
pub fn word_wrap(text : String, width : Int) -> String {
  if width <= 0 {
    return text
  }
  let lines : Array[String] = []
  for line in split_lines(text) {
    lines.push(wrap_line_by_words(line, width))
  }
  @internal.join_lines(lines)
}
