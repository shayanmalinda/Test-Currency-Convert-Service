// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.
//
// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
// You may not alter or remove any copyright or other notice from copies of this content.

import ballerina/crypto;
import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerina/time;
import ballerina/url;
import ballerina/uuid;

public type SigningAlgorithm HMAC_SHA1|HMAC_SHA256|HMAC_SHA512;
public const HMAC_SHA1 = "HMAC-SHA1";
public const HMAC_SHA256 = "HMAC-SHA256";
public const HMAC_SHA512 = "HMAC-SHA512";

public configurable NetSuiteConfigs netSuiteConfigs = ?;
const string UTF_8 = "UTF-8";

@display {
    label: "NetSuite HTTP Client",
    id: "netsuite-http-client"
}
public final http:Client netSuiteClientEP = check new (
    netSuiteConfigs.restletsBaseUrl,
    httpVersion = http:HTTP_1_1,
    http1Settings = {
        keepAlive: http:KEEPALIVE_NEVER
    }
);
public isolated function getOauthHeader() returns ClientOAuthHandler {
    ClientOAuthHandler oauthHandler = new ({
        signatureMethod: HMAC_SHA256,
        consumerKey: netSuiteConfigs.consumerId,
        consumerSecret: netSuiteConfigs.consumerSecret,
        accessToken: netSuiteConfigs.tokenId,
        accessTokenSecret: netSuiteConfigs.tokenSecret,
        realm: netSuiteConfigs.accountId
    });

    return oauthHandler;
}

isolated class ClientOAuthProvider {
    private final OAuthConfig & readonly config;
    isolated function init(OAuthConfig config) {
        self.config = config.cloneReadOnly();
    }

    isolated function generateToken(string httpMethod, string url) returns string|error {
        string|error authToken = buildOAuthValue(self.config, httpMethod, url);
        if authToken is string {
            return authToken;
        } else {
            return error("Failed to generate OAuth1.0a token.", authToken);
        }
    }
}

public isolated client class ClientOAuthHandler {
    private final ClientOAuthProvider provider;
    public isolated function init(OAuthConfig config) {
        self.provider = new(config);
    }

    public isolated function getSecurityHeaders(string httpMethod, string url) returns map<string|string[]>|error {
        string|error result = self.provider.generateToken(httpMethod, url);
        if result is string {
            map<string|string[]> headers = {};
            headers["Accept"] = "application/json";
            headers["Authorization"] = result;
            headers["Content-Type"] = "application/json";
            return headers;
        } else {
            return error("Failed to enrich headers with OAuth1.0a token.", result);
        }
    }
}

isolated function buildOAuthValue(OAuthConfig config, string httpMethod, string url) returns string|error {
    string nonce = uuid:createType4AsString().substring(0, 8);
    if config?.nonce is string {
        nonce = <string>config?.nonce;
    }
    int timeInSeconds = time:utcNow()[0];
    string timestamp = timeInSeconds.toString();
    map<string> params = check buildProtocolParams(config.signatureMethod, config.consumerKey, config.accessToken, nonce, timestamp);
    string requestUrl = url;
    if url.includes("?") {
        string[] urlParts = regex:split(url, "\\?");
        requestUrl = urlParts[0];
        map<string> queryParams = buildQueryParams(urlParts[1]);
        params = <map<string>> check queryParams.mergeJson(params);
    }
    string normalizedParams = normalizeParams(params);
    string baseString = check buildBaseString(httpMethod, requestUrl, normalizedParams);
    string signature = check generateSignature(config.signatureMethod, baseString, config.consumerSecret, config.accessTokenSecret);
    string encodedSignature = check url:encode(signature, UTF_8);
    string encodedaccessToken = check url:encode(config.accessToken, UTF_8);

    string value = "OAuth ";
    if config?.realm is string {
        value += "realm=\"" + <string>config?.realm + "\",";
    }
    value += "oauth_consumer_key=\"" + config.consumerKey + "\"," + 
            "oauth_token=\"" + encodedaccessToken + "\"," + 
            "oauth_signature=\"" + encodedSignature + "\"," + 
            "oauth_timestamp=\"" + timestamp + "\"," + 
            "oauth_nonce=\"" + nonce + "\"," + 
            "oauth_signature_method=\"" + config.signatureMethod + "\"," + 
            "oauth_version=\"1.0\"";
    return value;
}

