///|
fn object() -> Map[String, Json] {
  {}
}

///|
fn json_number(value : Double) -> Json {
  Json::number(value)
}

///|
fn json_string(value : String) -> Json {
  Json::string(value)
}

///|
fn json_position(lon : Double, lat : Double, alt : Double?) -> Json {
  let items = [json_number(lon), json_number(lat)]
  if alt is Some(value) {
    items.push(json_number(value))
  }
  Json::array(items)
}

///|
fn geo_point(position : Json) -> Json {
  Json::object({ "type": json_string("Point"), "coordinates": position })
}

///|
fn geo_line(positions : Array[Json]) -> Json {
  Json::object({
    "type": json_string("LineString"),
    "coordinates": Json::array(positions),
  })
}

///|
fn geo_multi_line(lines : Array[Json]) -> Json {
  Json::object({
    "type": json_string("MultiLineString"),
    "coordinates": Json::array(lines),
  })
}

///|
fn geo_polygon(rings : Array[Json]) -> Json {
  Json::object({
    "type": json_string("Polygon"),
    "coordinates": Json::array(rings),
  })
}

///|
fn feature(
  geometry : Json,
  properties : Map[String, Json],
  id? : String,
) -> Json {
  let fields = object()
  fields.set("type", json_string("Feature"))
  fields.set("geometry", geometry)
  fields.set("properties", Json::object(properties))
  if id is Some(value) {
    if value != "" {
      fields.set("id", json_string(value))
    }
  }
  Json::object(fields)
}

///|
fn feature_bbox(
  geometry : Json,
  properties : Map[String, Json],
  id : String?,
  bbox : Json?,
) -> Json {
  let fields = object()
  fields.set("type", json_string("Feature"))
  fields.set("geometry", geometry)
  fields.set("properties", Json::object(properties))
  if id is Some(value) {
    if value != "" {
      fields.set("id", json_string(value))
    }
  }
  if bbox is Some(value) {
    fields.set("bbox", value)
  }
  Json::object(fields)
}

///|
fn feature_collection(features : Array[Json]) -> Json {
  Json::object({
    "type": json_string("FeatureCollection"),
    "features": Json::array(features),
  })
}

///|
fn put_text_fields(
  properties : Map[String, Json],
  node : XmlNode,
  fields : Array[String],
) -> Unit {
  for field in fields {
    if node.value(field) is Some(value) {
      properties.set(field, json_string(value))
    }
  }
}
