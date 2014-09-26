//
//  DropBoxOAuthServiceIntegration.h
//  dropboxIntegrationExample
//
//  Created by Rajeev Kumar on 25/09/14.
//  Copyright (c) 2014 rajeev. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const oauthTokenKey;
extern NSString * const oauthTokenKeySecret;
extern NSString * const requestToken;
extern NSString * const requestTokenSecret;
extern NSString * const accessToken;
extern NSString * const accessTokenSecret;
extern NSString * const dropboxUIDKey;
extern NSString * const dropboxTokenReceivedNotification;
typedef void (^DropboxRequestTokenCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

@interface DropBoxOAuthServiceIntegration : NSObject
+(void)getOAuthRequestToken;
+(void)exchangeRequestTokenForAccessToken;
@end
