import SwiftUI

struct EntitiesTab: View {
    @Binding var project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach($project.entities) { $entity in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    TextField("Entity", text: $entity.name)
                                        .font(.title3.weight(.semibold))
                                        .textFieldStyle(.plain)
                                        .disabled(entity.name == "User")
                                    Spacer()
                                    HashCapsule(hash: entity.hash)
                                }
                                ForEach($entity.fields) { $field in
                                    HStack(spacing: 8) {
                                        TextField("поле", text: $field.name)
                                            .textFieldStyle(.plain)
                                            .padding(8)
                                            .brSurface(radius: 10, interactive: false)
                                        TextField("тип", text: $field.type)
                                            .textFieldStyle(.plain)
                                            .padding(8)
                                            .brSurface(radius: 10, interactive: false)
                                            .frame(width: 110)
                                        IconCircleButton(systemName: "xmark", role: .destructive) {
                                            entity.fields.removeAll { $0.id == field.id }
                                        }
                                    }
                                }
                                Button {
                                    entity.fields.append(EntityField(name: "", type: "String"))
                                } label: {
                                    Label("Поле", systemImage: "plus")
                                }
                                .brGlass()
                                BRField(label: "Связи", prompt: "с кем связана", text: $entity.relations, axis: .vertical)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .onAppear { ProjectFactory.ensureUser(&project) }
    }
}

struct RolesTab: View {
    @Binding var project: Project

    var body: some View {
        catalogList {
            ForEach($project.roles) { $role in
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Имя", text: $role.name)
                                .font(.title3.weight(.semibold))
                                .textFieldStyle(.plain)
                            Spacer()
                            HashCapsule(hash: role.hash)
                            IconCircleButton(systemName: "trash", role: .destructive) {
                                project.roles.removeAll { $0.id == role.id }
                            }
                        }
                        BRField(label: "Описание", prompt: "что делает роль", text: $role.description, axis: .vertical)
                    }
                }
            }
        }
    }
}

struct RulesTab: View {
    @Binding var project: Project

    var body: some View {
        catalogList {
            ForEach($project.rules) { $rule in
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Имя", text: $rule.name)
                                .font(.title3.weight(.semibold))
                                .textFieldStyle(.plain)
                            Spacer()
                            HashCapsule(hash: rule.hash)
                            IconCircleButton(systemName: "trash", role: .destructive) {
                                project.rules.removeAll { $0.id == rule.id }
                            }
                        }
                        BRField(label: "Текст", prompt: "правило", text: $rule.body, axis: .vertical)
                    }
                }
            }
        }
    }
}

private func catalogList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
