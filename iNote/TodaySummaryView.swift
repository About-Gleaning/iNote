import SwiftUI
import SwiftData

struct TodaySummaryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = TodaySummaryViewModel()
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.primaryText)
                            .frame(width: 44, height: 44)
                    }
                    
                    Text("今日总结")
                        .font(AppFonts.title2())
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                }
                .padding(.horizontal, AppDimens.padding)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .background(AppColors.background)
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch vm.state {
                        case .idle:
                            EmptyView()
                            
                        case .loading:
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding(.top, 100)
                                
                                Text("AI正在生成今日总结...")
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            
                        case .empty:
                            VStack(spacing: 16) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 60))
                                    .foregroundColor(AppColors.secondaryText.opacity(0.5))
                                    .padding(.top, 100)
                                
                                Text("今日还未创建笔记哟～")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            
                        case .success:
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.accent)
                                    
                                    Text("AI生成的今日总结")
                                        .font(AppFonts.headline())
                                        .foregroundColor(AppColors.primaryText)
                                }
                                .padding(.horizontal, AppDimens.padding)
                                
                                Text(vm.summary)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.primaryText)
                                    .lineSpacing(6)
                                    .padding(AppDimens.padding)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal, AppDimens.padding)
                            }
                            .padding(.top, 20)
                            
                        case .error:
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 60))
                                    .foregroundColor(AppColors.error.opacity(0.7))
                                    .padding(.top, 100)
                                
                                Text("生成总结失败")
                                    .font(AppFonts.headline())
                                    .foregroundColor(AppColors.primaryText)
                                
                                Text(vm.errorMessage)
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button(action: {
                                    Task {
                                        await vm.loadTodaySummary(context: context)
                                    }
                                }) {
                                    Text("重试")
                                        .font(AppFonts.headline())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .background(AppColors.accent)
                                        .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await vm.loadTodaySummary(context: context)
            }
        }
    }
}

#Preview {
    TodaySummaryView()
        .modelContainer(for: [Note.self, Tag.self, MediaAsset.self])
}
