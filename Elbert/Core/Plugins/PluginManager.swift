//
//  PluginManager.swift
//  Elbert
//

import Foundation

struct LoadedPlugin: Sendable {
    let name: String
    let commands: [PluginCommand]
}

actor PluginManager {
    private(set) var plugins: [LoadedPlugin] = []

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func reloadPlugins() async -> [LoadedPlugin] {
        let directory = pluginDirectoryURL()
        createDirectoryIfNeeded(at: directory)
        createSamplePluginIfMissing(in: directory)

        let manifestFiles = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension.lowercased() == "json" } ?? []

        let loaded: [LoadedPlugin] = manifestFiles.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let manifest = parseManifest(from: data) else {
                return nil
            }
            return LoadedPlugin(name: manifest.name, commands: manifest.commands)
        }

        plugins = loaded
        return loaded
    }

    nonisolated func pluginDirectoryURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Elbert/Plugins", isDirectory: true)
    }

    private func createDirectoryIfNeeded(at url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func createSamplePluginIfMissing(in directory: URL) {
        let sample = directory.appendingPathComponent("sample-plugin.json")
        guard !fileManager.fileExists(atPath: sample.path) else { return }

        let sampleManifest = PluginManifest(
            name: "Built-in Examples",
            commands: [
                PluginCommand(
                    id: "open-apple",
                    title: "Open Apple",
                    subtitle: "https://apple.com",
                    action: .init(type: "url", value: "https://apple.com")
                )
            ]
        )

        guard let data = makeManifestJSONData(sampleManifest) else { return }
        try? data.write(to: sample, options: .atomic)
    }

    private func parseManifest(from data: Data) -> PluginManifest? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["name"] as? String,
              let commandObjects = object["commands"] as? [[String: Any]] else {
            return nil
        }

        let commands: [PluginCommand] = commandObjects.compactMap { command in
            guard let id = command["id"] as? String,
                  let title = command["title"] as? String,
                  let subtitle = command["subtitle"] as? String,
                  let actionObject = command["action"] as? [String: Any],
                  let type = actionObject["type"] as? String,
                  let value = actionObject["value"] as? String else {
                return nil
            }

            return PluginCommand(
                id: id,
                title: title,
                subtitle: subtitle,
                action: .init(type: type, value: value)
            )
        }

        return PluginManifest(name: name, commands: commands)
    }

    private func makeManifestJSONData(_ manifest: PluginManifest) -> Data? {
        let object: [String: Any] = [
            "name": manifest.name,
            "commands": manifest.commands.map { command in
                [
                    "id": command.id,
                    "title": command.title,
                    "subtitle": command.subtitle,
                    "action": [
                        "type": command.action.type,
                        "value": command.action.value
                    ]
                ]
            }
        ]
        return try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }
}
