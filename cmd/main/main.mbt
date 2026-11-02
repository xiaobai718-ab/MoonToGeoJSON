///|
fn main raise {
  let sample = "<kml><Placemark><name>MoonBit</name><Point><coordinates>116.397,39.908</coordinates></Point></Placemark></kml>"
  println(@lib.kml(sample).stringify())
}
