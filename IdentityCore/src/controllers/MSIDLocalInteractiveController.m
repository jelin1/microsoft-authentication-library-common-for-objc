// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDLocalInteractiveController.h"
#import "MSIDInteractiveTokenRequest.h"
#import "MSIDInteractiveRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"


@interface MSIDLocalInteractiveController()

@property (nonatomic, readwrite) MSIDInteractiveRequestParameters *interactiveRequestParamaters;

@end

@implementation MSIDLocalInteractiveController

#pragma mark - Init

- (instancetype)initWithInteractiveRequestParameters:(MSIDInteractiveRequestParameters *)parameters
                                        oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                                 tokenRequestFactory:(nonnull MSIDTokenRequestFactory *)tokenRequestFactory
                              tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
                                          tokenCache:(nonnull id<MSIDTokenCacheProviding>)tokenCache
                                               error:(NSError **)error
{
    self = [super initWithRequestParameters:parameters
                               oauthFactory:oauthFactory
                        tokenRequestFactory:tokenRequestFactory
                     tokenResponseValidator:tokenResponseValidator
                                 tokenCache:tokenCache
                                      error:error];

    if (self)
    {
        self.interactiveRequestParamaters = parameters;
    }

    return self;
}

#pragma mark - MSIDInteractiveRequestControlling

- (void)acquireToken:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    [[MSIDTelemetry sharedInstance] startEvent:self.interactiveRequestParamaters.telemetryRequestId eventName:MSID_TELEMETRY_EVENT_API_EVENT];

    NSString *accountIdentifier = self.interactiveRequestParamaters.accountIdentifier.legacyAccountId;

    NSString *upn = accountIdentifier ? accountIdentifier : self.interactiveRequestParamaters.loginHint;

    [super resolveEndpointsWithUpn:upn
                        completion:^(BOOL resolved, NSError * _Nullable error) {

                            if (!resolved)
                            {
                                [self stopTelemetryEvent:[self telemetryAPIEvent] error:error];
                                completionBlock(nil, error);
                                return;
                            }

                            [self acquireTokenImpl:completionBlock];
                        }];
}

- (void)acquireTokenImpl:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    MSIDInteractiveTokenRequest *interactiveRequest = [[MSIDInteractiveTokenRequest alloc] initWithRequestParameters:self.interactiveRequestParamaters
                                                                                                        oauthFactory:self.oauthFactory
                                                                                                 tokenRequestFactory:self.tokenRequestFactory
                                                                                              tokenResponseValidator:self.tokenResponseValidator
                                                                                                          tokenCache:self.tokenCache];

    [interactiveRequest acquireToken:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {

        [self stopTelemetryEvent:[self telemetryAPIEvent] error:error];
        completionBlock(result, error);
    }];
}

- (BOOL)completeAcquireToken:(nonnull NSURL *)resultURL
{
    return NO;
}

- (MSIDTelemetryAPIEvent *)telemetryAPIEvent
{
    MSIDTelemetryAPIEvent *event = [super telemetryAPIEvent];

    if (self.interactiveRequestParamaters.loginHint)
    {
        [event setLoginHint:self.interactiveRequestParamaters.loginHint];
    }

    [event setWebviewType:self.interactiveRequestParamaters.telemetryWebviewType];
    [event setPromptType:self.interactiveRequestParamaters.promptType];

    return event;
}

@end
