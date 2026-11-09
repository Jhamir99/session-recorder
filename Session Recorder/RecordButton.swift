import SwiftUI

struct RecordButton: View {
    @Binding var currentStatus: STATUSES

    var body: some View {
        HStack(spacing: 30) {
            Button(action: {
                if (currentStatus == .RECORDING) {
                    currentStatus = .START
                    print("Stop recording")
                }
                else {
                    currentStatus = .RECORDING
                    print("Start recording")
                }
            }) {
                Image(systemName: currentStatus == .RECORDING
                      ? "record.circle.fill"
                      : "record.circle")
                    .font(.system(size: 30))
            }
        }
    }
}
