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

#import "MSIDDefaultCredentialCacheKey.h"
#import "NSString+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDCredentialType.h"
#import "NSURL+MSIDExtensions.h"
#import "MSIDIntuneEnrollmentIdsCache.h"

static NSString *keyDelimiter = @"-";
static NSInteger kCredentialTypePrefix = 2000;

@implementation MSIDDefaultCredentialCacheKey

#pragma mark - Helpers

// kSecAttrService - (<credential_type>-<client_id>-<realm>-<enrollment_id>-<target>)
- (NSString *)serviceWithType:(MSIDCredentialType)type
                     clientID:(NSString *)clientId
                        realm:(NSString *)realm
                 enrollmentId:(NSString *)enrollmentId
                       target:(NSString *)target
                       appKey:(NSString *)appKey
{
    realm = realm.msidTrimmedString.lowercaseString;
    clientId = clientId.msidTrimmedString.lowercaseString;
    target = target.msidTrimmedString.lowercaseString;
    enrollmentId = enrollmentId.msidTrimmedString.lowercaseString;

    NSString *credentialId = [self credentialIdWithType:type clientId:clientId realm:realm enrollmentId:enrollmentId];
    NSString *service = [NSString stringWithFormat:@"%@%@%@",
                         credentialId,
                         keyDelimiter,
                         (target ? target : @"")];
    
    if (![NSString msidIsStringNilOrBlank:appKey])
    {
        service  = [NSString stringWithFormat:@"%@|%@", service, appKey];
    }
    
    return service;
}

// credential_id - (<credential_type>-<client_id>-<realm>-<enrollment_id>)
- (NSString *)credentialIdWithType:(MSIDCredentialType)type
                          clientId:(NSString *)clientId
                             realm:(NSString *)realm
                      enrollmentId:(NSString *)enrollmentId
{
    realm = realm.msidTrimmedString.lowercaseString;
    clientId = clientId.msidTrimmedString.lowercaseString;
    enrollmentId = enrollmentId.msidTrimmedString.lowercaseString;

    NSString *credentialType = [MSIDCredentialTypeHelpers credentialTypeAsString:type].lowercaseString;
    
    return [NSString stringWithFormat:@"%@%@%@%@%@%@%@",
            credentialType, keyDelimiter, clientId,
            keyDelimiter,
            (realm ? realm : @""),
            (enrollmentId ? keyDelimiter : @""),
            (enrollmentId ? enrollmentId : @"")];
}

// kSecAttrAccount - account_id (<unique_id>-<environment>)
- (NSString *)accountIdWithHomeAccountId:(NSString *)homeAccountId
                             environment:(NSString *)environment
{
    homeAccountId = homeAccountId.msidTrimmedString.lowercaseString;
    environment = environment.msidTrimmedString.lowercaseString;

    return [NSString stringWithFormat:@"%@%@%@",
            homeAccountId, keyDelimiter, environment];
}

- (NSNumber *)credentialTypeNumber:(MSIDCredentialType)credentialType
{
    return @(kCredentialTypePrefix + credentialType);
}

#pragma mark - Public

- (instancetype)initWithHomeAccountId:(NSString *)homeAccountId
                          environment:(NSString *)environment
                             clientId:(NSString *)clientId
                       credentialType:(MSIDCredentialType)type
{
    self = [super init];

    if (self)
    {
        _homeAccountId = homeAccountId;
        _environment = environment;
        _clientId = clientId;
        _credentialType = type;
    }

    return self;
}

- (NSData *)generic
{
    NSString *clientId = self.familyId ? self.familyId : self.clientId;
    return [[self credentialIdWithType:self.credentialType clientId:clientId realm:self.realm enrollmentId:self.enrollmentId] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSNumber *)type
{
    return [self credentialTypeNumber:self.credentialType];
}

- (NSString *)account
{
    return [self accountIdWithHomeAccountId:self.homeAccountId environment:self.environment];
}

- (NSString *)service
{
    NSString *clientId = self.familyId ? self.familyId : self.clientId;
    return [self serviceWithType:self.credentialType clientID:clientId realm:self.realm enrollmentId:self.enrollmentId target:self.target appKey:self.appKey];
}

- (BOOL)isShared
{
    return self.credentialType == MSIDRefreshTokenType;
}

#pragma mark - Broker

- (NSNumber *)appKeyHash
{
    if (self.appKey)
    {
        return @(self.appKey.hash);
    }
    
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    MSIDDefaultCredentialCacheKey *item = [[self.class allocWithZone:zone] init];
    item->_homeAccountId = [_homeAccountId copyWithZone:zone];
    item->_environment = [_environment copyWithZone:zone];
    item->_realm = [_realm copyWithZone:zone];
    item->_clientId = [_clientId copyWithZone:zone];
    item->_familyId = [_familyId copyWithZone:zone];
    item->_target = [_target copyWithZone:zone];
    item->_enrollmentId = [_enrollmentId copyWithZone:zone];
    return item;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:self.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDDefaultCredentialCacheKey *)object];
}

- (BOOL)isEqualToItem:(MSIDDefaultCredentialCacheKey *)item
{
    BOOL result = YES;
    result &= (!self.homeAccountId && !item.homeAccountId) || [self.homeAccountId isEqualToString:item.homeAccountId];
    result &= (!self.environment && !item.environment) || [self.environment isEqualToString:item.environment];
    result &= (!self.realm && !item.realm) || [self.realm isEqualToString:item.realm];
    result &= (!self.clientId && !item.clientId) || [self.clientId isEqualToString:item.clientId];
    result &= (!self.familyId && !item.familyId) || [self.familyId isEqualToString:item.familyId];
    result &= (!self.target && !item.target) || [self.target isEqualToString:item.target];
    result &= (!self.enrollmentId && !item.enrollmentId) || [self.enrollmentId isEqualToString:item.enrollmentId];
    return result;
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.homeAccountId.hash;
    hash = hash * 31 + self.environment.hash;
    hash = hash * 31 + self.realm.hash;
    hash = hash * 31 + self.clientId.hash;
    hash = hash * 31 + self.familyId.hash;
    hash = hash * 31 + self.target.hash;
    hash = hash * 31 + self.enrollmentId.hash;
    return hash;
}


@end
