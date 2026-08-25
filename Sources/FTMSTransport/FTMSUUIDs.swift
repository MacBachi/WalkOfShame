import Foundation
import CoreBluetooth

/// UUIDs des Fitness Machine Service.
public enum FTMSUUIDs {
    nonisolated(unsafe) public static let service = CBUUID(string: "1826")
    nonisolated(unsafe) public static let treadmillData = CBUUID(string: "2ACD")
    nonisolated(unsafe) public static let feature = CBUUID(string: "2ACC")
    nonisolated(unsafe) public static let trainingStatus = CBUUID(string: "2AD3")
    nonisolated(unsafe) public static let speedRange = CBUUID(string: "2AD4")
    nonisolated(unsafe) public static let inclinationRange = CBUUID(string: "2AD5")
    nonisolated(unsafe) public static let heartRateRange = CBUUID(string: "2AD7")
    nonisolated(unsafe) public static let controlPoint = CBUUID(string: "2AD9")
    nonisolated(unsafe) public static let machineStatus = CBUUID(string: "2ADA")

    nonisolated(unsafe) static let zuLesen = [feature, speedRange, inclinationRange, heartRateRange]
    nonisolated(unsafe) static let zuAbonnieren = [treadmillData, trainingStatus, machineStatus, controlPoint]
}
