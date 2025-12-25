//
//  ProfilePopupView.swift
//  W Reminder
//
//  Created for Gamification Profile
//

import SwiftUI

struct ProfilePopupView: View {
    let theme: Theme
    @State private var levelManager = LevelManager.shared
    @State private var streakManager = StreakManager.shared
    @State private var showingPremium = false
    @State private var showingStats = false
    @State private var selectedAchievement: Achievement? // For details popup
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (Level & Avatar placeholder)
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .shadow(color: .purple.opacity(0.5), radius: 10)
                            .overlay(SparkleEffect()) // Reusing our new sparkle effect
                        
                        Text("\(levelManager.currentLevel)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(.top)
                    
                    Text("Level \(levelManager.currentLevel)")
                        .font(.title2.bold())
                    
                    Text("Top Earner")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.yellow.opacity(0.2)))
                }
                
                // EXP Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Experience")
                            .font(.headline)
                        Spacer()
                        Text("\(levelManager.currentExp) XP")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)
                            
                            Capsule()
                                .fill(theme.accent)
                                .frame(width: max(0, min(proxy.size.width * levelManager.expProgress, proxy.size.width)), height: 12)
                        }
                    }
                    .frame(height: 12)
                    
                    Text("\(levelManager.expForNextLevel - levelManager.currentExp) XP to next level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(theme.background) // Or material
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                
                // Streak Section
                HStack(spacing: 20) {
                    VStack {
                        Image(systemName: "flame.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text("\(streakManager.currentStreak)")
                            .font(.title2.bold())
                        Text("Day Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    VStack {
                        Image(systemName: "trophy.fill")
                            .font(.title)
                            .foregroundStyle(.yellow)
                        Text("\(levelManager.unlockedAchievementIds.count)")
                            .font(.title2.bold())
                        Text("Achievements")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Productivity Insights
                Button {
                    // Future Subscription Logic:
                    // Change `isStatsLocked` to `!StoreManager.shared.isPremium` or similar.
                    let isStatsLocked = false 
                    
                    if isStatsLocked {
                        showingPremium = true
                    } else {
                        showingStats = true
                    }
                } label: {
                    HStack {
                         ZStack {
                             Circle().fill(theme.accent.opacity(0.1)).frame(width: 40, height: 40)
                             Image(systemName: "chart.bar.fill")
                                 .foregroundStyle(theme.accent)
                         }
                         VStack(alignment: .leading, spacing: 2) {
                             Text("Productivity Insights")
                                 .font(.headline)
                                 .foregroundStyle(theme.primary)
                             
                             // Optional "Free Preview" label while it's free?
                             // Text("Free Preview").font(.caption).foregroundStyle(.green)
                         }
                         
                         Spacer()
                         
                         // Visual Gate
                         let isStatsLocked = false
                         if isStatsLocked {
                             Image(systemName: "lock.fill")
                                 .foregroundStyle(.secondary)
                         } else {
                             Image(systemName: "chevron.right")
                                 .foregroundStyle(theme.secondary)
                         }
                    }
                    .padding()
                    .background(theme.isDark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
                
                // Achievements Grid (Trophy Room Style)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Trophy Room")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 16)], spacing: 24) {
                        ForEach(Achievement.all) { achievement in
                            let isUnlocked = levelManager.unlockedAchievementIds.contains(achievement.id)
                            TrophyView(achievement: achievement, isUnlocked: isUnlocked, theme: theme)
                                .onTapGesture {
                                    // Show details
                                    selectedAchievement = achievement
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
        .background(theme.background)
        .sheet(isPresented: $showingPremium) {
            PremiumUpgradeView(theme: theme)
        }
        .sheet(isPresented: $showingStats) {
            StatisticsView(theme: theme)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailSheet(achievement: achievement, theme: theme)
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
    }
}

struct AchievementDetailSheet: View {
    let achievement: Achievement
    let theme: Theme
    @State private var levelManager = LevelManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Icon
                let isUnlocked = levelManager.unlockedAchievementIds.contains(achievement.id)
                
                ZStack {
                    Circle()
                        .fill(isUnlocked ? theme.accent.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(isUnlocked ? theme.accent : .gray)
                        .symbolEffect(.bounce, value: isUnlocked) // Subtle bounce if iOS 17+
                }
                .shadow(color: isUnlocked ? theme.accent.opacity(0.4) : .clear, radius: 10)
                
                // Text Info
                VStack(spacing: 8) {
                    Text(achievement.title)
                        .font(.title2.bold())
                        .foregroundStyle(theme.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(achievement.description)
                        .font(.body)
                        .foregroundStyle(theme.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Status Badge
                HStack(spacing: 6) {
                    Image(systemName: isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    Text(isUnlocked ? "Unlocked" : "Locked")
                }
                .font(.caption.bold())
                .foregroundStyle(isUnlocked ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(isUnlocked ? theme.accent : Color.gray.opacity(0.2)))
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(theme.secondary)
                .padding(.bottom)
            }
            .padding(.top, 40)
        }
    }
}

// MARK: - Subviews & Effects

struct TrophyView: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let theme: Theme
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                        ? AnyShapeStyle(LinearGradient(colors: [theme.accent.opacity(0.2), theme.accent.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.gray.opacity(0.1))
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(isUnlocked ? theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isUnlocked ? AnyShapeStyle(LinearGradient(colors: [theme.accent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.gray))
                    .shadow(color: isUnlocked ? theme.accent.opacity(0.5) : .clear, radius: 8)
                
                if isUnlocked {
                    SparkleEffect()
                }
            }
            
            Text(achievement.title)
                .font(.caption.bold())
                .foregroundStyle(isUnlocked ? theme.primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 80)
        }
        .opacity(isUnlocked ? 1.0 : 0.6)
        .scaleEffect(isUnlocked ? 1.0 : 0.9)
    }
}

struct SparkleEffect: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 4, height: 4)
                    .offset(x: isAnimating ? CGFloat.random(in: -25...25) : 0,
                            y: isAnimating ? CGFloat.random(in: -25...25) : 0)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
