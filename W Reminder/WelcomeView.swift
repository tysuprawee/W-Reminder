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
            // Animated Background (Light Theme)
            LinearGradient(colors: [
                Color(hex: "FFF8D4"), // Classic Background
                Color(hex: "FFFFFF"), // White
                Color(hex: "FFF0E0")  // Soft Warmth
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
                
                // Animated Logo Image
                ZStack {
                    // Glow Effect (Subtle for Light Mode)
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(Color(hex: "FFD700").opacity(0.4))
                        .frame(width: 220, height: 220)
                        .blur(radius: 30)
                        .scaleEffect(isAnimating ? 1.1 : 0.8)
                        .opacity(isAnimating ? 0.6 : 0)
                    
                    Image("Wreminder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .stroke(.white.opacity(0.5), lineWidth: 2)
                        )
                        .rotation3DEffect(.degrees(isAnimating ? 0 : 180), axis: (x: 0, y: 1, z: 0)) // Flip in
                }
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
                .rotationEffect(.degrees(isAnimating ? 0 : -10))
                
                // Text Content
                VStack(spacing: 16) {
                    Text("W Reminder")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "2C3E50")) // Dark Primary
                        .offset(y: showText ? 0 : 20)
                        .opacity(showText ? 1 : 0)
                    
                    Text("Organize your life\nwith style and simplicity.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(hex: "2C3E50").opacity(0.8)) // Dark Secondary
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
                    .foregroundStyle(.white) // Keep Text White
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6B8E23"), Color(hex: "556B2F")], // Green Accent
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color(hex: "6B8E23").opacity(0.4), radius: 15, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
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
        // Play Welcome Sound
        SoundPlayer.shared.playSound(named: "logo.mp3")
        
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
