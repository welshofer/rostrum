import Testing
@testable import Rostrum

@Suite("GeneratedSchemaTests")
struct GeneratedSchemaTests {

    // MARK: - childSuccessors

    @Test func presentationSldSzSuccessorsIncludeNotesSz() {
        let successors = OOXMLSchema.childSuccessors["p:presentation"]?["p:sldSz"]
        #expect(successors?.contains("p:notesSz") == true)
    }

    @Test func presentationSldMasterIdLstSuccessorOrderIsDeclaredOrder() {
        // Successor lists are search order, not sets — order must survive
        // extraction and generation.
        let successors = OOXMLSchema.childSuccessors["p:presentation"]?["p:sldMasterIdLst"]
        #expect(successors == [
            "p:notesMasterIdLst", "p:handoutMasterIdLst", "p:sldIdLst", "p:sldSz", "p:notesSz",
        ])
    }

    // MARK: - requiredAttributes

    @Test func offRequiresXAndY() {
        // a:off is CT_Point2D: RequiredAttribute("x"), RequiredAttribute("y").
        #expect(OOXMLSchema.requiredAttributes["a:off"] == ["x", "y"])
    }

    @Test func prstGeomRequiresPrst() {
        // a:prstGeom is CT_PresetGeometry2D: RequiredAttribute("prst").
        #expect(OOXMLSchema.requiredAttributes["a:prstGeom"] == ["prst"])
    }

    // MARK: - attributeDefaults

    @Test func bodyPrInsetDefaultsMatchPythonPptx() {
        // CT_TextBodyProperties: lIns/tIns default to Emu(91440)/Emu(45720).
        let defaults = OOXMLSchema.attributeDefaults["a:bodyPr"]
        #expect(defaults?["lIns"] == "91440")
        #expect(defaults?["tIns"] == "45720")
    }

    @Test func placeholderTypeDefaultIsObj() {
        // CT_Placeholder: OptionalAttribute("type", …, default=PP_PLACEHOLDER.OBJECT).
        #expect(OOXMLSchema.attributeDefaults["p:ph"]?["type"] == "obj")
    }

    // MARK: - table sizes (floors from the current extraction; regeneration
    // against a newer python-pptx may only grow these)

    @Test func elementTagCountFloor() {
        // Actual count at generation time: 325.
        #expect(OOXMLSchema.elementTags.count >= 325)
    }

    @Test func tableSizeFloors() {
        // Actual counts at generation time: 56 / 36 / 44.
        #expect(OOXMLSchema.childSuccessors.count >= 56)
        #expect(OOXMLSchema.attributeDefaults.count >= 36)
        #expect(OOXMLSchema.requiredAttributes.count >= 44)
    }

    @Test func elementTagsAreSortedAndUnique() {
        let tags = OOXMLSchema.elementTags
        #expect(tags == tags.sorted())
        #expect(Set(tags).count == tags.count)
    }
}
