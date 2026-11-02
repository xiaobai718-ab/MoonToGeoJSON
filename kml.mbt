///|
fn kml_color(
  properties : Map[String, Json],
  raw : String,
  prefix : String,
) -> Unit {
  let value = if raw.has_prefix("#") { raw[1:].to_owned() } else { raw }
  let key = if prefix == "stroke" || prefix == "fill" {
    prefix
  } else {
    prefix + "-color"
  }
  if value.length() == 3 || value.length() == 6 {
    properties.set(key, json_string("#" + value))
  } else if value.length() == 8 {
    let alpha = @string.parse_int(value[0:2], base=16) catch { _ => return }
    properties.set(prefix + "-opacity", json_number(alpha.to_double() / 255.0))
    properties.set(
      key,
      json_string(
        "#" +
        value[6:8].to_owned() +
        value[4:6].to_owned() +
        value[2:4].to_owned(),
      ),
    )
  }
}

///|
fn kml_style(node : XmlNode) -> Map[String, Json] {
  let properties = object()
  for
    (tag, prefix) in [
      ("PolyStyle", "fill"),
      ("LineStyle", "stroke"),
      ("LabelStyle", "label"),
      ("IconStyle", "icon"),
    ] {
    if node.first(tag) is Some(style) {
      if style.value("color") is Some(color) {
        kml_color(properties, color, prefix)
      }
      if tag == "LineStyle" && style.number("width") is Some(width) {
        properties.set("stroke-width", json_number(width))
      }
      if (tag == "LabelStyle" || tag == "IconStyle") &&
        style.number("scale") is Some(scale) {
        properties.set(prefix + "-scale", json_number(scale))
      }
      if tag == "IconStyle" {
        if style.number("heading") is Some(heading) {
          properties.set("icon-heading", json_number(heading))
        }
        if style.value("href") is Some(href) {
          properties.set("icon", json_string(href))
        }
      }
      if tag == "PolyStyle" {
        if style.value("fill") is Some("0") {
          properties.set("fill-opacity", json_number(0.0))
        }
        if style.value("outline") is Some("0") {
          properties.set("stroke-opacity", json_number(0.0))
        }
      }
    }
  }
  properties
}

///|
fn kml_style_map(document : XmlNode) -> Map[String, Map[String, Json]] {
  let styles : Map[String, Map[String, Json]] = Map([])
  for node in document.descendants("Style") {
    if node.attr("id") is Some(id) {
      styles.set("#" + id, kml_style(node))
    }
  }
  for node in document.descendants("StyleMap") {
    if node.attr("id") is Some(id) {
      if node.value("styleUrl") is Some(url) {
        let key = if url.has_prefix("#") { url } else { "#" + url }
        if styles.get(key) is Some(style) {
          styles.set("#" + id, style)
        }
      }
    }
  }
  styles
}

///|
fn kml_properties(
  node : XmlNode,
  styles : Map[String, Map[String, Json]],
) -> Map[String, Json] {
  let properties = object()
  put_text_fields(properties, node, [
    "name", "address", "open", "phoneNumber", "description",
  ])
  if node.value("visibility") is Some(value) {
    properties.set("visibility", Json::boolean(value != "0"))
  }
  if node.first("description") is Some(description) {
    if description.has_cdata {
      properties.set(
        "description",
        Json::object({
          "@type": json_string("html"),
          "value": json_string(description.text),
        }),
      )
    }
  }
  if node.value("styleUrl") is Some(url) {
    let key = if url.has_prefix("#") { url } else { "#" + url }
    properties.set("styleUrl", json_string(key))
    if styles.get(key) is Some(style) {
      for name, value in style {
        properties.set(name, value)
      }
    }
  }
  if node.first("Style") is Some(inline_style) {
    for name, value in kml_style(inline_style) {
      properties.set(name, value)
    }
  }
  if node.first("ExtendedData") is Some(extended) {
    for data in extended.descendants("Data") {
      if data.attr("name") is Some(name) {
        if data.value("value") is Some(value) {
          properties.set(name, json_string(value))
        }
      }
    }
    for data in extended.descendants("SimpleData") {
      if data.attr("name") is Some(name) {
        properties.set(name, json_string(data.text))
      }
    }
  }
  if node.first("TimeSpan") is Some(span) {
    let fields = object()
    fields.set("begin", json_string(span.value("begin").unwrap_or("")))
    fields.set("end", json_string(span.value("end").unwrap_or("")))
    properties.set("timespan", Json::object(fields))
  }
  if node.first("TimeStamp") is Some(stamp) {
    properties.set("timestamp", json_string(stamp.value("when").unwrap_or("")))
  }
  properties
}

///|
fn kml_placemark(
  node : XmlNode,
  styles : Map[String, Map[String, Json]],
  skip_null_geometry : Bool,
) -> Json? {
  let times : Array[Json] = []
  let geometry = kml_geometry(node, times)
  if geometry == Json::null() && skip_null_geometry {
    return None
  }
  let properties = kml_properties(node, styles)
  if !times.is_empty() {
    let value = if times.length() == 1 { times[0] } else { Json::array(times) }
    properties.set("coordinateProperties", Json::object({ "times": value }))
  }
  Some(
    match node.attr("id") {
      Some(id) => feature(geometry, properties, id~)
      None => feature(geometry, properties)
    },
  )
}

///|
/// Convert KML Placemarks to a GeoJSON FeatureCollection. Null geometries are
/// retained by default, matching the upstream library.
pub fn kml(source : String, skip_null_geometry~ : Bool = false) -> Json raise {
  let document = parse_xml(source)
  let styles = kml_style_map(document)
  let features : Array[Json] = []
  for placemark in document.descendants("Placemark") {
    if kml_placemark(placemark, styles, skip_null_geometry) is Some(value) {
      features.push(value)
    }
  }
  for overlay in document.descendants("GroundOverlay") {
    if kml_ground_overlay(overlay, styles, skip_null_geometry) is Some(value) {
      features.push(value)
    }
  }
  for link in document.descendants("NetworkLink") {
    if kml_network_link(link, styles, skip_null_geometry) is Some(value) {
      features.push(value)
    }
  }
  feature_collection(features)
}
