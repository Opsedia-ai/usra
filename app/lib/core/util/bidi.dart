/// Keeps [s] in left-to-right order inside Arabic text (a Unicode
/// left-to-right isolate). Without it "A+" shows as "+A" and "O-" as "-O"
/// in a right-to-left line, since the sign takes the line's direction.
String ltr(String s) => '\u2066$s\u2069';
