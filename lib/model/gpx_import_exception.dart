enum GpxImportIssue {
  tooLarge,
  invalidXml,
  unsupportedVersion,
  trackCount,
  segmentCount,
  invalidCoordinates,
  tooManyPoints,
  noTrackPoints,
  tooManyStops,
  invalidWaypoint,
}

class GpxImportException extends FormatException {
  const GpxImportException(this.issue, {this.count = 0, this.limit = 0})
      : super('Unsupported GPX data');

  final GpxImportIssue issue;
  final int count;
  final int limit;

  String userMessage({required bool english}) => switch (issue) {
        GpxImportIssue.tooLarge => english
            ? 'The GPX file is too large (maximum 4 MB).'
            : 'Die GPX-Datei ist zu groß (maximal 4 MB).',
        GpxImportIssue.invalidXml => english
            ? 'The GPX file is damaged or contains unsupported XML data.'
            : 'Die GPX-Datei ist beschädigt oder enthält nicht unterstützte XML-Daten.',
        GpxImportIssue.unsupportedVersion => english
            ? 'Please choose a GPX 1.1 file.'
            : 'Bitte eine GPX-1.1-Datei auswählen.',
        GpxImportIssue.trackCount => english
            ? 'The GPX file contains $count tracks. Exactly one track is supported.'
            : 'Die GPX-Datei enthält $count Tracks. Unterstützt wird genau ein Track.',
        GpxImportIssue.segmentCount => english
            ? 'The track contains $count segments. One continuous track is supported.'
            : 'Der Track enthält $count Teilstrecken. Unterstützt wird eine zusammenhängende Strecke.',
        GpxImportIssue.invalidCoordinates => english
            ? 'The track contains invalid GPS coordinates.'
            : 'Die Strecke enthält ungültige GPS-Koordinaten.',
        GpxImportIssue.tooManyPoints => english
            ? 'The track contains too many points (maximum $limit).'
            : 'Die Strecke enthält zu viele Trackpunkte (maximal $limit).',
        GpxImportIssue.noTrackPoints => english
            ? 'The GPX file does not contain a usable track.'
            : 'Die GPX-Datei enthält keine nutzbare Strecke.',
        GpxImportIssue.tooManyStops => english
            ? 'The GPX file contains $count intermediate stops. Up to $limit are supported.'
            : 'Die GPX-Datei enthält $count Zwischenziele. Unterstützt werden bis zu $limit.',
        GpxImportIssue.invalidWaypoint => english
            ? 'A GPX waypoint contains invalid coordinates or a name that is too long.'
            : 'Ein GPX-Zwischenziel enthält ungültige Koordinaten oder einen zu langen Namen.',
      };
}
