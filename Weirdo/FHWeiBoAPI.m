//
//  FHWeiBoAPI.m
//  Weirdo
//
//  Created by FengHuan on 14-3-18.
//  Copyright (c) 2014年 FengHuan. All rights reserved.
//

#define SuppressPerformSelectorLeakWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0)

#import "FHWeiBoAPI.h"
#import "FHURLConnection.h"

@implementation FHWeiBoAPI

static NSString *APIServer = @"https://api.weibo.com";
static NSString *APIRedirectURI = @"https://api.weibo.com/oauth2/default.html";
static NSString *VersionCheckURL = @"http://itunes.apple.com/lookup?id=870936418";

+ (FHWeiBoAPI *)sharedWeiBoAPI
{
    static FHWeiBoAPI *instance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init
{
    if (!appKey) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        appKey = [defaults objectForKey:@"appKey"]?:@"897481256";
        appSecretKey = [defaults objectForKey:@"appSecretKey"]?:@"83a6102c1435001a6d52cdd254cc7cbc";
        token = [defaults objectForKey:@"token"];
        uid = [defaults objectForKey:@"uid"];
        [self synchronize];
    }
    if (!connections) {
        connections = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)synchronize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (appKey) {
        [defaults setObject:appKey forKey:@"appKey"];
    }
    if (appSecretKey) {
        [defaults setObject:appSecretKey forKey:@"appSecretKey"];
    }
    if (token) {
        [defaults setObject:token forKey:@"token"];
    }
    if (uid) {
        [defaults setObject:uid forKey:@"uid"];
    }
}

- (NSString *)URLEncodString:(NSString *)string
{
    NSString *encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(nil,
                                                                                                    (CFStringRef)string, nil,
                                                                                                    (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                                    kCFStringEncodingUTF8));
    return encodedString;
}

- (NSDictionary *)postURL:(NSString *)URLString bodyString:(NSString *)bodyString withConnectionInteractionProperty:(FHConnectionInterationProperty *)properties error:(NSError **)erro
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URLString]];
    [request setTimeoutInterval:60.0];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
    
    if (properties) {
        NSURLConnection *connection = [FHURLConnection connectionWithRequest:request delegate:self];
        NSString *connectionKey = [NSString stringWithFormat: @"%ld", ((intptr_t) connection)];
        [connections setObject:properties forKey:connectionKey];
    }else{
        NSData *response = [FHURLConnection sendSynchronousRequest:request returningResponse:nil error:erro];
        if (response) {
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:nil];
            NSError *error = [self isRespondError:dic];
            if (error) {
                if (erro) {
                    *erro = error;
                }
            }else
                return dic;
        }
    }
    return nil;
}

- (NSDictionary *)getURL:(NSString *)URLString withConnectionInteractionProperty:(FHConnectionInterationProperty *)properties error:(NSError **)erro
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URLString]];
    [request setTimeoutInterval:60.0];
    [request setHTTPMethod:@"GET"];
    if (properties) {
        NSURLConnection *connection = [FHURLConnection connectionWithRequest:request delegate:self];
        NSString *connectionKey = [NSString stringWithFormat: @"%ld", ((intptr_t) connection)];
        [connections setObject:properties forKey:connectionKey];
    }else{
        NSData *response = [FHURLConnection sendSynchronousRequest:request returningResponse:nil error:erro];
        if (response) {
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingMutableContainers error:nil];
            NSError *error = [self isRespondError:dic];
            if (error) {
                if (erro) {
                    *erro = error;
                }
            }else
                return dic;
        }
    }
    return nil;
}

