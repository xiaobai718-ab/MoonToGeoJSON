///|
/// Iterate over KML features in upstream order: Placemarks, GroundOverlays,
/// then NetworkLinks. XML is parsed once; features are converted on demand.
pub fn kml_gen(
  source : String,
  skip_null_geometry~ : Bool = false,
) -> Iter[Json] raise {
  let document = parse_xml(source)
  let styles = kml_style_map(document)
  let schema = kml_schema(document)
  let nodes : Array[(Int32, XmlNode)] = []
  for node in document.descendants("Placemark") {
    nodes.push((0, node))
  }
  for node in document.descendants("GroundOverlay") {
    nodes.push((1, node))
  }
  for node in document.descendants("NetworkLink") {
    nodes.push((2, node))
  }
  let mut index = 0
  Iter::new(fn() {
    while index < nodes.length() {
      let (kind, node) = nodes[index]
      index += 1
      let value = match kind {
        0 => kml_placemark(node, styles, schema, skip_null_geometry)
        1 => kml_ground_overlay(node, styles, schema, skip_null_geometry)
        _ => kml_network_link(node, styles, schema, skip_null_geometry)
      }
      if value is Some(feature) {
        return Some(feature)
      }
    }
    None
  })
}

///|
/// Iterate over GPX features: tracks, routes, then waypoints.
pub fn gpx_gen(source : String) -> Iter[Json] raise {
  let document = parse_xml(source)
  let nodes : Array[(Int32, XmlNode)] = []
  for node in document.descendants("trk") {
    nodes.push((0, node))
  }
  for node in document.descendants("rte") {
    nodes.push((1, node))
  }
  for node in document.descendants("wpt") {
    nodes.push((2, node))
  }
  let mut index = 0
  Iter::new(fn() {
    while index < nodes.length() {
      let (kind, node) = nodes[index]
      index += 1
      let value = match kind {
        0 => gpx_track(node)
        1 => gpx_route(node)
        _ => gpx_waypoint(node)
      }
      if value is Some(feature) {
        return Some(feature)
      }
    }
    None
  })
}

///|
/// Iterate over TCX features: laps, then courses.
pub fn tcx_gen(source : String) -> Iter[Json] raise {
  let document = parse_xml(source)
  let nodes : Array[XmlNode] = []
  nodes.append(document.descendants("Lap"))
  nodes.append(document.descendants("Courses"))
  let mut index = 0
  Iter::new(fn() {
    while index < nodes.length() {
      let node = nodes[index]
      index += 1
      if tcx_lap(node) is Some(feature) {
        return Some(feature)
      }
    }
    None
  })
}
