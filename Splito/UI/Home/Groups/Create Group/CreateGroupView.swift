//
//  CreateGroupView.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import SwiftUI
import BaseStyle

struct CreateGroupView: View {

    @ObservedObject var viewModel: CreateGroupViewModel

    var body: some View {
        VStack {
            if case .loading = viewModel.currentState {
                LoaderView(tintColor: primaryColor, scaleSize: 2)
            } else {
                VStack(spacing: 40) {
                    VSpacer(30)

                    AddGroupNameView(image: viewModel.profileImage, groupName: $viewModel.groupName, handleProfileTap: viewModel.handleProfileTap)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: isIpad ? 600 : nil, alignment: .center)
                .navigationBarTitle("Create a group", displayMode: .inline)
            }
        }
        .background(surfaceColor)
        .toastView(toast: $viewModel.toast)
        .backport.alert(isPresented: $viewModel.showAlert, alertStruct: viewModel.alert)
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
        .confirmationDialog("", isPresented: $viewModel.showImagePickerOptions, titleVisibility: .hidden) {
            Button("Take Picture") {
                viewModel.handleActionSelection(.camera)
            }
            Button("Choose from Library") {
                viewModel.handleActionSelection(.gallery)
            }
            if viewModel.profileImage != nil {
                Button("Remove") {
                    viewModel.handleActionSelection(.remove)
                }
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(cropOption: .square,
                            sourceType: !viewModel.sourceTypeIsCamera ? .photoLibrary : .camera,
                            image: $viewModel.profileImage, isPresented: $viewModel.showImagePicker)
        }
        .navigationBarItems(
            trailing: Button("Done") {
                viewModel.handleDoneAction()
            }
            .font(.subTitle2())
            .tint(primaryColor)
            .disabled(viewModel.groupName.count < 3 || viewModel.currentState == .loading)
        )
    }
}

private struct AddGroupNameView: View {

    var image: UIImage?
    @Binding var groupName: String

    let handleProfileTap: (() -> Void)

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "camera")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 56, height: 55)
            .background(secondaryText.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundColor(secondaryText)
            .onTapGesture {
                handleProfileTap()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Group name")
                    .font(.subTitle4())
                    .foregroundColor(secondaryText)

                VSpacer(2)

                TextField("", text: $groupName)

                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct GroupTypeSelectionView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Type")
                .font(.subTitle4())
                .foregroundColor(secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CreateGroupViewModel.GroupType.allCases, id: \.self) { type in
                        Button {

                        } label: {
                            Text(type.rawValue)
                                .font(.subTitle3())
                                .foregroundColor(secondaryText)
//                                .foregroundColor(viewModel.selectedGroupType == type ? .white : .primary)
//                                .background(viewModel.selectedGroupType == type ? Color.blue : Color.clear)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(secondaryText.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .padding(1)
            }
        }
    }
}

#Preview {
    CreateGroupView(viewModel: CreateGroupViewModel(router: .init(root: .CreateGroupView)))
}
