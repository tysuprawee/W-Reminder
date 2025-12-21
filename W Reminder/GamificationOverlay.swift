import SwiftUI
import Combine

struct GamificationOverlay: View {
    @State private var xpToasts: [XPToast] = []
    @State private var showingAchievement: Achievement?
    @State private var achievementOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // XP Floating Text Overlay
            // We use a GeometryReader to position them generally, or just ZStack alignment
            VStack {
                Spacer()
                ForEach(xpToasts) { toast in
                    Text("+\(toast.amount) XP")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        .scaleEffect(toast.isAnimating ? 1.2 : 0.5)
                        .opacity(toast.opacity)
                        .offset(y: toast.offsetY)
                        .onAppear {
                            // Start Animation
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                if let index = xpToasts.firstIndex(where: { $0.id == toast.id }) {
                                    xpToasts[index].isAnimating = true
                                    xpToasts[index].opacity = 1
                                    xpToasts[index].offsetY = -100 // Float up
                                }
                            }
                            
                            // Fade out
                            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                                if let index = xpToasts.firstIndex(where: { $0.id == toast.id }) {
                                    xpToasts[index].opacity = 0
                                }
                            }
                        }
                }
            }
            .padding(.bottom, 150) // Position near bottom center but above tab bar
            .allowsHitTesting(false)
            
            // Achievement Unlock Modal / Banner
            if let achievement = showingAchievement {
                VStack {
                    HStack(spacing: 16) {
                        Image(systemName: achievement.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(Color.orange))
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Achievement Unlocked!")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Text(achievement.title)
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            
                            Text(achievement.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    )
                    .padding(.horizontal)
                    .padding(.top, 60) // Top safe area
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        withAnimation {
                            showingAchievement = nil
                        }
                    }
                    Spacer()
                }
                .zIndex(100)
            }
        }
        .onReceive(LevelManager.shared.xpGainedSubject) { amount in
            let toast = XPToast(amount: amount)
            xpToasts.append(toast)
            
            // Cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                xpToasts.removeAll(where: { $0.id == toast.id })
            }
            
            // Play sound?
            // SoundPlayer.shared.playXP() 
        }
        .onReceive(LevelManager.shared.achievementUnlockedSubject) { achievement in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showingAchievement = achievement
            }
            
            // Wait and dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation {
                    if showingAchievement?.id == achievement.id {
                        showingAchievement = nil
                    }
                }
            }
        }
    }
}

struct XPToast: Identifiable {
    let id = UUID()
    let amount: Int
    var isAnimating = false
    var opacity: Double = 0
    var offsetY: CGFloat = 0
}
