import Foundation
import Testing
@testable import WLEDWatch

@MainActor
struct DeviceControllerTests {
    /// - Parameter localChangeGrace: 0 applies polled values right away, even just after a local change.
    private func makeController(
        for device: FakeWledDevice,
        localChangeGrace: TimeInterval = 0
    ) -> DeviceController {
        DeviceController(
            device: device.watchDevice,
            transport: device,
            localChangeGrace: localChangeGrace,
            brightnessDebounce: .milliseconds(10)
        )
    }

    // MARK: - Polling

    @Test func startsConnecting() {
        let controller = makeController(for: FakeWledDevice())
        #expect(controller.connection == .connecting)
    }

    @Test func refreshAppliesDeviceState() async {
        let device = FakeWledDevice(.init(on: true, bri: 200))
        let controller = makeController(for: device)

        await controller.refresh()

        #expect(controller.connection == .online)
        #expect(controller.isOn)
        #expect(controller.brightness == 200)
        #expect(!controller.isNightlightOn)
        #expect(controller.nightlightEnd == nil)
    }

    @Test func refreshWhileOffShowsBrightnessForNextPowerOn() async {
        let device = FakeWledDevice(.init(on: false, bri: 90))
        let controller = makeController(for: device)

        await controller.refresh()

        #expect(!controller.isOn)
        #expect(controller.brightness == 90)
    }

    @Test func unreachableDeviceIsOffline() async {
        let device = FakeWledDevice()
        device.isReachable = false
        let controller = makeController(for: device)

        await controller.refresh()

        #expect(controller.connection == .offline)
    }

    @Test func comesBackOnlineWhenReachableAgain() async {
        let device = FakeWledDevice()
        device.isReachable = false
        let controller = makeController(for: device)
        await controller.refresh()

        device.isReachable = true
        await controller.refresh()

        #expect(controller.connection == .online)
    }

    @Test func unreadableStateKeepsLastValues() async {
        let device = FakeWledDevice(.init(on: true, bri: 200))
        let controller = makeController(for: device)
        await controller.refresh()

        device.sendsGarbage = true
        await controller.refresh()

        #expect(controller.connection == .offline)
        #expect(controller.isOn)
        #expect(controller.brightness == 200)
    }

    @Test func pollStopsWhenCancelled() async {
        let device = FakeWledDevice(.init(on: true, bri: 42))
        let controller = makeController(for: device)

        let task = Task { await controller.poll() }
        while controller.connection == .connecting {
            await Task.yield()
        }
        task.cancel()
        await task.value

        #expect(controller.brightness == 42)
    }

    @Test func closingWithQueuedCommandsSendsNothingMore() async throws {
        let device = FakeWledDevice()
        var controller: DeviceController? = makeController(for: device)
        controller?.setPower(true)
        controller?.setNightlight(true)
        controller?.setBrightness(30)

        controller = nil
        #expect(device.isInvalidated)
        // Give the queued tasks (and the brightness debounce) time to run.
        try await Task.sleep(for: .milliseconds(100))

        #expect(device.requestsAfterInvalidate == 0)
    }

    // MARK: - Power

    @Test func setPowerSendsOnAndUpdatesRightAway() async {
        let device = FakeWledDevice(.init(on: false))
        let controller = makeController(for: device)

        controller.setPower(true)
        #expect(controller.isOn)
        await controller.waitForPendingRequests()

        #expect(device.updates == [.init(on: true)])
        #expect(device.state.on)
        #expect(controller.connection == .online)
    }

    @Test func pollIgnoresPowerJustAfterLocalChange() async {
        let device = FakeWledDevice(.init(on: false))
        let controller = makeController(for: device, localChangeGrace: 60)
        controller.setPower(true)
        await controller.waitForPendingRequests()

        // Stale value, e.g. a poll that started before the command was handled.
        device.state.on = false
        await controller.refresh()

        #expect(controller.isOn)
    }

