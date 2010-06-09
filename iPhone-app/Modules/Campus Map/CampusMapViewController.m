#import <QuartzCore/QuartzCore.h>
#import "CampusMapViewController.h"
#import "NSString+SBJSON.h"
#import "MITMapSearchResultAnnotation.h"
#import "MITMapSearchResultsVC.h"
#import "MITMapDetailViewController.h"
#import "ShuttleDataManager.h"
#import "ShuttleStopMapAnnotation.h"
#import "ShuttleStopViewController.h"
#import "MITUIConstants.h"
#import "MITConstants.h"

#import "MapSearch.h"
#import "CoreDataManager.h"

#import "MapSelectionController.h"

// TODO: Remove this import when done integrating the new bookmark table
#import "BookmarksTableViewController.h"


#define kSearchBarWidth 270
#define kSearchBarCancelWidthDiff 28

#define kAPISearch		@"Search"

#define kNoSearchResultsTag 31678
#define kErrorConnectingTag 31679

#define kPreviousSearchLimit 25

@interface CampusMapViewController(Private)

-(void) addAnnotationsForShuttleStops:(NSArray*)shuttleStops;

-(void) noSearchResultsAlert;

-(void) errorConnectingAlert;

-(void) saveRegion;					// a convenience method for saving the mapView's current region (for saving state)

@end

