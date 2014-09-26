//
//  DropBoxOAuthServiceIntegration.m
//  dropboxIntegrationExample
//
//  Created by Rajeev Kumar on 25/09/14.
//  Copyright (c) 2014 rajeev. All rights reserved.
//

#import "DropBoxOAuthServiceIntegration.h"

//#warning INSERT YOUR OWN API KEY and SECRET HERE
static NSString *apiKey = @"8343b03llcys1pw";
static NSString *appSecret = @"fjj7trsupyofoho";

NSString *const oauthTokenKey = @"oauth_token";
NSString *const oauthTokenKeySecret = @"oauth_token_secret";
NSString *const dropboxUIDKey = @"uid";

NSString *const deletedFilesToken = @"deleted_files";
NSString *const modifiedFilesToken = @"modified_files";
NSString *const  allFilesToken = @"all_files";

NSString *const cursor_key = @"cursor";

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

+(void)getLatestCursonToFindDeltaChanges
{
    NSURL *requestTokenURL = [NSURL URLWithString:@"https://api.dropbox.com/1/delta/latest_cursor"];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestTokenURL];
    [request setHTTPMethod:@"POST"];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [config setHTTPAdditionalHeaders:@{@"Authorization": [self apiAuthorizationHeader]}];
    [config setTimeoutIntervalForRequest:10];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data,
                                                                                              NSURLResponse *nsurlresponse,
                                                                                              NSError *error) {
        if(!error){
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)nsurlresponse;
            if(httpResp.statusCode == 200){
                NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *cursor = response[@"cursor"];
                [[NSUserDefaults standardUserDefaults] setObject:cursor forKey:cursor_key];
            }else{
                NSLog(@"error http code while receiving delta changes. http error code => %u", httpResp.statusCode);
            }
        }else{
            NSLog(@"Error while retrieving delta changes =>  %@", [error localizedDescription]);
        }
    }];
    [dataTask resume];
}

+(void)getDeltaChanges
{
    NSString *cursor = [[NSUserDefaults standardUserDefaults] objectForKey:cursor_key];
    if(!cursor){
        [self getLatestCursonToFindDeltaChanges];
        cursor = [[NSUserDefaults standardUserDefaults] objectForKey:cursor_key];
    }
    
    NSString *requestTokenURLStr = @"https://api.dropbox.com/1/delta";
    requestTokenURLStr = [NSString stringWithFormat:@"%@?cursor=%@", requestTokenURLStr,cursor];
    
    NSURL *requestTokenURL = [NSURL URLWithString:requestTokenURLStr];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestTokenURL];
    [request setHTTPMethod:@"POST"];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    [config setHTTPAdditionalHeaders:@{@"Authorization": [self apiAuthorizationHeader]}];
    [config setTimeoutIntervalForRequest:10];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data,
                                                                                              NSURLResponse *nsurlresponse,
                                                                                              NSError *error) {
        if(!error){
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)nsurlresponse;
            if(httpResp.statusCode == 200){
                NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                //update the cursor in shared default session
                NSString *cursor = response[@"cursor"];
                [[NSUserDefaults standardUserDefaults] setObject:cursor forKey:cursor_key];
                NSLog(@"response => %@", response);
                
                NSMutableSet *deletedFilesSet = [NSMutableSet new];
                NSMutableSet *modifiedFilesSet = [NSMutableSet new];
                
                NSArray *entries = response[@"entries"];
                for(NSArray *entry in entries){
                    NSString *fileName = [NSString stringWithFormat:@"%@",entry[0]];
                    NSLog(@"data is not array. => %@", [entry[0] class]);
                    if([entry[1] isKindOfClass:[NSDictionary class]]){
                        NSDictionary *fileProps = entry[1];
                        NSNumber * isDirectory = (NSNumber *)[fileProps objectForKey: @"success"];
                        if(![isDirectory boolValue] == YES){
                            [modifiedFilesSet addObject:fileName];
                        }
                    }else{//deleted file
                        NSLog(@"data is not array. => %@", [entry[1] class]);
                        [deletedFilesSet addObject:fileName];
                    }
                }
                
                NSMutableArray *allFiles = [NSMutableArray new];
                for(NSString *fileName in modifiedFilesSet){
                    [allFiles addObject:fileName];
                }
                for(NSString *fileName in deletedFilesSet){
                    [allFiles addObject:fileName];
                }
                
                [[NSUserDefaults standardUserDefaults] setObject:[deletedFilesSet allObjects]  forKey:deletedFilesToken];
                [[NSUserDefaults standardUserDefaults] setObject:[modifiedFilesSet allObjects]  forKey:modifiedFilesToken];
                [[NSUserDefaults standardUserDefaults] setObject:allFiles  forKey:allFilesToken];
                
            }else{
                NSLog(@"error http code while receiving delta changes. http error code => %u", httpResp.statusCode);
            }
        }else{
             NSLog(@"Error while retrieving delta changes =>  %@", [error localizedDescription]);
        }
    }];
    [dataTask resume];
}

+(void)getFilesMetadata
{     
    NSMutableArray *tempFiles = [[NSUserDefaults standardUserDefaults] objectForKey:@"dropboxFiles"];
    if(tempFiles == nil){
        return;
    }
    
    for(NSMutableArray *fileInfo in tempFiles){
        NSString *filePath = fileInfo[1];
        NSString *urlStr = [NSString stringWithFormat:@"%@%@", @"https://api.dropbox.com/1/metadata/auto/", filePath];
        
        NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        [config setHTTPAdditionalHeaders:@{@"Authorization": [self apiAuthorizationHeader]}];
        [config setTimeoutIntervalForRequest:10];
        NSURLSession * session = [NSURLSession sessionWithConfiguration:config];
        
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data,
                                                                                                  NSURLResponse *nsurlresponse,
                                                                                                  NSError *error) {
            if(!error){
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)nsurlresponse;
                if(httpResp.statusCode == 200){
                    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    NSString *newRevision = response[@"revision"];
                    
                    if([fileInfo count] == 2){
                        [fileInfo addObject:newRevision];//setting old revision as -1
                        [fileInfo addObject:newRevision]; //next parameter if new revision
                    }else{
                        fileInfo[2] = fileInfo[3];
                        fileInfo[3] = newRevision;
                        
                        if(fileInfo[2] != fileInfo[3])
                            NSLog(@"%@ has new been updated.", fileInfo[0]);
                    }
                }
            }else{
                NSLog(@"Error while retrieving metadata of file %@", [error localizedDescription]);
            }
        }];
        [dataTask resume];
    }
    
    tempFiles = [[NSUserDefaults standardUserDefaults] objectForKey:@"dropboxFiles"];
    NSLog(@"temp files data => %@", tempFiles);
}

+(NSString*)apiAuthorizationHeader
{
    NSString *token = [[NSUserDefaults standardUserDefaults] valueForKey:accessToken];
    NSString *tokenSecret = [[NSUserDefaults standardUserDefaults] valueForKey:accessTokenSecret];
    return [self plainTextAuthorizationHeaderForAppKey:apiKey
                                             appSecret:appSecret
                                                 token:token
                                           tokenSecret:tokenSecret];
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
                
                //Now get the latest cursor to be set in state for further use.
                [self getLatestCursonToFindDeltaChanges];
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
