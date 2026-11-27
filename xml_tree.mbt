///|
/// A small DOM-like tree for the XML input accepted by toGeoJSON. XML parsing
/// itself is delegated to Milky2018/xml, which validates entities and nesting.
priv struct XmlNode {
  name : String
  attrs : Map[String, String]
  namespace_uri : String?
  children : Array[XmlNode]
  mut text : String
  mut all_text : String
  mut cdata_text : String
  mut has_cdata : Bool
}

///|
fn xml_node(
  name : String,
  attrs : Map[String, String],
  namespace_uri : String?,
) -> XmlNode {
  {
    name,
    attrs,
    namespace_uri,
    children: [],
    text: "",
    all_text: "",
    cdata_text: "",
    has_cdata: false,
  }
}

///|
fn parse_xml(source : String) -> XmlNode raise {
  let root = xml_node("#document", {}, None)
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
        let namespace_uri = xml_prefix_namespace(element.name, attrs, stack)
        let node = xml_node(element.name, attrs, namespace_uri)
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
        for ancestor in stack {
          ancestor.all_text = ancestor.all_text + value
        }
      }
      @xml.CData(value) => {
        let current = stack[stack.length() - 1]
        current.text = current.text + value
        current.cdata_text = current.cdata_text + value
        current.has_cdata = true
        for ancestor in stack {
          ancestor.all_text = ancestor.all_text + value
        }
      }
      @xml.Eof => break
      _ => ()
    }
  }
  root
}

///|
fn xml_prefix_namespace(
  name : String,
  attrs : Map[String, String],
  stack : Array[XmlNode],
) -> String? {
  guard name.split_once(":") is Some((prefix, _)) else { return None }
  let declaration = "xmlns:" + prefix.to_owned()
  if attrs.get(declaration) is Some(uri) {
    return Some(uri)
  }
  for index = stack.length() - 1; index >= 0; index = index - 1 {
    if stack[index].attr(declaration) is Some(uri) {
      return Some(uri)
    }
  }
  None
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
fn XmlNode::all_descendants(self : XmlNode) -> Array[XmlNode] {
  let found : Array[XmlNode] = []
  for child in self.children {
    found.push(child)
    found.append(child.all_descendants())
  }
  found
}

///|
fn XmlNode::value(self : XmlNode, name : String) -> String? {
  self.first(name).map(node => node.text_content())
}

///|
fn XmlNode::text_content(self : XmlNode) -> String {
  self.all_text
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