@implementation CampusMapViewController
@synthesize geoButton = _geoButton;
@synthesize searchResults = _searchResults;
@synthesize mapView = _mapView;
@synthesize lastSearchText = _lastSearchText;
@synthesize hasSearchResults = _hasSearchResults;
@synthesize displayingList = _displayingList;
@synthesize searchBar = _searchBar;
@synthesize url;
@synthesize campusMapModule = _campusMapModule;

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	
	// create our own view
	self.view = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 364)] autorelease];
	
	_viewTypeButton = [[[UIBarButtonItem alloc] initWithTitle:@"List" style:UIBarButtonItemStylePlain target:self action:@selector(viewTypeChanged:)] autorelease];
	self.navigationItem.rightBarButtonItem = _viewTypeButton;
	
	// add a search bar to our view
	_searchBar = [[ UISearchBar alloc] initWithFrame:CGRectMake(0, 0, kSearchBarWidth, NAVIGATION_BAR_HEIGHT)];
	[_searchBar setDelegate:self];
	_searchBar.placeholder = NSLocalizedString(@"Search MIT Campus Map", nil);
	_searchBar.translucent = NO;
	_searchBar.tintColor = SEARCH_BAR_TINT_COLOR;
	_searchBar.showsBookmarkButton = NO; // we'll be adding a custom bookmark button
	[self.view addSubview:_searchBar];
		
	// create the map view controller and its view to our view. 
	_mapView = [[MITMapView alloc] initWithFrame: CGRectMake(0, _searchBar.frame.size.height, 320, self.view.frame.size.height - _searchBar.frame.size.height)];
	_mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	[self.view addSubview:_mapView];
	_mapView.delegate = self;
	
	// add the rest of the toolbar to which we can add buttons
	_toolBar = [[CampusMapToolbar alloc] initWithFrame:CGRectMake(kSearchBarWidth, 0, 320 - kSearchBarWidth, NAVIGATION_BAR_HEIGHT)];
	_toolBar.translucent = NO;
	_toolBar.tintColor = SEARCH_BAR_TINT_COLOR;
	[self.view addSubview:_toolBar];
	
	// create toolbar button item for geolocation  
	UIImage* image = [UIImage imageNamed:@"map_button_icon_locate.png"];
	_geoButton = [[UIBarButtonItem alloc] initWithImage:image
												  style:UIBarButtonItemStyleBordered
												 target:self
												 action:@selector(geoLocationTouched:)];
	_geoButton.width = image.size.width + 10;

	/*
	_shuttleButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"map_button_shuttle.png"]
													  style:UIBarButtonItemStyleBordered
													 target:self
													 action:@selector(shuttleButtonTouched:)];
	_shuttleButton.width = image.size.width + 10;
	[_toolBar setItems:[NSArray arrayWithObjects:_geoButton, _shuttleButton, nil]];
	*/
	[_toolBar setItems:[NSArray arrayWithObjects:_geoButton, nil]];
	
	// register for shuttle notifications
	//[[ShuttleDataManager sharedDataManager] registerDelegate:self];
	
	// add our own bookmark button item since we are not using the default
	// bookmark button of the UISearchBar
	_bookmarkButton = [[UIButton alloc] initWithFrame:CGRectMake(231, 8, 32, 28)];
	[_bookmarkButton setImage:[UIImage imageNamed:@"searchfield_star.png"] forState:UIControlStateNormal];
	[self.view addSubview:_bookmarkButton];
	[_bookmarkButton addTarget:self action:@selector(bookmarkButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
	
	url = [[MITModuleURL alloc] initWithTag:CampusMapTag];
	
}



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {

	
	[super viewDidLoad];
	
	
	/*
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults objectForKey:@"mapCenterLat"] != nil) {
		CLLocationCoordinate2D center;
		center.latitude = [[defaults objectForKey:@"mapCenterLat"] doubleValue];
		center.longitude = [[defaults objectForKey:@"mapCenterLon"] doubleValue];
		
		MKCoordinateRegion region = MKCoordinateRegionMake(center, 
														   MKCoordinateSpanMake([[defaults objectForKey:@"mapLatDelta"] doubleValue],
																				[[defaults objectForKey:@"mapLonDelta"] doubleValue]));
		_mapView.region = region;
	}
	*/
	
	// turn on the location dot
	_mapView.showsUserLocation = YES;
}

-(void) hideAnnotations:(BOOL)hide
{
	for (id<MKAnnotation> annotation in _searchResults) {
		MITMapAnnotationView* annotationView = [_mapView viewForAnnotation:annotation];
		[annotationView setHidden:hide];
	}
	
	for (id<MKAnnotation> annotation in _filteredSearchResults) {
		MITMapAnnotationView* annotationView = [_mapView viewForAnnotation:annotation];
		[annotationView setHidden:hide];		
	}
}

-(void) viewWillAppear:(BOOL)animated
{
	if(_displayingList)
	{
		self.navigationItem.rightBarButtonItem.title = @"Map";
	}
	else if(_hasSearchResults)
	{
		if (_displayingList) {
			self.navigationItem.rightBarButtonItem.title = @"Map";
		} else {
			self.navigationItem.rightBarButtonItem.title = @"List";
		}
	}
	else 
	{
		self.navigationItem.rightBarButtonItem.title = @"Browse";
	}
}

-(void) viewWillDisappear:(BOOL)animated
{
	// hide the annotations
	//[self hideAnnotations:YES];
}

-(void) viewDidAppear:(BOOL)animated
{
	// show the annotations
	//[self hideAnnotations:NO];
	
	[super viewDidAppear:animated];
	
	// if there is a bookmarks view controller hanging around, dismiss and release it. 
	if(nil != _selectionVC)
	{
		[_selectionVC dismissModalViewControllerAnimated:NO];
		[_selectionVC release];
		_selectionVC = nil;
	}
	
	
	// if we're in the list view, save that state
	if (_displayingList) {
		[url setPath:[NSString stringWithFormat:@"list", [(MITMapSearchResultAnnotation*)_mapView.currentAnnotation uniqueID]] query:_lastSearchText];
		[url setAsModulePath];
		[self setURLPathUserLocation];
	} else {
		if (_lastSearchText != nil && ![_lastSearchText isEqualToString:@""] && _mapView.currentAnnotation) {
			[url setPath:[NSString stringWithFormat:@"search/%@", [(MITMapSearchResultAnnotation*)_mapView.currentAnnotation uniqueID]] query:_lastSearchText];
			[url setAsModulePath];
			[self setURLPathUserLocation];
		}
	}
	[self saveRegion];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    //[super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {

	[[ShuttleDataManager sharedDataManager] unregisterDelegate:self];
	
	[url release];
	
	_mapView.delegate = nil;
	[_mapView release];

	[_toolBar release];

	[_geoButton release];
	
	[_shuttleButton release];
	
	[_shuttleAnnotations release];
	
	[_searchResults release];
	_searchResults = nil;
	
	[_viewTypeButton release];
	[_searchResultsVC release];
	[_searchBar release];
	
	[_bookmarkButton release];
	[_selectionVC release];
	[_cancelSearchButton release];

}


- (void)dealloc 
{
	[super dealloc];
}

-(void) setSearchResultsWithoutRecentering:(NSArray*)searchResults
{
	_searchFilter = nil;
	
	// remove search results
	[_mapView removeAnnotations:_searchResults];
	[_mapView removeAnnotations:_filteredSearchResults];
	[_searchResults release];
	_searchResults = [searchResults retain];
	
	[_filteredSearchResults release];
	_filteredSearchResults = nil;
	
	// remove any remaining annotations
	[_mapView removeAllAnnotations];
	
	if (nil != _searchResultsVC) {
		_searchResultsVC.searchResults = _searchResults;
	}
	
	[_mapView addAnnotations:_searchResults];
}

-(void) setSearchResults:(NSArray *)searchResults
{
	[self setSearchResultsWithoutRecentering:searchResults];
	
	if (_searchResults.count > 0) 
	{
		// determine the region for the search results
		double minLat = 90;
		double maxLat = -90;
		double minLon = 180;
		double maxLon = -180;
		
		for (id<MKAnnotation> annotation in _searchResults) 
		{
			CLLocationCoordinate2D coordinate = annotation.coordinate;
			
			if (coordinate.latitude < minLat) 
			{
				minLat = coordinate.latitude;
			}
			if (coordinate.latitude > maxLat )
			{
				maxLat = coordinate.latitude;
			}
			if (coordinate.longitude < minLon) 
			{
				minLon = coordinate.longitude;
			}
			if(coordinate.longitude > maxLon)
			{
				maxLon = coordinate.longitude;
			}
			
		}
		if (_mapView.stayCenteredOnUserLocation) {
			if ([_mapView.userLocation coordinate].latitude < minLat)
				minLat = [_mapView.userLocation coordinate].latitude;
			if ([_mapView.userLocation coordinate].latitude > maxLat)
				maxLat = [_mapView.userLocation coordinate].latitude;
			if ([_mapView.userLocation coordinate].longitude < minLon)
				minLon = [_mapView.userLocation coordinate].longitude;
			if ([_mapView.userLocation coordinate].longitude > maxLon)
				maxLon = [_mapView.userLocation coordinate].longitude;
		}
		
		CLLocationCoordinate2D center;
		center.latitude = minLat + (maxLat - minLat) / 2;
		center.longitude = minLon + (maxLon - minLon) / 2;
		
		// create the span and region with a little padding
		double latDelta = maxLat - minLat;
		double lonDelta = maxLon - minLon;
		
		if (latDelta < .002) latDelta = .002;
		if (lonDelta < .002) lonDelta = .002;
		
		MKCoordinateRegion region = MKCoordinateRegionMake(center, 	MKCoordinateSpanMake(latDelta + latDelta / 4 , lonDelta + lonDelta / 4));
		
		_mapView.region = region;
		
		// turn off locate me
		_geoButton.style = UIBarButtonItemStyleBordered;
		_mapView.stayCenteredOnUserLocation = NO;
	}
	
	[self saveRegion];
	
	// if we're showing the map, only enable the list button if there are search results. 
	//if (!_displayingList) {
	//	_viewTypeButton.enabled = (_searchResults != nil && _searchResults.count > 0);
	//}
	
}

-(void) setSearchResults:(NSArray *)searchResults withFilter:(SEL)filter
{
	_searchFilter = filter;
	
	// if there was no filter, just add the annotations the normal way
	if(nil == filter)
	{
		[self setSearchResults:searchResults];
		return;
	}
	
	[_mapView removeAnnotations:_filteredSearchResults];
	[_mapView removeAnnotations:_searchResults];
	
	[_searchResults release];
	_searchResults = [searchResults retain];
	
	[_filteredSearchResults release];
	_filteredSearchResults = nil;
	
	
	// reformat the search results for the map. Combine items that are in common buildings into one annotation result.
	NSMutableDictionary* mapSearchResults = [NSMutableDictionary dictionaryWithCapacity:_searchResults.count];
	for (MITMapSearchResultAnnotation* annotation in _searchResults)
	{
		MITMapSearchResultAnnotation* previousAnnotation = [mapSearchResults objectForKey:[annotation performSelector:filter]];
		if (nil == previousAnnotation) {
			MITMapSearchResultAnnotation* newAnnotation = [[[MITMapSearchResultAnnotation alloc] initWithCoordinate:annotation.coordinate] autorelease];
			newAnnotation.bldgnum = annotation.bldgnum;
			[mapSearchResults setObject:newAnnotation forKey:[annotation performSelector:filter]];
		}
	}
	
	_filteredSearchResults = [[mapSearchResults allValues] retain];
	
	[_mapView addAnnotations:_filteredSearchResults];
	
	// if we're showing the map, only enable the list button if there are search results. 
	//if (!_displayingList) {
	//	_viewTypeButton.enabled = (_searchResults != nil && _searchResults.count > 0);
	//}
	
}

#pragma mark ShuttleDataManagerDelegate

// message sent when routes were received. If request failed, this is called with a nil routes array
-(void) routesReceived:(NSArray*) routes
{
}

// message sent when stops were received. If request failed, this is called with a nil stops array
-(void) stopsReceived:(NSArray*) stops
{
	if (_displayShuttles) {
		[self addAnnotationsForShuttleStops:stops];
	}
}

#pragma mark CampusMapViewController(Private)

-(void) addAnnotationsForShuttleStops:(NSArray*)shuttleStops
{
	if (_shuttleAnnotations == nil) {
		_shuttleAnnotations = [[NSMutableArray alloc] initWithCapacity:shuttleStops.count];
	}
	
	for (ShuttleStop* shuttleStop in shuttleStops) 
	{
		ShuttleStopMapAnnotation* annotation = [[[ShuttleStopMapAnnotation alloc] initWithShuttleStop:shuttleStop] autorelease];
		[_mapView addAnnotation:annotation];
		[_shuttleAnnotations addObject:annotation];
	}
}

-(void) noSearchResultsAlert
{
	UIAlertView* alert = [[[UIAlertView alloc] initWithTitle:nil
													 message:NSLocalizedString(@"Nothing found.", nil)
													delegate:self cancelButtonTitle:NSLocalizedString(@"OK", nil)
										   otherButtonTitles:nil] autorelease];
	alert.tag = kNoSearchResultsTag;
	alert.delegate = self;
	[alert show];
}

-(void) errorConnectingAlert
{
	UIAlertView* alert = [[[UIAlertView alloc] initWithTitle:nil
													 message:NSLocalizedString(@"Error connecting. Please check your internet connection.", nil)
													delegate:self cancelButtonTitle:NSLocalizedString(@"OK", nil)
										   otherButtonTitles:nil] autorelease];
	alert.tag = kErrorConnectingTag;
	alert.delegate = self;
	[alert show];
}

-(void) setURLPathUserLocation {
	NSMutableArray *components = [NSMutableArray arrayWithArray:[url.path componentsSeparatedByString:@"/"]];
	if (_mapView.stayCenteredOnUserLocation && ![[components lastObject] isEqualToString:@"userLoc"]) {
		[url setPath:[NSString stringWithFormat:@"%@/%@", url.path, @"userLoc"] query:_lastSearchText];
		[url setAsModulePath];
	}
	if (!_mapView.stayCenteredOnUserLocation && [[components lastObject] isEqualToString:@"userLoc"]) {
		[url setPath:[url.path stringByReplacingOccurrencesOfString:@"userLoc" withString:@""] query:_lastSearchText];
		[url setAsModulePath];
	}
}

-(void) saveRegion
{	
	// save this region so we can use it on launch
	NSNumber* centerLat = [NSNumber numberWithDouble:_mapView.region.center.latitude];
	NSNumber* centerLong = [NSNumber numberWithDouble:_mapView.region.center.longitude];
	NSNumber* spanLat = [NSNumber numberWithDouble:_mapView.region.span.latitudeDelta];
	NSNumber* spanLong = [NSNumber numberWithDouble:_mapView.region.span.longitudeDelta];
	NSDictionary* regionDict = [NSDictionary dictionaryWithObjectsAndKeys:centerLat, @"centerLat", centerLong, @"centerLong", spanLat, @"spanLat", spanLong, @"spanLong", nil];
	
	NSString* docsFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
	NSString* regionFilename = [docsFolder stringByAppendingPathComponent:@"region.plist"];
	[regionDict writeToFile:regionFilename atomically:YES];
	//NSLog(@"saved region");
}

#pragma mark UIAlertViewDelegate
-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	// if the alert view was "no search results", give focus back to the search bar
	if (alertView.tag = kNoSearchResultsTag) {
		[_searchBar becomeFirstResponder];
	}
}


