//
//  StatisticsView.swift
//  W Reminder
//
//  Created for v1.0.4 Insights
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var milestones: [Checklist]
    @Query private var simpleChecklists: [SimpleChecklist]
    
    let theme: Theme
    
    // Animation state
    @State private var isAnimated = false
    
    // Computed Data
    private var chartData: [DailyStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Generate last 7 days
        var days: [Date] = []
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                days.append(date)
            }
        }
        
        // Aggregate Data
        return days.map { date in
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
            
            // Count Milestones
            let milestoneCount = milestones.filter {
                guard let completedAt = $0.completedAt else { return false }
                return completedAt >= date && completedAt < nextDate
            }.count
            
            // Count Simple Checklists
            let checklistCount = simpleChecklists.filter {
                guard let completedAt = $0.completedAt else { return false }
                return completedAt >= date && completedAt < nextDate
            }.count
            
            return DailyStat(date: date, milestoneCount: milestoneCount, simpleCount: checklistCount)
        }
    }
    
    private var totalCompletedThisWeek: Int {
        chartData.reduce(0) { $0 + $1.total }
    }
    
    // New Insights
    private var mostProductiveDay: String {
        // Find the day object with highest total
        guard let best = chartData.max(by: { $0.total < $1.total }), best.total > 0 else {
            return "-"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: best.date)
    }
    
    private var dailyAverage: String {
        let avg = Double(totalCompletedThisWeek) / 7.0
        return String(format: "%.1f", avg)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Productivity Insights")
                            .font(.title2.bold())
                        Text("Your activity over the last 7 days")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(totalCompletedThisWeek)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.accent)
                                .contentTransition(.numericText())
                            Text("tasks completed")
                                .font(.headline)
                                .foregroundStyle(theme.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(theme.background) // Glassmorphism handled by parent opacity? No, solid bg
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    .padding(.horizontal)
                    
                    // Key Metrics Grid
                    HStack(spacing: 16) {
                        InsightCard(
                            title: "Daily Average",
                            value: dailyAverage,
                            icon: "function",
                            color: .blue
                        )
                        InsightCard(
                            title: "Best Day",
                            value: mostProductiveDay,
                            icon: "trophy.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Chart Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Weekly Trend")
                            .font(.headline)
                        
                        Chart(chartData) { stat in
                            // Stacked Bar for Milestones
                            BarMark(
                                x: .value("Day", stat.weekday),
                                y: .value("Milestones", isAnimated ? stat.milestoneCount : 0)
                            )
                            .foregroundStyle(theme.accent)
                            .cornerRadius(4)
                            
                            // Stacked Bar for Quick Checklists
                            BarMark(
                                x: .value("Day", stat.weekday),
                                y: .value("Quick Tasks", isAnimated ? stat.simpleCount : 0)
                            )
                            .foregroundStyle(theme.accent.opacity(0.5)) // Lighter shade
                            .cornerRadius(4)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartLegend(.visible)
                        .chartForegroundStyleScale([
                            "Milestones": theme.accent,
                            "Quick Tasks": theme.accent.opacity(0.5)
                        ])
                        .frame(height: 250)
                    }
                    .padding()
                    .background(theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    .padding(.horizontal)
                    
                    // Breakdown / Legend info
                    HStack(spacing: 16) {
                        StatBadge(
                            title: "Milestones",
                            count: chartData.reduce(0) { $0 + $1.milestoneCount },
                            color: theme.accent
                        )
                        StatBadge(
                            title: "Quick Tasks",
                            count: chartData.reduce(0) { $0 + $1.simpleCount },
                            color: theme.accent.opacity(0.5)
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                    
                    // Motivation Section
                    VStack(spacing: 8) {
                        Text(generateSmartComment())
                            .font(.headline)
                            .foregroundStyle(theme.primary)
                        
                        Text("\"\(getRandomQuote())\"")
                            .font(.caption.italic())
                            .foregroundStyle(theme.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(theme.background.opacity(0.5).ignoresSafeArea())
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.secondary)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isAnimated = true
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func generateSmartComment() -> String {
        let total = totalCompletedThisWeek
        let activeDays = chartData.filter { $0.total > 0 }.count
        
        if total == 0 {
            return "Ready to start your streak? 🌱"
        } else if total >= 25 {
            return "You are absolutely crushing it! 🚀"
        } else if total >= 15 {
            return "Incredible momentum! ⚡️"
        } else if total >= 8 {
            return "Solid progress this week! 📈"
        } else if activeDays >= 5 {
            return "Great consistency! 🗓️"
        } else {
            return "Every step counts. Keep going! 💪"
        }
    }
    
    private func getRandomQuote() -> String {
        let quotes = [
            "The only way to do great work is to love what you do. – Steve Jobs",
            "Productivity is being able to do things that you were never able to do before. – Franz Kafka",
            "It’s not always that we need to do more but rather that we need to focus on less. – Nathan W. Morris",
            "Starve your distractions, feed your focus.",
            "You don’t have to be great to start, but you have to start to be great. – Zig Ziglar",
            "Efficiency is doing things right. Effectiveness is doing the right things. – Peter Drucker",
            "The secret of getting ahead is getting started. – Mark Twain",
            "If you spend too much time thinking about a thing, you’ll never get it done. – Bruce Lee",
            "Don't wait. The time will never be just right. – Napoleon Hill",
            "Focus on being productive instead of busy. – Tim Ferriss",
            "Discipline is choosing between what you want now and what you want most. – Abraham Lincoln",
            "Amateurs sit and wait for inspiration, the rest of us just get up and go to work. – Stephen King",
            "Action is the foundational key to all success. – Pablo Picasso",
            "Your future is created by what you do today, not tomorrow. – Robert Kiyosaki",
            "Small daily improvements over time lead to stunning results. – Robin Sharma",
            "Don’t count the days, make the days count. – Muhammad Ali",
            "Success is the sum of small efforts, repeated day in and day out. – Robert Collier",
            "The way to get started is to quit talking and begin doing. – Walt Disney",
            "Believe you can and you're halfway there. – Theodore Roosevelt",
            "Do what you can, with what you have, where you are. – Theodore Roosevelt",
            "Excellence is not a skill. It is an attitude. – Ralph Marston",
            "The key is not to prioritize what's on your schedule, but to schedule your priorities. – Stephen Covey"
        ]
        // Use Day-of-year or random? Random for variety on visit.
        return quotes.randomElement() ?? quotes[0]
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title3.bold())
                .layoutPriority(1)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Helper Models
struct DailyStat: Identifiable {
    let id = UUID()
    let date: Date
    let milestoneCount: Int
    let simpleCount: Int
    
    var total: Int { milestoneCount + simpleCount }
    
    var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // Mon, Tue...
        return formatter.string(from: date)
    }
}

struct StatBadge: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text("\(count)")
                    .font(.title3.bold())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
