import Foundation
import Testing
@testable import LecternCore

@Suite struct SlidePreviewGeometryTests {
    @Test(arguments: [(16.0, 9.0), (4.0, 3.0), (9.0, 16.0)])
    func dimensionsSurviveSVGAndPlaceholder(_ dimensions: (Double, Double)) {
        let (width, height) = dimensions
        let geometry = SlidePreviewGeometry(svg: "<svg viewBox='0 0 \(width) \(height)'><rect/></svg>")
        #expect(geometry.aspectRatio == width / height)
        let size = geometry.fitted(toWidth: 640)
        #expect(abs(size.height - 640 * height / width) < 0.001)
        let failed = SlidePreviewRecord(number: 2, title: "", svg: nil, geometry: geometry)
        #expect(abs(SlidePreviewGeometry(svg: failed.displaySVG).aspectRatio - geometry.aspectRatio) < 0.001)
    }

    @Test func malformedDimensionsUseSafeFallback() {
        for svg in ["", "<svg viewBox='0 0 0 3'/>", "<svg viewBox='0 0 nan 4'/>", "<svg viewBox='0 bad 0 4 3'/>", "<svg width='-1' height='2'/>", "<not-svg width='4' height='3'/>"] {
            #expect(SlidePreviewGeometry(svg: svg) == .widescreen)
        }
        #expect(SlidePreviewGeometry(svg: "<svg width='640px' height='480px'/>").aspectRatio == 4.0 / 3)
        #expect(SlidePreviewGeometry(svg: "<svg viewBox='1,2,4,3'/>").aspectRatio == 4.0 / 3)
    }

    @Test func allocationIsBoundedWithoutChangingAspectRatio() {
        let size = SlidePreviewGeometry(width: 1, height: 100).fitted(toWidth: 10000)
        #expect(size.height == 4096)
        #expect(size.width <= 4096)
        #expect(size.aspectRatio == 0.01)
    }
}
