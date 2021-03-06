//
//  CryptoBuff.m
//
//  Created by BoWang on 16/5/3.
//  Copyright © 2016年 BoWang. All rights reserved.
//

#import "CryptoBuff.h"

#pragma mark - NSData extension

//MD5
NSData *_buffMD5FromData(NSData *source) {
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(source.bytes, (CC_LONG) source.length, result);
    NSData *md5 = [[NSData alloc] initWithBytes:result length:CC_MD5_DIGEST_LENGTH];
    NSData *data;
    [data bytes];
    return md5;

}

//SHA1
NSData *_buffSHA1FromData(NSData *source) {
    uint8_t result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(source.bytes, (CC_LONG) source.length, result);
    NSData *sha1 = [[NSData alloc] initWithBytes:result length:CC_SHA1_DIGEST_LENGTH];
    return sha1;
}

//SHA224
NSData *_buffSHA224FromData(NSData *source) {
    uint8_t result[CC_SHA224_DIGEST_LENGTH];
    CC_SHA224(source.bytes, (CC_LONG) source.length, result);
    NSData *sha224 = [[NSData alloc] initWithBytes:result length:CC_SHA224_DIGEST_LENGTH];
    return sha224;
}

NSData *_buffSHA256FromData(NSData *source) {
    uint8_t result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(source.bytes, (CC_LONG) source.length, result);
    NSData *sha256 = [[NSData alloc] initWithBytes:result length:CC_SHA256_DIGEST_LENGTH];
    return sha256;
}

NSData *_buffSHA384FromData(NSData *source) {
    uint8_t result[CC_SHA384_DIGEST_LENGTH];
    CC_SHA384(source.bytes, (CC_LONG) source.length, result);
    NSData *sha384 = [[NSData alloc] initWithBytes:result length:CC_SHA384_DIGEST_LENGTH];
    return sha384;
}

NSData *_buffSHA512FromData(NSData *source) {
    uint8_t result[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(source.bytes, (CC_LONG) source.length, result);
    NSData *sha512 = [[NSData alloc] initWithBytes:result length:CC_SHA512_DIGEST_LENGTH];
    return sha512;
}

#pragma mark - AES,DES,3DES,Blowfish加密解密通用

BOOL _buffCheckKey(CCAlgorithm al, NSString *key, NSString *iv) {
    BOOL isKeyRight = YES;
//    NSException *e ;
//    e=[NSException
//       exceptionWithName: @""
//       reason: @""
//       userInfo: nil];
//    @throw e;
    //密钥有效性判断
    //AES密钥长度有3个固定值。DES,3DES密钥长度是一个固定值。Blowfish的密钥长度处于区间[8,56]。
    switch (al) {
        case 0:
            if (key.length != kCCKeySizeAES128 && key.length != kCCKeySizeAES192 && key.length != kCCKeySizeAES256) {
#ifdef DEBUG
                NSLog(@"AES:KEY LENGTH MUST BE 16,24 OR 32");
#endif


                isKeyRight = NO;
            }
            break;
        case kCCAlgorithmDES:
            if (key.length != kCCKeySizeDES) {
#ifdef DEBUG
                NSLog(@"DES:KEY LENGTH MUST BE 8");
#endif
                isKeyRight = NO;
            }
            break;
        case kCCAlgorithm3DES:
            if (key.length != kCCKeySize3DES) {
#ifdef DEBUG
                NSLog(@"3DES:KEY LENGTH MUST BE 24");
#endif
                isKeyRight = NO;
            }
            break;
        case kCCAlgorithmBlowfish:
            if (key.length > 56 || key.length < 8) {
#ifdef DEBUG
                NSLog(@"Blowfish:KEY LENGTH MUST BE in closed interval [8,56]");
#endif
                isKeyRight = NO;
            }
            break;
        default:
            break;
    }
    //IV有效性判断
    if (key.length != iv.length) {
#ifdef DEBUG
        NSLog(@"IV LENGTH MUST BE EQUAL TO KEY LENGTH");
#endif
        isKeyRight = NO;
    }
    return isKeyRight;
}

NSData *_buffCryptoFromData(CCOperation op, BuffCryptoMode mode, CCAlgorithm al, NSData *source, NSString *iv, NSString *key, NSInteger keySize) {
    CCCryptorRef cryptor;
    //检验传入的key和iv的正确性
    BOOL isKeyRight = _buffCheckKey(al, key, iv);
    if (!isKeyRight) {
        return nil;
    }
    NSMutableData *sourceM = [[NSMutableData alloc] initWithData:source];

    if (mode == BuffCryptoModeCBC || mode == BuffCryptoModeECB) {
        //   在CBC和ECB的情况下可能需要进行补位(padding)操作（加解密操作需要源数据的长度必须能被key.length整除。若不能，则通过添加0x07对源数据来补位，直到源数据的长度能被key.length整除。PS:加密后的长度必然能被key.length整除）
        int pad = 0x07;
        while (sourceM.length % key.length != 0) {
            NSData *padData = [[NSData alloc] initWithBytes:&pad length:1];
            [sourceM appendData:padData];
        }

    }
    NSData *ivData = [iv dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    //CTR模式必填kCCModeOptionCTR_BE
    CCModeOptions mo = 0;
    if (mode == BuffCryptoModeCTR) {
        mo = kCCModeOptionCTR_BE;
    }
    CCCryptorStatus result = CCCryptorCreateWithMode(op,
            mode,
            al,
            0,
            [ivData bytes] ? [ivData bytes] : NULL,
            [keyData bytes],
            keyData.length,
            NULL,
            0,
            0,
            mo,
            &cryptor);
    size_t bufferLength = CCCryptorGetOutputLength(cryptor, [sourceM length], true);
    size_t outLength;
    NSMutableData *outData = [[NSMutableData alloc] initWithLength:bufferLength];
    if (result == kCCSuccess) {
        result = CCCryptorUpdate(cryptor,
                [sourceM bytes],
                [sourceM length],
                [outData mutableBytes],
                outData.length,
                &outLength);
        if (result != kCCSuccess) {
            outData = nil;
        }
    }
    else {
        outData = nil;
    }
    return outData;
}

#pragma mark -

NSData *_buffAESEncodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key) {
    return _buffCryptoFromData(kCCEncrypt, mode, kCCAlgorithmAES, source, iv, key, key.length);
}

NSData *_buffAESDecodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key) {
    return _buffCryptoFromData(kCCDecrypt, mode, kCCAlgorithmAES, source, iv, key, key.length);
}