isolated function buildProtocolParams(string signatureMethod, string consumerKey, string accessToken, string nonce, string timestamp) returns map<string>|error {
    map<string> protocolParams = {
        "oauth_consumer_key": consumerKey, 
        "oauth_token": accessToken, 
        "oauth_timestamp": timestamp, 
        "oauth_nonce": nonce, 
        "oauth_signature_method": signatureMethod, 
        "oauth_version": "1.0"
    };
    return protocolParams;
}

isolated function buildQueryParams(string urlQueryParams) returns map<string> {
    map<string> queryParams = {};
    string[] queryParamParts = regex:split(urlQueryParams, "\\&");
    foreach string param in queryParamParts {
        string[] splittedParam = regex:split(param, "=");
        queryParams[splittedParam[0]] = splittedParam[1];
    }
    return queryParams;
}

isolated function normalizeParams(map<string> params) returns string {
    string normalizedParams = "";
    string[] sortedKeys = params.keys().sort();
    foreach string 'key in sortedKeys {
        normalizedParams += "&" + 'key + "=" + params.get('key);
    }
    return normalizedParams.substring(1, normalizedParams.length());
}

isolated function buildBaseString(string httpMethod, string url, string normalizedParams) returns string|error {
    string encodedParams = check url:encode(normalizedParams, UTF_8);
    string encodedUrl = check url:encode(url, UTF_8);
    return httpMethod + "&" + encodedUrl + "&" + encodedParams;
}

isolated function generateSignature(string signatureMethod, string baseString, string consumerSecret, string accessTokenSecret) returns string|error {
    string encodedConsumerSecret = check url:encode(consumerSecret, UTF_8);
    string encodedAccessTokenSecret = check url:encode(accessTokenSecret, UTF_8);
    string 'key = encodedConsumerSecret + "&" + encodedAccessTokenSecret;
    if signatureMethod is HMAC_SHA1 {
        byte[] hmac = check crypto:hmacSha1(baseString.toBytes(), 'key.toBytes());
        return hmac.toBase64();
    } else if signatureMethod is HMAC_SHA256 {
        byte[] hmac = check crypto:hmacSha256(baseString.toBytes(), 'key.toBytes());
        return hmac.toBase64();
    } else {
        byte[] hmac = check crypto:hmacSha512(baseString.toBytes(), 'key.toBytes());
        return hmac.toBase64();
    }
}

# Get URL encoded string for given string value
#
# + value - Value to encode
# + return - Encoded string
isolated function getUrlEncodedString(string value) returns string {
    string|error encodedString = url:encode(value, "UTF8");
    if encodedString is string {
        return encodedString;
    }
    log:printWarn(string `Error at getUrlEncodedString when encoding: ${value}`, encodedString);

    return value;
}

# Get path parameters and/or query parameters for URL
#
# + pathParamArray - Array with path parameter(s)
# + queryParamMap - Map with query parameter(s)
# + return - Combined string with path parameters and/or query parameters
public isolated function getPathAndQueryParams(readonly & anydata[] pathParamArray = [], readonly & map<anydata> queryParamMap = {}) returns string{
    string pathParams = pathParamArray.reduce(isolated function(string path, anydata value) returns string {
        return string `${path}/${getUrlEncodedString(value.toString())}`;
    }, "");

    string queryParams = queryParamMap.keys().reduce(isolated function(string query, string key) returns string {
        string prefix = query.length() == 0? "?" : "&";
        return string `${query}${prefix}${key}=${getUrlEncodedString(queryParamMap.get(key).toString())}`;
    }, "");

    return pathParams + queryParams;
}