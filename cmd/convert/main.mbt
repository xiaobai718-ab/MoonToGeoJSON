///|
/// Convert one local file to GeoJSON on stdout.
/// Usage: moon run cmd/convert --target native -- [kml|gpx|tcx|kml-folders] file
suberror CliError {
  InvalidInput(String)
} derive(Debug)

///|
impl Show for CliError with fn output(self, logger) {
  let InvalidInput(message) = self
  logger <+ "\{message}"
}

///|
async fn main {
  let args = @env.args()
  if args.length() < 2 || args.length() > 3 {
    raise InvalidInput(
      "Usage: moontogeojson [kml|gpx|tcx|kml-folders|kml-folders-skip] FILE",
    )
  }
  let (kind, file) = if args.length() == 2 {
    (infer_format(args[1]), args[1])
  } else {
    (args[1], args[2])
  }
  if kind != "kml" &&
    kind != "gpx" &&
    kind != "tcx" &&
    kind != "kml-folders" &&
    kind != "kml-folders-skip" {
    raise InvalidInput("Unknown format: " + kind)
  }
  let source = @fs.read_file(file).text() catch {
    err =>
      raise InvalidInput(
        "Could not read input file: " + file + ": " + err.to_string(),
      )
  }
  let output = convert(kind, source) catch {
    err => raise InvalidInput("Conversion failed: " + err.to_string())
  }
  println(output.stringify())
}

///|
fn infer_format(file : String) -> String raise {
  let lower = file.to_lower()
  if lower.has_suffix(".kml") {
    return "kml"
  }
  if lower.has_suffix(".gpx") {
    return "gpx"
  }
  if lower.has_suffix(".tcx") {
    return "tcx"
  }
  raise InvalidInput("Cannot infer format from file extension: " + file)
}

///|
fn convert(kind : String, source : String) -> Json raise {
  match kind {
    "kml" => @lib.kml(source)
    "gpx" => @lib.gpx(source)
    "tcx" => @lib.tcx(source)
    "kml-folders" => @lib.kml_with_folders(source)
    "kml-folders-skip" => @lib.kml_with_folders(source, skip_null_geometry=true)
    _ => Json::null()
  }
}