NSData *_buffDESEncodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key) {
    return _buffCryptoFromData(kCCEncrypt, mode, kCCAlgorithmDES, source, iv, key, kCCKeySizeDES);
}

NSData *_buffDESDecodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key) {
    return _buffCryptoFromData(kCCDecrypt, mode, kCCAlgorithmDES, source, iv, key, kCCKeySizeDES);
}

NSData *_buff3DESEncodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key) {
    return _buffCryptoFromData(kCCEncrypt, mode, kCCAlgorithm3DES, source, iv, key, kCCKeySize3DES);
}

NSData *_buff3DESDecodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key) {
    return _buffCryptoFromData(kCCDecrypt, mode, kCCAlgorithm3DES, source, iv, key, kCCKeySize3DES);
}

NSData *_buffBlowfishEncodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key, NSInteger keySize) {
    return _buffCryptoFromData(kCCEncrypt, mode, kCCAlgorithmBlowfish, source, iv, key, keySize);
}

NSData *_buffBlowfishDecodeFromData(NSData *source, BuffCryptoMode mode, NSString *iv, NSString *key, NSInteger keySize) {
    return _buffCryptoFromData(kCCDecrypt, mode, kCCAlgorithmBlowfish, source, iv, key, keySize);
}

@implementation NSData (CryptoBuff)

#pragma mark MD5,SHA1,SHA2,

- (NSData *)bfCryptoMD5 {
    return _buffMD5FromData(self);
}

- (void)bfCryptoMD5Async:(void (^)(NSData *))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffMD5FromData(self));
    });
}

- (NSData *)bfCryptoSHA1 {
    return _buffSHA1FromData(self);
}

- (void)bfCryptoSHA1Async:(void (^)(NSData *))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA1FromData(self));
    });
}

- (NSData *)bfCryptoSHA224 {
    return _buffSHA224FromData(self);
}

- (void)bfCryptoSHA224Async:(void (^)(NSData *))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA224FromData(self));
    });
}

- (NSData *)bfCryptoSHA256 {
    return _buffSHA256FromData(self);
}

- (void)bfCryptoSHA256Async:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA256FromData(self));
    });
}

- (NSData *)bfCryptoSHA384 {
    return _buffSHA384FromData(self);
}

- (void)bfCryptoSHA384Async:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA384FromData(self));
    });
}

- (NSData *)bfCryptoSHA512 {
    return _buffSHA512FromData(self);
}

- (void)bfCryptoSHA512Async:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA512FromData(self));
    });
}

#pragma mark AES


- (void)bfCryptoAESEncodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffAESEncodeFromData(self, mode, iv, key));
    });
}

