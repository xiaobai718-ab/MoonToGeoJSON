///|
fn gpx_position(node : XmlNode) -> Json? {
  let lon = node.attribute_number("lon")
  let lat = node.attribute_number("lat")
  match (lon, lat) {
    (Some(lon), Some(lat)) => Some(json_position(lon, lat, node.number("ele")))
    _ => None
  }
}

///|
fn gpx_properties(node : XmlNode) -> Map[String, Json] {
  let properties = object()
  put_text_fields(properties, node, [
    "name", "cmt", "desc", "type", "time", "keywords",
  ])
  if node.value("sym") is Some(value) {
    properties.set("sym", json_string(value))
  }
  let links = []
  for link in node.descendants("link") {
    let fields = object()
    if link.attr("href") is Some(href) {
      fields.set("href", json_string(href))
    }
    put_text_fields(fields, link, ["text", "type"])
    links.push(Json::object(fields))
  }
  if links.length() > 0 {
    properties.set("links", Json::array(links))
  }
  if node.first("extensions") is Some(extensions) {
    if extensions.first("line") is Some(line) {
      if line.value("color") is Some(color) {
        properties.set("stroke", json_string("#" + color))
      }
      if line.number("opacity") is Some(opacity) {
        properties.set("stroke-opacity", json_number(opacity))
      }
      if line.number("width") is Some(width) {
        properties.set("stroke-width", json_number(width * 96.0 / 25.4))
      }
    }
  }
  properties
}

///|
fn gpx_extension_values(point : XmlNode) -> Map[String, Json] {
  let values = object()
  if point.first("extensions") is Some(extensions) {
    for child in extensions.children {
      let nodes = if local_name(child.name) == "TrackPointExtension" {
        child.children
      } else {
        [child]
      }
      for item in nodes {
        let name = if local_name(item.name) == "hr" ||
          local_name(item.name) == "heart" {
          "heart"
        } else {
          item.name
        }
        let key = if name == "heart" {
          "heart"
        } else if name.has_prefix("gpxtpx:") {
          name[7:].to_owned() + "s"
        } else {
          name + "s"
        }
        let value = item.text_content()
        values.set(
          key,
          match parse_number(value) {
            Some(number) => json_number(number)
            None => json_string(value)
          },
        )
      }
    }
  }
  values
}

///|
fn gpx_line_points(
  node : XmlNode,
  tag : String,
) -> (Array[Json], Array[Json], Map[String, Json]) {
  let positions : Array[Json] = []
  let times : Array[Json] = []
  let extended : Map[String, Array[Json]] = Map([])
  let points = node.descendants(tag)
  for index, point in points {
    match gpx_position(point) {
      Some(position) => {
        positions.push(position)
        if point.value("time") is Some(value) {
          times.push(json_string(value))
        }
        for key, value in gpx_extension_values(point) {
          if extended.get(key) is None {
            let blank : Array[Json] = []
            for _ in 0..<points.length() {
              blank.push(Json::null())
            }
            extended.set(key, blank)
          }
          if extended.get(key) is Some(items) {
            items[index] = value
          }
        }
      }
      None => ()
    }
  }
  let coordinate_properties = object()
  for key, values in extended {
    coordinate_properties.set(key, Json::array(values))
  }
  (positions, times, coordinate_properties)
}

///|
fn gpx_track(node : XmlNode) -> Json? {
  let lines : Array[Json] = []
  let all_times : Array[Json] = []
  let all_extended : Array[Map[String, Json]] = []
  for segment in node.descendants("trkseg") {
    let (positions, times, extended) = gpx_line_points(segment, "trkpt")
    if positions.length() >= 2 {
      lines.push(Json::array(positions))
      all_extended.push(extended)
      if times.length() > 0 {
        all_times.push(Json::array(times))
      }
    }
  }
  if lines.is_empty() {
    return None
  }
  let properties = gpx_properties(node)
  properties.set("_gpxType", json_string("trk"))
  let coordinate_properties = object()
  if !all_times.is_empty() {
    let time_value = if lines.length() == 1 {
      all_times[0]
    } else {
      Json::array(all_times)
    }
    coordinate_properties.set("times", time_value)
  }
  for extended in all_extended {
    for key, value in extended {
      if lines.length() == 1 {
        coordinate_properties.set(key, value)
      } else if coordinate_properties.get(key) is None {
        let segments : Array[Json] = []
        for segment_index in 0..<all_extended.length() {
          match all_extended[segment_index].get(key) {
            Some(items) => segments.push(items)
            None => {
              let blank : Array[Json] = []
              if lines[segment_index] is Array(points) {
                for _ in points {
                  blank.push(Json::null())
                }
              }
              segments.push(Json::array(blank))
            }
          }
        }
        coordinate_properties.set(key, Json::array(segments))
      }
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
fn gpx_route(node : XmlNode) -> Json? {
  let (positions, _, _) = gpx_line_points(node, "rtept")
  if positions.length() < 2 {
    return None
  }
  let properties = gpx_properties(node)
  properties.set("_gpxType", json_string("rte"))
  Some(feature(geo_line(positions), properties))
}

///|
fn gpx_waypoint(node : XmlNode) -> Json? {
  match gpx_position(node) {
    Some(position) => Some(feature(geo_point(position), gpx_properties(node)))
    None => None
  }
}

///|
/// Convert a GPX document to a GeoJSON FeatureCollection. Tracks precede
/// routes, which precede waypoints, matching @tmcw/togeojson 7.1.3.
pub fn gpx(source : String) -> Json raise {
  let document = parse_xml(source)
  let features : Array[Json] = []
  for node in document.descendants("trk") {
    if gpx_track(node) is Some(value) {
      features.push(value)
    }
  }
  for node in document.descendants("rte") {
    if gpx_route(node) is Some(value) {
      features.push(value)
    }
  }
  for node in document.descendants("wpt") {
    if gpx_waypoint(node) is Some(value) {
      features.push(value)
    }
  }
  feature_collection(features)
}
