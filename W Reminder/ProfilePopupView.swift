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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header (Level & Avatar placeholder)
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        
                        Text("\(levelManager.currentLevel)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
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
                    
                    Text("\(levelManager.expForNextLevel - (levelManager.currentExp % 100)) XP to next level")
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
                
                // Premium Banner
                Button {
                    showingPremium = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("W Reminder Pro")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                            Text("Unlock Insights, Icons & More")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.leading, 4)
                        
                        Spacer()
                        
                        Text("Upgrade")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white))
                    }
                    .padding()
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                }
                
                // Achievements List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Achievements")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(Achievement.all) { achievement in
                        let isUnlocked = levelManager.unlockedAchievementIds.contains(achievement.id)
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(isUnlocked ? theme.accent.opacity(0.2) : Color.gray.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: achievement.icon)
                                    .font(.title3)
                                    .foregroundStyle(isUnlocked ? theme.accent : .gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                                Text(achievement.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if isUnlocked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal)
                        .opacity(isUnlocked ? 1.0 : 0.6)
                    }
                }
                .padding(.bottom)
            }
            .padding()
        }
        .background(theme.background) // Ensure background consistent
        .sheet(isPresented: $showingPremium) {
            PremiumUpgradeView(theme: theme)
        }
    }
}
