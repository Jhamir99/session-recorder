import SwiftUI
import Playgrounds

struct ContentView: View {

    var body: some View {
        HStack(spacing: 30) {
            Button(action: {
                print("Play")
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 30))
            }

            Button(action: {
                print("Pause")
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 30))
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
