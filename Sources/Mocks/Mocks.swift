import APIConnect
import APIModels
import APIService

import Vapor

extension Service {
    public static let mockContext: Context = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    public static func loadTest(_ api: BackendAPIType) async throws {
        try await load(api, githubPrivateKey: privateKeyString)
    }
    
    public static func loadTestWithEmptyAPI() async throws {
        try await load(EmptyMockAPI(), githubPrivateKey: privateKeyString)
    }
    
    public static let privateKeyString = """
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDAfAHM5k46aJA/
B0B/IgL1w4vgRWzEh9UapotDqT+hYZiFK24TKWeWf4li0HXjV31jg936Q90DyiJx
L2JUZ8ELAo6v4bThoDwHH5brso7+BrjlLlqK2zqmjNFDI1iEmlv7NoahCgbI1gXX
tcSIsLOaIw7ZlsQOvdm/e7m7Jvg/0u11Uh4OxlMT5tfnUEALYSKive3Qg6Bcdy0q
laSxP9bdFXTeep4DfUs/ebFDPoj936z/2Ux2Rt8oAuV2x7vE5YzihjJ7Pk3FkhZM
IVv6TyWsWZZ3ajuuTrEB7VVGXCqtCpizfQE9vsJMfbIq9dpat5QZ6VuHY4PA6KT6
n5n3YG1rAgMBAAECggEAGdxPTZ0fo39K6fzqcGo8ZZKJJ2+MZnctbXA0w7logCEh
obqtBkwIy9KEvc7uF8Y4ZXdhCm+1sP2mVPidyGNML1N/oie76phhmD9pQm9yALUc
gEYTChbcMWY380I7cU1f0EeKHPbA5JjEni+goRDEgI/3Pcqguq5NJAnWcUuSDNjp
OTwYeeb+1W7IO2TurdKGlJGyhtWuwnFgN0NlctnCmCARUTzx84DfuABvDXri4931
xtcgDI3BSj250k260DM6HYekTmJgqHFV7ODFwrbQhvg/3yqvcVsoVuDpqG1qjJf7
kAk+6PEKSXVGsTu9HJ37q3JJMWCXilCGFSaEn/RF0QKBgQDl0SNx8o9t77uqfKO3
n6wGKIDU9RngSx4luKsJiM0SMVFGSgMSSBIxSn6KNjKemj9r/84IAGG0XwdthNml
KgnJ4nSV3SHneuLVtru7BIfQXqx9HhKq6rfnznPIpZ4cs5GJnYdzzJv+3rS335sa
QirzjaSzW0weUPwMfONjfbdsUwKBgQDWagY1i39bK706UhJ+oTo7LWMQwklm+u1v
R7Yxfpbz8wIn2tkzgeKep/Vk7HwpOeEohnyhtiBPGV9dxvicHdZfsHDsIqQljF0i
sFuUW1Gan398ZLGmOD9AdpI3x2jAQiS1pwRS6OUIJW5+bDIueyNIQ/2UnW37b0hf
OV0lZRQXiQKBgQCp/x/3A/Pw4GqzW+tGwwferktOO9feP/KW+JkcPmNjV7PFCK5o
8YLzjyU3W4vqIjNT0i83YADmCX1XF/Re5k/DVI3k5WRU9GOirr8DQgCss7tn+bzZ
TTKod+DRxSDGHlZDs5EkqW+jAl4vvWnf7J4U9uuj+J6/tiwbmK4jRDVQHQKBgQC/
VtY7qkT4o0u2Y89FWbORY6toJTlDwOFp0ODxwjoLcOyXjGEP6fTGCLSgX7ldQN2B
QKKv3MtwSwAju4/YIXhQ5C+hSjiZmWzzq9XNysBD79ngtCskXkVzzVwmkrkT+PKx
eF4Pbu4UGvNDtmIBwLl3n9UHboXbPy+iapqI6G7JoQKBgQCgU85e2Y/UJavUW213
Ub7j5zNQLurtUEWlxd/vLlnBW380pCc+/znv18f1EUz6EZMLGnyKdx01S8mGrbJl
1aTqyXAz2EvAiFrvIZh+Us6vo5NQ7XtbpRFXcm3I1vy1kZ0jBII4hjubuBigfUB4
nQqMaxxcy49hS31RhPCzYrAVFw==
-----END PRIVATE KEY-----
"""
    
    public static let publicKeyString = """
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwHwBzOZOOmiQPwdAfyIC
9cOL4EVsxIfVGqaLQ6k/oWGYhStuEylnln+JYtB141d9Y4Pd+kPdA8oicS9iVGfB
CwKOr+G04aA8Bx+W67KO/ga45S5aits6pozRQyNYhJpb+zaGoQoGyNYF17XEiLCz
miMO2ZbEDr3Zv3u5uyb4P9LtdVIeDsZTE+bX51BAC2Eior3t0IOgXHctKpWksT/W
3RV03nqeA31LP3mxQz6I/d+s/9lMdkbfKALldse7xOWM4oYyez5NxZIWTCFb+k8l
rFmWd2o7rk6xAe1VRlwqrQqYs30BPb7CTH2yKvXaWreUGelbh2ODwOik+p+Z92Bt
awIDAQAB
-----END PUBLIC KEY-----
"""
}

private final class EmptyMockAPI: BackendAPIType {
    
    func execute(request: HTTPClient.Request) -> EventLoopFuture<HTTPClient.Response> {
        pure(MockHTTPResponse.okResponse(body: ""), Service.mockContext)
    }
}

public enum MockHTTPResponse {
    public static func okResponse(body: String) -> HTTPClient.Response {
        .init(
            host: "",
            status: .ok,
            version: .http1_1,
            headers: .init(),
            body: body.toByteBuffer()
        )
    }
}

extension String {
    public func toByteBuffer() -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: utf8.count)
        buffer.writeString(self)
        return buffer
    }
}
