///|
test "KML point, id and null geometry" {
  let source = "<kml><Document><Placemark id='a'><name>Home</name><Point><coordinates>12.5,34.5,8</coordinates></Point></Placemark><Placemark><name>Empty</name></Placemark></Document></kml>"
  let result = kml(source)
  let expected = @json.parse(
    "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"id\":\"a\",\"properties\":{\"name\":\"Home\"},\"geometry\":{\"type\":\"Point\",\"coordinates\":[12.5,34.5,8]}},{\"type\":\"Feature\",\"properties\":{\"name\":\"Empty\"},\"geometry\":null}]}",
  )
  assert_eq(result, expected)
  let skipped = kml(source, skip_null_geometry=true)
  if skipped is Object(fields) {
    if fields.get("features") is Some(Array(features)) {
      assert_eq(features.length(), 1)
    } else {
      fail("features missing")
    }
  } else {
    fail("collection missing")
  }
}

///|
test "KML polygon ring closure and folders" {
  let source = "<kml><Folder><name>Area</name><Placemark><Polygon><outerBoundaryIs><LinearRing><coordinates>0,0 1,0 1,1 0,1</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark></Folder></kml>"
  let tree = kml_with_folders(source)
  if tree is Object(root) {
    if root.get("children") is Some(Array(children)) {
      assert_eq(children.length(), 1)
      if children[0] is Object(folder) {
        assert_eq(folder.get("type"), Some(json_string("folder")))
      } else {
        fail("folder missing")
      }
    } else {
      fail("children missing")
    }
  } else {
    fail("root missing")
  }
  let collection = kml(source)
  if collection is Object(fields) {
    if fields.get("features") is Some(Array(features)) {
      if features[0] is Object(item) {
        if item.get("geometry") is Some(Object(geometry)) {
          assert_eq(geometry.get("type"), Some(json_string("Polygon")))
        } else {
          fail("polygon missing")
        }
      }
    }
  }
}

///|
test "GPX track, route and waypoint ordering" {
  let source = "<gpx><wpt lon='5' lat='6'><name>W</name></wpt><rte><rtept lon='1' lat='2'/><rtept lon='3' lat='4'/></rte><trk><trkseg><trkpt lon='7' lat='8'><time>T1</time></trkpt><trkpt lon='9' lat='10'><time>T2</time></trkpt></trkseg></trk></gpx>"
  let result = gpx(source)
  if result is Object(fields) {
    if fields.get("features") is Some(Array(features)) {
      assert_eq(features.length(), 3)
      if features[0] is Object(track) {
        if track.get("properties") is Some(Object(properties)) {
          assert_eq(properties.get("_gpxType"), Some(json_string("trk")))
        }
      }
      if features[1] is Object(route) {
        if route.get("properties") is Some(Object(properties)) {
          assert_eq(properties.get("_gpxType"), Some(json_string("rte")))
        }
      }
    } else {
      fail("features missing")
    }
  } else {
    fail("collection missing")
  }
}

///|
test "TCX lap with metrics" {
  let source = "<TrainingCenterDatabase><Lap><TotalTimeSeconds>60</TotalTimeSeconds><Track><Trackpoint><Position><LatitudeDegrees>2</LatitudeDegrees><LongitudeDegrees>1</LongitudeDegrees></Position><AltitudeMeters>5</AltitudeMeters></Trackpoint><Trackpoint><Position><LatitudeDegrees>4</LatitudeDegrees><LongitudeDegrees>3</LongitudeDegrees></Position></Trackpoint></Track></Lap></TrainingCenterDatabase>"
  let result = tcx(source)
  if result is Object(fields) {
    if fields.get("features") is Some(Array(features)) {
      assert_eq(features.length(), 1)
      if features[0] is Object(item) {
        if item.get("properties") is Some(Object(properties)) {
          assert_eq(properties.get("totalTimeSeconds"), Some(json_number(60.0)))
        }
      }
    }
  }
}