    @Test func pollAppliesPowerOnceGraceIsOver() async {
        let device = FakeWledDevice(.init(on: false))
        let controller = makeController(for: device)
        controller.setPower(true)
        await controller.waitForPendingRequests()

        device.state.on = false
        await controller.refresh()

        #expect(!controller.isOn)
    }

    @Test func failedCommandMarksOffline() async {
        let device = FakeWledDevice()
        let controller = makeController(for: device)
        await controller.refresh()

        device.isReachable = false
        controller.setPower(true)
        await controller.waitForPendingRequests()

        #expect(controller.connection == .offline)
    }

    @Test func unreadableCommandResponseStaysOnline() async {
        let device = FakeWledDevice()
        device.sendsGarbage = true
        let controller = makeController(for: device)

        controller.setPower(true)
        await controller.waitForPendingRequests()

        #expect(device.updates == [.init(on: true)])
        #expect(controller.connection == .online)
    }

    @Test func commandsAreSentInOrder() async {
        let device = FakeWledDevice()
        let controller = makeController(for: device)

        controller.setPower(true)
        controller.setPower(false)
        controller.setPower(true)
        await controller.waitForPendingRequests()

        #expect(device.updates.map(\.on) == [true, false, true])
        #expect(device.state.on)
    }

    // MARK: - Brightness

    @Test func setBrightnessTurnsOnAndSendsLevel() async {
        let device = FakeWledDevice(.init(on: false, bri: 100))
        let controller = makeController(for: device)

        controller.setBrightness(180.4)
        #expect(controller.isOn)
        #expect(controller.brightness == 180.4)
        await controller.waitForPendingRequests()

        #expect(device.updates == [.init(on: true, bri: 180)])
    }

    @Test func setBrightnessIsDebounced() async {
        let device = FakeWledDevice(.init(on: true, bri: 100))
        let controller = makeController(for: device)

        for value in stride(from: 110.0, through: 150, by: 10) {
            controller.setBrightness(value)
        }
        await controller.waitForPendingRequests()

        #expect(device.updates == [.init(on: true, bri: 150)])
    }

    @Test func setSameBrightnessSendsNothing() async {
        let device = FakeWledDevice(.init(on: true, bri: 100))
        let controller = makeController(for: device)
        await controller.refresh()

        controller.setBrightness(100)
        await controller.waitForPendingRequests()

        #expect(device.updates.isEmpty)
    }

    @Test func brightnessZeroTurnsOffWithoutSendingBri() async {
        let device = FakeWledDevice(.init(on: true, bri: 100))
        let controller = makeController(for: device)
        await controller.refresh()

        controller.setBrightness(0)
        #expect(!controller.isOn)
        await controller.waitForPendingRequests()

        #expect(device.updates == [.init(on: false)])
        // The device keeps its brightness for the next power on.
        #expect(device.state.bri == 100)
    }

    @Test func offStateShowsLastBrightness() async {
        let device = FakeWledDevice(.init(on: true, bri: 100))
        let controller = makeController(for: device)
        await controller.refresh()
        controller.setBrightness(170)
        await controller.waitForPendingRequests()

        controller.setBrightness(0)
        await controller.waitForPendingRequests()
        #expect(controller.brightness == 170)
    }

    @Test func remoteBrightnessIsClamped() async {
        let device = FakeWledDevice(.init(on: true, bri: 400))
        let controller = makeController(for: device)

        await controller.refresh()

        #expect(controller.brightness == DeviceController.maxBrightness)
    }

    // MARK: - Nightlight

    @Test func nightlightStateAndEndAreApplied() async throws {
        let device = FakeWledDevice(.init(on: true, bri: 100, nightlightOn: true, nightlightRemaining: 1500))
        let controller = makeController(for: device)

        let before = Date.now
        await controller.refresh()

        #expect(controller.isNightlightOn)
        let end = try #require(controller.nightlightEnd)
        #expect(end.timeIntervalSince(before) >= 1500)
        #expect(end.timeIntervalSince(before) < 1510)
    }

