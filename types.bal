// Copyright (c) 2023, WSO2 Inc. (http://www.wso2.com). All Rights Reserved.
//
// This software is the property of WSO2 Inc. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
// You may not alter or remove any copyright or other notice from copies of this content.

import ballerina/constraint;
import ballerina/http;

# [Configurable] MySQL Database configuration.
#
# + hostname - Database hostname  
# + username - Database username  
# + password - Database password  
# + database - Database name
# + port - Default port  
# + maxOpenConnections -   The maximum open connections
# + maxConnectionLifeTime - The maximum lifetime of a connection  
# + minIdleConnections - The minimum idle time of a connection  
# + connectTimeout - Timeout to be used when establishing a connection
type DatabaseConfig record {|
    string hostname;
    string username;
    string password;
    string database;
    int port = 3306;
    int maxOpenConnections = 50;
    decimal maxConnectionLifeTime = 2000.0;
    int minIdleConnections = 5;
    decimal connectTimeout = 10;
|};

public type NetSuiteConfigs record {
    ScriptAndDeploymentId getCurrency;
    string restletsBaseUrl;
    string accountId;
    string tokenId;
    string tokenSecret;
    string consumerId;
    string consumerSecret;
};

public type ScriptAndDeploymentId record {
    int scriptId;
    int deploymentId = 1;
};

type CsvConfig record {
    string taxCodesFilePath;
    string subsidiariesFilePath;
    string inputFieldDataFilePath;
    // string projectDataFilePath;
};

public type OAuthConfig record {|
    SigningAlgorithm signatureMethod;
    string consumerKey;
    string consumerSecret;
    string accessToken;
    string accessTokenSecret;
    string realm?;
    string nonce?;
|};

type IdRecord record {
    int id;
};

# Internal Server Error record type for response
#
# + body - Body of the response
public type InternalServerError record {|
    *http:InternalServerError;
    InternalServerBody body;
|};

# Body of the error response 
#
# + msg - Message of the error
public type InternalServerBody record {|
    string msg;
|};

public type Currency record {
    CurrencyCodes currencyCode;
    decimal exchangeRate;
};

public type ConvertCurrencyPayload record {|
    CurrencyCodes baseCode;
    @constraint:String {
        pattern: re `^\d{4}-\d{2}-\d{2}$`
    }
    string date;
|};

public type GetCurrencyResponse record {
    record {
        string transactionCurrency;
        decimal conversionRate;
    }[] currencyRates;
};