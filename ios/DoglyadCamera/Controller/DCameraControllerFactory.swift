@MainActor
public enum DCameraControllerFactory {
    #if targetEnvironment(simulator)
        public typealias Controller = SimulatorCameraController
    #else
        public typealias Controller = DeviceCameraController
    #endif

    public static func make() -> Controller {
        Controller()
    }
}