#pragma mark User actions
-(void) geoLocationTouched:(id)sender
{
	//_mapVC.showsUserLocation = !_mapVC.showsUserLocation;
	_mapView.stayCenteredOnUserLocation = !_mapView.stayCenteredOnUserLocation;
	
	_geoButton.style = _mapView.stayCenteredOnUserLocation ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
	
	[self setURLPathUserLocation];
}

-(void) shuttleButtonTouched:(id)sender
{
	_displayShuttles = !_displayShuttles;
	
	_shuttleButton.style = _displayShuttles ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
	
	if (_displayShuttles) 
	{
		// if we already have the shuttle information, just display it. If not, file a request. 
		if (nil != [[ShuttleDataManager sharedDataManager] shuttleStops]) {
			[self addAnnotationsForShuttleStops:[[ShuttleDataManager sharedDataManager] shuttleStops]];
		}
		else 
		{
			[[ShuttleDataManager sharedDataManager] requestStops];
		}

	}
	else {
		[_mapView removeAnnotations:_shuttleAnnotations];
		[_shuttleAnnotations release];
		_shuttleAnnotations = nil;
	}

}

-(void) showListView:(BOOL)showList
{

	if (showList) 
	{
		// if we are not already showing the list, do all this 
		if (!_displayingList) 
		{
			
			_viewTypeButton.title = @"Map";
			
			// show the list.
			if(nil == _searchResultsVC)
			{
				_searchResultsVC = [[MITMapSearchResultsVC alloc] initWithNibName:@"MITMapSearchResultsVC" bundle:nil];
				_searchResultsVC.title = @"Campus Map";
				_searchResultsVC.campusMapVC = self;
			}
			
			_searchResultsVC.searchResults = _searchResults;
			_searchResultsVC.view.frame = _mapView.frame;
						
			[self.view addSubview:_searchResultsVC.view];
			
			// hide the toolbar and stretch the search bar
			//_toolBar.hidden = YES;
			_toolBar.items = nil;
			_toolBar.frame =  CGRectMake(kSearchBarWidth, 0, 0, NAVIGATION_BAR_HEIGHT);
			_searchBar.frame = CGRectMake(_searchBar.frame.origin.x, 
										  _searchBar.frame.origin.y,
										  self.view.frame.size.width,
										  _searchBar.frame.size.height);
			_bookmarkButton.frame = CGRectMake(281, 8, 32, 28);
			
			[url setPath:@"list" query:_lastSearchText];
			[url setAsModulePath];
			[self setURLPathUserLocation];
		}
		
		// we can always allow the user to switch back to the map
		//_viewTypeButton.enabled = YES;
		
	}
	else 
	{
		// if we're not already showing the map
		if (_displayingList)
		{
			_viewTypeButton.title = @"List";
			
			// show the map, by hiding the list. 
			[_searchResultsVC.view removeFromSuperview];
			[_searchResultsVC release];
			_searchResultsVC = nil;
			
			// show the toolbar and shring the search bar. 
			//_toolBar.hidden = NO;
			_toolBar.frame =  CGRectMake(kSearchBarWidth, 0, 320 - kSearchBarWidth, NAVIGATION_BAR_HEIGHT);
			_toolBar.items = [NSArray arrayWithObject:_geoButton];
			_searchBar.frame = CGRectMake(_searchBar.frame.origin.x, 
										  _searchBar.frame.origin.y,
										  kSearchBarWidth,
										  _searchBar.frame.size.height);
			_bookmarkButton.frame = CGRectMake(231, 8, 32, 28);
		}
	
		// only let the user switch to the list view if there are search results. 
		//_viewTypeButton.enabled = (_searchResults != nil && _searchResults.count > 0);
		if (_lastSearchText != nil && ![_lastSearchText isEqualToString:@""] && _mapView.currentAnnotation)
			[url setPath:[NSString stringWithFormat:@"search/%@", [(MITMapSearchResultAnnotation*)_mapView.currentAnnotation uniqueID]] query:_lastSearchText];
		else 
			[url setPath:@"" query:nil];
		[url setAsModulePath];
		[self setURLPathUserLocation];
	}
	
	_displayingList = showList;
	
}

