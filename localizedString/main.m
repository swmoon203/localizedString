//
//  main.m
//  localizedString
//
//  Created by MoonSung Wook on 2016. 1. 2..
//  Copyright © 2016년 smoon.kr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSMutableArray *arguments = [NSMutableArray array];
        
        for (int i = 1; i < argc; i++) {
            NSString *s = [NSString stringWithUTF8String:argv[i]];
            [arguments addObject:s];
        }
        
        if ([arguments count] != 2) {
            NSLog(@"invalid arguments");
            return 0;
        }
        
        NSString *projectPath = arguments[0];
        NSString *stringPath = arguments[1];
        
        NSString *header = nil;
        
        NSMutableDictionary *words = [NSMutableDictionary dictionary];
        NSMutableDictionary *groupedWords = [NSMutableDictionary dictionary];
        
#define FS [NSFileManager defaultManager]
        
        if ([FS fileExistsAtPath:stringPath]) {
            header = [NSString stringWithContentsOfFile:stringPath encoding:NSUTF8StringEncoding error:nil];
            
            NSDictionary *stringDictionary = [header propertyListFromStringsFileFormat];
            if (stringDictionary) [words setDictionary:words];
            
            if ([header rangeOfString:@"/*"].location == 0) {
                NSRange r = [header rangeOfString:@"*/"];
                header = [header substringWithRange:NSMakeRange(0, r.location + 2)];
            } else {
                header = @"";
            }
        } else {
            header = @"";
        }
        
        JSContext *context = [[JSContext alloc] init];
        [context evaluateScript:@"var nil = null"];
        [context evaluateScript:@"function NSLocalizedString(key, comment) { return key; }"];
        
        NSArray *subPaths = [FS subpathsAtPath:projectPath];
        
        for (NSString *subPath in subPaths) {
            NSString *path = [projectPath stringByAppendingPathComponent:subPath];
            if ([[path pathExtension] isEqualToString:@"m"] == NO) continue;
            NSLog(@"%@", path);
            
            NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            if (content == nil) continue;
            // The NSRegularExpression class is currently only available in the Foundation framework of iOS 4
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"NSLocalizedString\\(\\@\\\"((?!NSLocalizedString).)*\\\",[ ]*(\\@\\\"((?!NSLocalizedString).)*\\\"|nil)\\)" options:0 error:nil];
            NSArray *matches = [regex matchesInString:content options:0 range:NSMakeRange(0, [content length])];
            for (NSTextCheckingResult *match in matches) {
                NSString *matchText = [content substringWithRange:[match range]];
                matchText = [matchText stringByReplacingOccurrencesOfString:@"%@" withString:@"%@@"];
                matchText = [matchText stringByReplacingOccurrencesOfString:@"@\"" withString:@"\""];
                matchText = [matchText stringByReplacingOccurrencesOfString:@"%@@" withString:@"%@"];
                
                JSValue *value = [context evaluateScript:matchText];
                
                NSLog(@"match: %@ -> %@", matchText, [value toString]);
                
                NSString *key = [value toString];
                
                if (words[key] == nil) {
                    words[key] = key;
                }
                NSMutableDictionary *g = groupedWords[subPath];
                if (g == nil) {
                    g = [NSMutableDictionary dictionary];
                    groupedWords[subPath] = g;
                }
                g[key] = words[key];
            }
        }
        
        NSLog(@"%@", groupedWords);
        NSLog(@"");
        
        NSMutableSet *taken = [NSMutableSet set];
        
        NSMutableString *output = [NSMutableString stringWithString:header];

        NSString *(^escape)(NSString *) = ^(NSString *string) {
            string = [string stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
            string = [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            
            return string;
        };
        
        for (NSString *file in groupedWords.allKeys) {
            [output appendFormat:@"\n// %@\n", file];
            
            NSDictionary *w = groupedWords[file];
            for (NSString *key in w.allKeys) {
                NSString *vk = escape(key);
                NSString *value = escape(w[key]);
                
                if ([taken containsObject:key] == NO) [output appendFormat:@"%@\"%@\" = \"%@\";\n", [taken containsObject:key] ? @"//" : @"", vk, value];
                [taken addObject:key];
            }
            
            [output appendString:@"\n"];
        }
        
        NSLog(@"%@", output);
        [output writeToFile:stringPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
    return 0;
}
