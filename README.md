# MoonToGeoJSON

Convert KML, GPX and TCX XML into GeoJSON using MoonBit. This project ports the core conversion behavior of [@tmcw/togeojson 7.1.3](https://github.com/placemark/togeojson/tree/v7.1.3) to MoonBit. XML parsing uses [`Milky2018/xml`](https://mooncakes.io/docs/Milky2018/xml).

The library accepts XML text and returns MoonBit `Json` values. The KML API supports placemarks, basic styles, extended data, timestamps, GroundOverlay, NetworkLink, folder trees and `gx:Track`. GPX supports tracks, routes, waypoints, times and trackpoint extensions. TCX supports laps, courses, time and heart-rate arrays, lap metrics, cadence, speed and watts.

## Requirements

- MoonBit compiler `moonc` 0.10.16 or newer
- Internet access for the first `moon update` to fetch `Milky2018/xml@0.6.1`

## Install

```sh
moon add xiaobai718-ab/moontogeojson
```

Until the Mooncakes release is available, clone this repository and run `moon update` from its root. The public Mooncakes name in `moon.mod` is reserved for publication; a release is not claimed here.

## Use

Add the package to your `moon.pkg`:

```moonbit nocheck
///|
import {
  "xiaobai718-ab/moontogeojson" @togeojson,
}
```

```moonbit nocheck
///|
fn main raise {
  let source = "<kml><Placemark><name>MoonBit</name><Point><coordinates>116.397,39.908</coordinates></Point></Placemark></kml>"
  println(@togeojson.kml(source).stringify())
}
```

Run the checked-in example:

```sh
moon run cmd/main --target native
```

It prints a GeoJSON `FeatureCollection` containing one Point at `[116.397, 39.908]`.

The public conversion functions are:

| Function | Input | Output |
| --- | --- | --- |
| `kml(source, skip_null_geometry?=false)` | KML XML string | GeoJSON FeatureCollection |
| `kml_with_folders(source, skip_null_geometry?=false)` | KML XML string | Nested root/folder tree with GeoJSON features |
| `gpx(source)` | GPX XML string | GeoJSON FeatureCollection |
| `tcx(source)` | TCX XML string | GeoJSON FeatureCollection |

Malformed XML raises an XML parser error. Invalid or incomplete geospatial coordinates are omitted; KML placemarks without valid geometry have `geometry: null` unless `skip_null_geometry=true`.

## Develop

```sh
moon update
moon check --target native
moon build --target native
moon test --target native
moon check --target js
moon test --target js
moon check --target wasm-gc
```

The `.upstream` directory is an ignored local reference checkout and is not required to build. The port currently returns complete `Json` collections; the upstream JavaScript iterator API is not present. Some uncommon KML styles, schema typing and rotated overlays are still being worked on. Check the tests and commit history for the implemented behavior; do not assume byte-for-byte parity for every upstream fixture yet.

## License and attribution

MoonToGeoJSON is licensed under Apache-2.0. It adapts algorithms and behavior from `@tmcw/togeojson`, which is BSD-2-Clause licensed. The upstream copyright and license notice are included in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
