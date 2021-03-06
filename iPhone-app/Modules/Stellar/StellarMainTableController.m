#import "StellarModule.h"
#import "StellarMainTableController.h"
#import "StellarCoursesTableController.h"
#import "StellarDetailViewController.h"
#import "StellarCourseGroup.h"
#import "StellarModel.h"
#import "StellarSearch.h"
#import "UITableView+MITUIAdditions.h"
#import "UITableViewCell+MITUIAdditions.h"
#import "MITConstants.h"
#import "MITUIConstants.h"
#import "MITLoadingActivityView.h"
#import "MITModuleURL.h"

#define myStellarGroup 0
#define browseGroup 1

#define searchBarHeight NAVIGATION_BAR_HEIGHT
@interface StellarMainTableController(Private)
@property (nonatomic, retain) NSString *doSearchTerms;
@end

@implementation StellarMainTableController

@synthesize courseGroups, myStellar;
@synthesize searchController;
@synthesize translucentOverlay, loadingView;
@synthesize myStellarUIisUpToDate;
@synthesize url;

- (id) init {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		url = [[MITModuleURL alloc] initWithTag:StellarTag];
		isViewAppeared = NO;
	}
	return self;
}

- (void) viewDidLoad {
	[self.tableView applyStandardColors];
	
	// initialize with an empty array, to be replaced with data when available
	self.courseGroups = [NSArray array];
	self.myStellar = [NSArray array];
	
	CGRect viewFrame = self.view.frame;
	UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, viewFrame.size.width, searchBarHeight)];
	searchBar.tintColor = SEARCH_BAR_TINT_COLOR;
	
	self.tableView.tableHeaderView = searchBar;	
	
	self.searchController = [[[UISearchDisplayController alloc] 
		initWithSearchBar:searchBar contentsController:self] autorelease];
	
	stellarSearch = [[StellarSearch alloc] initWithSearchBar:searchBar viewController:self];	
	self.searchController.delegate = stellarSearch;
	self.searchController.searchResultsDelegate = stellarSearch;
	self.searchController.searchResultsDataSource = stellarSearch;
	searchBar.placeholder = @"Search by keyword or subject #";
	self.translucentOverlay = [MITSearchEffects overlayForTableviewController:self];
	 
	self.loadingView = [[[MITLoadingActivityView alloc] 
		initWithFrame:[MITSearchEffects frameWithHeader:searchBar]]
			autorelease];
	
	[self reloadMyStellarData];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadMyStellarData) name:MyStellarChanged object:nil];	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadMyStellarNotifications) name:MyStellarAlertNotification object:nil];
	
	// load all course groups (asynchronously) in case it requires server access
	[StellarModel loadCoursesFromServerAndNotify:self];
	
	[StellarModel removeOldFavorites:self];
	
	self.doSearchTerms = nil;
}

- (void) viewDidAppear:(BOOL)animated {
	isViewAppeared = YES;
	if (doSearchTerms) {
		[self doSearch:doSearchTerms execute:doSearchExecute];
	}
	[url setAsModulePath];
}

- (void) viewDidDisappear:(BOOL)animated {
	isViewAppeared = NO;
}

- (void) reloadMyStellarData {
	self.myStellar = [StellarModel myStellarClasses];
	if(![stellarSearch isSearchResultsVisible]) {
		[self.tableView reloadData];
		myStellarUIisUpToDate = YES;
	} else {
		myStellarUIisUpToDate = NO;
	}
}
	
- (void) reloadMyStellarNotifications {
	if(myStellar.count) {
		NSMutableArray *indexPaths = [NSMutableArray array];
		for (NSUInteger rowIndex=0; rowIndex < myStellar.count; rowIndex++) {
			[indexPaths addObject:[NSIndexPath indexPathForRow:rowIndex inSection:myStellarGroup]];
		}
		[self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
	}
}
		
- (void) reloadMyStellarUI {
	if(!myStellarUIisUpToDate) {
		[self.tableView reloadData];
	    myStellarUIisUpToDate = YES;
	}
}

- (void) classesRemoved: (NSArray *)classes {
	NSString *message = @"The following old classes have been removed from your My Stellar settings:";
	BOOL firstId = YES;
	for(StellarClass *class in classes) {
		if(firstId) {
			firstId = NO;
			message = [message stringByAppendingString:@" "];
		} else {
			message = [message stringByAppendingString:@", "];
		}
		message = [message stringByAppendingString:class.masterSubjectId];
	}
	
	UIAlertView *alertView = [[UIAlertView alloc]
		initWithTitle:@"Old Classes" 
		message:message delegate:nil 
		cancelButtonTitle:@"OK" 
		otherButtonTitles:nil];
	
	[alertView show];
	[alertView release];
}

- (void) coursesLoaded {
	self.courseGroups = [StellarCourseGroup allCourseGroups:[StellarModel allCourses]];
	[self.tableView reloadData];
}

// "DataSource" methods
- (NSInteger) numberOfSectionsInTableView: (UITableView *)tableView {
	if([myStellar count]) {
		return 2;
	} else {
		return 1;
	}
}

- (NSInteger) groupIndexFromSectionIndex: (NSInteger)sectionIndex {
	if([myStellar count]) {
		return sectionIndex;
	} else if(sectionIndex == 0) {
		return browseGroup;
	}
	
	return -1;
}

- (UITableViewCell *)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StellarMain"];
	if(cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StellarMain"] autorelease];
		[cell applyStandardFonts];
	}
	
	StellarClass *myStellarClass;
	NSInteger groupIndex = [self groupIndexFromSectionIndex:indexPath.section];
	if(groupIndex == myStellarGroup) {
		myStellarClass = (StellarClass *)[myStellar objectAtIndex:indexPath.row];
		cell.textLabel.text = myStellarClass.name;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
		// check if the class has an unread notice
		if([MITUnreadNotifications hasUnreadNotification:[[[MITNotification alloc] initWithModuleName:StellarTag noticeId:myStellarClass.masterSubjectId] autorelease]]) {
			cell.imageView.image = [UIImage imageNamed:@"unread-message.png"];
		} else {
			cell.imageView.image = nil;
		}
	} else if(groupIndex == browseGroup) {
		cell.textLabel.text = ((StellarCourseGroup *)[courseGroups objectAtIndex:indexPath.row]).title;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.imageView.image = nil;
	}
	return cell;
}

