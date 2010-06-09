#import "StellarClassesTableController.h"
#import "StellarCoursesTableController.h"
#import "StellarDetailViewController.h"
#import "StellarClassTableCell.h"
#import "MITModuleList.h"
#import "MITModule.h"
#import "MITLoadingActivityView.h"
#import "MITSearchEffects.h"
#import "UITableView+MITUIAdditions.h"
#import "MultiLineTableViewCell.h"


@interface StellarClassesTableController (Private)
- (void) alertViewCancel: (UIAlertView *)alertView;
- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex: (NSInteger)buttonIndex;
@end

@implementation StellarClassesTableController
@synthesize classes, currentClassLoader;
@synthesize loadingView;
@synthesize url;

- (id) initWithCourse: (StellarCourse *)aCourse {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		course = [aCourse retain];
		classes = [[NSArray array] retain];
		loadingView = nil;
		url = [[MITModuleURL alloc] initWithTag:StellarTag];
	}
	return self;
}

- (void) dealloc {
	currentClassLoader.tableController = nil;
	[url release];
	[loadingView release];
	[currentClassLoader release];
	[classes release];
	[course release];
	[super dealloc];
}

- (void) showLoadingView {
	self.tableView.tableHeaderView = loadingView;
	self.tableView.backgroundColor = [UIColor clearColor];
}

- (void) hideLoadingView {
	self.tableView.tableHeaderView = nil;
	self.tableView.backgroundColor = [UIColor whiteColor];
}
	
- (void) viewDidLoad {
	self.title = [@"Course " stringByAppendingString:course.number];
	self.currentClassLoader = [[LoadClassesInTable new] autorelease];
	self.currentClassLoader.tableController = self;
	
	[self.tableView applyStandardCellHeight];
	
	self.loadingView = [[[MITLoadingActivityView alloc] initWithFrame:[MITSearchEffects frameWithHeader:self.navigationController.navigationBar]]
		autorelease];
	
	[self showLoadingView];
	
	[StellarModel loadClassesForCourse:course delegate:self.currentClassLoader];
	
	[url setPathWithViewController:self extension:course.number];
}

- (void) viewDidAppear: (BOOL)animated {
	[url setAsModulePath];
}

- (NSInteger) numberOfSectionsInTableView: (UITableView *)tableView {
	return 1;
}

- (UITableViewCell *)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StellarClasses"];
	if(cell == nil) {
		cell = [[[StellarClassTableCell alloc] initWithReusableCellIdentifier:@"StellarClasses"] autorelease];
	}
	
	StellarClass *stellarClass = [classes objectAtIndex:indexPath.row];
	return [StellarClassTableCell configureCell:cell withStellarClass:stellarClass];
}	

- (NSInteger) tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section {
	return [classes count];
}

- (void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath {
	[StellarDetailViewController 
		launchClass:(StellarClass *)[classes objectAtIndex:indexPath.row]
		viewController: self];
}

- (CGFloat) tableView: (UITableView *)tableView heightForRowAtIndexPath: (NSIndexPath *)indexPath {
	return [StellarClassTableCell cellHeightForTableView:tableView class:[classes objectAtIndex:indexPath.row]];
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex: (NSInteger)buttonIndex {
	[self.navigationController popViewControllerAnimated:YES];
}

- (void) alertViewCancel: (UIAlertView *)alertView {
	[self.navigationController popViewControllerAnimated:YES];
}
	
@end


@implementation LoadClassesInTable
@synthesize tableController;

- (void) classesLoaded: (NSArray *)aClassList {
	if(tableController.currentClassLoader == self) {
		tableController.classes = aClassList;
		[tableController hideLoadingView];
		[tableController.tableView reloadData];
	}
}

- (void) handleCouldNotReachStellar {
	if(tableController.currentClassLoader == self) {
		[tableController hideLoadingView];
		
		UIAlertView *alert = [[UIAlertView alloc] 
			initWithTitle:@"Connection Failed" 
			message:[NSString stringWithFormat:@"Could not connect to Stellar to retrieve classes for %@, please try again later", tableController.title]
			delegate:tableController
			cancelButtonTitle:@"OK" 
			otherButtonTitles:nil];
		[alert show];
        [alert release];
	}
}
@end