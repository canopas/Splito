//
//  GroupTotalsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import Combine

class GroupTotalsViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published var viewState: ViewState = .initial

    private let groupId: String
    private var groupMemberData: [AppUser] = []

    init(groupId: String) {
        self.groupId = groupId
        super.init()
    }
}

// MARK: - View States
extension GroupTotalsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}