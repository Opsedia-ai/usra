// No Flutter imports: the PDF reports draw in a background isolate.

/// The mark as SVG, for the PDF reports. Same artwork as `UsraMarkPainter`,
/// with print colours: navy house, orchid heart with an orchid-ink edge so
/// it reads on white paper.
const usraMarkSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" '
    'viewBox="0 0 30 30">'
    '<path d="M4 14 L15 4.5 L26 14 V25.5 A1.5 1.5 0 0 1 24.5 27 H5.5 '
    'A1.5 1.5 0 0 1 4 25.5 Z" fill="none" stroke="#24405F" '
    'stroke-width="2.2" stroke-linejoin="round"/>'
    '<path d="M15 23 C9.5 19.2 9.6 14.6 12.3 14.2 C13.6 14 14.5 14.8 15 15.8 '
    'C15.5 14.8 16.4 14 17.7 14.2 C20.4 14.6 20.5 19.2 15 23 Z" '
    'fill="#C48CB3" stroke="#77405F" stroke-width="0.6" '
    'stroke-linejoin="round"/>'
    '</svg>';
