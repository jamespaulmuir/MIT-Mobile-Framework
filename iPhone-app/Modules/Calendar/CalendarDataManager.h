#import <Foundation/Foundation.h>
#import "MITCalendarEvent.h"
#import "EventCategory.h"
#import "CalendarConstants.h"

@interface CalendarDataManager : NSObject {

}

+ (NSArray *)eventsWithStartDate:(NSDate *)startDate listType:(CalendarEventListType)listType category:(NSNumber *)catID;
+ (NSNumber *)idForCategory:(NSString *)categoryName;

+ (NSArray *)topLevelCategories;
+ (EventCategory *)categoryWithID:(NSInteger)catID;
+ (MITCalendarEvent *)eventWithID:(NSInteger)eventID;
+ (MITCalendarEvent *)eventWithDict:(NSDictionary *)dict;
+ (EventCategory *)categoryWithDict:(NSDictionary *)dict;
+ (void)pruneOldEvents;

@end
