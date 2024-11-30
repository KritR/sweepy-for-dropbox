//
//  Button.swift
//  cloudsweeper
//
//  Created by Krithik Rao on 7/3/24.
//

import SwiftUI

struct BoxyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .monospaced()
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .padding()
            .background(Color(hue: 0.14, saturation: 0.16, brightness: isEnabled ? 0.97 : 0.8))
            .foregroundColor(.black)
            .cornerRadius(0)
            .controlSize(.large)
            .clipped()
            .shadow(color: Color(hue: 0, saturation: 0, brightness: isEnabled ? 0 : 0.2), radius: 0, x: configuration.isPressed ? 0 : 8, y: configuration.isPressed ? 1 : 8)
            .offset(x: configuration.isPressed ? 8 : 0,  y: configuration.isPressed ? 8 : 0) // 2
            .animation(.interactiveSpring(duration: 0.03), value: configuration.isPressed) // 3
            .strikethrough(!isEnabled)
    }
}



#Preview {
    VStack(alignment: .leading, spacing: 20) {
        Button("moo") { }.buttonStyle(BoxyButtonStyle())
        Button("moo") { }.buttonStyle(BoxyButtonStyle()).disabled(true)
    }.padding(30)
}
