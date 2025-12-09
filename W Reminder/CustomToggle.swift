//
//  CustomToggle.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI

struct CustomToggle: View {
    @Binding var isOn: Bool
    
    // Customization
    var activeColor: Color = .blue
    var inactiveColor: Color = .gray.opacity(0.2)
    var thumbColor: Color = .white
    var width: CGFloat = 50
    var height: CGFloat = 28
    
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: height / 2)
                .fill(isOn ? activeColor : inactiveColor)
                .frame(width: width, height: height)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            
            Circle()
                .fill(thumbColor)
                .frame(width: height - 4, height: height - 4)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .padding(2)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

#Preview {
    CustomToggle(isOn: .constant(true))
}