- (NSInteger) tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section {
	NSInteger groupIndex = [self groupIndexFromSectionIndex:section];
	if(groupIndex == myStellarGroup) {
		return [myStellar count];
	} else if(groupIndex == browseGroup) {
		return [courseGroups count];
	}
	return 0;
}

- (UIView *) tableView: (UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	// TODO: determine if there is any benefit to optimizing this
	NSInteger groupIndex = [self groupIndexFromSectionIndex:section];
	NSString *headerTitle = nil;
	if(groupIndex == myStellarGroup) {
		headerTitle = @"My Stellar:";
	} else if(groupIndex == browseGroup) {
		headerTitle = @"Browse By Course:";
	}
	return [UITableView groupedSectionHeaderWithTitle:headerTitle];
}

- (CGFloat)tableView: (UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return GROUPED_SECTION_HEADER_HEIGHT;
}

- (void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath {
	NSInteger groupIndex = [self groupIndexFromSectionIndex:indexPath.section];
	if(groupIndex == myStellarGroup) {
		[StellarDetailViewController
			launchClass:(StellarClass *)[myStellar objectAtIndex:indexPath.row]
			viewController: self];
	} else if(groupIndex == browseGroup) {
		[self.navigationController
			pushViewController: [[[StellarCoursesTableController alloc] 
				initWithCourseGroup: (StellarCourseGroup *)[courseGroups objectAtIndex:indexPath.row]] autorelease]
			animated:YES];
	}
}

- (void) handleCouldNotReachStellar {
	UIAlertView *alert = [[UIAlertView alloc] 
		initWithTitle:@"Connection Failed" 
		message:@"Could not connect to Stellar, please try again later"
		delegate:nil
		cancelButtonTitle:@"OK" 
		otherButtonTitles:nil];
	[alert show];
    [alert release];
}

- (void) searchOverlayTapped {
	[stellarSearch searchOverlayTapped];
}

- (void) doSearch:(NSString *)searchTerms execute:(BOOL)execute {
	if(isViewAppeared) {
		self.searchController.active = YES;
		self.searchController.searchBar.text = searchTerms;
		if (execute) {
			self.searchController.searchBar.text = searchTerms;
			[stellarSearch performSelector:@selector(searchBarSearchButtonClicked:) withObject:self.searchController.searchBar afterDelay:0.3];
		} else {
			// using a delay gets rid of a mysterious wait_fences warning
			[self.searchController.searchBar performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.001];
			[self showTranslucentOverlayWithDelay:YES];
		}
		self.doSearchTerms = nil;
	} else {
		// since view has not appeared yet, this search needs to be delay to either viewWillAppear or viewDidAppear
		// this is a work around for funky behavior when module is in the more list controller
		self.doSearchTerms = searchTerms;
		doSearchExecute = execute;
	}
}

- (void) setDoSearchTerms:(NSString *)searhTerms {
	[doSearchTerms release];
	doSearchTerms = [searhTerms retain];
}

- (NSString *) doSearchTerms {
	return doSearchTerms;
}

- (void) showSearchResultsTable {
	[self.view addSubview:searchController.searchResultsTableView];
}

- (void) showTranslucentOverlayWithDelay:(BOOL)useDelay {
	[translucentOverlay removeBuiltInOverlay];
	if (useDelay) {
		[translucentOverlay removeFromSuperview];
		[self.view performSelector:@selector(addSubview:) withObject:translucentOverlay afterDelay:0.01];
	} else {
		[self.view addSubview:translucentOverlay];
	}
}
	
- (void) showLoadingView {
	[self.view addSubview:loadingView];
}

- (void) hideSearchResultsTable {
	[searchController.searchResultsTableView removeFromSuperview];
}

- (void) hideTranslucentOverlay {
	[translucentOverlay removeFromSuperview];
}

- (void) hideLoadingView {
	[loadingView removeFromSuperview];
}

- (void) dealloc {
	[doSearchTerms release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[myStellar release];
	[courseGroups release];
	[stellarSearch release];
	[searchController release];
	
	translucentOverlay.controller = nil;
	[translucentOverlay release];
	
	[loadingView release];
	[url release];
	[super dealloc];
}

@end
