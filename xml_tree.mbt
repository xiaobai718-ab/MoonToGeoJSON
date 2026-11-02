///|
/// A small DOM-like tree for the XML input accepted by toGeoJSON. XML parsing
/// itself is delegated to Milky2018/xml, which validates entities and nesting.
priv struct XmlNode {
  name : String
  attrs : Map[String, String]
  children : Array[XmlNode]
  mut text : String
  mut has_cdata : Bool
}

///|
fn xml_node(name : String, attrs : Map[String, String]) -> XmlNode {
  { name, attrs, children: [], text: "", has_cdata: false, }
}

///|
fn parse_xml(source : String) -> XmlNode raise {
  let root = xml_node("#document", {})
  let stack : Array[XmlNode] = [root]
  let reader = @xml.Reader::from_string(source)
  while true {
    let event = reader.read_event()
    match event.kind {
      @xml.Start(element) | @xml.Empty(element) => {
        let attrs : Map[String, String] = Map([])
        for attribute in element.attributes {
          attrs.set(attribute.name, attribute.value)
        }
        let node = xml_node(element.name, attrs)
        stack[stack.length() - 1].children.push(node)
        match event.kind {
          @xml.Start(_) => stack.push(node)
          _ => ()
        }
      }
      @xml.End(_) => ignore(stack.pop())
      @xml.Text(value) => {
        let current = stack[stack.length() - 1]
        current.text = current.text + value
      }
      @xml.CData(value) => {
        let current = stack[stack.length() - 1]
        current.text = current.text + value
        current.has_cdata = true
      }
      @xml.Eof => break
      _ => ()
    }
  }
  root
}

///|
fn local_name(name : String) -> String {
  match name.split_once(":") {
    Some((_, suffix)) => suffix.to_owned()
    None => name
  }
}

///|
fn XmlNode::attr(self : XmlNode, name : String) -> String? {
  self.attrs.get(name)
}

///|
fn XmlNode::first(self : XmlNode, name : String) -> XmlNode? {
  for child in self.children {
    if local_name(child.name) == name {
      return Some(child)
    }
    if child.first(name) is Some(found) {
      return Some(found)
    }
  }
  None
}

///|
fn XmlNode::descendants(self : XmlNode, name : String) -> Array[XmlNode] {
  let found : Array[XmlNode] = []
  for child in self.children {
    if local_name(child.name) == name {
      found.push(child)
    }
    found.append(child.descendants(name))
  }
  found
}

///|
fn XmlNode::value(self : XmlNode, name : String) -> String? {
  self.first(name).map(node => node.text_content())
}

///|
fn XmlNode::text_content(self : XmlNode) -> String {
  let mut value = self.text
  for child in self.children {
    value = value + child.text_content()
  }
  value
}

///|
fn XmlNode::number(self : XmlNode, name : String) -> Double? {
  match self.value(name) {
    Some(value) => parse_number(value)
    None => None
  }
}

///|
fn XmlNode::attribute_number(self : XmlNode, name : String) -> Double? {
  match self.attr(name) {
    Some(value) => parse_number(value)
    None => None
  }
}

///|
fn parse_number(value : String) -> Double? {
  let number = @string.parse_double(value.trim()) catch { _ => return None }
  Some(number)
}
