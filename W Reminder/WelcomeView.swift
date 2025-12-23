//
//  WelcomeView.swift
//  W Reminder
//
//  Created for Guest Mode (Redesigned)
//

import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void
    
    // Animation States
    @State private var isAnimating = false
    @State private var showText = false
    @State private var showButton = false
    
    // Gradient Animation
    @State private var gradientStart = UnitPoint(x: 0, y: -2)
    @State private var gradientEnd = UnitPoint(x: 4, y: 0)
    
    var body: some View {
        ZStack {
            // Animated Background
            LinearGradient(colors: [
                Color(hex: "02050E"), // Almost Black
                Color(hex: "1F1C2C"), // Deep Purple/Blue
                Color(hex: "232526")  // Dark Grey
            ], startPoint: gradientStart, endPoint: gradientEnd)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 15).repeatForever(autoreverses: true)) {
                    gradientStart = UnitPoint(x: 4, y: 2)
                    gradientEnd = UnitPoint(x: 0, y: -2)
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated CSS-style Logo
                ZStack {
                    // Pulse Ring 1
                    Circle()
                        .stroke(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                        .frame(width: 220, height: 220)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 0.3 : 0)
                    
                    // Pulse Ring 2
                    Circle()
                        .fill(Color(hex: "5D5FEF").opacity(0.1))
                        .frame(width: 180, height: 180)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .blur(radius: 20)
                    
                    // Main Gradient Circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "5D5FEF"), Color(hex: "9D50BB")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "5D5FEF").opacity(0.6), radius: 20, y: 10)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    // "W" Icon / Logo
                    // Using a stylized W composed of rounded paths or just text for reliability
                    Text("W")
                        .font(.system(size: 70, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 5)
                        .rotation3DEffect(.degrees(isAnimating ? 0 : 20), axis: (x: 0, y: 1, z: 0))
                }
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
                .rotation3DEffect(.degrees(isAnimating ? 0 : -30), axis: (x: 1, y: 0, z: 0))
                
                // Text Content
                VStack(spacing: 16) {
                    Text("W Reminder")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: showText ? 0 : 20)
                        .opacity(showText ? 1 : 0)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                    
                    Text("Organize your life\nwith style and simplicity.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(6)
                        .offset(y: showText ? 0 : 20)
                        .opacity(showText ? 1 : 0)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Get Started Button
                Button {
                    // Haptic & Action
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        onGetStarted()
                    }
                } label: {
                    HStack {
                        Text("Get Started")
                            .font(.headline.bold())
                        Image(systemName: "arrow.right")
                            .bold()
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "5D5FEF"), Color(hex: "3B3DBF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color(hex: "5D5FEF").opacity(0.4), radius: 15, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .scaleEffect(showButton ? 1 : 0.9)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .offset(y: showButton ? 0 : 50)
                .opacity(showButton ? 1 : 0)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Logo Animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            isAnimating = true
        }
        
        // Text Animation
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            showText = true
        }
        
        // Button Animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2)) {
            showButton = true
        }
    }
}
