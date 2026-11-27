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
  for child in node.all_descendants() {
    if child.name.split_once(":") is Some((_, _)) &&
      child.namespace_uri != Some("http://www.topografix.com/GPX/1/1") &&
      child.namespace_uri != Some("http://www.topografix.com/GPX/1/0") {
      properties.set(
        child.name.replace(old=":", new="_"),
        json_string(child.text_content().trim().to_owned()),
      )
    }
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
) -> (Array[Json], Map[String, Json]) {
  let positions : Array[Json] = []
  let samples : Array[Map[String, Json]] = []
  for point in node.descendants(tag) {
    if gpx_position(point) is Some(position) {
      positions.push(position)
      let values = gpx_extension_values(point)
      if point.value("time") is Some(value) && value != "" {
        values.set("times", json_string(value))
      }
      samples.push(values)
    }
  }
  (positions, track_columns(samples))
}

///|
fn gpx_track(node : XmlNode) -> Json? {
  let lines : Array[Json] = []
  let columns : Array[Map[String, Json]] = []
  for segment in node.descendants("trkseg") {
    let (positions, values) = gpx_line_points(segment, "trkpt")
    if positions.length() >= 2 {
      lines.push(Json::array(positions))
      columns.push(values)
    }
  }
  if lines.is_empty() {
    return None
  }
  let properties = gpx_properties(node)
  properties.set("_gpxType", json_string("trk"))
  properties.set(
    "coordinateProperties",
    Json::object(merge_track_columns(lines, columns)),
  )
  let geometry = if lines.length() == 1 {
    Json::object({ "type": json_string("LineString"), "coordinates": lines[0] })
  } else {
    geo_multi_line(lines)
  }
  Some(feature(geometry, properties))
}

///|
fn gpx_route(node : XmlNode) -> Json? {
  let (positions, _) = gpx_line_points(node, "rtept")
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
    Some(position) => {
      let properties = gpx_properties(node)
      if node.value("sym") is Some(value) {
        if value != "" {
          properties.set("sym", json_string(value))
        }
      }
      Some(feature(geo_point(position), properties))
    }
    None => None
  }
}

///|
/// Convert a GPX document to a GeoJSON FeatureCollection. Tracks precede
/// routes, which precede waypoints, matching @tmcw/togeojson 7.1.3.
pub fn gpx(source : String) -> Json raise {
  feature_collection(gpx_gen(source).collect())
}
