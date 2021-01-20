//
//  Copyright © 2018 Iterable. All rights reserved.
//

import XCTest

@testable import IterableSDK

class IterableAutoRegistrationTests: XCTestCase {
    private static let apiKey = "zeeApiKey"
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCallDisableAndEnable() {
        let expectation1 = expectation(description: "call register device API")
        let expectation2 = expectation(description: "call registerForRemoteNotifications twice")
        expectation2.expectedFulfillmentCount = 2
        let expectation3 = expectation(description: "call disable on user1@example.com")
        
        let token = "zeeToken".data(using: .utf8)!
        let networkSession = MockNetworkSession(statusCode: 200)
        networkSession.callback = { _, response, _ in
            if let (request, body) = TestUtils.matchingRequest(networkSession: networkSession,
                                                                  response: response,
                                                                  endPoint: Const.Path.registerDeviceToken) {
                // First call, API call to register endpoint
                expectation1.fulfill()
                TestUtils.validate(request: request, requestType: .post, apiEndPoint: Endpoint.api, path: Const.Path.registerDeviceToken, queryParams: [])
                TestUtils.validateMatch(keyPath: KeyPath("device.dataFields.notificationsEnabled"), value: false, inDictionary: body)
            }

            if let (request, body) = TestUtils.matchingRequest(networkSession: networkSession,
                                                                  response: response,
                                                                  endPoint: Const.Path.disableDevice) {
                // Second call, API call to disable endpoint
                expectation3.fulfill()
                TestUtils.validate(request: request, requestType: .post, apiEndPoint: Endpoint.api, path: Const.Path.disableDevice, queryParams: [])
                TestUtils.validateElementPresent(withName: JsonKey.token.jsonKey, andValue: token.hexString(), inDictionary: body)
                TestUtils.validateElementPresent(withName: JsonKey.email.jsonKey, andValue: "user1@example.com", inDictionary: body)
            }
        }

        let config = IterableConfig()
        config.pushIntegrationName = "my-push-integration"
        config.autoPushRegistration = true
        
        let notificationStateProvider = MockNotificationStateProvider(enabled: false, expectation: expectation2)
        
        let internalAPI = IterableAPIInternal.initializeForTesting(apiKey: IterableAutoRegistrationTests.apiKey,
                                                                   config: config,
                                                                   networkSession: networkSession,
                                                                   notificationStateProvider: notificationStateProvider)
        internalAPI.email = "user1@example.com"
        internalAPI.register(token: token)
        internalAPI.email = "user2@example.com"
        
        wait(for: [expectation1, expectation2, expectation3], timeout: testExpectationTimeout)
    }
    
    func testDoNotCallDisableAndEnableWhenSameValue() {
        let expectation1 = expectation(description: "Register for remote notifications called")
        let expectation2 = expectation(description: "Do not call disable device")
        expectation2.isInverted = true
        let expectation3 = expectation(description: "registerDeviceToken is called")
        
        let token = "zeeToken".data(using: .utf8)!
        let networkSession = MockNetworkSession(statusCode: 200)
        networkSession.callback = { _, response, _ in
            if let (request, _) = TestUtils.matchingRequest(networkSession: networkSession,
                                                            response: response,
                                                            endPoint: Const.Path.registerDeviceToken) {
                // First call, API call to register endpoint
                expectation3.fulfill()
                TestUtils.validate(request: request, requestType: .post, apiEndPoint: Endpoint.api, path: Const.Path.registerDeviceToken, queryParams: [])
            }

            if let (_, _) = TestUtils.matchingRequest(networkSession: networkSession,
                                                      response: response,
                                                      endPoint: Const.Path.disableDevice) {
                // Inverted
                expectation2.fulfill()
            }
        }
        let config = IterableConfig()
        config.pushIntegrationName = "my-push-integration"
        config.autoPushRegistration = true
        // notifications are enabled
        let notificationStateProvider = MockNotificationStateProvider(enabled: true, expectation: expectation1)
        
        let internalAPI = IterableAPIInternal.initializeForTesting(apiKey: IterableAutoRegistrationTests.apiKey,
                                                                   config: config, networkSession: networkSession,
                                                                   notificationStateProvider: notificationStateProvider)
        let email = "user1@example.com"
        internalAPI.email = email
        internalAPI.register(token: token)
        internalAPI.email = email
        
        wait(for: [expectation1, expectation3], timeout: testExpectationTimeout)
        wait(for: [expectation2], timeout: testExpectationTimeoutForInverted)
    }
    
    func testDoNotCallDisableOrEnableWhenAutoPushIsOff() {
        let expectation1 = expectation(description: "do not call register for remote")
        expectation1.isInverted = true
        let expectation2 = expectation(description: "Do not call disable device")
        expectation2.isInverted = true
        let expectation3 = expectation(description: "registerDeviceToken is called")

        let token = "zeeToken".data(using: .utf8)!
        let networkSession = MockNetworkSession()
        networkSession.callback = { _, response, _ in
            if let (request, _) = TestUtils.matchingRequest(networkSession: networkSession,
                                                            response: response,
                                                            endPoint: Const.Path.registerDeviceToken) {
                // First call, API call to register endpoint
                expectation3.fulfill()
                TestUtils.validate(request: request, requestType: .post, apiEndPoint: Endpoint.api, path: Const.Path.registerDeviceToken, queryParams: [])
            }

            if let (_, _) = TestUtils.matchingRequest(networkSession: networkSession,
                                                      response: response,
                                                      endPoint: Const.Path.disableDevice) {
                // Inverted
                expectation2.fulfill()
            }
        }
        let config = IterableConfig()
        config.pushIntegrationName = "my-push-integration"
        config.autoPushRegistration = false
        let notificationStateProvider = MockNotificationStateProvider(enabled: true, expectation: expectation1)
        
        let internalAPI = IterableAPIInternal.initializeForTesting(apiKey: IterableAutoRegistrationTests.apiKey,
                                                                   config: config,
                                                                   networkSession: networkSession,
                                                                   notificationStateProvider: notificationStateProvider)
        internalAPI.email = "user1@example.com"
        internalAPI.register(token: token)
        internalAPI.email = "user2@example.com"

        wait(for: [expectation3], timeout: testExpectationTimeout)
        wait(for: [expectation1, expectation2], timeout: testExpectationTimeoutForInverted)
    }
    
    func testAutomaticPushRegistrationOnInit() {
        let expectation1 = expectation(description: "call register for remote")
        
        let networkSession = MockNetworkSession(statusCode: 200)
        let config = IterableConfig()
        config.pushIntegrationName = "my-push-integration"
        config.autoPushRegistration = true
        let notificationStateProvider = MockNotificationStateProvider(enabled: true, expectation: expectation1)
        
        let localStorage = MockLocalStorage()
        localStorage.email = "user1@example.com"
        IterableAPIInternal.initializeForTesting(apiKey: IterableAutoRegistrationTests.apiKey,
                                                 config: config,
                                                 networkSession: networkSession,
                                                 notificationStateProvider: notificationStateProvider,
                                                 localStorage: localStorage)
        
        // only wait for small time, supposed to error out
        wait(for: [expectation1], timeout: testExpectationTimeout)
    }
}
