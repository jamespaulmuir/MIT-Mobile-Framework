
#import <Foundation/Foundation.h>
#import "StellarModel.h"


@class StellarMainTableController;

@interface StellarSearch : NSObject <
	UITableViewDataSource, 
	UITableViewDelegate, 
	UISearchDisplayDelegate, 
	UISearchBarDelegate,
	ClassesSearchDelegate> {

		BOOL activeMode;
		BOOL hasSearchInitiated;
		NSArray *lastResults;
		StellarMainTableController *viewController;
		UISearchBar *searchBar;
}

@property (nonatomic, retain) NSArray *lastResults;
@property (nonatomic, readonly) BOOL activeMode;
@property (nonatomic, retain) UISearchBar *searchBar;

- (id) initWithSearchBar: (UISearchBar *)theSearchBar viewController: (StellarMainTableController *)controller;

- (void) searchOverlayTapped;

- (BOOL) isSearchResultsVisible;

@end
