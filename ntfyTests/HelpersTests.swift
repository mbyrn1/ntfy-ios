import Testing
@testable import ntfy

struct HelpersTests {
    @Test(arguments: [
        ("https://ntfy.sh", "https://ntfy.sh"),
        ("https://ntfy.sh/", "https://ntfy.sh"),
        ("https://ntfy.sh///", "https://ntfy.sh"),
        ("  https://example.com/ \n", "https://example.com")
    ])
    func normalizeBaseUrlTrimsWhitespaceAndSlashes(input: String, expected: String) {
        #expect(normalizeBaseUrl(input) == expected)
    }

    @Test func topicUrlJoinsNormalizedBaseUrlAndTopic() {
        #expect(topicUrl(baseUrl: "https://ntfy.sh/", topic: "alerts") == "https://ntfy.sh/alerts")
        #expect(topicAuthUrl(baseUrl: "https://ntfy.sh", topic: "alerts") == "https://ntfy.sh/alerts/auth")
    }

    @Test func topicShortUrlStripsScheme() {
        #expect(topicShortUrl(baseUrl: "https://ntfy.sh", topic: "alerts") == "ntfy.sh/alerts")
        #expect(topicShortUrl(baseUrl: "http://10.0.0.1:8080", topic: "x") == "10.0.0.1:8080/x")
    }

    @Test func topicHashIsStableSha256OfTopicUrl() {
        let hash = topicHash(baseUrl: "https://example.com", topic: "alerts")
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit })
        // Trailing slashes must not change the hash, or self-hosted subscriptions stop matching.
        #expect(hash == topicHash(baseUrl: "https://example.com/", topic: "alerts"))
        #expect(hash != topicHash(baseUrl: "https://example.com", topic: "other"))
    }

    @Test func firebaseTopicUsesPlainTopicOnlyForDefaultServer() {
        #expect(firebaseTopic(baseUrl: Config.appBaseUrl, topic: "alerts") == "alerts")
        #expect(firebaseTopic(baseUrl: Config.appBaseUrl + "/", topic: "alerts") == "alerts")

        let selfHosted = "https://example.com"
        #expect(firebaseTopic(baseUrl: selfHosted, topic: "alerts") == topicHash(baseUrl: selfHosted, topic: "alerts"))
    }

    @Test func parseAllTagsDropsBlankEntries() {
        #expect(parseAllTags("a,b, ,,c") == ["a", "b", "c"])
        #expect(parseAllTags("") == [])
        #expect(parseAllTags(nil) == [])
    }

    @Test func emojiTagsAreSplitFromPlainTags() {
        #expect(parseEmojiTags("tada,backup") == ["🎉"])
        #expect(parseNonEmojiTags("tada,backup") == ["backup"])
    }
}