///|
test "KML GroundOverlay and NetworkLink" {
  let source = "<kml><GroundOverlay id='o'><name>Image</name><Icon><href>image.png</href></Icon><LatLonBox><west>1</west><south>2</south><east>3</east><north>4</north></LatLonBox></GroundOverlay><NetworkLink><Link><href>next.kml</href></Link></NetworkLink></kml>"
  let result = kml(source)
  if result is Object(root) {
    if root.get("features") is Some(Array(features)) {
      assert_eq(features.length(), 2)
      if features[0] is Object(overlay) {
        assert_eq(overlay.get("bbox"), Some(@json.parse("[1,2,3,4]")))
        if overlay.get("properties") is Some(Object(properties)) {
          assert_eq(
            properties.get("@geometry-type"),
            Some(json_string("groundoverlay")),
          )
          assert_eq(properties.get("icon"), Some(json_string("image.png")))
        }
      }
      if features[1] is Object(link) {
        if link.get("properties") is Some(Object(properties)) {
          assert_eq(properties.get("href"), Some(json_string("next.kml")))
        }
      }
    } else {
      fail("features missing")
    }
  }
}

///|
test "GPX trackpoint extension arrays" {
  let source = "<gpx><trk><trkseg><trkpt lon='1' lat='2'><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>101</gpxtpx:hr><gpxtpx:cad>60</gpxtpx:cad></gpxtpx:TrackPointExtension></extensions></trkpt><trkpt lon='3' lat='4'><extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>102</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions></trkpt></trkseg></trk></gpx>"
  let result = gpx(source)
  if result is Object(root) {
    if root.get("features") is Some(Array(features)) {
      if features[0] is Object(item) {
        if item.get("properties") is Some(Object(properties)) {
          if properties.get("coordinateProperties") is Some(Object(coordinates)) {
            assert_eq(coordinates.get("heart"), Some(@json.parse("[101,102]")))
            assert_eq(coordinates.get("cads"), Some(@json.parse("[60,null]")))
          } else {
            fail("coordinate properties missing")
          }
        }
      }
    }
  }
}

///|
test "TCX extended arrays" {
  let source = "<TrainingCenterDatabase><Lap><Track><Trackpoint><Position><LatitudeDegrees>2</LatitudeDegrees><LongitudeDegrees>1</LongitudeDegrees></Position><Cadence>60</Cadence><Extensions><TPX><Speed>4.5</Speed><Watts>100</Watts></TPX></Extensions></Trackpoint><Trackpoint><Position><LatitudeDegrees>4</LatitudeDegrees><LongitudeDegrees>3</LongitudeDegrees></Position><Cadence>61</Cadence></Trackpoint></Track></Lap></TrainingCenterDatabase>"
  let result = tcx(source)
  if result is Object(root) {
    if root.get("features") is Some(Array(features)) {
      if features[0] is Object(item) {
        if item.get("properties") is Some(Object(properties)) {
          assert_eq(properties.get("cadences"), Some(@json.parse("[60,61]")))
          assert_eq(properties.get("speeds"), Some(@json.parse("[4.5,null]")))
          assert_eq(properties.get("watts"), Some(@json.parse("[100,null]")))
        }
      }
    }
  }
}

///|
test "KML schema typing and icon hotspot" {
  let source = "<kml><Document><Schema><SimpleField name='elevation' type='double'/><SimpleField name='open' type='bool'/></Schema><Placemark><Style><IconStyle><hotSpot x='3' y='4' xunits='pixels' yunits='insetPixels'/></IconStyle></Style><ExtendedData><SchemaData><SimpleData name='elevation'>12.5</SimpleData><SimpleData name='open'>false</SimpleData></SchemaData></ExtendedData><Point><coordinates>1,2</coordinates></Point></Placemark></Document></kml>"
  let result = kml(source)
  if result is Object(root) {
    if root.get("features") is Some(Array(features)) {
      if features[0] is Object(item) {
        if item.get("properties") is Some(Object(properties)) {
          assert_eq(properties.get("elevation"), Some(json_number(12.5)))
          assert_eq(properties.get("open"), Some(Json::boolean(true)))
          assert_eq(properties.get("icon-offset"), Some(@json.parse("[3,4]")))
          assert_eq(
            properties.get("icon-offset-units"),
            Some(@json.parse("[\"pixels\",\"insetPixels\"]")),
          )
        }
      }
    }
  }
}

