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
fn tcx_track(
  node : XmlNode,
) -> (Array[Json], Array[Json], Array[Json], Map[String, Json]) {
  let positions : Array[Json] = []
  let times : Array[Json] = []
  let hearts : Array[Json] = []
  let extended : Map[String, Array[Json]] = Map([])
  let points = node.descendants("Trackpoint")
  for index, point in points {
    if tcx_position(point) is Some(position) {
      positions.push(position)
      if point.value("Time") is Some(value) {
        times.push(json_string(value))
      }
      if point.number("Value") is Some(value) {
        hearts.push(json_number(value))
      }
      for
        (tag, field) in [
          ("Cadence", "cadences"),
          ("Speed", "speeds"),
          ("Watts", "watts"),
        ] {
        if point.number(tag) is Some(value) {
          if extended.get(field) is None {
            let blank : Array[Json] = []
            for _ in points {
              blank.push(Json::null())
            }
            extended.set(field, blank)
          }
          if extended.get(field) is Some(items) {
            items[index] = json_number(value)
          }
        }
      }
    }
  }
  let extended_json = object()
  for field, values in extended {
    extended_json.set(field, Json::array(values))
  }
  (positions, times, hearts, extended_json)
}

///|
fn tcx_lap(node : XmlNode) -> Json? {
  let lines : Array[Json] = []
  let all_times : Array[Json] = []
  let all_hearts : Array[Json] = []
  let all_extended : Array[Map[String, Json]] = []
  for track in node.descendants("Track") {
    let (positions, times, hearts, extended) = tcx_track(track)
    if positions.length() >= 2 {
      lines.push(Json::array(positions))
      all_extended.push(extended)
      if !times.is_empty() {
        all_times.push(Json::array(times))
      }
      if !hearts.is_empty() {
        all_hearts.push(Json::array(hearts))
      }
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
  for extended in all_extended {
    for field, value in extended {
      if lines.length() == 1 {
        properties.set(field, value)
      } else if properties.get(field) is None {
        let segments : Array[Json] = []
        for index in 0..<all_extended.length() {
          match all_extended[index].get(field) {
            Some(items) => segments.push(items)
            None => {
              let blank : Array[Json] = []
              if lines[index] is Array(points) {
                for _ in points {
                  blank.push(Json::null())
                }
              }
              segments.push(Json::array(blank))
            }
          }
        }
        properties.set(field, Json::array(segments))
      }
    }
  }
  if !all_times.is_empty() || !all_hearts.is_empty() {
    let coordinate_properties = object()
    if !all_times.is_empty() {
      let values = if lines.length() == 1 {
        all_times[0]
      } else {
        Json::array(all_times)
      }
      coordinate_properties.set("times", values)
    }
    if !all_hearts.is_empty() {
      let values = if lines.length() == 1 {
        all_hearts[0]
      } else {
        Json::array(all_hearts)
      }
      coordinate_properties.set("heart", values)
    }
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
  let document = parse_xml(source)
  let features : Array[Json] = []
  for lap in document.descendants("Lap") {
    if tcx_lap(lap) is Some(value) {
      features.push(value)
    }
  }
  for courses in document.descendants("Courses") {
    if tcx_lap(courses) is Some(value) {
      features.push(value)
    }
  }
  feature_collection(features)
}