    @Test func unknownNightlightRemainingHasNoEnd() async {
        let device = FakeWledDevice(.init(on: true, bri: 100, nightlightOn: true, nightlightRemaining: -1))
        let controller = makeController(for: device)

        await controller.refresh()

        #expect(controller.isNightlightOn)
        #expect(controller.nightlightEnd == nil)
    }

    @Test func startingNightlightTurnsStripOn() async {
        let device = FakeWledDevice(.init(on: false, bri: 120))
        let controller = makeController(for: device)
        await controller.refresh()

        controller.setNightlight(true)
        #expect(controller.isNightlightOn)
        #expect(controller.isOn)
        await controller.waitForPendingRequests()

        #expect(device.updates == [.init(on: true, nl: .init(on: true))])
    }

    @Test func startingNightlightFromZeroBrightnessRestoresLastBrightness() async {
        let device = FakeWledDevice(.init(on: true, bri: 120))
        let controller = makeController(for: device, localChangeGrace: 60)
        await controller.refresh()
        controller.setBrightness(0)

        controller.setNightlight(true)

        #expect(controller.brightness == 120)
    }

    @Test func stoppingNightlightRestoresBrightness() async {
        let device = FakeWledDevice(.init(on: true, bri: 200))
        let controller = makeController(for: device)
        await controller.refresh()
        controller.setNightlight(true)
        await controller.waitForPendingRequests()

        // The nightlight fades the strip down.
        device.state.bri = 30
        await controller.refresh()
        #expect(controller.brightness == 30)

        controller.setNightlight(false)
        #expect(!controller.isNightlightOn)
        #expect(controller.nightlightEnd == nil)
        #expect(controller.brightness == 200)
        await controller.waitForPendingRequests()

        #expect(device.updates.last == .init(bri: 200, nl: .init(on: false)))
        #expect(device.state.bri == 200)
    }

    @Test func brightnessChangedDuringNightlightIsTheOneRestored() async {
        let device = FakeWledDevice(.init(on: true, bri: 200))
        let controller = makeController(for: device)
        await controller.refresh()
        controller.setNightlight(true)
        controller.setBrightness(80)
        await controller.waitForPendingRequests()

        controller.setNightlight(false)
        await controller.waitForPendingRequests()

        #expect(device.updates.last == .init(bri: 80, nl: .init(on: false)))
    }

    @Test func nightlightEndingElsewhereRestoresBrightnessAndKeepsStripOff() async {
        let device = FakeWledDevice(.init(on: true, bri: 200))
        let controller = makeController(for: device)
        await controller.refresh()

        // Started from the iPhone, then faded down to off.
        device.state.nightlightOn = true
        device.state.nightlightRemaining = 300
        device.state.bri = 50
        await controller.refresh()
        #expect(controller.isNightlightOn)

        device.state = .init(on: false, bri: 1, nightlightOn: false, nightlightRemaining: -1)
        await controller.refresh()
        await controller.waitForPendingRequests()

        #expect(!controller.isNightlightOn)
        #expect(!controller.isOn)
        #expect(controller.brightness == 200)
        #expect(device.updates == [.init(on: false, bri: 200)])
    }

    @Test func nightlightEndingElsewhereKeepsStripOnIfItWasLeftOn() async {
        let device = FakeWledDevice(.init(on: true, bri: 200, nightlightOn: true, nightlightRemaining: 300))
        let controller = makeController(for: device)
        // First seen with a nightlight already running: its brightness is the best guess.
        await controller.refresh()

        device.state = .init(on: true, bri: 60, nightlightOn: false, nightlightRemaining: -1)
        await controller.refresh()
        await controller.waitForPendingRequests()

        #expect(controller.isOn)
        #expect(device.updates.count == 1)
        #expect(device.updates.first?.on == nil)
        #expect(device.updates.first?.nl == nil)
    }
}