-(void) viewTypeChanged:(id)sender
{
	// resign the search bar, if it was first selector
	[_searchBar resignFirstResponder];
	
	// if there is nothing in the search bar, we are browsing categories; otherwise go to list view
	if (!_displayingList && !_hasSearchResults) {
		if(nil != _selectionVC)
		{
			[_selectionVC dismissModalViewControllerAnimated:NO];
			[_selectionVC release];
			_selectionVC = nil;
		}
		
		_selectionVC = [[MapSelectionController alloc]  initWithMapSelectionControllerSegment:MapSelectionControllerSegmentBrowse campusMap:self];
		MIT_MobileAppDelegate *appDelegate = (MIT_MobileAppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate presentAppModalViewController:_selectionVC animated:YES];
	} else {	
		[self showListView:!_displayingList];
	}
	
}

-(void) receivedNewSearchResults:(NSArray*)searchResults forQuery:(NSString *)searchQuery
{
	// clear the map view's annotations, and add new ones for these search results
	//[_mapView removeAnnotations:_searchResults];
	//[_searchResults release];
	//_searchResults = nil;
	
	NSMutableArray* searchResultsArr = [NSMutableArray arrayWithCapacity:searchResults.count];
	
	for (NSDictionary* info in searchResults)
	{
		MITMapSearchResultAnnotation* annotation = [[[MITMapSearchResultAnnotation alloc] initWithInfo:info] autorelease];
		[searchResultsArr addObject:annotation];
	}
	
	// this will remove old annotations and add the new ones. 
	self.searchResults = searchResultsArr;
	
	NSString* docsFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
	NSString* searchResultsFilename = [docsFolder stringByAppendingPathComponent:@"searchResults.plist"];
	[searchResults writeToFile:searchResultsFilename atomically:YES];
	[[NSUserDefaults standardUserDefaults] setObject:searchQuery forKey:CachedMapSearchQueryKey];
	
	/*
	// if we have 2 view controllers, push a new search results controller onto the stack
	if (self.navigationController.viewControllers.count == 2) {
		MITMapSearchResultsVC* searchResultsVC = [[[MITMapSearchResultsVC alloc] initWithNibName:@"MITMapSearchResultsVC"
																												bundle:nil] autorelease];
		searchResultsVC.view;
		searchResultsVC.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
		searchResultsVC.title = @"Campus Map";
		searchResultsVC.searchResults = self.searchResults;
		searchResultsVC.navigationItem.hidesBackButton = YES;
		
		searchResultsVC.campusMapVC = self;
				
		[self.navigationController pushViewController:searchResultsVC animated:YES];
	}
	
	// if we have 3 view controllers, update the search results in the search results view controller. 
	if (self.navigationController.viewControllers.count == 3) {
		MITMapSearchResultsVC* searchResultsVC = (MITMapSearchResultsVC*)[self.navigationController.viewControllers objectAtIndex:2];
		searchResultsVC.searchResults = self.searchResults;
	}
	 */
	
}


