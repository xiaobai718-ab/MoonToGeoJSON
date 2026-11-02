///|
/// Convert one local file to GeoJSON on stdout.
/// Usage: moon run cmd/convert --target native -- kml|gpx|tcx|kml-folders file
async fn main {
  let args = @env.args()
  if args.length() < 3 {
    println("Usage: moontogeojson kml|gpx|tcx|kml-folders FILE")
    return
  }
  let source = @fs.read_file(args[2]).text() catch {
    _ => {
      println("Could not read input file")
      return
    }
  }
  if args[1] != "kml" &&
    args[1] != "gpx" &&
    args[1] != "tcx" &&
    args[1] != "kml-folders" &&
    args[1] != "kml-folders-skip" {
    println("Unknown format: " + args[1])
    return
  }
  let output = convert(args[1], source) catch {
    _ => {
      println("Invalid XML")
      return
    }
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
