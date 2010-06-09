#import "PeopleModule.h"
#import "MITModuleURL.h"
#import "PeopleSearchViewController.h"
#import "PeopleDetailsViewController.h"
#import "PeopleRecentsData.h"
#import "PersonDetails.h"

static NSString * const PeopleStateSearchBegin = @"search-begin";
static NSString * const PeopleStateSearchComplete = @"search-complete";
static NSString * const PeopleStateSearchExternal = @"search";
static NSString * const PeopleStateDetail = @"detail";

@implementation PeopleModule

- (id)init
{
    if (self = [super init]) {
        self.tag = DirectoryTag;
        self.shortName = @"Directory";
        self.longName = @"People Directory";
        self.iconName = @"people";

		viewController = [[[PeopleSearchViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
		viewController.navigationItem.title = self.longName;
        
        [self.tabNavController setViewControllers:[NSArray arrayWithObject:viewController]];
    }
    return self;
}

- (void)applicationWillTerminate
{
	MITModuleURL *url = [[MITModuleURL alloc] initWithTag:DirectoryTag];
	
	UIViewController *visibleVC = viewController.navigationController.visibleViewController;
	if ([visibleVC isMemberOfClass:[PeopleSearchViewController class]]) {
		PeopleSearchViewController *searchVC = (PeopleSearchViewController *)visibleVC;
		if (searchVC.searchController.active) {
			if (searchVC.searchResults != nil) {
				[url setPath:PeopleStateSearchComplete query:searchVC.searchTerms];
			} else {
				[url setPath:PeopleStateSearchBegin query:searchVC.searchTerms];
			}
		} else {
			[url setPath:nil query:nil];
		}

	} else if ([visibleVC isMemberOfClass:[PeopleDetailsViewController class]]) {
		PeopleDetailsViewController *detailVC = (PeopleDetailsViewController *)visibleVC;
		[url setPath:PeopleStateDetail query:detailVC.personDetails.uid];
	}
	
	[url setAsModulePath];
	[url release];
}


/*
- (void)applicationDidFinishLaunching
{
}
*/

- (BOOL)handleLocalPath:(NSString *)localPath query:(NSString *)query {
    BOOL didHandle = NO;
	
	UIViewController *visibleVC = viewController.navigationController.visibleViewController;

	if (visibleVC != viewController) {
		// start from root view of directory.  the only time this is really
		// needed is when we're called from another module, not on startup
		[viewController.navigationController popViewControllerAnimated:NO];
	}
 
	if (localPath == nil) {
		didHandle = YES;
	} 
	
	// search
	else if ([localPath isEqualToString:PeopleStateSearchBegin]) {
		viewController.view;
		if (query != nil) {
			viewController.searchBar.text = query;
		}
		viewController.actionAfterAppearing = @selector(prepSearchBar);
        didHandle = YES;
		
	} else if (!query || [query length] == 0) {
		// from this point forward we don't want to handle anything
		// without proper query terms
		didHandle = NO;
		
	} else if ([localPath isEqualToString:PeopleStateSearchComplete]) {
		viewController.view;
		viewController.actionAfterAppearing = @selector(prepSearchBar);
        [viewController beginExternalSearch:query];
		didHandle = YES;
		
	} else if ([localPath isEqualToString:PeopleStateSearchExternal]) {
		// this path is reserved for calling from other modules
		// do not save state with this path       
		viewController.view;
		if (viewController.viewAppeared) {
			[viewController prepSearchBar];
		} else {
			[viewController setActionAfterAppearing:@selector(prepSearchBar)];
		}
        [viewController beginExternalSearch:query];
        [self becomeActiveTab];
        didHandle = YES;
    
	}

	// detail
	else if ([localPath isEqualToString:PeopleStateDetail]) {
		PersonDetails *person = [PeopleRecentsData personWithUID:query];
		if (person != nil) {
			PeopleDetailsViewController *detailVC = [[PeopleDetailsViewController alloc] initWithStyle:UITableViewStyleGrouped];
			detailVC.personDetails = person;
			[viewController.navigationController pushViewController:detailVC animated:NO];
			[detailVC release];
			didHandle = YES;
		}
	}
	
    return didHandle;
}


- (void)dealloc
{
	[super dealloc];
}


@end

