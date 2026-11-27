///|
fn tcx_position(node : XmlNode) -> Json? {
  match node.first("Position") {
    Some(position) =>
      match
        (
          position.number("LongitudeDegrees"),
          position.number("LatitudeDegrees"),
        ) {
        (Some(lon), Some(lat)) =>
          Some(json_position(lon, lat, node.number("AltitudeMeters")))
        _ => None
      }
    None => None
  }
}

///|
fn tcx_track(node : XmlNode) -> (Array[Json], Map[String, Json]) {
  let positions : Array[Json] = []
  let samples : Array[Map[String, Json]] = []
  for point in node.descendants("Trackpoint") {
    if tcx_position(point) is Some(position) {
      positions.push(position)
      let values = object()
      if point.value("Time") is Some(value) && value != "" {
        values.set("times", json_string(value))
      }
      if point.first("HeartRateBpm") is Some(heart) {
        if heart.number("Value") is Some(value) {
          values.set("heart", json_number(value))
        }
      }
      for
        (tag, field) in [
          ("heartRate", "heartRates"),
          ("Cadence", "cadences"),
          ("Speed", "speeds"),
          ("Watts", "watts"),
        ] {
        if point.number(tag) is Some(value) {
          values.set(field, json_number(value))
        }
      }
      samples.push(values)
    }
  }
  (positions, track_columns(samples))
}

///|
fn tcx_lap(node : XmlNode) -> Json? {
  let lines : Array[Json] = []
  let columns : Array[Map[String, Json]] = []
  for track in node.descendants("Track") {
    let (positions, values) = tcx_track(track)
    if positions.length() >= 2 {
      lines.push(Json::array(positions))
      columns.push(values)
    }
  }
  if lines.is_empty() {
    return None
  }
  let properties = object()
  if node.value("Name") is Some(value) {
    properties.set("name", json_string(value))
  }
  for
    (key, output_name) in [
      ("TotalTimeSeconds", "totalTimeSeconds"),
      ("DistanceMeters", "distanceMeters"),
      ("MaximumSpeed", "maxSpeed"),
      ("AverageHeartRateBpm", "avgHeartRate"),
      ("MaximumHeartRateBpm", "maxHeartRate"),
      ("AvgSpeed", "avgSpeed"),
      ("AvgWatts", "avgWatts"),
      ("MaxWatts", "maxWatts"),
    ] {
    if node.number(key) is Some(value) {
      properties.set(output_name, json_number(value))
    }
  }
  let coordinate_properties = object()
  for field, values in merge_track_columns(lines, columns) {
    if field == "times" || field == "heart" {
      coordinate_properties.set(field, values)
    } else {
      properties.set(field, values)
    }
  }
  if !coordinate_properties.is_empty() {
    properties.set("coordinateProperties", Json::object(coordinate_properties))
  }
  let geometry = if lines.length() == 1 {
    Json::object({ "type": json_string("LineString"), "coordinates": lines[0] })
  } else {
    geo_multi_line(lines)
  }
  Some(feature(geometry, properties))
}

///|
/// Convert a Garmin Training Center XML document to GeoJSON.
pub fn tcx(source : String) -> Json raise {
  feature_collection(tcx_gen(source).collect())
}
