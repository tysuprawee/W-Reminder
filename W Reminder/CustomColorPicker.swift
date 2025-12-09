//
//  CustomColorPicker.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI

struct CustomColorPicker: View {
    @Binding var selection: Color
    
    private let presets: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown, .gray
    ]
    
    @State private var red: Double = 0
    @State private var green: Double = 0
    @State private var blue: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Presets Grid
            LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 40)), count: 6), spacing: 12) {
                ForEach(presets, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                        .onTapGesture {
                            withAnimation {
                                selection = color
                                updateRGB(from: color)
                            }
                        }
                        .scaleEffect(selection == color ? 1.1 : 1.0)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .opacity(selection == color ? 1 : 0)
                        )
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Custom RGB
            VStack(spacing: 12) {
                HStack {
                    Text("R").font(.caption.bold()).foregroundStyle(.red)
                    Slider(value: $red, in: 0...1)
                        .tint(.red)
                }
                HStack {
                    Text("G").font(.caption.bold()).foregroundStyle(.green)
                    Slider(value: $green, in: 0...1)
                        .tint(.green)
                }
                HStack {
                    Text("B").font(.caption.bold()).foregroundStyle(.blue)
                    Slider(value: $blue, in: 0...1)
                        .tint(.blue)
                }
            }
            .padding(.horizontal)
            .onChange(of: red) { _, _ in updateSelection() }
            .onChange(of: green) { _, _ in updateSelection() }
            .onChange(of: blue) { _, _ in updateSelection() }
            
            // Preview
            RoundedRectangle(cornerRadius: 12)
                .fill(selection)
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .padding()
        }
        .onAppear {
            updateRGB(from: selection)
        }
    }
    
    private func updateSelection() {
        selection = Color(red: red, green: green, blue: blue)
    }
    
    private func updateRGB(from color: Color) {
        // This is tricky because SwiftUI Color doesn't easily expose RGB components
        // But for our Tag system which uses hex, we might re-initialize Color from our known hex/components
        // For simplicity in this demo, we trust the sliders update the selection,
        // and presets update the sliders only if we can exact match or just set them approximately.
        // A robust solution usually involves storing the source components state.
        
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
    }
}
