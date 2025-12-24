//
//  LevelUpCelebrationView.swift
//  W Reminder
//
//  Created for Gamification
//

import SwiftUI

struct LevelUpCelebrationView: View {
    @State private var animateIcon = false
    @State private var animateText = false
    @State private var rotation = 0.0
    
    let level: Int
    
    var body: some View {
        ZStack {
            // Dimmed Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Confetti Layer (Behind Popup)
            ConfettiView()
            
            // Card Content
            VStack(spacing: 20) {
                // Animated Level Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        )
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.white)
                        .shadow(color: .purple, radius: 2, x: 0, y: 2)
                        .rotationEffect(.degrees(rotation))
                }
                .scaleEffect(animateIcon ? 1 : 0.1)
                .opacity(animateIcon ? 1 : 0)
                
                VStack(spacing: 8) {
                    Text("Level Up!")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text("Level \(level)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.5), radius: 5)
                    
                    Text("You're getting stronger!")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .offset(y: animateText ? 0 : 20)
                .opacity(animateText ? 1 : 0)
                
                Button {
                    withAnimation {
                        LevelManager.shared.showLevelUpCelebration = false
                    }
                } label: {
                    Text("Continue")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.top, 10)
                .offset(y: animateText ? 0 : 20)
                .opacity(animateText ? 1 : 0)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
            )
        }
        .onAppear {
            // Haptic Feedback for Impact
            HapticManager.shared.play(.success)
            
            // Play Celebration Sound
            SoundPlayer.shared.playSound(named: "success.mp3")
            
            // Sequence Animations
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animateIcon = true
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateText = true
            }
            
            // Continuous Loop for Star
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