- (NSError *)isRespondError:(NSDictionary *)response
{
    NSError *erro;
    NSMutableDictionary *userinfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"系统错误", NSLocalizedDescriptionKey, nil];
    if ([response objectForKey:@"error_code"]) {
        int errorCode = [[response objectForKey:@"error_code"] intValue];
        switch (errorCode) {
            case 21314:
            case 21315:
            case 21316:
            case 21317:
            case 21327:
            case 21332:
            case 21501:
            {
                errorCode = ERROR_TOKEN_INVALID;
                [userinfo setObject:@"授权失效或错误" forKey:NSLocalizedDescriptionKey];
                break;
            }
            default:
                [userinfo setObject:[response objectForKey:@"error"] forKey:NSLocalizedDescriptionKey];
                break;
        }
        erro = [NSError errorWithDomain:@"WeiBoErrorDomain" code:errorCode userInfo:userinfo];
    }
    return erro;
}

- (NSDictionary *)checkVersion
{
    NSString *currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey];
    NSArray *currentVersions = [currentVersion componentsSeparatedByString:@"."];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:VersionCheckURL]];
    [request setHTTPMethod:@"GET"];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
    NSArray *newVersions;
    NSDictionary *dic;
    if (data) {
        dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (dic && [dic objectForKey:@"results"]) {
            for (id result in [dic objectForKey:@"results"]) {
                newVersions = [[result objectForKey:@"version"] componentsSeparatedByString:@"."];
            }
        }
    }
    if (newVersions) {
        if (([[currentVersions objectAtIndex:0] isEqualToString:[newVersions objectAtIndex:0]]) && ([[currentVersions objectAtIndex:1] isEqualToString:[newVersions objectAtIndex:1]])) {
            return nil;
        }
    }else
        return nil;
    return [dic objectForKey:@"results"];
}

- (NSError *)checkToken
{
    NSString *paramString = [NSString stringWithFormat:@"access_token=%@", token];
    NSString *URLString = [NSString stringWithFormat:@"%@/2/account/get_uid.json?%@", APIServer, paramString];
    NSError *error;
    [self getURL:URLString withConnectionInteractionProperty:nil error:&error];
    return error;
}

- (NSError *)getAccountTokenWithCode:(NSString *)code
{
    NSString *paramString = [NSString stringWithFormat:@"client_id=%@&client_secret=%@&grant_type=authorization_code&code=%@&redirect_uri=%@", appKey, appSecretKey, code, APIRedirectURI];
    NSString *URLString = [NSString stringWithFormat:@"%@/oauth2/access_token?%@", APIServer, paramString];
    NSError *error;
    NSDictionary *response = [self postURL:URLString bodyString:nil withConnectionInteractionProperty:nil error:&error];
    if (response) {
        NSError *erro = [self isRespondError:response];
        if (erro) {
            error = erro;
        }else{
            token = [response objectForKey:@"access_token"];
            uid = [response objectForKey:@"uid"];
            [self synchronize];
        }
    }
    return error;
}

- (NSURL *)authorizeURL
{
    NSString *paramString = [NSString stringWithFormat:@"client_id=%@&redirect_uri=%@&display=mobile", appKey, APIRedirectURI];
    NSString *URLString = [NSString stringWithFormat:@"%@/oauth2/authorize?%@", APIServer, paramString];
    return [NSURL URLWithString:URLString];
}

- (NSError *)isAuthorized:(NSURL *)redirectURL
{
    NSError *error;
    if (!redirectURL) {
        error = [self checkToken];
    }else{
        NSString *authorizeString = redirectURL.absoluteString;
        NSRange codeRange = [authorizeString rangeOfString:@"code="];
        error = [NSError errorWithDomain:@"SYSTEM" code:ERROR_AUTHORIZE_DID_NOT_COMPLETED userInfo:nil];
        if (codeRange.location != NSNotFound) {
            NSString *code = [authorizeString substringFromIndex:(codeRange.location+codeRange.length)];
            [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"authorize_code"];
            error = [self getAccountTokenWithCode:code];
        }
    }
    return error;
}

- (void)fetchUserPostsLaterThanPost:(FHPost *)post interactionProperty:(FHConnectionInterationProperty *)property
{
    NSMutableString *paramString = [NSMutableString stringWithFormat:@"access_token=%@&uid=%@&count=5", token, uid];
    if (post) {
        [paramString appendFormat:@"&max_id=%@", post.ID];
    }
    NSString *URLString = [NSString stringWithFormat:@"%@/2/statuses/user_timeline.json?%@", APIServer, paramString];
    [self getURL:URLString withConnectionInteractionProperty:property error:nil];
}