#pragma mark UISearchBarDelegate
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
	_bookmarkButton.hidden = searchBar.text.length > 0;
	
	// Add the cancel button, and remove the geo button. 
	_cancelSearchButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancelSearch)];
	
	if (_displayingList) {
		_toolBar.frame = CGRectMake(320, 0, 320 - kSearchBarWidth + kSearchBarCancelWidthDiff, NAVIGATION_BAR_HEIGHT);
	}
	
	[UIView beginAnimations:@"searching" context:nil];
	_searchBar.frame = CGRectMake(0, 0, kSearchBarWidth - kSearchBarCancelWidthDiff, NAVIGATION_BAR_HEIGHT);
	[_searchBar layoutSubviews];
	_bookmarkButton.frame = CGRectMake(231 - kSearchBarCancelWidthDiff, 8, 32, 28);
	[_toolBar setItems:[NSArray arrayWithObjects:_cancelSearchButton, nil]];
	_toolBar.frame = CGRectMake(kSearchBarWidth - kSearchBarCancelWidthDiff, 0, 320 - kSearchBarWidth + kSearchBarCancelWidthDiff, NAVIGATION_BAR_HEIGHT);
	[UIView commitAnimations];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
	// when we're not editing, make sure the bookmark button is put back
	_bookmarkButton.hidden = NO;
	
	// remove the cancel button and add the geo button back. 
	[_cancelSearchButton release];
	_cancelSearchButton = nil;
	
	
	[UIView beginAnimations:@"doneSearching" context:nil];
	_searchBar.frame = CGRectMake(0, 0, _displayingList ? self.view.frame.size.width : kSearchBarWidth, NAVIGATION_BAR_HEIGHT);
	[_searchBar layoutSubviews];
	[_toolBar setItems:[NSArray arrayWithObjects:_displayingList ? nil : _geoButton , nil]];
	_toolBar.frame = CGRectMake( _displayingList ? 320 : kSearchBarWidth, 0, 320 - kSearchBarWidth, NAVIGATION_BAR_HEIGHT);
	_bookmarkButton.frame = _displayingList ? CGRectMake(281, 8, 32, 28) : CGRectMake(231, 8, 32, 28);

	[UIView commitAnimations];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{	
	[searchBar resignFirstResponder];
	
	// delete any previous instance of this search term
	MapSearch* mapSearch = [CoreDataManager getObjectForEntity:CampusMapSearchEntityName attribute:@"searchTerm" value:searchBar.text];
	if(nil != mapSearch)
	{
		[CoreDataManager deleteObject:mapSearch];
	}
	
	// insert the new instance of this search term
	mapSearch = [CoreDataManager insertNewObjectForEntityForName:CampusMapSearchEntityName];
	mapSearch.searchTerm = searchBar.text;
	mapSearch.date = [NSDate date];
	[CoreDataManager saveData];
	
	
	// determine if we are past our max search limit. If so, trim an item
	NSError* error = nil;
	
	NSFetchRequest* countFetchRequest = [[[NSFetchRequest alloc] init] autorelease];
	[countFetchRequest setEntity:[NSEntityDescription entityForName:CampusMapSearchEntityName inManagedObjectContext:[CoreDataManager managedObjectContext]]];
	NSUInteger count = 	[[CoreDataManager managedObjectContext] countForFetchRequest:countFetchRequest error:&error];
	
	// cap the number of previous searches maintained in the DB. If we go over the limit, delete one. 
	if(nil == error && count > kPreviousSearchLimit)
	{
		// get the oldest item
		NSSortDescriptor* sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES] autorelease];
		NSFetchRequest* limitFetchRequest = [[[NSFetchRequest alloc] init] autorelease];		
		[limitFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
		[limitFetchRequest setEntity:[NSEntityDescription entityForName:CampusMapSearchEntityName inManagedObjectContext:[CoreDataManager managedObjectContext]]];
		[limitFetchRequest setFetchLimit:1];
		NSArray* overLimit = [[CoreDataManager managedObjectContext] executeFetchRequest: limitFetchRequest error:nil];
		 
		if(overLimit && overLimit.count == 1)
		{
			[[CoreDataManager managedObjectContext] deleteObject:[overLimit objectAtIndex:0]];
		}

		[CoreDataManager saveData];
	}
	
	// ask the campus map view controller to perform the search
	[self search:searchBar.text];
	
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar
{
	self.navigationItem.rightBarButtonItem.title = _displayingList ? @"Map" : @"Browse";
	_hasSearchResults = NO;
	[searchBar resignFirstResponder];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
	// the bookmark button is only shown when there is no text. 
	_bookmarkButton.hidden = searchText.length > 0;
	
	if (searchText.length == 0 )
	{		
		self.navigationItem.rightBarButtonItem.title = _displayingList ? @"Map" : @"Browse";
		_hasSearchResults = NO;
		// tell the campus view controller to remove its search results. 
		[self search:nil];
		
	}

}

