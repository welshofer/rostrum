import Foundation

/// Default print geometry for newly authored notes. Existing notes and masters
/// are never rewritten. New notes bind to an existing master's placeholder IDs.
enum NotesPageTemplate {
    static func pageSize(in presentation: XML.Element) throws -> (Int, Int) {
        let scope = namespaceScope(of: presentation, inherited: [:])
        guard let size = presentation.childElements.first(where: {
            let name = $0.name.split(separator: ":", maxSplits: 1).map(String.init)
            return name.last == "notesSz"
                && namespaceScope(of: $0, inherited: scope)[name.count == 2 ? name[0] : ""] == MinimalTemplate.nsP
        }),
              let width = Int(size[attribute: "cx"] ?? ""),
              let height = Int(size[attribute: "cy"] ?? ""),
              width > 0, height > 0, width <= Int32.max, height <= Int32.max else {
            throw RostrumError.packageInvalid("notes page size must contain positive 32-bit dimensions")
        }
        return (width, height)
    }

    static func master(size: (Int, Int)) -> Data {
        let content = shape(type: "sldImg", id: 2, index: "2", geometry: geometry("sldImg", size), body: false)
            + shape(type: "body", id: 3, index: "1", geometry: geometry("body", size), body: true)
        return document("notesMaster", content: content,
            tail: "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/>"
                + "<p:notesStyle><a:lvl1pPr marL=\"0\" indent=\"0\" algn=\"l\"><a:buNone/><a:defRPr sz=\"1800\"><a:solidFill><a:schemeClr val=\"tx1\"/></a:solidFill><a:latin typeface=\"+mn-lt\"/><a:ea typeface=\"+mn-ea\"/><a:cs typeface=\"+mn-cs\"/></a:defRPr></a:lvl1pPr></p:notesStyle>")
    }

    static func slide(master: XML.Element, size: (Int, Int)) -> Data {
        // Namespace-aware lookup also handles foreign producers' prefix aliases.
        // Copy only the standard placeholder matching attributes, not arbitrary
        // master XML or relationship IDs into a differently owned notes part.
        var placeholders: [String: XML.Element] = [:]
        let path = ["notesMaster", "cSld", "spTree", "sp", "nvSpPr", "nvPr", "ph"]
        var pending: [(XML.Element, [String: String], Int)] = [(master, [:], 0)]
        while let (node, inherited, depth) = pending.popLast() {
            let scope = namespaceScope(of: node, inherited: inherited)
            let pieces = node.name.split(separator: ":", maxSplits: 1).map(String.init)
            guard pieces.last == path[depth], scope[pieces.count == 2 ? pieces[0] : ""] == MinimalTemplate.nsP else { continue }
            if depth == path.count - 1,
               let type = node[attribute: "type"], placeholders[type] == nil {
                placeholders[type] = node
            }
            if depth < path.count - 1 {
                for child in node.childElements.reversed() { pending.append((child, scope, depth + 1)) }
            }
        }
        var content = ""
        for (type, id, fallbackIndex) in [("sldImg", 2, "2"), ("body", 3, "1")] {
            let placeholder = placeholders[type]
            let index = placeholder?[attribute: "idx"] ?? (placeholder == nil ? fallbackIndex : "0")
            // Old Rostrum masters were empty. Supply local geometry only when
            // the selected master has no corresponding placeholder.
            content += shape(type: type, id: id, index: index,
                geometry: placeholder == nil ? geometry(type, size) : "", body: type == "body",
                orientation: placeholder?[attribute: "orient"], size: placeholder?[attribute: "sz"])
        }
        return document("notes", content: content, tail: "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>")
    }

    private static func geometry(_ type: String, _ size: (Int, Int)) -> String {
        let (width, height) = size
        let x = width / 10, y = type == "body" ? height * 19 / 40 : height * 3 / 40
        let w = width * 4 / 5, h = type == "body" ? height * 9 / 20 : height * 3 / 8
        // A visible frame matches Office's conventional notes image placeholder.
        // PowerPoint 16.113.3 suppresses the image for the no-fill/no-line form.
        let line = type == "sldImg"
            ? "<a:ln w=\"12700\"><a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill></a:ln>"
            : "<a:ln><a:noFill/></a:ln>"
        return "<a:xfrm><a:off x=\"\(x)\" y=\"\(y)\"/><a:ext cx=\"\(w)\" cy=\"\(h)\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/>" + line
    }

    private static func shape(type: String, id: Int, index: String, geometry: String,
                              body: Bool, orientation: String? = nil, size: String? = nil) -> String {
        let ph = XML.Element("p:ph", attributes: [("type", type), ("idx", index)])
        ph[attribute: "orient"] = orientation; ph[attribute: "sz"] = size
        return "<p:sp><p:nvSpPr><p:cNvPr id=\"\(id)\" name=\"\(body ? "Notes" : "Slide Image") Placeholder\"/><p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr><p:nvPr>\(ph.serialized())</p:nvPr></p:nvSpPr><p:spPr>\(geometry)</p:spPr>"
            + "<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>"
    }

    private static func namespaceScope(of node: XML.Element, inherited: [String: String]) -> [String: String] {
        var scope = inherited
        for attribute in node.attributes {
            if attribute.name == "xmlns" { scope[""] = attribute.value }
            else if attribute.name.hasPrefix("xmlns:") { scope[String(attribute.name.dropFirst(6))] = attribute.value }
        }
        return scope
    }

    private static func document(_ root: String, content: String, tail: String) -> Data {
        let background = root == "notesMaster" ? "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" : ""
        return Data(("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<p:\(root) xmlns:a=\"\(MinimalTemplate.nsA)\" xmlns:r=\"\(MinimalTemplate.nsR)\" xmlns:p=\"\(MinimalTemplate.nsP)\"><p:cSld>" + background + "<p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
            + content + "</p:spTree></p:cSld>" + tail + "</p:\(root)>").utf8)
    }
}
