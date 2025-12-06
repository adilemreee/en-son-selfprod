import SwiftUI

struct ContentView: View {
    @ObservedObject var cloudManager = CloudKitManager.shared
    
    var body: some View {
        Group {
            if cloudManager.isPaired {
                HeartView()
            } else {
                PairingView()
            }
        }
        .animation(.default, value: cloudManager.isPaired)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
