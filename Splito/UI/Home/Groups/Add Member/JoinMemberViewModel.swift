//
//  JoinMemberViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 13/03/24.
//

import Data
import BaseStyle

class JoinMemberViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var memberRepository: MemberRepository
    @Inject var codeRepository: ShareCodeRepository

    @Published var code = ""
    @Published private(set) var currentState: ViewState = .initial

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
    }

    func joinMemberWithCode() {
        currentState = .loading
        codeRepository.fetchSharedCode(code: code)
            .sink { [weak self] completion in
                switch completion {
                case .failure(let error):
                    self?.currentState = .initial
                    self?.showToastFor(error)
                case .finished:
                    self?.currentState = .initial
                }
            } receiveValue: { [weak self] code in
                guard let self else { return }

                guard let code else {
                    self.showToastFor(toast: ToastPrompt(type: .error, title: "Error", message: "Your entered code not exists."))
                    return
                }

                self.addMember(groupId: code.groupId) {
                    _ = self.codeRepository.deleteSharedCode(documentId: code.id ?? "")
                    self.goToGroupHome()
                }
            }.store(in: &cancelables)
    }

    // Add member to the collection
    func addMember(groupId: String, completion: @escaping () -> Void) {
        guard let userId = preference.user?.id else { return }
        currentState = .loading

        let member = Member(userId: userId, groupId: groupId)

        memberRepository.addMemberToMembers(member: member) { [weak self] memberId in
            guard let self, let memberId else {
                self?.showAlertFor(message: "Something went wrong")
                return
            }
            self.groupRepository.addMemberToGroup(groupId: groupId, memberId: memberId)
                .sink { [weak self] result in
                    switch result {
                    case .failure(let error):
                        self?.currentState = .initial
                        self?.showToastFor(error)
                        completion()
                    case .finished:
                        self?.currentState = .initial
                    }
                } receiveValue: { _ in
                    completion()
                }.store(in: &self.cancelables)
        }
    }

    func goToGroupHome() {
        self.router.pop()
    }
}

// MARK: - View's State
extension JoinMemberViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
