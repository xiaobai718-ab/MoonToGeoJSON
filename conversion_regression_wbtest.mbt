///|
fn regression_field(value : Json, key : String) -> Json raise {
  guard value is Object(fields) else { fail("Expected object for " + key) }
  guard fields.get(key) is Some(found) else { fail("Missing field " + key) }
  found
}

///|
test "prefixed KML folders keep Unicode names and descriptions" {
  let default_ns = "<kml xmlns=\"http://www.opengis.net/kml/2.2\"><Folder><name>路线🚀</name><description>说明</description><Placemark><Point><coordinates>1,2</coordinates></Point></Placemark></Folder></kml>"
  let prefixed = "<k:kml xmlns:k=\"http://www.opengis.net/kml/2.2\"><k:Folder><k:name>路线🚀</k:name><k:description>说明</k:description><k:Placemark><k:Point><k:coordinates>1,2</k:coordinates></k:Point></k:Placemark></k:Folder></k:kml>"
  let actual = kml_with_folders(prefixed, skip_null_geometry=true)
  assert_eq(actual, kml_with_folders(default_ns, skip_null_geometry=true))
  guard regression_field(actual, "children") is Array([folder]) else {
    fail("Expected one folder")
  }
  assert_eq(
    regression_field(folder, "meta"),
    @json.parse("{\"name\":\"路线🚀\",\"description\":\"说明\"}"),
  )
}

///|
test "KML SchemaData uses the schema referenced by each placemark" {
  let source = "<kml xmlns=\"http://www.opengis.net/kml/2.2\"><Document><Schema id=\"numeric\"><SimpleField name=\"value\" type=\"int\"/></Schema><Schema id=\"text\"><SimpleField name=\"value\" type=\"string\"/></Schema><Placemark><ExtendedData><SchemaData schemaUrl=\"#numeric\"><SimpleData name=\"value\">42</SimpleData></SchemaData></ExtendedData><Point><coordinates>1,2</coordinates></Point></Placemark><Placemark><ExtendedData><SchemaData schemaUrl=\"#text\"><SimpleData name=\"value\">42</SimpleData></SchemaData></ExtendedData><Point><coordinates>1,2</coordinates></Point></Placemark><Placemark><ExtendedData><SchemaData schemaUrl=\"#unknown\"><SimpleData name=\"value\">42</SimpleData></SchemaData></ExtendedData><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>"
  let features = kml_gen(source).collect()
  assert_eq(features.length(), 3)
  for
    index, expected in [
      Json::number(42.0),
      Json::string("42"),
      Json::string("42"),
    ] {
    assert_eq(
      regression_field(regression_field(features[index], "properties"), "value"),
      expected,
    )
  }
}

///|
test "GPX aligns nullable times and extensions with retained coordinates" {
  let source = "<gpx xmlns=\"http://www.topografix.com/GPX/1/1\" xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\" version=\"1.1\" creator=\"Audit\"><trk><trkseg><trkpt lon=\"1\" lat=\"2\"></trkpt><trkpt lon=\"3\" lat=\"4\"></trkpt></trkseg><trkseg><trkpt lon=\"5\" lat=\"6\"><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>110</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt><trkpt lon=\"bad\" lat=\"8\"><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>999</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt><trkpt lon=\"9\" lat=\"10\"><time>2026-01-01T00:00:04Z</time><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>123</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt></trkseg></trk></gpx>"
  guard regression_field(gpx(source), "features") is Array([track]) else {
    fail("Expected a GPX track")
  }
  assert_eq(
    regression_field(regression_field(track, "geometry"), "coordinates"),
    @json.parse("[[[1,2],[3,4]],[[5,6],[9,10]]]"),
  )
  assert_eq(
    regression_field(
      regression_field(track, "properties"),
      "coordinateProperties",
    ),
    @json.parse(
      "{\"times\":[[null,null],[null,\"2026-01-01T00:00:04Z\"]],\"heart\":[[null,null],[110,123]]}",
    ),
  )
}

///|
test "GPX core namespace prefixes do not create extension properties" {
  let source = "<g:gpx xmlns:g='http://www.topografix.com/GPX/1/1' xmlns:x='urn:audit' version='1.1' creator='Audit'><g:wpt lon='1' lat='2'><g:ele>0</g:ele><g:name>路标🚀</g:name><g:extensions><x:rating>3</x:rating></g:extensions></g:wpt></g:gpx>"
  guard regression_field(gpx(source), "features") is Array([waypoint]) else {
    fail("Expected one GPX waypoint")
  }
  assert_eq(
    regression_field(waypoint, "properties"),
    @json.parse("{\"name\":\"路标🚀\",\"x_rating\":\"3\"}"),
  )
}

///|
test "TCX aligns sparse heart rates cadence and times across tracks" {
  let source = "<TrainingCenterDatabase xmlns=\"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2\"><Activities><Activity Sport=\"Biking\"><Id>2026-01-01T00:00:00Z</Id><Lap StartTime=\"2026-01-01T00:00:00Z\"><TotalTimeSeconds>4</TotalTimeSeconds><DistanceMeters>10</DistanceMeters><Calories>0</Calories><Intensity>Active</Intensity><TriggerMethod>Manual</TriggerMethod><Track><Trackpoint><Time>2026-01-01T00:00:00Z</Time><Position><LatitudeDegrees>2</LatitudeDegrees><LongitudeDegrees>1</LongitudeDegrees></Position></Trackpoint><Trackpoint><Time>2026-01-01T00:00:01Z</Time><Position><LatitudeDegrees>4</LatitudeDegrees><LongitudeDegrees>3</LongitudeDegrees></Position></Trackpoint></Track><Track><Trackpoint><Time>2026-01-01T00:00:02Z</Time><Position><LatitudeDegrees>6</LatitudeDegrees><LongitudeDegrees>5</LongitudeDegrees></Position></Trackpoint><Trackpoint><Time>2026-01-01T00:00:03Z</Time><HeartRateBpm><Value>99</Value></HeartRateBpm><Cadence>99</Cadence></Trackpoint><Trackpoint><Time>2026-01-01T00:00:04Z</Time><Position><LatitudeDegrees>10</LatitudeDegrees><LongitudeDegrees>9</LongitudeDegrees></Position><HeartRateBpm><Value>123</Value></HeartRateBpm><Cadence>81</Cadence><Extensions><ae:heartRate xmlns:ae=\"http://www.garmin.com/xmlschemas/ActivityExtension/v2\">124</ae:heartRate></Extensions></Trackpoint></Track></Lap></Activity></Activities></TrainingCenterDatabase>"
  guard regression_field(tcx(source), "features") is Array([lap]) else {
    fail("Expected a TCX lap")
  }
  assert_eq(
    regression_field(regression_field(lap, "geometry"), "coordinates"),
    @json.parse("[[[1,2],[3,4]],[[5,6],[9,10]]]"),
  )
  let props = regression_field(lap, "properties")
  assert_eq(
    regression_field(props, "cadences"),
    @json.parse("[[null,null],[null,81]]"),
  )
  assert_eq(
    regression_field(props, "heartRates"),
    @json.parse("[[null,null],[null,124]]"),
  )
  assert_eq(
    regression_field(props, "coordinateProperties"),
    @json.parse(
      "{\"times\":[[\"2026-01-01T00:00:00Z\",\"2026-01-01T00:00:01Z\"],[\"2026-01-01T00:00:02Z\",\"2026-01-01T00:00:04Z\"]],\"heart\":[[null,null],[null,123]]}",
    ),
  )
}
