///|
test "public KML, GPX and TCX entry points" {
  let kml_result = @moontogeojson.kml(
    "<kml><Placemark><Point><coordinates>1,2</coordinates></Point></Placemark></kml>",
  )
  let gpx_result = @moontogeojson.gpx("<gpx><wpt lon='1' lat='2'/></gpx>")
  let tcx_result = @moontogeojson.tcx("<TrainingCenterDatabase/>")
  for result in [kml_result, gpx_result, tcx_result] {
    if result is Object(fields) {
      assert_eq(fields.get("type"), Some(Json::string("FeatureCollection")))
    } else {
      fail("expected GeoJSON object")
    }
  }
  let tree = @moontogeojson.kml_with_folders(
    "<kml><Folder><name>A</name></Folder></kml>",
  )
  if tree is Object(fields) {
    assert_eq(fields.get("type"), Some(Json::string("root")))
  } else {
    fail("expected folder root")
  }
  assert_eq(
    @moontogeojson.kml_gen("<kml><Placemark/></kml>").collect().length(),
    1,
  )
  assert_eq(
    @moontogeojson.gpx_gen("<gpx><wpt lon='1' lat='2'/></gpx>")
    .collect()
    .length(),
    1,
  )
  assert_eq(
    @moontogeojson.tcx_gen("<TrainingCenterDatabase/>").collect().length(),
    0,
  )
}

///|
test "public converters preserve non-ASCII text and feature geometry" {
  let kml = @moontogeojson.kml(
    "<kml><Placemark><name>北京😀</name><Point><coordinates>116.397,39.908</coordinates></Point></Placemark></kml>",
  )
  let gpx = @moontogeojson.gpx(
    "<gpx><wpt lon='1' lat='2'><name>路标😀</name></wpt></gpx>",
  )
  let tcx = @moontogeojson.tcx(
    "<TrainingCenterDatabase><Lap><Track><Trackpoint><Position><LongitudeDegrees>1</LongitudeDegrees><LatitudeDegrees>2</LatitudeDegrees></Position></Trackpoint><Trackpoint><Position><LongitudeDegrees>3</LongitudeDegrees><LatitudeDegrees>4</LatitudeDegrees></Position></Trackpoint></Track></Lap></TrainingCenterDatabase>",
  )
  for
    (document, expected_name, expected_geometry) in [
      (kml, "北京😀", "Point"),
      (gpx, "路标😀", "Point"),
      (tcx, "", "LineString"),
    ] {
    if document is Object(root) {
      if root.get("features") is Some(Array(features)) {
        assert_eq(features.length(), 1)
        if features[0] is Object(feature) {
          if feature.get("geometry") is Some(Object(geometry)) {
            assert_eq(
              geometry.get("type"),
              Some(Json::string(expected_geometry)),
            )
          } else {
            fail("missing geometry")
          }
          if expected_name != "" {
            if feature.get("properties") is Some(Object(properties)) {
              assert_eq(
                properties.get("name"),
                Some(Json::string(expected_name)),
              )
            } else {
              fail("missing properties")
            }
          }
        } else {
          fail("missing feature")
        }
      } else {
        fail("missing features")
      }
    } else {
      fail("missing collection")
    }
  }
}

///|
test "public converters reject malformed XML" {
  let mut errors = 0
  ignore(@moontogeojson.kml("<kml><Placemark></kml>")) catch {
    _ => errors += 1
  }
  ignore(@moontogeojson.gpx("<gpx><wpt></gpx>")) catch {
    _ => errors += 1
  }
  ignore(
    @moontogeojson.tcx("<TrainingCenterDatabase><Lap></TrainingCenterDatabase>"),
  ) catch {
    _ => errors += 1
  }
  assert_eq(errors, 3)
}