- (void)fetchHomePostsNewer:(BOOL)newer thanPost:(FHPost *)post interactionProperty:(FHConnectionInterationProperty *)property
{
    NSMutableString *paramString = [NSMutableString stringWithFormat:@"access_token=%@", token];
    if (post) {
        if (newer) {
            [paramString appendFormat:@"&since_id=%@", post.ID];
        }else
            [paramString appendFormat:@"&max_id=%@", post.ID];
    }
//    NSString *URLString = [NSString stringWithFormat:@"%@/2/statuses/user_timeline.json?%@", APIServer, paramString];
    NSString *URLString = [NSString stringWithFormat:@"%@/2/statuses/home_timeline.json?%@", APIServer, paramString];
    [self getURL:URLString withConnectionInteractionProperty:property error:nil];
}

- (void)fetchBilateralPostsNewer:(BOOL)newer thanPost:(FHPost *)post interactionProperty:(FHConnectionInterationProperty *)property
{
    NSMutableString *paramString = [NSMutableString stringWithFormat:@"access_token=%@", token];
    if (post) {
        if (newer) {
            [paramString appendFormat:@"&since_id=%@", post.ID];
        }else
            [paramString appendFormat:@"&max_id=%@", post.ID];
    }
    NSString *URLString = [NSString stringWithFormat:@"%@/2/statuses/bilateral_timeline.json?%@", APIServer, paramString];
    [self getURL:URLString withConnectionInteractionProperty:property error:nil];
}

- (void)fetchPublicPostsWithInteractionProperty:(FHConnectionInterationProperty *)property
{
    NSString *paramString = [NSString stringWithFormat:@"access_token=%@&feature=1", token];
    NSString *URLString = [NSString stringWithFormat:@"%@/2/statuses/public_timeline.json?%@", APIServer, paramString];
    [self getURL:URLString withConnectionInteractionProperty:property error:nil];
}

- (void)fetchImagesForURL:(NSString *)URLString interactionProperty:(FHConnectionInterationProperty *)property
{
    [self getURL:URLString withConnectionInteractionProperty:property error:nil];
}

- (void)fetchCommentForStatus:(NSNumber *)statusID laterThanComment:(NSNumber *)commentID interactionProperty:(FHConnectionInterationProperty *)property
{
    NSMutableString *paramString = [NSMutableString stringWithFormat:@"access_token=%@&id=%@&count=20", token, statusID];
    if (commentID) {
        [paramString appendFormat:@"&max_id=%@", commentID];
    }
    NSString *URLString = [NSString stringWithFormat:@"%@/2/comments/show.json?%@", APIServer, paramString];
    [self getURL:URLString withConnectionInteractionProperty:property error:nil];
}

- (void)retweetStatus:(NSNumber *)statusID content:(NSString *)content commentTo:(int)commentType interactionProperty:(FHConnectionInterationProperty *)property
{
    NSMutableString *paramString = [NSMutableString stringWithFormat:@"id=%@&access_token=%@", statusID, token];
    if (content) {
        content = content.length > 140? [content substringToIndex:139]:content;
        content = [self URLEncodString:content];
        [paramString appendFormat:@"&status=%@", content];
    }
    NSString *URLString = [NSString stringWithFormat:@"%@/2/statuses/repost.json", APIServer];
    NSError *error;
    [self postURL:URLString bodyString:paramString withConnectionInteractionProperty:property error:&error];
}

