//
//  CreateGroupViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data
import UIKit
import Combine
import BaseStyle
import AVFoundation
import FirebaseFirestoreInternal

class CreateGroupViewModel: BaseViewModel, ObservableObject {

    enum GroupType: String, CaseIterable {
        case trip = "Trip"
        case home = "Home"
        case couple = "Couple"
        case other = "Other"
    }

    @Inject var preference: SplitoPreference
    @Inject var storageManager: StorageManager
    @Inject var groupRepository: GroupRepository
    @Inject var memberRepository: MemberRepository

    @Published var groupName = ""
    @Published var sourceTypeIsCamera = false
    @Published var showImagePicker = false
    @Published var showImagePickerOptions = false
    @Published var profileImage: UIImage?

    @Published var selectedGroupType: GroupType?
    @Published var currentState: ViewState = .initial

    let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
    }

    func checkCameraPermission(authorized: @escaping (() -> Void)) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    authorized()
                }
            }
            return
        case .restricted, .denied:
            showAlertFor(alert: .init(title: "Important!", message: "Camera access is required to take picture for your profile",
                                      positiveBtnTitle: "Allow", positiveBtnAction: { [weak self] in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                self?.showAlert = false
            }))
        case .authorized:
            authorized()
        default:
            return
        }
    }

    func handleActionSelection(_ action: ActionsOfSheet) {
        switch action {
        case .camera:
            self.checkCameraPermission {
                self.sourceTypeIsCamera = true
                self.showImagePicker = true
            }
        case .gallery:
            sourceTypeIsCamera = false
            showImagePicker = true
        case .remove:
            profileImage = nil
        }
    }

    func handleProfileTap() {
        showImagePickerOptions = true
    }

    /// Create a new group
    func handleDoneAction() {
        currentState = .loading
        let userId = preference.user?.id ?? ""
        let group = Groups(name: groupName, createdBy: userId, members: [], imageUrl: nil, createdAt: Timestamp())

        let resizedImage = profileImage?.aspectFittedToHeight(200)
        let imageData = resizedImage?.jpegData(compressionQuality: 0.2)

        groupRepository.createGroup(group: group, imageData: imageData)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.currentState = .initial
                    self?.showAlertFor(error)
                }
            } receiveValue: { id in
                self.goToGroupHome(groupId: id)
            }.store(in: &cancelables)
    }

    func goToGroupHome(groupId: String) {
        self.router.pop()
        self.router.push(.GroupHomeView(groupId: groupId))
    }
}

// MARK: - Action sheet Struct
extension CreateGroupViewModel {
    enum ActionsOfSheet {
        case camera
        case gallery
        case remove
    }
}

// MARK: - View's State
extension CreateGroupViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
