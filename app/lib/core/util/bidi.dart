/// Keeps [s] in left-to-right order inside Arabic text (a Unicode
/// left-to-right isolate). Without it "A+" shows as "+A" and "O-" as "-O"
/// in a right-to-left line, since the sign takes the line's direction.
String ltr(String s) => '\u2066$s\u2069';

/// Keeps [s] (a person's name, typed in any script) in one piece inside
/// text of the other direction: a first-strong isolate. Without it
/// "منى · 22 weeks" shows as "22 · منى weeks" in English.
String isolate(String s) => '\u2068$s\u2069';
