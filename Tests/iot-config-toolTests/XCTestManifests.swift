import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(iot_config_toolTests.allTests),
    ]
}
#endif
