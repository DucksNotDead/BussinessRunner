import SwiftUI

struct EnvironmentTab: View {
    @Binding var project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Технологии, железо и переменные окружения. Сдвиг env vars на Save создаёт тикет migration.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ForEach($project.environments) { $env in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                TextField("dev", text: $env.name)
                                    .font(.title2.weight(.semibold))
                                    .textFieldStyle(.plain)
                                Spacer()
                                HashCapsule(hash: env.hash)
                            }
                            BRField(label: "Технологии", prompt: "стек", text: $env.technologies)
                            BRField(label: "Железо", prompt: "Mac mini", text: $env.hardware)
                            BRField(label: "GitHub URL агента", prompt: "https://github.com/…", text: $project.githubURL)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Переменные окружения")
                                    .font(.subheadline.weight(.semibold))
                                ForEach($env.variables) { $variable in
                                    HStack(spacing: 8) {
                                        TextField("NAME", text: $variable.name)
                                            .textFieldStyle(.plain)
                                            .font(.body.monospaced())
                                            .padding(10)
                                            .brSurface(radius: BR.field, interactive: false)
                                        TextField("value", text: $variable.value)
                                            .textFieldStyle(.plain)
                                            .padding(10)
                                            .brSurface(radius: BR.field, interactive: false)
                                        IconCircleButton(systemName: "xmark", role: .destructive) {
                                            env.variables.removeAll { $0.id == variable.id }
                                        }
                                    }
                                }
                                Button {
                                    env.variables.append(EnvVariable(name: "", value: ""))
                                } label: {
                                    Label("Переменная", systemImage: "plus")
                                }
                                .brGlass()
                            }
                        }
                    }
                }
                Button {
                    project.environments.append(DevEnvironment(name: "dev-\(project.environments.count + 1)", technologies: "", hardware: ""))
                } label: {
                    Label("Добавить среду", systemImage: "plus")
                }
                .brGlass()
            }
            .padding(28)
        }
    }
}

struct EntitiesTab: View {
    @Binding var project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("User всегда есть и хешируется. Изменение сущностей на Save создаёт тикет migration.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
                Button {
                    project.entities.append(Entity(name: "NewEntity"))
                } label: {
                    Label("Добавить сущность", systemImage: "plus")
                }
                .brGlass()
            }
            .padding(28)
        }
        .onAppear { ProjectFactory.ensureUser(&project) }
    }
}

struct RolesTab: View {
    @Binding var project: Project

    var body: some View {
        catalogList(
            hint: "Опционально. На Save файл roles.md всё равно будет записан.",
            addTitle: "Добавить роль",
            add: { project.roles.append(Role(name: "")) }
        ) {
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
        catalogList(
            hint: "Опционально. Агент следует им, только если не противоречат readme.md.",
            addTitle: "Добавить правило",
            add: { project.rules.append(UserRule(name: "", body: "")) }
        ) {
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

private func catalogList<Content: View>(hint: String, addTitle: String, add: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text(hint).font(.callout).foregroundStyle(.secondary)
            content()
            Button(action: add) {
                Label(addTitle, systemImage: "plus")
            }
            .brGlass()
        }
        .padding(28)
    }
}
