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

enum StatusRouter: URLRequestConvertible {
    case status
    
    func asURLRequest() throws -> URLRequest {
        let server = KeychainHelper.server
        if !server.isEmpty {
            var ocsUrlComponents = URLComponents()
            if let url = URL(string: server),
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                ocsUrlComponents.scheme = components.scheme
                ocsUrlComponents.host = components.host
                ocsUrlComponents.port = components.port
                var pathComponents = url.pathComponents
                
                if pathComponents.last == "index.php" {
                    pathComponents = pathComponents.dropLast()
                }
                var newPath = pathComponents.joined(separator: "/")
                if newPath.last == "/" {
                    newPath = String(newPath.dropLast())
                }
                if newPath.hasPrefix("//") {
                    newPath = String(newPath.dropFirst())
                }
                ocsUrlComponents.path = "\(newPath)/status.php"
            }
            let url = try ocsUrlComponents.url ?? server.asURL()
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = HTTPMethod.get.rawValue
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

// GET /ocs/v1.php/cloud/capabilities
enum OCSRouter: URLRequestConvertible {
    case capabilities
        
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
            var ocsUrlComponents = URLComponents()
            if let url = URL(string: server),
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                ocsUrlComponents.scheme = components.scheme
                ocsUrlComponents.host = components.host
                ocsUrlComponents.port = components.port
                var pathComponents = url.pathComponents
                
                if pathComponents.last == "index.php" {
                    pathComponents = pathComponents.dropLast()
                }
                var newPath = pathComponents.joined(separator: "/")
                if newPath.last == "/" {
                    newPath = String(newPath.dropLast())
                }
                if newPath.hasPrefix("//") {
                    newPath = String(newPath.dropFirst())
                }
                ocsUrlComponents.path = "\(newPath)/ocs/v1.php/cloud\(self.path)"
                let queryItem = URLQueryItem(name: "format", value: "json") // required on ownCloud. Otherwise xml is returned
                ocsUrlComponents.queryItems = [queryItem]
            }
            let url = try ocsUrlComponents.url ?? server.asURL()

            var urlRequest = URLRequest(url: url)
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
                if !KeychainHelper.eTag.isEmpty {
                    urlRequest.headers.add(.ifNoneMatch(KeychainHelper.eTag))
                }
                var parameters = Parameters()
                if !exclude.isEmpty {
                    parameters["exclude"] = exclude
                }
                if KeychainHelper.lastModified > 0 {
                    parameters["pruneBefore"] = KeychainHelper.lastModified
                }
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            case .getNote(_, let exclude, let etag):
                let parameters = ["exclude": exclude] as [String : Any]
                if !etag.isEmpty {
                    urlRequest.headers.add(.ifNoneMatch(etag))
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
    
    public static func ifNoneMatch(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "If-None-Match", value: value)
    }
}
