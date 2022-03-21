struct Dog: Codable {
    let id: Int64
    let name: String
    var owner: Person?
}
