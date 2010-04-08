#import "MobileWebModule.h"

@implementation MobileWebModule

- (id) init {
    self = [super init];
    if (self != nil) {
        self.tag = MobileWebTag;
        self.shortName = @"Mobile Web";
        self.longName = @"MIT Mobile Web";
        self.iconName = @"webmitedu";
        self.isMovableTab = FALSE;
        self.canBecomeDefault = FALSE;
    }
    return self;
}

- (void)willAppear {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@/", MITMobileWebDomainString]]];
}

@end
