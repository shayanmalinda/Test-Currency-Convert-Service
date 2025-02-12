// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.
//
// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
// You may not alter or remove any copyright or other notice from copies of this content.

import ballerina/http;
import ballerina/log;

@display {
    label: "Currency Convert Service",
    id: "finance/currency-convert-service"
}
service / on new http:Listener(9090) {

    resource function post convert\-currency(@http:Payload ConvertCurrencyPayload payload)
        returns Currency[]|InternalServerError {
        ClientOAuthHandler oauthHandler = getOauthHeader();
        readonly & map<anydata> queryParamMap = {
            script: netSuiteConfigs.getCurrency.scriptId,
            deploy: netSuiteConfigs.getCurrency.deploymentId,
            date: transformDate(payload.date),
            baseCrr: payload.baseCode
        };
        do {
            map<string|string[]> securityHeaders = check oauthHandler.getSecurityHeaders(
                "GET",
                string `${netSuiteConfigs.restletsBaseUrl}/app/site/hosting/restlet.nl${
                    getPathAndQueryParams(queryParamMap = queryParamMap)
                }`);
            http:Response response = check netSuiteClientEP->get(string `/app/site/hosting/restlet.nl${
                getPathAndQueryParams(queryParamMap = queryParamMap)
            }`,
                headers = securityHeaders, targetType = http:Response);
            if response.statusCode == http:STATUS_OK {
                json jsonPayload = check response.getJsonPayload();
                GetCurrencyResponse currencyResponse = check jsonPayload.cloneWithType();
                Currency[] result = from var currency in currencyResponse.currencyRates
                    let var currencyCode = currency.transactionCurrency
                    where currencyCode is CurrencyCodes
                    select {
                        currencyCode: currencyCode,
                        exchangeRate: currency.conversionRate
                    };
                return result;
            }

            json|error jsonPayload = response.getJsonPayload();
            fail error(string `Error fetching currencies. Status code: ${response.statusCode} JSON response: 
                ${jsonPayload is json ? jsonPayload.toString() : "''"}`);
        } on fail error err {
            log:printError(string `Error at convert-currency.`, err);
            InternalServerError response = {
                body: {msg: "Error fetching currencies."}
            };
            return response;
        }
        return [];
    }

}

