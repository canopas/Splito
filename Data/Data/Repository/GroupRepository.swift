//
//  GroupRepository.swift
//  Data
//
//  Created by Amisha Italiya on 07/03/24.
//

import Combine

public class GroupRepository: ObservableObject {

    @Inject private var store: GroupStore

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var storageManager: StorageManager

    private var cancelable = Set<AnyCancellable>()

    public func createGroup(group: Groups, imageData: Data?) -> AnyPublisher<String, ServiceError> {
        return store.createGroup(group: group)
            .flatMap { [weak self] groupId -> AnyPublisher<String, ServiceError> in
                guard let self else { return Fail(error: .unexpectedError).eraseToAnyPublisher() }
                guard let imageData else {
                    return Just(groupId).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
                }

                var newGroup = group
                newGroup.id = groupId

                return self.uploadImage(imageData: imageData, group: newGroup)
                    .map { _ in groupId }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func uploadImage(imageData: Data, group: Groups) -> AnyPublisher<Void, ServiceError> {
        guard let groupId = group.id else {
            return Fail(error: .unexpectedError).eraseToAnyPublisher()
        }

        return storageManager.uploadImage(for: .group, id: groupId, imageData: imageData)
            .flatMap { imageUrl -> AnyPublisher<Void, ServiceError> in
                var newGroup = group
                newGroup.imageUrl = imageUrl
                return self.updateGroup(group: newGroup)
            }
            .eraseToAnyPublisher()
    }

    public func updateGroup(group: Groups) -> AnyPublisher<Void, ServiceError> {
        store.updateGroup(group: group)
    }

    public func updateGroupWithImage(imageData: Data?, newImageUrl: String?, group: Groups) -> AnyPublisher<Void, ServiceError> {
        var newGroup = group

        if let currentUrl = group.imageUrl, newImageUrl == nil {
            newGroup.imageUrl = newImageUrl

            return storageManager.deleteImage(imageUrl: currentUrl)
                .flatMap { _ in
                    if let imageData {
                        self.uploadImage(imageData: imageData, group: newGroup)
                    } else {
                        self.updateGroup(group: newGroup)
                    }
                }
                .eraseToAnyPublisher()
        }

        if let imageData {
            return self.uploadImage(imageData: imageData, group: newGroup)
        } else {
            return updateGroup(group: newGroup)
        }
    }

    public func fetchGroupBy(id: String) -> AnyPublisher<Groups?, ServiceError> {
        store.fetchGroupBy(id: id)
    }

    public func fetchGroups(userId: String) -> AnyPublisher<[Groups], ServiceError> {
        Future { [weak self] promise in
            guard let self else { return }

            self.store.fetchGroups()
                .sink { completion in
                    if case .failure(let error) = completion {
                        promise(.failure(error))
                    }
                } receiveValue: { groups in
                    // Show only those groups in which the user is part of
                    let filteredGroups = groups.filter { $0.createdBy == userId || $0.members.contains { $0 == userId } }
                    promise(.success(filteredGroups))
                }.store(in: &self.cancelable)
        }.eraseToAnyPublisher()
    }

    public func addMemberToGroup(memberId: String, groupId: String) -> AnyPublisher<Void, ServiceError> {
        return fetchGroupBy(id: groupId)
            .flatMap { group -> AnyPublisher<Void, ServiceError> in
                guard var group else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }

                // Check if the member already exists in the group
                if group.members.contains(memberId) {
                    return Fail(error: .alreadyExists).eraseToAnyPublisher()
                }

                group.members.append(memberId)
                return self.updateGroup(group: group)
            }
            .eraseToAnyPublisher()
    }

    public func fetchMembersBy(groupId: String) -> AnyPublisher<[AppUser], ServiceError> {
        fetchGroupBy(id: groupId)
            .flatMap { group -> AnyPublisher<[AppUser], ServiceError> in
                guard let group else {
                    return Fail(error: .dataNotFound).eraseToAnyPublisher()
                }

                // Create a publisher for each member ID and fetch user data
                let memberPublishers = group.members.map { (userId: String) -> AnyPublisher<AppUser?, ServiceError> in
                    return self.fetchMemberBy(userId: userId)
                }

                return Publishers.MergeMany(memberPublishers)
                    .compactMap { $0 }
                    .collect()
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    public func fetchMemberBy(userId: String) -> AnyPublisher<AppUser?, ServiceError> {
        userRepository.fetchUserBy(userID: userId)
    }

    public func removeMemberFrom(group: Groups, memberId: String) -> AnyPublisher<Void, ServiceError> {
        var newGroup = group
        newGroup.members.removeAll(where: { $0 == memberId })
        if newGroup.members.isEmpty {
            return deleteGroup(groupID: newGroup.id ?? "")
        } else {
            return updateGroup(group: newGroup)
        }
    }

    public func deleteGroup(groupID: String) -> AnyPublisher<Void, ServiceError> {
        store.deleteGroup(groupID: groupID)
    }
}