-(void) touchEnded
{
	[_searchBar resignFirstResponder];
}

-(void) cancelSearch
{
	_searchBar.text = @"";
	[_searchBar resignFirstResponder];
}

#pragma mark Custom Bookmark Button Functionality

- (void)bookmarkButtonClicked:(UIButton *)sender
{
	if(nil != _selectionVC)
	{
		[_selectionVC dismissModalViewControllerAnimated:NO];
		[_selectionVC release];
		_selectionVC = nil;
	}
	
	_selectionVC = [[MapSelectionController alloc]  initWithMapSelectionControllerSegment:MapSelectionControllerSegmentBookmarks campusMap:self];
	MIT_MobileAppDelegate *appDelegate = (MIT_MobileAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate presentAppModalViewController:_selectionVC animated:YES];
	
		
	//UINavigationController* navController = [[[UINavigationController alloc] initWithRootViewController:_bookmarksVC] autorelease];
	//[self presentModalViewController:navController animated:YES];
}

#pragma mark MITMapViewControllerDelegate
-(void) mapViewRegionDidChange:(MITMapView*)mapView
{
	_geoButton.style = _mapView.stayCenteredOnUserLocation ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
	
	[self setURLPathUserLocation];
	
	[self saveRegion];

		/*
	MKCoordinateRegion region =  mapView.region;
	
	// save the region

	NSNumber* centerLat = [NSNumber numberWithDouble:region.center.latitude];
	NSNumber* centerLon = [NSNumber numberWithDouble:region.center.longitude];
	NSNumber* latDelta = [NSNumber numberWithDouble:region.span.latitudeDelta];
	NSNumber* lonDelta = [NSNumber numberWithDouble:region.span.longitudeDelta];

	NSUserDefaults* standardDefaults = [NSUserDefaults standardUserDefaults];
	
	[standardDefaults setValue:centerLat forKey:@"mapCenterLat"];
	[standardDefaults setValue:centerLon forKey:@"mapCenterLon"];
	[standardDefaults setValue:latDelta  forKey:@"mapLatDelta"];
	[standardDefaults setValue:lonDelta  forKey:@"mapLonDelta"];
	*/
}

