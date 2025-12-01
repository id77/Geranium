//
//  BookmarkEditorView.swift
//  Geranium
//
//  Created by Codex on 22.05.2024.
//

import SwiftUI
import CoreLocation

struct BookmarkEditorView: View {
    var mode: BookmarkEditorMode
    var onSave: (String, CLLocationCoordinate2D, String?) -> Void
    var onCancel: () -> Void

    @State private var name: String
    @State private var note: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var showValidationError = false

    init(mode: BookmarkEditorMode, onSave: @escaping (String, CLLocationCoordinate2D, String?) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel

        if let bookmark = mode.existingBookmark {
            _name = State(initialValue: bookmark.name)
            _note = State(initialValue: bookmark.note ?? "")
            _latitude = State(initialValue: String(bookmark.coordinate.latitude))
            _longitude = State(initialValue: String(bookmark.coordinate.longitude))
        } else if let seed = mode.seedLocation {
            // 自动填充地点名称和详细地址
            _name = State(initialValue: seed.label ?? "")
            _note = State(initialValue: seed.note ?? "")
            _latitude = State(initialValue: String(seed.latitude))
            _longitude = State(initialValue: String(seed.longitude))
        } else {
            _name = State(initialValue: "")
            _note = State(initialValue: "")
            _latitude = State(initialValue: "")
            _longitude = State(initialValue: "")
        }
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                editorNavigationStack
            } else {
                editorNavigationView
            }
        }
    }

    @ViewBuilder
    @available(iOS 16.0, *)
    private var editorNavigationStack: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称", text: $name)
                    TextField("备注（可选）", text: $note)
                }

                Section(header: Text("坐标")) {
                    TextField("纬度", text: $latitude)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("经度", text: $longitude)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle(mode.existingBookmark == nil ? "新增收藏" : "编辑收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: validateAndSave)
                }
            }
            .alert(isPresented: $showValidationError) {
                Alert(title: Text("坐标无效"),
                      message: Text("请填写完整的经纬度。"),
                      dismissButton: .default(Text("确定")))
            }
        }
    }

    private var editorNavigationView: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("名称", text: $name)
                    TextField("备注（可选）", text: $note)
                }

                Section(header: Text("坐标")) {
                    TextField("纬度", text: $latitude)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("经度", text: $longitude)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle(mode.existingBookmark == nil ? "新增收藏" : "编辑收藏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: validateAndSave)
                }
            }
            .alert(isPresented: $showValidationError) {
                Alert(title: Text("坐标无效"),
                      message: Text("请填写完整的经纬度。"),
                      dismissButton: .default(Text("确定")))
            }
        }
    }

    private func validateAndSave() {
        guard
            let latitude = Double(latitude),
            let longitude = Double(longitude)
        else {
            showValidationError = true
            return
        }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        onSave(name.isEmpty ? "未命名收藏" : name,
               coordinate,
               note.isEmpty ? nil : note)
    }
}
