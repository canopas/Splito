//
//  GroupSettingView.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import Data
import SwiftUI
import BaseStyle
import Kingfisher

struct GroupSettingView: View {

    @ObservedObject var viewModel: GroupSettingViewModel

    var body: some View {
        VStack {
            if case .loading = viewModel.currentViewState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else if case .initial = viewModel.currentViewState {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        VSpacer(20)

                        GroupTitleView(group: viewModel.group)
                            .onTouchGesture {
                                viewModel.handleEditGroupTap()
                            }

                        GroupMembersView(members: viewModel.members, onAddMemberTap: viewModel.handleAddMemberTap) { user in
                            viewModel.handleMemberTap(member: user)
                        }

                        GroupAdvanceSettingsView(onLeaveGroupTap: viewModel.handleLeaveGroupTap,
                                                 onDeleteGroupTap: viewModel.handleLeaveGroupTap)
                    }
                }
            }
        }
        .background(backgroundColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
        .navigationBarTitle("Group settings", displayMode: .inline)
        .confirmationDialog("", isPresented: $viewModel.showLeaveGroupDialog, titleVisibility: .hidden) {
            // Show disable when member has debt
            Button("Leave Group") {
                viewModel.showAlert = true
            }
        }
        .confirmationDialog("", isPresented: $viewModel.showRemoveMemberDialog, titleVisibility: .hidden) {
            // Show disable when member has debt
            Button("Remove from group") {
                viewModel.showAlert = true
            }
        }
    }
}

private struct GroupTitleView: View {

    let group: Groups?

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                GroupProfileImageView(imageUrl: group?.imageUrl)

                Text(group?.name ?? "")
                    .font(.subTitle1())
                    .foregroundColor(primaryText)

                Spacer()

                Text("Edit")
                    .font(.bodyBold(17))
                    .foregroundColor(primaryColor)
            }
            .padding(.horizontal, 22)

            Divider()
                .frame(height: 1)
                .background(disableLightText)
        }
    }
}

private struct GroupMembersView: View {

    var members: [AppUser]
    var onAddMemberTap: () -> Void
    var onMemberTap: (AppUser) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Group members")
                .font(.subTitle2())
                .foregroundColor(primaryText)

            GroupListEditCellView(icon: "person.badge.plus", text: "Add people to group", onTap: onAddMemberTap)

            LazyVStack(spacing: 20) {
                ForEach(members) { member in
                    GroupMemberCellView(member: member)
                        .onTouchGesture {
                            onMemberTap(member)
                        }
                }
            }
        }
        .padding(.horizontal, 22)
    }
}

private struct GroupAdvanceSettingsView: View {

    var onLeaveGroupTap: () -> Void
    var onDeleteGroupTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced settings")
                .font(.subTitle2())
                .foregroundColor(primaryText)

            GroupListEditCellView(icon: "arrow.left.square", text: "Leave group",
                                  isDistructive: true, onTap: onLeaveGroupTap)

            GroupListEditCellView(icon: "trash", text: "Delete group",
                                  isDistructive: true, onTap: onDeleteGroupTap)
        }
        .padding(.horizontal, 22)
    }
}

private struct GroupListEditCellView: View {

    var icon: String
    var text: String
    var isDistructive: Bool = false

    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 22, height: 22)

            Text(text)
                .font(.subTitle2())
        }
        .frame(height: 40)
        .padding(.leading, 16)
        .foregroundColor(isDistructive ? awarenessColor : primaryText)
        .onTouchGesture {
            onTap()
        }
    }
}

private struct GroupMemberCellView: View {

    @Inject var preference: SplitoPreference

    let member: AppUser
    var userName: String?
    var subInfo: String?

    init(member: AppUser) {
        self.member = member
        if let user = preference.user, member.id == user.id {
            userName = "You"
        } else {
            userName = (member.firstName ?? "") + " " + (member.lastName ?? "")
        }
        userName = (userName ?? "").isEmpty ? "Unknown" : userName

        if let emailId = member.emailId {
            subInfo = emailId
        } else if let phoneNumber = member.phoneNumber {
            subInfo = phoneNumber
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            MemberProfileImageView(imageUrl: member.imageUrl)

            VStack(alignment: .leading, spacing: 5) {
                Text(userName ?? "")
                    .lineLimit(1)
                    .font(.subTitle2())
                    .foregroundColor(primaryText)

                Text(subInfo ?? "")
                    .lineLimit(1)
                    .font(.subTitle3())
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Text("settled up")
                .font(.subTitle3())
                .foregroundColor(secondaryText)
        }
    }
}

#Preview {
    GroupSettingView(viewModel: GroupSettingViewModel(router: .init(root: .GroupSettingView(groupId: "")), groupId: ""))
}
