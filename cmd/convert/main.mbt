///|
/// Convert one local file to GeoJSON on stdout.
/// Usage: moon run cmd/convert --target native -- kml|gpx|tcx|kml-folders file
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
  if args.length() < 3 {
    raise InvalidInput(
      "Usage: moontogeojson kml|gpx|tcx|kml-folders|kml-folders-skip FILE",
    )
  }
  if args[1] != "kml" &&
    args[1] != "gpx" &&
    args[1] != "tcx" &&
    args[1] != "kml-folders" &&
    args[1] != "kml-folders-skip" {
    raise InvalidInput("Unknown format: " + args[1])
  }
  let source = @fs.read_file(args[2]).text() catch {
    err =>
      raise InvalidInput(
        "Could not read input file: " + args[2] + ": " + err.to_string(),
      )
  }
  let output = convert(args[1], source) catch {
    err => raise InvalidInput("Conversion failed: " + err.to_string())
  }
  println(output.stringify())
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
