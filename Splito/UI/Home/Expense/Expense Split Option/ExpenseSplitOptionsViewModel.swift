//
//  ExpenseSplitOptionsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/04/24.
//

import Data
import Combine
import BaseStyle

class ExpenseSplitOptionsViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published private(set) var totalAmount: Double = 0
    @Published private(set) var splitAmount: Double = 0
    @Published private(set) var totalPercentage: Double = 0
    @Published private(set) var totalShares: Double = 0

    @Published private(set) var groupMembers: [AppUser] = []
    @Published private(set) var shares: [String: Double] = [:]
    @Published private(set) var percentages: [String: Double] = [:]

    @Published var selectedTab: SplitType
    @Published private(set) var viewState: ViewState = .initial

    @Published var selectedMembers: [String] {
        didSet {
            splitAmount = totalAmount / Double(selectedMembers.count)
        }
    }

    var isAllSelected: Bool {
        members.count == selectedMembers.count
    }

    private var members: [String] = []
    private var handleSplitTypeSelection: ((_ members: [String], _ percentages: [String: Double], _ shares: [String: Double], _ splitType: SplitType) -> Void)

    init(amount: Double, splitType: SplitType = .equally, splitData: [String: Double]? = nil, members: [String], selectedMembers: [String], handleSplitTypeSelection: @escaping ((_ members: [String], _ percentages: [String: Double], _ shares: [String: Double], _ splitType: SplitType) -> Void)) {
        self.totalAmount = amount
        self.selectedTab = splitType
        self.members = members
        self.selectedMembers = selectedMembers
        self.handleSplitTypeSelection = handleSplitTypeSelection
        super.init()

        if splitType == .percentage {
            self.percentages = splitData ?? [:]
        } else if splitType == .shares {
            self.shares = splitData ?? [:]
            self.totalShares = splitData?.values.reduce(0, +) ?? 0
        }
        fetchUsersData()
        splitAmount = totalAmount / Double(selectedMembers.count)
    }

    private func fetchUsersData() {
        var users: [AppUser] = []
        let queue = DispatchGroup()

        self.viewState = .loading

        for memberId in members {
            queue.enter()
            userRepository.fetchUserBy(userID: memberId)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.viewState = .initial
                        self?.showToastFor(error)
                    }
                } receiveValue: { user in
                    guard let user else { return }
                    users.append(user)
                    queue.leave()
                }.store(in: &cancelable)
        }

        queue.notify(queue: .main) {
            self.groupMembers = users
            self.viewState = .initial
        }
    }

    func checkIsMemberSelected(_ memberId: String) -> Bool {
        return selectedMembers.contains(memberId)
    }

    func updatePercentage(for memberId: String, percentage: Double) {
        percentages[memberId] = percentage
        totalPercentage = percentages.values.reduce(0, +)
    }

    func updateShare(for memberId: String, share: Double) {
        shares[memberId] = share
        totalShares = shares.values.reduce(0, +)
    }

    func handleAllBtnAction() {
        if isAllSelected {
            selectedMembers = [preference.user?.id ?? ""]
        } else {
            selectedMembers = members
        }
    }

    func handleMemberSelection(_ memberId: String) {
        if selectedMembers.contains(memberId) {
            selectedMembers.removeAll(where: { $0 == memberId })
        } else {
            selectedMembers.append(memberId)
        }
    }

    func handleDoneAction(completion: @escaping () -> Void) {
        if selectedTab == .equally && selectedMembers.count == 0 {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "You must select at least one person to split with."))
            return
        }

        if selectedTab == .percentage && totalPercentage != 100 {
            if totalPercentage < 100 {
                self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "The shares do not add up to 100%. You are short by \(String(format: "%.0f", 100 - totalPercentage))%"))
            } else if totalPercentage > 100 {
                self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "The shares do not add up to 100%. You are over by \(String(format: "%.0f", totalPercentage - 100))%"))
            }
            return
        }

        if selectedTab == .shares && totalShares <= 0 {
            self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "You must assign a non-zero share to at least one person."))
            return
        }

        handleSplitTypeSelection(selectedMembers, percentages.filter({ $0.value != 0 }), shares.filter({ $0.value != 0 }), selectedTab)
        completion()
    }
}

// MARK: - View States
extension ExpenseSplitOptionsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
