///|
fn kml_coordinate(value : String) -> Json? {
  let pieces = value.trim().split(",").to_array()
  if pieces.length() < 2 {
    return None
  }
  match
    (parse_number(pieces[0].to_owned()), parse_number(pieces[1].to_owned())) {
    (Some(lon), Some(lat)) => {
      let alt = if pieces.length() > 2 {
        parse_number(pieces[2].to_owned())
      } else {
        None
      }
      Some(json_position(lon, lat, alt))
    }
    _ => None
  }
}

///|
fn kml_coordinates(value : String) -> Array[Json] {
  let normalized = value
    .replace(old="\n", new=" ")
    .replace(old="\r", new=" ")
    .replace(old="\t", new=" ")
  let positions : Array[Json] = []
  for part in normalized.split(" ") {
    if kml_coordinate(part.to_owned()) is Some(position) {
      positions.push(position)
    }
  }
  positions
}

///|
fn kml_ring(value : String) -> Json? {
  let positions = kml_coordinates(value)
  if positions.length() == 0 {
    return None
  }
  if positions[0] != positions[positions.length() - 1] {
    positions.push(positions[0])
  }
  if positions.length() >= 4 {
    Some(Json::array(positions))
  } else {
    None
  }
}

///|
fn kml_geometries(node : XmlNode, times : Array[Json]) -> Array[Json] {
  let result : Array[Json] = []
  for child in node.children {
    match local_name(child.name) {
      "MultiGeometry" | "MultiTrack" =>
        result.append(kml_geometries(child, times))
      "Point" =>
        if child.value("coordinates") is Some(raw) {
          if kml_coordinate(raw) is Some(position) {
            result.push(geo_point(position))
          }
        }
      "LineString" | "LinearRing" =>
        if child.value("coordinates") is Some(raw) {
          let positions = kml_coordinates(raw)
          if positions.length() >= 2 {
            result.push(geo_line(positions))
          }
        }
      "Polygon" => {
        let rings : Array[Json] = []
        for ring in child.descendants("LinearRing") {
          if ring.value("coordinates") is Some(raw) {
            if kml_ring(raw) is Some(value) {
              rings.push(value)
            }
          }
        }
        if !rings.is_empty() {
          result.push(geo_polygon(rings))
        }
      }
      "Track" => {
        let points : Array[Json] = []
        for coordinate in child.descendants("coord") {
          let normalized = coordinate.text
            .trim()
            .replace(old="\t", new=" ")
            .replace(old="\n", new=" ")
          let values = normalized
            .split(" ")
            .filter(part => !part.is_empty())
            .to_array()
          if values.length() >= 2 {
            match
              (
                parse_number(values[0].to_owned()),
                parse_number(values[1].to_owned()),
              ) {
              (Some(lon), Some(lat)) => {
                let alt = if values.length() > 2 {
                  parse_number(values[2].to_owned())
                } else {
                  None
                }
                points.push(json_position(lon, lat, alt))
              }
              _ => ()
            }
          }
        }
        if points.length() > 0 {
          result.push(
            if points.length() == 1 {
              geo_point(points[0])
            } else {
              geo_line(points)
            },
          )
          let track_times : Array[Json] = []
          for when in child.descendants("when") {
            track_times.push(json_string(when.text))
          }
          if !track_times.is_empty() {
            times.push(Json::array(track_times))
          }
        }
      }
      _ => ()
    }
  }
  result
}

///|
fn kml_geometry(node : XmlNode, times : Array[Json]) -> Json {
  let geometries = kml_geometries(node, times)
  if geometries.length() == 0 {
    Json::null()
  } else if geometries.length() == 1 {
    geometries[0]
  } else {
    Json::object({
      "type": json_string("GeometryCollection"),
      "geometries": Json::array(geometries),
    })
  }
}
