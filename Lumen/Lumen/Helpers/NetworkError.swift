import Foundation

extension Error {
    /// URLError가 네트워크 연결 끊김/없음인 경우 true
    var isOffline: Bool {
        guard let urlError = self as? URLError else { return false }
        return urlError.code == .notConnectedToInternet
            || urlError.code == .networkConnectionLost
            || urlError.code == .dataNotAllowed
    }

    /// 인터넷 연결 오류는 친절한 한국어 메시지로, 그 외는 localizedDescription
    var networkErrorMessage: String {
        isOffline ? "인터넷 연결을 확인해 주세요." : localizedDescription
    }
}