- (void)bfCryptoAESDecodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffAESDecodeFromData(self, mode, iv, key));
    });
}

#pragma mark DES


- (void)bfCryptoDESEncodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffDESEncodeFromData(self, mode, iv, key));
    });
}

- (void)bfCryptoDESDecodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffDESDecodeFromData(self, mode, iv, key));
    });
}

#pragma mark 3DES

- (void)bfCrypto3DESEncodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buff3DESEncodeFromData(self, mode, iv, key));
    });
}

- (void)bfCrypto3DESDecodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buff3DESDecodeFromData(self, mode, iv, key));
    });

}

#pragma mark Blowfish

- (void)bfCryptoBlowfishEncodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffBlowfishEncodeFromData(self, mode, iv, key, key.length));
    });
}

- (void)bfCryptoBlowfishDecodeWithMode:(BuffCryptoMode)mode iv:(NSString *)iv key:(NSString *)key completion:(void (^)(NSData *cryptoData))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffBlowfishDecodeFromData(self, mode, iv, key, key.length));
    });
}

@end

#pragma mark - NSString extension

NSString *_buffMD5FromString(NSString *source) {
    const char *cStr = [source UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG) strlen(cStr), result);
    NSString *md5 = [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
    ];
    return md5;
}

NSString *_buffSHA1FromString(NSString *source) {
    const char *cstr = [source cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:source.length];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG) data.length, digest);
    NSMutableString *sha1 = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [sha1 appendFormat:@"%02x", digest[i]];
    }
    return sha1;
}

NSString *_buffSHA224FromString(NSString *source) {
    const char *cstr = [source cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:source.length];
    uint8_t digest[CC_SHA224_DIGEST_LENGTH];
    CC_SHA224(data.bytes, (CC_LONG) data.length, digest);
    NSMutableString *sha224 = [NSMutableString stringWithCapacity:CC_SHA224_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA224_DIGEST_LENGTH; i++) {
        [sha224 appendFormat:@"%02x", digest[i]];
    }
    return sha224;
}

NSString *_buffSHA256FromString(NSString *source) {
    const char *cstr = [source cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:source.length];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG) data.length, digest);
    NSMutableString *sha256 = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [sha256 appendFormat:@"%02x", digest[i]];
    }
    return sha256;
}

NSString *_buffSHA384FromString(NSString *source) {
    const char *cstr = [source cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:source.length];
    uint8_t digest[CC_SHA384_DIGEST_LENGTH];
    CC_SHA384(data.bytes, (CC_LONG) data.length, digest);
    NSMutableString *sha384 = [NSMutableString stringWithCapacity:CC_SHA384_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA384_DIGEST_LENGTH; i++) {
        [sha384 appendFormat:@"%02x", digest[i]];
    }
    return sha384;
}

NSString *_buffSHA512FromString(NSString *source) {
    const char *cstr = [source cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:source.length];
    uint8_t digest[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(data.bytes, (CC_LONG) data.length, digest);
    NSMutableString *sha512 = [NSMutableString stringWithCapacity:CC_SHA512_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++) {
        [sha512 appendFormat:@"%02x", digest[i]];
    }
    return sha512;
}

@implementation NSString (CryptoBuff)
#pragma mark MD5,SHA1,SHA2,

- (NSString *)bfCryptoMD5 {
    return _buffMD5FromString(self);
}

- (void)bfCryptoMD5Async:(void (^)(NSString *))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffMD5FromString(self));
    });
}

- (NSString *)bfCryptoSHA1 {
    return _buffSHA1FromString(self);
}

- (void)bfCryptoSHA1Async:(void (^)(NSString *))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA1FromString(self));
    });
}

- (NSString *)bfCryptoSHA224 {
    return _buffSHA224FromString(self);

}

- (void)bfCryptoSHA224Async:(void (^)(NSString *cryptoString))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA224FromString(self));
    });
}

- (NSString *)bfCryptoSHA256 {
    return _buffSHA256FromString(self);
}

- (void)bfCryptoSHA256Async:(void (^)(NSString *cryptoString))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA256FromString(self));
    });
}

- (NSString *)bfCryptoSHA384 {
    return _buffSHA384FromString(self);
}

- (void)bfCryptoSHA384Async:(void (^)(NSString *cryptoString))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA384FromString(self));
    });
}

- (NSString *)bfCryptoSHA512 {
    return _buffSHA512FromString(self);
}

- (void)bfCryptoSHA512Async:(void (^)(NSString *cryptoString))cryptoBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        cryptoBlock(_buffSHA512FromString(self));
    });
}
@end

@implementation CryptoBuff
@end

