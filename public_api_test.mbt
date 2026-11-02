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