- (void)commentStatus:(NSNumber *)statusID content:(NSString *)content commentTo:(int)commentType interactionProperty:(FHConnectionInterationProperty *)property
{
    NSMutableString *paramString = [NSMutableString stringWithFormat:@"id=%@&access_token=%@", statusID, token];
    if (content) {
        content = content.length > 140? [content substringToIndex:139]:content;
        content = [self URLEncodString:content];
        [paramString appendFormat:@"&comment=%@", content];
    }
    NSString *URLString = [NSString stringWithFormat:@"%@/2/comments/create.json", APIServer];
    NSError *error;
    [self postURL:URLString bodyString:paramString withConnectionInteractionProperty:property error:&error];
    DLog(@"comment error:%d", (int)error.code);
}

- (void)replyComment:(NSNumber *)commentID Status:(NSNumber *)statusID content:(NSString *)content commentTo:(int)commentType interactionProperty:(FHConnectionInterationProperty *)property
{
    NSMutableString *paramString = [NSMutableString stringWithFormat:@"cid=%@&id=%@&access_token=%@", commentID, statusID, token];
    if (content) {
        content = content.length > 140? [content substringToIndex:139]:content;
        content = [self URLEncodString:content];
        [paramString appendFormat:@"&comment=%@", content];
    }
    NSString *URLString = [NSString stringWithFormat:@"%@/2/comments/reply.json", APIServer];
    NSError *error;
    [self postURL:URLString bodyString:paramString withConnectionInteractionProperty:property error:&error];
    DLog(@"comment error:%ld", (long)error.code);
}

#pragma mark
#pragma mark - connecetion delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	NSString *connectionKey = [NSString stringWithFormat: @"%ld", ((intptr_t) connection)];
	FHConnectionInterationProperty * properties = [connections objectForKey:connectionKey];
	NSMutableData *data = [[NSMutableData alloc] init];
    [properties setData:data];
    
    if (properties.progressTarget) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if(httpResponse && [httpResponse respondsToSelector:@selector(allHeaderFields)])
        {
            NSDictionary *httpResponseHeaderFields = [httpResponse allHeaderFields];
            NSNumber *contentLength = [NSNumber numberWithLongLong:[[httpResponseHeaderFields objectForKey:@"Content-Length"] longLongValue]];
            [properties setContentLength:contentLength];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	NSString *connectionKey = [NSString stringWithFormat: @"%ld", ((intptr_t) connection)];
	FHConnectionInterationProperty *properties = [connections objectForKey:connectionKey];
	NSMutableData * oldData = (NSMutableData *) properties.data;
	[oldData appendData:data];
    
    if (properties.progressTarget && properties.progressSelector)
    {
        SuppressPerformSelectorLeakWarning([properties.progressTarget performSelector:properties.progressSelector withObject:[properties progressRate]]);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	NSString *connectionKey = [NSString stringWithFormat: @"%ld", ((intptr_t) connection)];
	FHConnectionInterationProperty *properties = [connections objectForKey:connectionKey];
	if (properties.afterFailedSelector && properties.afterFailedTarget)
	{
        SuppressPerformSelectorLeakWarning([properties.afterFailedTarget performSelector:properties.afterFailedSelector withObject:error]);
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	NSString *connectionKey = [NSString stringWithFormat: @"%ld", ((intptr_t) connection)];
	FHConnectionInterationProperty *properties = [connections objectForKey:connectionKey];
	if (properties.afterFinishedTarget && properties.afterFinishedSelector)
	{
        id theData = [NSJSONSerialization JSONObjectWithData:properties.data options:NSJSONReadingMutableContainers error:nil];
        theData = theData ? theData : properties.data;
        SuppressPerformSelectorLeakWarning([properties.afterFinishedTarget performSelector:properties.afterFinishedSelector withObject:theData]);
        
        if ([theData isKindOfClass:[NSDictionary class]]) {
            NSError *error = [self isRespondError:theData];
            if (error && properties.afterFailedTarget && properties.afterFailedSelector) {
                SuppressPerformSelectorLeakWarning([properties.afterFailedTarget performSelector:properties.afterFailedSelector withObject:error]);
            }
        }
	}
	[connections removeObjectForKey:connectionKey];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
			 willSendRequest:(NSURLRequest *)request
			redirectResponse:(NSURLResponse *)redirectResponse
{
    return request;
}

@end
