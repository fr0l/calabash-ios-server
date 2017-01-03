#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

//
//  Operation.m
//  Created by Karl Krukow on 14/08/11.
//  Copyright 2011 LessPainful. All rights reserved.
//

#import "LPOperation.h"
#import "UIScriptParser.h"
#import "LPScrollToMarkOperation.h"
#import "LPScrollToRowOperation.h"
#import "LPScrollToRowWithMarkOperation.h"
#import "LPCollectionViewScrollToItemWithMarkOperation.h"
#import "LPScrollOperation.h"
#import "LPQueryOperation.h"
#import "LPFlashOperation.h"
#import "LPSetTextOperation.h"
#import "LPDatePickerOperation.h"
#import "LPOrientationOperation.h"
#import "LPTouchUtils.h"
#import "LPSliderOperation.h"
#import "LPCollectionViewScrollToItemOperation.h"
#import "LPInvoker.h"
#import "LPInvocationResult.h"
#import "LPInvocationError.h"
#import "LPCocoaLumberjack.h"
#import "LPJSONUtils.h"
#import "CocoaLumberjack.h"

NSString const *kLPServerOperationErrorToken = @"LPOperationErrorToken";

@interface LPOperation ()

@end

@implementation LPOperation

#pragma mark - Memory Management

@synthesize selector = _selector;
@synthesize arguments = _arguments;
@synthesize done = _done;

- (id) initWithOperation:(NSDictionary *) operation {
  self = [super init];
  if (self != nil) {
    _selector = NSSelectorFromString(operation[@"method_name"]);
    _arguments = operation[@"arguments"];
    _done = NO;
  }
  return self;
}

+ (id) operationFromDictionary:(NSDictionary *) dictionary {
  NSString *opName = [dictionary valueForKey:@"method_name"];
  LPOperation *operation = nil;
  if ([opName isEqualToString:@"scrollToRow"]) {
    operation = [[LPScrollToRowOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"collectionViewScrollToItemWithMark"]) {
    operation = [[LPCollectionViewScrollToItemWithMarkOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"scrollToRowWithMark"]) {
    operation = [[LPScrollToRowWithMarkOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"scrollToMark"]) {
    operation = [[LPScrollToMarkOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"scroll"]) {
    operation = [[LPScrollOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"query"]) {
    operation = [[LPQueryOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"query_all"]) {
    operation = [[LPQueryAllOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"setText"]) {
    operation = [[LPSetTextOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"flash"]) {
    operation = [[LPFlashOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"orientation"]) {
    operation = [[LPOrientationOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"changeDatePickerDate"]) {
    operation = [[LPDatePickerOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"changeSlider"]) {
    operation = [[LPSliderOperation alloc] initWithOperation:dictionary];
  } else if ([opName isEqualToString:@"collectionViewScroll"]) {
    operation = [[LPCollectionViewScrollToItemOperation alloc]
                 initWithOperation:dictionary];
  } else {
    operation = [[LPOperation alloc] initWithOperation:dictionary];
  }

  return operation;
}

- (NSString *) description {
  NSString *className = NSStringFromClass([self class]);
  return [NSString stringWithFormat:@"<%@ '%@' with arguments '%@'>",
          className, NSStringFromSelector(_selector),
          [_arguments componentsJoinedByString:@", "]];
}

- (NSError *)errorWithDescription:(NSString *)description {
  LPLogError(@"%@", description);
  return [NSError errorWithDomain:@"LPServerError"
                             code:1
                         userInfo:@{ NSLocalizedDescriptionKey : description }];
}

- (void)getError:(NSError *__autoreleasing*)error
 withDescription:(NSString *)description {
   NSError *innerError = [self errorWithDescription:description];
  if (error) { *error = innerError; }
}

+ (NSArray *) performQuery:(id) query {
  UIScriptParser *parser = nil;
  if ([query isKindOfClass:[NSString class]]) {
    parser = [[UIScriptParser alloc] initWithUIScript:(NSString *) query];
  } else if ([query isKindOfClass:[NSArray class]]) {
    parser = [[UIScriptParser alloc] initWithQuery:(NSArray *) query];
  } else {
    return nil;
  }
  [parser parse];

  NSArray *allWindows = [LPTouchUtils applicationWindows];

  NSArray *result = [parser evalWith:allWindows];

  return result;
}

/*
 Examples:

 # Map calls this method, because :text is not a defined operation.
 > map("textField", :text)
 => [ "old text" ]

 # Map does not call this method, because :setText is a defined operation -
 # see operationFromDictionary:
 > map("textField", :setText, 'new text')
 => [ <UITextField ... > ]

 # Map calls this method, because 'setText:' (note the trailing ':'!) is not a defined
 # operation.
 > map("textField", 'setText:', 'newer text')
 => [ "<VOID>" ]

 The map function in the ruby client is the only caller I have found.
 */
- (id) performWithTarget:(id) target error:(NSError *__autoreleasing*) error {
  LPInvocationResult *invocationResult;
  invocationResult = [LPInvoker invokeSelector:self.selector
                                    withTarget:target
                                     arguments:self.arguments];
  id returnValue = nil;

  if ([invocationResult isError]) {
    NSString *description = [invocationResult description];
    if (error) {
      NSDictionary *userInfo =
      @{
        NSLocalizedDescriptionKey : description
        };
      *error = [NSError errorWithDomain:@"CalabashServer"
                                   code:1
                               userInfo:userInfo];
    }
    LPLogError(@"Could not call selector '%@' on target '%@' - %@",
               NSStringFromSelector(self.selector), target, description);
    returnValue = description;
  } else {
    if ([invocationResult isNSNull]) {
      returnValue = nil;
    } else {
      returnValue = invocationResult.value;
    }
  }

  return returnValue;
}

@end