///|
test "KML rotated overlay changes polygon coordinates" {
  let normal = kml(
    "<kml><GroundOverlay><LatLonBox><west>0</west><south>0</south><east>2</east><north>2</north></LatLonBox></GroundOverlay></kml>",
  )
  let rotated = kml(
    "<kml><GroundOverlay><LatLonBox><west>0</west><south>0</south><east>2</east><north>2</north><rotation>45</rotation></LatLonBox></GroundOverlay></kml>",
  )
  assert_true(normal != rotated)
}

///|
test "generators match collection APIs" {
  let kml_source = "<kml><Placemark><Point><coordinates>1,2</coordinates></Point></Placemark><GroundOverlay><LatLonBox><west>0</west><south>0</south><east>1</east><north>1</north></LatLonBox></GroundOverlay></kml>"
  let gpx_source = "<gpx><wpt lon='1' lat='2'/></gpx>"
  let tcx_source = "<TrainingCenterDatabase/>"
  assert_eq(feature_collection(kml_gen(kml_source).collect()), kml(kml_source))
  assert_eq(feature_collection(gpx_gen(gpx_source).collect()), gpx(gpx_source))
  assert_eq(feature_collection(tcx_gen(tcx_source).collect()), tcx(tcx_source))
  let skip_source = "<kml><Placemark/><Placemark><Point><coordinates>1,2</coordinates></Point></Placemark></kml>"
  assert_eq(kml_gen(skip_source, skip_null_geometry=true).collect().length(), 1)
}

///|
test "KML mixed geometry and XML text decoding" {
  let source = "<kml><Placemark><name>A &amp; B</name><description><![CDATA[<b>hi</b>]]></description><MultiGeometry><Point><coordinates>1,2</coordinates></Point><LineString><coordinates>1,2 3,4</coordinates></LineString></MultiGeometry></Placemark></kml>"
  let expected = @json.parse(
    "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"name\":\"A & B\",\"description\":{\"@type\":\"html\",\"value\":\"<b>hi</b>\"}},\"geometry\":{\"type\":\"GeometryCollection\",\"geometries\":[{\"type\":\"Point\",\"coordinates\":[1,2]},{\"type\":\"LineString\",\"coordinates\":[[1,2],[3,4]]}]}}]}",
  )
  assert_eq(kml(source), expected)
}

///|
test "GPX rejects incomplete tracks but keeps valid waypoints" {
  let source = "<gpx><trk><trkseg><trkpt lon='1' lat='2'/><trkpt lon='bad' lat='4'/></trkseg></trk><wpt lon='5' lat='6'/></gpx>"
  let expected = @json.parse(
    "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"Point\",\"coordinates\":[5,6]}}]}",
  )
  assert_eq(gpx(source), expected)
}

///|
test "TCX combines valid lap tracks into one MultiLineString" {
  let source = "<TrainingCenterDatabase><Lap><Track><Trackpoint><Position><LongitudeDegrees>1</LongitudeDegrees><LatitudeDegrees>2</LatitudeDegrees></Position></Trackpoint><Trackpoint><Position><LongitudeDegrees>3</LongitudeDegrees><LatitudeDegrees>4</LatitudeDegrees></Position></Trackpoint></Track><Track><Trackpoint><Position><LongitudeDegrees>5</LongitudeDegrees><LatitudeDegrees>6</LatitudeDegrees></Position></Trackpoint><Trackpoint><Position><LongitudeDegrees>7</LongitudeDegrees><LatitudeDegrees>8</LatitudeDegrees></Position></Trackpoint></Track></Lap></TrainingCenterDatabase>"
  let expected = @json.parse(
    "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"MultiLineString\",\"coordinates\":[[[1,2],[3,4]],[[5,6],[7,8]]]}}]}",
  )
  assert_eq(tcx(source), expected)
}