- (void)mapViewRegionWillChange:(MITMapView*)mapView
{
	_geoButton.style = _mapView.stayCenteredOnUserLocation ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
	
	[self setURLPathUserLocation];
}

- (MITMapAnnotationView *)mapView:(MITMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
	MITMapAnnotationView* annotationView = nil;
	
	if ([annotation isKindOfClass:[ShuttleStopMapAnnotation class]]) 
	{
		annotationView = [[[MITMapAnnotationView alloc] initWithAnnotation:annotation] autorelease];
		UIImage* pin = [UIImage imageNamed:@"map_pin_shuttle_stop_complete.png"];
		UIImageView* imageView = [[[UIImageView alloc] initWithImage:pin] autorelease];
		annotationView.frame = imageView.frame;
		annotationView.canShowCallout = YES;
		[annotationView addSubview:imageView];
		annotationView.backgroundColor = [UIColor clearColor];
		annotationView.layer.anchorPoint = CGPointMake(0.5, 1.0);
	}
	
	return annotationView;
}

-(void) pushAnnotationDetails:(id <MKAnnotation>) annotation animated:(BOOL)animated
{
	// determine the type of the annotation. If it is a search result annotation, display the details
	if ([annotation isKindOfClass:[MITMapSearchResultAnnotation class]]) 
	{
		
		// push the details page onto the stack for the item selected. 
		MITMapDetailViewController* detailsVC = [[[MITMapDetailViewController alloc] initWithNibName:@"MITMapDetailViewController"
																							  bundle:nil] autorelease];
		
		detailsVC.annotation = annotation;
		detailsVC.title = @"Info";
		detailsVC.campusMapVC = self;
		
		if(!((MITMapSearchResultAnnotation*)annotation).bookmark)
		{

			if(self.lastSearchText != nil && self.lastSearchText.length > 0)
			{
				detailsVC.queryText = self.lastSearchText;
			}
		}
		[self.navigationController pushViewController:detailsVC animated:animated];		
	}
	
	else if ([annotation isKindOfClass:[ShuttleStopMapAnnotation class]])
	{
		
		// move this logic to the shuttle module
		ShuttleStopViewController* shuttleStopVC = [[[ShuttleStopViewController alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
		shuttleStopVC.shuttleStop = [(ShuttleStopMapAnnotation*)annotation shuttleStop];
		[self.navigationController pushViewController:shuttleStopVC animated:animated];
		
	}
	if ([annotation class] == [MITMapSearchResultAnnotation class]) {
		MITMapSearchResultAnnotation* theAnnotation = (MITMapSearchResultAnnotation*)annotation;
		if (_displayingList)
			[url setPath:[NSString stringWithFormat:@"list/detail/%@", theAnnotation.uniqueID] query:_lastSearchText];
		else 
			[url setPath:[NSString stringWithFormat:@"detail/%@", theAnnotation.uniqueID] query:_lastSearchText];
		[url setAsModulePath];
		[self setURLPathUserLocation];
	}	
}

// a callout accessory control was tapped. 
- (void)mapView:(MITMapView *)mapView annotationViewcalloutAccessoryTapped:(MITMapAnnotationCalloutView *)view 
{
	[self pushAnnotationDetails:view.annotation animated:YES];
}

- (void)mapView:(MITMapView *)mapView wasTouched:(UITouch*)touch
{
	[_searchBar resignFirstResponder];
}

- (void) annotationSelected:(id<MKAnnotation>)annotation {
	if([annotation isKindOfClass:[MITMapSearchResultAnnotation class]])
	{
		MITMapSearchResultAnnotation* searchAnnotation = (MITMapSearchResultAnnotation*)annotation;
		//NSLog(@"annotation bldgnum = %@", searchAnnotation.bldgnum);
		// if the annotation is not fully loaded, try to load it
		if (!searchAnnotation.dataPopulated) 
		{	
			[MITMapSearchResultAnnotation executeServerSearchWithQuery:searchAnnotation.bldgnum jsonDelegate:self object:annotation];	
		}
		[url setPath:[NSString stringWithFormat:@"search/%@", searchAnnotation.uniqueID] query:_lastSearchText];
		[url setAsModulePath];
		[self setURLPathUserLocation];
	}
}

-(void) locateUserFailed
{
	if (_mapView.stayCenteredOnUserLocation) 
	{
		[_geoButton setStyle:UIBarButtonItemStyleBordered];
	}	
}

#pragma mark JSONLoadedDelegate
- (void) request:(MITMobileWebAPI *)request jsonLoaded:(id)JSONObject
{	
	NSArray *searchResults = JSONObject;
	if ([request.userData isKindOfClass:[NSString class]]) {
		NSString *searchType = request.userData;
	
		if ([searchType isEqualToString:kAPISearch])
		{		
		
			[_lastSearchText release];
			_lastSearchText = [request.params objectForKey:@"q"];
		
			[self receivedNewSearchResults:searchResults forQuery:_lastSearchText];
		
			// if there were no search results, tell the user about it. 
			if(nil == searchResults || searchResults.count <= 0) {
				[self noSearchResultsAlert];
				_hasSearchResults = NO;
				self.navigationItem.rightBarButtonItem.title = _displayingList ? @"Map" : @"Browse";
			} else {
				_hasSearchResults = YES;
				if(!_displayingList)
					self.navigationItem.rightBarButtonItem.title = @"List";
			}
		}
	}

	
	else if([request.userData isKindOfClass:[MITMapSearchResultAnnotation class]]) {
		// updating an annotation search request
		MITMapSearchResultAnnotation* oldAnnotation = request.userData;
		NSArray* results = JSONObject;
		
		if (results.count > 0) 
		{
			MITMapSearchResultAnnotation* newAnnotation = [[[MITMapSearchResultAnnotation alloc] initWithInfo:[results objectAtIndex:0]] autorelease];
			
			BOOL isViewingAnnotation = (_mapView.currentAnnotation == oldAnnotation);
			
			[_mapView removeAnnotation:oldAnnotation];
			[_mapView addAnnotation:newAnnotation];
			
			if (isViewingAnnotation) {
				[_mapView selectAnnotation:newAnnotation animated:NO withRecenter:NO];
			}
			_hasSearchResults = YES;
			self.navigationItem.rightBarButtonItem.title = @"List";
		} else {
			_hasSearchResults = NO;
			self.navigationItem.rightBarButtonItem.title = @"Browse";
		}

	}	
}


// there was an error connecting to the specified URL. 
- (void) handleConnectionFailureForRequest:(MITMobileWebAPI *)request {
	if ([(NSString *)request.userData isEqualToString:kAPISearch]) {
		[self errorConnectingAlert];
	}
}

#pragma mark UITableViewDataSource

-(void) search:(NSString*)searchText
{	
	if (nil == searchText) 
	{
		self.searchResults = nil;

		[_lastSearchText release];
		_lastSearchText = nil;
		
		/*
		[_mapView removeAnnotations:_searchResults];
		[_searchResults release];
		_searchResults = nil;
		[_lastSearchText release];
		_lastSearchText = nil;

		if (nil != _searchResultsVC) {
			_searchResultsVC.searchResults = nil;
			
		}
		 */
	}
	else
	{		
		[MITMapSearchResultAnnotation executeServerSearchWithQuery:searchText jsonDelegate:self object:kAPISearch];
	}
	if (_displayingList)
		[url setPath:@"list" query:searchText];
	else if (searchText != nil && ![searchText isEqualToString:@""])
		[url setPath:@"search" query:searchText];
	else 
		[url setPath:@"" query:nil];
	[url setAsModulePath];
	[self setURLPathUserLocation];
}


@end
