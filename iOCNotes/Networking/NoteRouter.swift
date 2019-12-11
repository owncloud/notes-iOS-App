//
//  NoteRouter.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/3/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Alamofire

enum Router: URLRequestConvertible {
    case allNotes(exclude: String)
    case getNote(id: Int, exclude: String)
    case createNote(parameters: Parameters)
    case updateNote(id: Int, paramters: Parameters)
    case deleteNote(id: Int)

    static let applicationJson = "application/json"

    var method: HTTPMethod {
        switch self {
        case .allNotes, .getNote:
            return .get
        case .createNote:
            return .post
        case .updateNote:
            return .put
        case .deleteNote:
            return .delete
        }
    }
    
    var path: String {
        switch self {
        case .allNotes:
            return "/notes"
        case .getNote(let id , _):
            return "/notes/\(id)"
        case .createNote:
            return "/notes"
        case .updateNote(let id, _):
            return "/notes/\(id)"
        case .deleteNote(let id):
            return "/notes/\(id)"
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        let server = KeychainHelper.server
        if !server.isEmpty {
            let baseURLString = "\(server)/apps/notes/api/v0.2"
            let url = try baseURLString.asURL()
            
            var urlRequest = URLRequest(url: url.appendingPathComponent(self.path))
            urlRequest.httpMethod = self.method.rawValue
            let username = KeychainHelper.username
            let password = KeychainHelper.password
            if let authorizationHeader = Request.authorizationHeader(user: username, password: password) {
                urlRequest.setValue(authorizationHeader.value, forHTTPHeaderField: authorizationHeader.key)
            }
            urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Accept")

            switch self {
            case .allNotes(let exclude):
                let parameters = ["exclude": exclude] as [String : Any]
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            case .getNote(_, let exclude):
                let parameters = ["exclude": exclude] as [String : Any]
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)

            case .createNote(let parameters):
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)

            case .updateNote(_, let parameters):
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)

            default:
                break
            }

            return urlRequest
        } else {
            throw AFError.parameterEncodingFailed(reason: .missingURL)
        }
    }
}
