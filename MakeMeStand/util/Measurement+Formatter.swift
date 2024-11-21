import Foundation

extension Measurement where UnitType == UnitLength {
  func formattedPreserveUnit() -> String {
    let formatter = MeasurementFormatter()
    formatter.numberFormatter.maximumFractionDigits = 2
    formatter.unitStyle = .medium
    formatter.unitOptions = [.providedUnit]
    return formatter.string(from: self)
  }
}
