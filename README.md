# MoonToGeoJSON

Convert KML, GPX and TCX XML into GeoJSON using MoonBit. This project ports the core conversion behavior of [@tmcw/togeojson 7.1.3](https://github.com/placemark/togeojson/tree/v7.1.3) to MoonBit. XML parsing uses [`Milky2018/xml`](https://mooncakes.io/docs/Milky2018/xml).

The library accepts XML text and returns MoonBit `Json` values. The KML API supports placemarks, styles, schema typed extended data, timestamps, GroundOverlay, NetworkLink, folder trees and `gx:Track`. GPX supports tracks, routes, waypoints, times and trackpoint extensions. TCX supports laps, courses, time and heart-rate arrays, lap metrics, cadence, speed and watts.

## Requirements

- MoonBit compiler `moonc` 0.10.16 or newer
- Internet access for the first `moon update` to fetch `Milky2018/xml@0.6.1` and `moonbitlang/async@0.22.4` (the latter is used by the native file CLI)

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

Convert a local file with the native CLI:

```sh
moon run cmd/convert --target native -- kml input.kml
moon run cmd/convert --target native -- gpx route.gpx
moon run cmd/convert --target native -- tcx activity.tcx
moon run cmd/convert --target native -- route.gpx
```

The CLI writes the converted JSON to standard output. When the format is omitted, it uses the `.kml`, `.gpx` or `.tcx` file extension. `kml-folders` and `kml-folders-skip` are also accepted as explicit formats. Errors go to standard error and return a nonzero exit status.

Three small input files are included so the conversion can be reproduced immediately:

```sh
moon run cmd/convert --target native -- examples/places.kml
moon run cmd/convert --target native -- examples/route.gpx
moon run cmd/convert --target native -- examples/activity.tcx
```

The public conversion functions are:

| Function | Input | Output |
| --- | --- | --- |
| `kml(source, skip_null_geometry?=false)` | KML XML string | GeoJSON FeatureCollection |
| `kml_with_folders(source, skip_null_geometry?=false)` | KML XML string | Nested root/folder tree with GeoJSON features |
| `gpx(source)` | GPX XML string | GeoJSON FeatureCollection |
| `tcx(source)` | TCX XML string | GeoJSON FeatureCollection |
| `kml_gen(source, skip_null_geometry?=false)` | KML XML string | `Iter[Json]` yielding one feature at a time |
| `gpx_gen(source)` | GPX XML string | `Iter[Json]` yielding one feature at a time |
| `tcx_gen(source)` | TCX XML string | `Iter[Json]` yielding one feature at a time |

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

To rerun the upstream v7.1.3 parity suite (62 fixtures and 132 snapshots), clone the reference source into the ignored `.upstream` directory and run:

```sh
git clone --depth 1 --branch v7.1.3 https://github.com/placemark/togeojson.git .upstream
moon build --target native
node tools/compare-upstream.mjs
```

The comparison covers GeoJSON collections and both KML folder modes. It is also part of CI. The current result is **132/132 matching snapshots**.

On Windows, the current `moonc` can fail to create output in very long paths. If your checkout is in a long path, map the project to a short drive before running the same commands:

```powershell
subst M: 'E:\AAAAAAAAAAAAAAAAAAAAAA\2026.10\10月黑客松\xiaobai\moontogeojson'
moon -C M:\ test --target native
moon -C M:\ run cmd/main --target native
$env:MOONTOGEOJSON_MOON_ROOT='M:\'
node tools/compare-upstream.mjs
```

Replace the path and drive letter as needed. The mapping does not move project files.

The `.upstream` directory is an ignored local reference checkout and is not required to build. The source is a MoonBit port, so the public API takes XML strings rather than JavaScript DOM objects and returns `Json`/`Iter[Json]` rather than TypeScript GeoJSON types. For behavior covered by upstream v7.1.3 snapshots, output matches exactly.

## License and attribution

MoonToGeoJSON is licensed under Apache-2.0. It adapts algorithms and behavior from `@tmcw/togeojson`, which is BSD-2-Clause licensed. The upstream copyright and license notice are included in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
