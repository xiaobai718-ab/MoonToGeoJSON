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
/// Only emit fields with at least one value. Each column follows the
/// retained positions and uses null where a measurement is absent.
fn track_columns(samples : Array[Map[String, Json]]) -> Map[String, Json] {
  let columns : Map[String, Array[Json]] = Map([])
  for index, sample in samples {
    for key, value in sample {
      let column = match columns.get(key) {
        Some(column) => column
        None => {
          let column = Array::make(samples.length(), Json::null())
          columns.set(key, column)
          column
        }
      }
      column[index] = value
    }
  }
  let result = object()
  for key, column in columns {
    result.set(key, Json::array(column))
  }
  result
}

///|
fn merge_track_columns(
  lines : Array[Json],
  columns : Array[Map[String, Json]],
) -> Map[String, Json] {
  let result = object()
  if lines.length() == 1 {
    return columns[0]
  }
  for segment in columns {
    for key, _ in segment {
      if result.get(key) is None {
        let values = []
        for index, line in lines {
          let value = match (columns[index].get(key), line) {
            (Some(value), _) => value
            (None, Array(points)) =>
              Json::array(Array::make(points.length(), Json::null()))
            _ => Json::array([])
          }
          values.push(value)
        }
        result.set(key, Json::array(values))
      }
    }
  }
  result
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
      if value != "" {
        properties.set(field, json_string(value))
      }
    }
  }
}
