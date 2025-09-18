#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "AiAppLogo" asset catalog image resource.
static NSString * const ACImageNameAiAppLogo AC_SWIFT_PRIVATE = @"AiAppLogo";

/// The "Button" asset catalog image resource.
static NSString * const ACImageNameButton AC_SWIFT_PRIVATE = @"Button";

/// The "TargetImage" asset catalog image resource.
static NSString * const ACImageNameTargetImage AC_SWIFT_PRIVATE = @"TargetImage";

#undef AC_SWIFT_PRIVATE
