import ProjectDescription

let project = Project(
    name: "CoreDataStack",
    packages: [
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        "MACOSX_DEPLOYMENT_TARGET": "15.0",
        "ENABLE_MODULE_VERIFIER": "YES"
    ]),
    targets: [
        .target(
            name: "CoreDataStack",
            destinations: [.iPhone, .mac],
            product: .framework,
            bundleId: "dev.jano.coredatastack",
            sources: ["Sources/Main/**"],
            scripts: [
                swiftlintScript()
            ],
            dependencies: [
            ]
        ),
        .target(
            name: "CoreDataStackTests",
            destinations: [.iPhone, .mac],
            product: .unitTests,
            bundleId: "dev.jano.coredatastack.test",
            sources: ["Sources/Tests/**"],
            resources: [
                "Sources/Tests/Resources/**",
                "Sources/Tests/Model.xcdatamodeld"
            ],
            dependencies: [
            ],
            additionalFiles: [
                "Package.swift",
                "Project.swift"
            ]
        )
    ],
    schemes: [
       Scheme.scheme(
           name: "CoreDataStack",
           shared: true,
           buildAction: BuildAction.buildAction(
               targets: [TargetReference.target("CoreDataStack")]
           ),
           testAction: .testPlans(
               [Path.path("Sources/Tests/CoreDataStack.xctestplan")],
               configuration: .debug,
               attachDebugger: true
           )
       )
    ]
)

func swiftlintScript() -> ProjectDescription.TargetScript {
    let script = """
    #!/bin/sh
    
    # Check swiftlint
    command -v /opt/homebrew/bin/swiftlint >/dev/null 2>&1 || { echo >&2 "swiftlint not found at /opt/homebrew/bin/swiftlint. Aborting."; exit 1; }

    # Create a temp file
    temp_file=$(mktemp)

    # Gather all modified and stopiced files within the Sources directory
    git ls-files -m Sources | grep ".swift$" > "${temp_file}"
    git diff --name-only --cached Sources | grep ".swift$" >> "${temp_file}"

    # Make list of unique and sorterd files
    counter=0
    for f in $(sort "${temp_file}" | uniq)
    do
        eval "export SCRIPT_INPUT_FILE_$counter=$f"
        counter=$(expr $counter + 1)
    done

    # Lint
    if [ $counter -gt 0 ]; then
        export SCRIPT_INPUT_FILE_COUNT=${counter}
        /opt/homebrew/bin/swiftlint autocorrect --use-script-input-files
    fi
    """
    return .post(script: script, name: "Swiftlint", basedOnDependencyAnalysis: false, runForInstallBuildsOnly: false, shellPath: "/bin/zsh")
}
