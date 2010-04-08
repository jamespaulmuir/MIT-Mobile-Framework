
#import "MITMapSearchResultsVC.h"
#import "MITMapSearchResultCell.h"
#import "MITMapSearchResultAnnotation.h"
#import "MITMapDetailViewController.h"
#import "CampusMapViewController.h"
#import "TouchableTableView.h"
#import "MITUIConstants.h"
#import "UITableView+MITUIAdditions.h"

@implementation MITMapSearchResultsVC
@synthesize searchResults = _searchResults;
@synthesize isCategory = _isCategory;
@synthesize campusMapVC = _campusMapVC;

- (void)dealloc {
    [super dealloc];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

-(void) viewDidLoad
{
	[super viewDidLoad];
		
	
}

- (void)viewDidUnload {
	
	self.searchResults = nil;
	[_tableView release];
	
	[super viewDidUnload];
}

-(void) setSearchResults:(NSArray *)searchResults
{
	[_searchResults release];
	_searchResults = [searchResults retain];
	[_tableView reloadData];
}

-(void) touchEnded
{
	[self.campusMapVC.searchBar resignFirstResponder];
}
#pragma mark Table view methods


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchResults.count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[MITMapSearchResultCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
	// get the annotation for this index
	MITMapSearchResultAnnotation* annotation = [self.searchResults objectAtIndex:indexPath.row];
	cell.textLabel.text = annotation.name;
	
	if(nil != annotation.bldgnum)
		cell.detailTextLabel.text = [NSString stringWithFormat:@"Building %@", annotation.bldgnum];
	else
		cell.detailTextLabel.text = nil;
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	MITMapDetailViewController* detailsVC = [[[MITMapDetailViewController alloc] initWithNibName:@"MITMapDetailViewController"
																						  bundle:nil] autorelease];
	
	detailsVC.annotation = [self.searchResults objectAtIndex:indexPath.row];
	detailsVC.title = @"Info";
	detailsVC.campusMapVC = self.campusMapVC;

	if (self.isCategory) 
	{
		detailsVC.queryText = detailsVC.annotation.name;
	}
	else if(self.campusMapVC.lastSearchText != nil && self.campusMapVC.lastSearchText.length > 0)
	{
		detailsVC.queryText = self.campusMapVC.lastSearchText;
	}
	
	[self.campusMapVC.navigationController pushViewController:detailsVC animated:YES];
     
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[cell setNeedsLayout];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	
	MITMapSearchResultAnnotation* annotation = [self.searchResults objectAtIndex:indexPath.row];
	
	CGFloat width = self.view.frame.size.width - 47.0;
	
	CGSize labelSize = [annotation.name sizeWithFont:[UIFont systemFontOfSize:17]
								   constrainedToSize:CGSizeMake(width, self.view.frame.size.height)
									   lineBreakMode:UILineBreakModeWordWrap];
	
	CGFloat height = labelSize.height;
	
	NSString *detailString = [NSString stringWithFormat:@"Building %@", annotation.bldgnum];
	
	labelSize = [detailString sizeWithFont:[UIFont systemFontOfSize:14]
						 constrainedToSize:CGSizeMake(width, 200.0)
							 lineBreakMode:UILineBreakModeWordWrap];
	
	return (height + labelSize.height) * 1.2 + 6.0;
	
	
}

- (UIView *) tableView: (UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return [UITableView ungroupedSectionHeaderWithTitle:
			[NSString stringWithFormat:@"%d matches found.", self.searchResults.count]];
}

- (CGFloat)tableView: (UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return UNGROUPED_SECTION_HEADER_HEIGHT;
}

@end
