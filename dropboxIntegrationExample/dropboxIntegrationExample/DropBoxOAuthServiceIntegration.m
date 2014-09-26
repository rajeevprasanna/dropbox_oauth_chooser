//
//  DropBoxOAuthServiceIntegration.m
//  dropboxIntegrationExample
//
//  Created by Rajeev Kumar on 25/09/14.
//  Copyright (c) 2014 rajeev. All rights reserved.
//

#import "DropBoxOAuthServiceIntegration.h"

//#warning INSERT YOUR OWN API KEY and SECRET HERE
static NSString *apiKey = @"briefri6tqykkal";
static NSString *appSecret = @"ag5e4ofrx22leyn";

NSString *const oauthTokenKey = @"oauth_token";
NSString *const oauthTokenKeySecret = @"oauth_token_secret";
NSString *const dropboxUIDKey = @"uid";

NSString *const dropboxTokenReceivedNotification = @"have_user_request_token";

NSString * const requestToken = @"requestToken";
NSString * const requestTokenSecret = @"requestTokenSecret";

NSString * const accessToken = @"accessToken";
NSString * const accessTokenSecret = @"accessTokenSecret";


@implementation DropBoxOAuthServiceIntegration

+(void)getOAuthRequestToken
{
    // OAUTH Step 1. Get request token.
    [self requestTokenWithCompletionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
            if (httpResp.statusCode == 200) {
                
                NSString *responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
                /*
                 oauth_token The request token that was just authorized. The request token secret isn't sent back.
                 If the user chooses not to authorize the application,
                 they will get redirected to the oauth_callback URL with the additional URL query parameter not_approved=true.
                 */
                NSDictionary *oauthDict = [self dictionaryFromOAuthResponseString:responseStr];
                // save the REQUEST token and secret to use for normal api calls
                [[NSUserDefaults standardUserDefaults] setObject:oauthDict[oauthTokenKey] forKey:requestToken];
                [[NSUserDefaults standardUserDefaults] setObject:oauthDict[oauthTokenKeySecret] forKey:requestTokenSecret];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                
                NSString *authorizationURLWithParams = [NSString stringWithFormat:@"https://www.dropbox.com/1/oauth/authorize?oauth_token=%@&oauth_callback=byteclub://userauthorization",oauthDict[oauthTokenKey]];
                
                // escape codes
                NSString *escapedURL = [authorizationURLWithParams stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                
//                [_tokenAlert dismissWithClickedButtonIndex:0 animated:NO];
                
                // opens to user auth page in safari
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:escapedURL]];
                
            } else {
                // HANDLE BAD RESPONSE //
                NSLog(@"unexpected response getting token %@",[NSHTTPURLResponse localizedStringForStatusCode:httpResp.statusCode]);
            }
        } else {
            // ALWAYS HANDLE ERRORS :-] //
        }
    }];
}

+(void)exchangeRequestTokenForAccessToken
{
    //OAUTH step3 - exchange request token for user access token
    [self exchangeTokenForUserAccessTokenURLWithCompletionHandler:^(NSData *data, NSURLResponse *nsurlresponse, NSError *error) {
        if(!error){
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)nsurlresponse;
            if(httpResp.statusCode == 200){
                NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSDictionary *accessTokenDict = [self dictionaryFromOAuthResponseString:response];
                
                [[NSUserDefaults standardUserDefaults] setObject:accessTokenDict[oauthTokenKey] forKey:accessToken];
                [[NSUserDefaults standardUserDefaults] setObject:accessTokenDict[oauthTokenKeySecret] forKey:accessTokenSecret];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                NSLog(@"accessToken => %@", accessTokenDict[oauthTokenKey]);
            }else{
                // HANDLE BAD RESPONSE //
                NSLog(@"unexpected response getting token %@",[NSHTTPURLResponse localizedStringForStatusCode:httpResp.statusCode]);
            }
        }else{
            NSLog(@"Error in connecting to dropbox using OAuth. error => %@", error);
        }
    }];
}

+(void)exchangeTokenForUserAccessTokenURLWithCompletionHandler:(DropboxRequestTokenCompletionHandler)completionBlock
{
    NSString *urlString = [NSString stringWithFormat:@"https://api.dropbox.com/1/oauth/access_token?"];
    NSURL *requestTokenURL = [NSURL URLWithString:urlString];
    
    NSString *reqToken = [[NSUserDefaults standardUserDefaults] valueForKey:requestToken];
    NSString *reqTokenSecret = [[NSUserDefaults standardUserDefaults] valueForKey:requestTokenSecret];
    
    NSString *authorizationHeader = [self plainTextAuthorizationHeaderForAppKey:apiKey appSecret:appSecret token:reqToken tokenSecret:reqTokenSecret];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setHTTPAdditionalHeaders:@{@"Authorization": authorizationHeader}];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestTokenURL];
    [request setHTTPMethod:@"POST"];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    [[session dataTaskWithRequest:request completionHandler:completionBlock] resume];
    
}

+(void)requestTokenWithCompletionHandler:(DropboxRequestTokenCompletionHandler)completionBlock
{
    NSString *authorizationHeader = [self plainTextAuthorizationHeaderForAppKey:apiKey appSecret:appSecret token:nil tokenSecret:nil];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setHTTPAdditionalHeaders:@{@"Authorization":authorizationHeader}];
    
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:[NSURL URLWithString:@"https://api.dropbox.com/1/oauth/request_token"]];
    [request setHTTPMethod:@"POST"];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    [[session dataTaskWithRequest:request completionHandler:completionBlock] resume];
}

+(NSString *)plainTextAuthorizationHeaderForAppKey:(NSString *)appKey appSecret:(NSString *)appSecret token:(NSString *)token tokenSecret:(NSString *)tokenSecret
{
    //version, method, and oauth_consumer_key are always present
    NSString *header = [NSString stringWithFormat:@"OAuth oauth_version=\"1.0\",oauth_signature_method=\"PLAINTEXT\",oauth_consumer_key=\"%@\"", apiKey];
    
    //look for oauth_token, include if one is passed in
    if(token){
        header = [header stringByAppendingString:[NSString stringWithFormat:@",oauth_token=\"%@\"",token]];
    }
    
    //add oauth_signature which is app_secret&token_secret, token_secret may not be there yet, just include @"" if it's not there
    if(!tokenSecret){
        tokenSecret = @"";
    }
    header = [header stringByAppendingString:[NSString stringWithFormat:@",oauth_signature=\"%@&%@\"",appSecret,tokenSecret]];
    return header;
}

+(NSDictionary*)dictionaryFromOAuthResponseString:(NSString*)response
{
    NSArray *tokens = [response componentsSeparatedByString:@"&"];
    NSMutableDictionary *oauthDict = [[NSMutableDictionary alloc] initWithCapacity:5];
    
    for(NSString *t in tokens) {
        NSArray *entry = [t componentsSeparatedByString:@"="];
        NSString *key = entry[0];
        NSString *val = entry[1];
        [oauthDict setValue:val forKey:key];
    }
    
    return [NSDictionary dictionaryWithDictionary:oauthDict];
}




@end
