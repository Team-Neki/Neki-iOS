//
//  AnalyticsEvent+RawParameters.swift
//  Neki-iOS
//
//  Created by SwainYun on 7/30/26.
//

extension AnalyticsEvent {
    var rawParameters: [String: Any]? {
        guard let parameters else { return nil }
        return parameters.reduce(into: [:]) { result, parameter in
            result[parameter.key.name] = parameter.value.rawValue
        }
    }
}

private extension AnalyticsParameterValue {
    var rawValue: Any {
        switch self {
        case let .string(value): return value
        case let .integer(value): return value
        case let .boolean(value): return value
        case let .double(value): return value
        }
    }
}
