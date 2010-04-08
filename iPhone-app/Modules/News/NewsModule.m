#import "NewsModule.h"
#import "StoryListViewController.h"

@implementation NewsModule

@synthesize storyListChannelController;

- (id) init {
    self = [super init];
    if (self != nil) {
        self.tag = NewsOfficeTag;
        self.shortName = @"News";
        self.longName = @"News Office";
        self.iconName = @"webmitedu";
        
        storyListChannelController = [[StoryListViewController alloc] init];
        [self.tabNavController setViewControllers:[NSArray arrayWithObject:storyListChannelController]];
    }
    return self;
}

- (void)dealloc {
    [storyListChannelController release];
    [super dealloc];
}

@end
