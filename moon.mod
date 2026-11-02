// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "xiaobai718-ab/moontogeojson"

version = "0.1.0"

readme = "README.md"

license = "Apache-2.0"

keywords = [ "kml", "gpx", "tcx", "geojson", "geospatial" ]

preferred_target = "native"

description = "KML, GPX and TCX to GeoJSON conversion in pure MoonBit"

import {
  "Milky2018/xml@0.6.1",
  "moonbitlang/async@0.22.4",
}
