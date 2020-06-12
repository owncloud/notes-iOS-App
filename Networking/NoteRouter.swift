//
//  NoteRouter.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/3/19.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Alamofire
import Foundation
import Version

// GET /ocs/v1.php/cloud/capabilities
enum OCSRouter: URLRequestConvertible {
    case capabilities
    
    static let applicationJson = "application/json"
    
    var method: HTTPMethod {
        switch self {
        case .capabilities:
            return .get
        }
    }
    
    var path: String {
        switch self {
        case .capabilities:
            return "/capabilities"
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        let server = KeychainHelper.server
        if !server.isEmpty {
            let baseURLString = "\(server)/ocs/v1.php/cloud"
            let url = try baseURLString.asURL()

            var urlRequest = URLRequest(url: url.appendingPathComponent(self.path))
            urlRequest.httpMethod = self.method.rawValue
            let username = KeychainHelper.username
            let password = KeychainHelper.password
            let headers: HTTPHeaders = [
                .authorization(username: username, password: password),
                .accept(Router.applicationJson),
                .ocsAPIRequest(true)
            ]
            urlRequest.headers = headers
            return urlRequest
        } else {
            throw AFError.parameterEncodingFailed(reason: .missingURL)
        }
    }
}

enum Router: URLRequestConvertible {
    case allNotes(exclude: String)
    case getNote(id: Int, exclude: String, etag: String)
    case createNote(parameters: Parameters)
    case updateNote(id: Int, paramters: Parameters)
    case deleteNote(id: Int)

    static let applicationJson = "application/json"
    static let defaultApiVersion = "0.2"
    
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
        case .getNote(let id , _, _):
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
            var apiVersion = Router.defaultApiVersion
            do {
                let version = try Version(KeychainHelper.notesApiVersion)
                if version.major == 1 {
                    apiVersion = "1"
                }
            } catch { }

            let baseURLString = "\(server)/apps/notes/api/v\(apiVersion)"
//            let baseURLString = "\(server)/apps/notes/api/v0.2"
//            let baseURLString = "\(server)/apps/notes/api/v1"
            let url = try baseURLString.asURL()
            
            var urlRequest = URLRequest(url: url.appendingPathComponent(self.path))
            urlRequest.httpMethod = self.method.rawValue
            let username = KeychainHelper.username
            let password = KeychainHelper.password
            let headers: HTTPHeaders = [
                .authorization(username: username, password: password),
                .accept(Router.applicationJson)
            ]
            urlRequest.headers = headers

            switch self {
            case .allNotes(let exclude):
                let parameters = ["exclude": exclude] as [String : Any]
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            case .getNote(_, let exclude, let etag):
                let parameters = ["exclude": exclude] as [String : Any]
                if !etag.isEmpty {
                    urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
                }
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

extension HTTPHeader {
    public static func ocsAPIRequest(_ value: Bool) -> HTTPHeader {
        HTTPHeader(name: "OCS-APIRequest", value: value ? "true" : "false")
   }
}
