import Testing
@testable import ntfy

@MainActor
struct DisplayNameTests {
    let store = Store(inMemory: true)

    private func subscription(customDisplayName: String? = nil) -> Subscription {
        let subscription = store.saveSubscription(baseUrl: "https://ntfy.sh", topic: "garage")
        subscription.customDisplayName = customDisplayName
        return subscription
    }

    @Test(arguments: [
        (nil, "ntfy.sh/garage"),
        ("", "ntfy.sh/garage"),
        ("Garage door", "Garage door"),
    ] as [(String?, String)])
    func displayNameFallsBackToShortUrl(customDisplayName: String?, want: String) {
        #expect(subscription(customDisplayName: customDisplayName).displayName() == want)
    }

    @Test(arguments: [
        ("  Garage  ", "Garage"),
        (String(repeating: "a", count: 70), String(repeating: "a", count: 64)),
        ("", nil),
        ("   ", nil),
        (nil, nil),
    ] as [(String?, String?)])
    func updateSubscriptionNormalizesName(input: String?, want: String?) {
        let subscription = subscription(customDisplayName: "old")
        store.updateSubscription(subscription: subscription, displayName: input)
        #expect(subscription.customDisplayName == want)
    }

    @Test func updateSubscriptionPersists() throws {
        let subscription = subscription()
        store.updateSubscription(subscription: subscription, displayName: "Garage door")
        store.context.refreshAllObjects()

        let fetched = try #require(store.getSubscription(baseUrl: "https://ntfy.sh", topic: "garage"))
        #expect(fetched.customDisplayName == "Garage door")
        #expect(!store.context.hasChanges)
    }
}
