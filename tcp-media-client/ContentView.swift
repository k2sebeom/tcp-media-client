//
//  ContentView.swift
//  tcpclient
//
//  Created by SeBeom on 2022/02/13.
//

import SwiftUI
import SwiftSocket
import AVKit

var BASE_HOST: String = "54.180.101.186"

struct ContentView: View {
    @State var name: String = ""
    
    @ObservedObject var vm = ViewModel()
    
    var body: some View {
        StreamView()
            .environmentObject(vm)
    }
}


struct StreamView: View {
    @EnvironmentObject var vm: ViewModel
    
    var streamButton: some View {
        ZStack {
            if vm.isStreaming {
                Button(action: {
                    vm.stopStream()
                }, label: {
                    Text("End Streaming")
                })
            }
            else {
                Button(action: {
                    vm.startStream()
                }, label: {
                    Text("Start Streaming")
                })
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text("Stream Key")
                    .font(.system(size: 25))
                TextField("Stream key", text: $vm.streamKey)
                    .font(.system(size: 25))
                    .padding(.horizontal, 20)
            }
            streamButton
            
        }
        .onAppear {
            vm.initialize()
        }
    }
}

class ViewModel: NSObject, ObservableObject {
    var client: TCPClient!
    var engine: AVAudioEngine!
    
    @Published var streamKey: String = ""
    @Published var isStreaming: Bool = false
    
    func initialize() {
        self.client = TCPClient(address: BASE_HOST, port: 5222)
        
        self.engine = AVAudioEngine()
        self.engine.connect(engine.inputNode, to: engine.mainMixerNode, format: nil)
        self.engine.mainMixerNode.volume = 0
        self.engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, time in
            let data = buffer.toData()
            _ = self.client.send(data: data)
        }
    }
    
    private func getAssetId() -> String {
        if let resp = client.read(1024) {
            return String(bytes: resp, encoding: .utf8)!
        }
        else {
            return getAssetId()
        }
    }
    
    func startStream() {
        _ = self.client.connect(timeout: 5)
        
        _ = self.client.send(string: self.streamKey)
        
        if let resp = self.client.read(4, timeout: 3) {
            let code = String(bytes: resp, encoding: .utf8)!
            print(code)
        }

        let fmt = self.engine.mainMixerNode.outputFormat(forBus: 0)
        
        var a = UInt16(fmt.sampleRate)
        var b = UInt16(fmt.channelCount)
        var data = Data(bytes: &a, count: 2)
        data.append(Data(bytes: &b, count: 2))
        data.append("f32le".data(using: .utf8)!)
        _ = self.client.send(data: data)
        
        if let resp = self.client.read(4, timeout: 3) {
            let code = String(bytes: resp, encoding: .utf8)!
            print(code)
        }
        
        try? self.engine.start()
        self.engine.mainMixerNode.volume = 0
        isStreaming = true
    }
    
    func stopStream() {
        self.engine.stop()
        isStreaming = false
        self.client.close()
    }
}

extension AVAudioPCMBuffer {
    func toData() -> Data {
        let channelCount = Int(self.format.channelCount)
        let frameLength = Int(self.frameCapacity)
        let sampleWidth = Int(self.format.streamDescription.pointee.mBytesPerFrame)
        
        let data = self.floatChannelData!
        
        let pointer = UnsafeMutablePointer<Float32>.allocate(capacity: frameLength * channelCount)
        defer {
            pointer.deallocate()
        }

        for i in 0..<frameLength {
            for ch in 0..<channelCount {
                pointer[i * channelCount + ch] = data[ch][i]
            }
        }
        return Data(bytes: pointer, count: frameLength * channelCount * sampleWidth)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
