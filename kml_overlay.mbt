///|
fn kml_rotate_position(
  x : Double,
  y : Double,
  cx : Double,
  cy : Double,
  angle : Double,
) -> Json {
  let dx = x - cx
  let dy = y - cy
  let distance = (@math.pow(dy, 2.0) + @math.pow(dx, 2.0)).sqrt()
  let radians = @math.atan2(dy, dx) + angle * (3.141592653589793 / 180.0)
  json_position(
    cx + @math.cos(radians) * distance,
    cy + @math.sin(radians) * distance,
    None,
  )
}

///|
fn kml_box(box : XmlNode) -> (Json, Json)? {
  match
    (
      box.number("west"),
      box.number("south"),
      box.number("east"),
      box.number("north"),
    ) {
    (Some(west), Some(south), Some(east), Some(north)) => {
      let cx = (west + east) / 2.0
      let cy = (south + north) / 2.0
      let angle = box.number("rotation").unwrap_or(0.0)
      let ring = [
        kml_rotate_position(west, north, cx, cy, angle),
        kml_rotate_position(east, north, cx, cy, angle),
        kml_rotate_position(east, south, cx, cy, angle),
        kml_rotate_position(west, south, cx, cy, angle),
        kml_rotate_position(west, north, cx, cy, angle),
      ]
      let bbox = Json::array([
        json_number(west),
        json_number(south),
        json_number(east),
        json_number(north),
      ])
      Some((geo_polygon([Json::array(ring)]), bbox))
    }
    _ => None
  }
}

///|
fn kml_ground_overlay(
  node : XmlNode,
  styles : Map[String, Map[String, Json]],
  schema : Map[String, String],
  skip_null_geometry : Bool,
) -> Json? {
  let mut geometry = Json::null()
  let mut bbox : Json? = None
  if node.first("LatLonQuad") is Some(quad) {
    if quad.value("coordinates") is Some(raw) {
      if kml_ring(raw) is Some(ring) {
        geometry = geo_polygon([ring])
      }
    }
  } else if node.first("LatLonBox") is Some(box) {
    if kml_box(box) is Some((shape, bounds)) {
      geometry = shape
      bbox = Some(bounds)
    }
  }
  if geometry == Json::null() && skip_null_geometry {
    return None
  }
  let properties = kml_properties(node, styles, schema)
  properties.set("@geometry-type", json_string("groundoverlay"))
  if node.value("href") is Some(href) {
    properties.set("icon", json_string(href))
  }
  Some(feature_bbox(geometry, properties, node.attr("id"), bbox))
}

///|
fn kml_network_link(
  node : XmlNode,
  styles : Map[String, Map[String, Json]],
  schema : Map[String, String],
  skip_null_geometry : Bool,
) -> Json? {
  let mut geometry = Json::null()
  let mut bbox : Json? = None
  if node.first("LatLonAltBox") is Some(box) {
    if kml_box(box) is Some((shape, bounds)) {
      geometry = shape
      bbox = Some(bounds)
    }
  }
  if geometry == Json::null() && skip_null_geometry {
    return None
  }
  let properties = kml_properties(node, styles, schema)
  properties.set("@geometry-type", json_string("networklink"))
  put_text_fields(properties, node, ["refreshVisibility", "flyToView"])
  if node.first("Link") is Some(link) {
    put_text_fields(properties, link, [
      "href", "refreshMode", "refreshInterval", "viewRefreshMode", "viewRefreshTime",
      "viewBoundScale", "viewFormat", "httpQuery",
    ])
  }
  if node.first("Lod") is Some(lod) {
    let values : Array[Json] = []
    values.push(json_number(lod.number("minLodPixels").unwrap_or(-1.0)))
    values.push(json_number(lod.number("maxLodPixels").unwrap_or(-1.0)))
    for field in ["minFadeExtent", "maxFadeExtent"] {
      match lod.number(field) {
        Some(number) => values.push(json_number(number))
        None => values.push(Json::null())
      }
    }
    properties.set("lod", Json::array(values))
  }
  Some(feature_bbox(geometry, properties, node.attr("id"), bbox))
}

///|
fn kml_folder_children(
  node : XmlNode,
  styles : Map[String, Map[String, Json]],
  schema : Map[String, String],
  skip_null_geometry : Bool,
) -> Array[Json] {
  let result : Array[Json] = []
  for child in node.children {
    match local_name(child.name) {
      "Folder" => {
        let meta = object()
        for field in child.children {
          match field.name {
            "name"
            | "visibility"
            | "open"
            | "address"
            | "description"
            | "phoneNumber" =>
              meta.set(field.name, json_string(field.text_content()))
            _ => ()
          }
        }
        result.push(
          Json::object({
            "type": json_string("folder"),
            "meta": Json::object(meta),
            "children": Json::array(
              kml_folder_children(child, styles, schema, skip_null_geometry),
            ),
          }),
        )
      }
      "Placemark" =>
        if kml_placemark(child, styles, schema, skip_null_geometry)
          is Some(value) {
          result.push(value)
        }
      "GroundOverlay" =>
        if kml_ground_overlay(child, styles, schema, skip_null_geometry)
          is Some(value) {
          result.push(value)
        }
      "NetworkLink" =>
        if kml_network_link(child, styles, schema, skip_null_geometry)
          is Some(value) {
          result.push(value)
        }
      _ =>
        result.append(
          kml_folder_children(child, styles, schema, skip_null_geometry),
        )
    }
  }
  result
}

///|
/// Preserve the KML Folder hierarchy in a root object.
pub fn kml_with_folders(
  source : String,
  skip_null_geometry~ : Bool = false,
) -> Json raise {
  let document = parse_xml(source)
  let styles = kml_style_map(document)
  let schema = kml_schema(document)
  Json::object({
    "type": json_string("root"),
    "children": Json::array(
      kml_folder_children(document, styles, schema, skip_null_geometry),
    ),
  })
}
