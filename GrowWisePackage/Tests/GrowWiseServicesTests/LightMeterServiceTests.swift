import Foundation
@testable import GrowWiseServices
import Testing

@Suite("LightMeterService — pure math + buckets")
struct LightMeterServiceTests {
    // MARK: - EV100

    @Test("EV100 is 0 at f/1.0, 1s, ISO 100")
    func ev100Baseline() {
        let ev = LightMeterService.ev100(aperture: 1.0, exposureSeconds: 1.0, iso: 100)
        #expect(abs(ev - 0.0) < 0.0001)
    }

    @Test("EV100 increases by 1 when aperture squared doubles")
    func ev100ApertureDouble() {
        let base = LightMeterService.ev100(aperture: 1.0, exposureSeconds: 1.0, iso: 100)
        let doubled = LightMeterService.ev100(aperture: sqrt(2.0), exposureSeconds: 1.0, iso: 100)
        #expect(abs(doubled - base - 1.0) < 0.0001)
    }

    @Test("EV100 increases by 1 when shutter halves")
    func ev100ShutterHalves() {
        let base = LightMeterService.ev100(aperture: 1.0, exposureSeconds: 1.0, iso: 100)
        let faster = LightMeterService.ev100(aperture: 1.0, exposureSeconds: 0.5, iso: 100)
        #expect(abs(faster - base - 1.0) < 0.0001)
    }

    @Test("EV100 decreases by 1 when ISO doubles")
    func ev100IsoDouble() {
        let base = LightMeterService.ev100(aperture: 1.0, exposureSeconds: 1.0, iso: 100)
        let isoDoubled = LightMeterService.ev100(aperture: 1.0, exposureSeconds: 1.0, iso: 200)
        #expect(abs(isoDoubled - base + 1.0) < 0.0001)
    }

    // MARK: - Lux

    @Test("Lux at EV100=0 equals the calibration constant")
    func luxAtBaseline() {
        let lux = LightMeterService.lux(aperture: 1.0, exposureSeconds: 1.0, iso: 100)
        #expect(abs(lux - LightMeterService.luxCalibration) < 0.0001)
    }

    @Test("Bright outdoor scene (~EV15) produces order-of-magnitude lux above 50k")
    func luxBrightScene() {
        // f/16, 1/125s, ISO 100 → EV15 → ~80k lux (sunlight)
        let lux = LightMeterService.lux(aperture: 16.0, exposureSeconds: 1.0 / 125.0, iso: 100)
        #expect(lux > 50000)
        #expect(lux < 200_000)
    }

    @Test("Dim indoor scene (~EV5) produces hundreds of lux")
    func luxDimScene() {
        // f/2.8, 1/30s, ISO 1600 → roughly EV5
        let lux = LightMeterService.lux(aperture: 2.8, exposureSeconds: 1.0 / 30.0, iso: 1600)
        #expect(lux > 20)
        #expect(lux < 1000)
    }

    // MARK: - Bucket thresholds

    @Test("Bucket boundaries")
    func bucketBoundaries() {
        #expect(LightMeterBucket.bucket(forLux: 0) == .deepShade)
        #expect(LightMeterBucket.bucket(forLux: 499) == .deepShade)
        #expect(LightMeterBucket.bucket(forLux: 500) == .shade)
        #expect(LightMeterBucket.bucket(forLux: 2499) == .shade)
        #expect(LightMeterBucket.bucket(forLux: 2500) == .brightIndirect)
        #expect(LightMeterBucket.bucket(forLux: 9999) == .brightIndirect)
        #expect(LightMeterBucket.bucket(forLux: 10000) == .directSun)
        #expect(LightMeterBucket.bucket(forLux: 80000) == .directSun)
    }

    @Test("Every bucket has non-empty display + subtitle")
    func bucketCopy() {
        for bucket in LightMeterBucket.allCases {
            #expect(!bucket.displayName.isEmpty)
            #expect(!bucket.subtitle.isEmpty)
        }
    }
}
