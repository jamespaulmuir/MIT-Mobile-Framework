#import "StellarCoursesTableController.h"
#import "StellarCourse.h"
#import "StellarClassesTableController.h"
#import "MITModuleList.h"
#import "MITModule.h"
#import "UITableView+MITUIAdditions.h"
#import "UITableViewCell+MITUIAdditions.h"
#import "MultiLineTableViewCell.h"


@implementation StellarCoursesTableController
@synthesize courseGroup;
@synthesize url;

- (id) initWithCourseGroup: (StellarCourseGroup *)aCourseGroup {
	if(self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.courseGroup = aCourseGroup;
		NSString *path = [NSString stringWithFormat:@"courses/%@", [courseGroup serialize]];
		url = [[MITModuleURL alloc] initWithTag:StellarTag path:path query:nil];
		self.title = aCourseGroup.title;
	}
	return self;
}

- (void) dealloc {
	[url release];
	[courseGroup release];
	[super dealloc];
}

- (void) viewDidLoad {
	[self.tableView applyStandardColors];
	[self.tableView applyStandardCellHeight];
}

- (void) viewDidAppear:(BOOL)animated {
	[url setAsModulePath];
}
	
// "DataSource" methods
- (NSInteger) numberOfSectionsInTableView: (UITableView *)tableView {
	return 1;
}

- (UITableViewCell *)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StellarCourses"];
	if(cell == nil) {
		cell = [[[MultiLineTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"StellarCourses"] autorelease];
		[cell applyStandardFonts];
	}
	
	StellarCourse *stellarCourse = (StellarCourse *)[self.courseGroup.courses objectAtIndex:indexPath.row];
	
	cell.textLabel.text = [@"Course " stringByAppendingString:stellarCourse.number];
	cell.detailTextLabel.text = stellarCourse.title;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}

- (NSInteger) tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section {
	return [self.courseGroup.courses count];
}


- (CGFloat) tableView: (UITableView *)tableView heightForRowAtIndexPath: (NSIndexPath *)indexPath {
	StellarCourse *stellarCourse = (StellarCourse *)[self.courseGroup.courses objectAtIndex:indexPath.row];
	return 2.0 + [MultiLineTableViewCell cellHeightForTableView:tableView 
													 main:@"single line" 
												   detail:stellarCourse.title
											accessoryType:UITableViewCellAccessoryDisclosureIndicator
												isGrouped:YES];
}


- (void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath {
	[self.navigationController
		pushViewController: [[[StellarClassesTableController alloc] 
			initWithCourse: (StellarCourse *)[self.courseGroup.courses objectAtIndex:indexPath.row]] autorelease]
		animated:YES];
}




@end
