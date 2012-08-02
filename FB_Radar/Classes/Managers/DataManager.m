//
//  DataManager.m
//  FB_Radar
//
//  Created by Sonny Black on 04.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DataManager.h"
#import "UserAnnotation.h"

#define kFavoritiesFriends [NSString stringWithFormat:@"kFavoritiesFriends_%@", [DataManager shared].currentFBUserId]
#define kFavoritiesFriendsIds [NSString stringWithFormat:@"kFavoritiesFriendsIds_%@", [DataManager shared].currentFBUserId]

#define kFirstSwitchAllFriends [NSString stringWithFormat:@"kFirstSwitchAllFriends_%@", [DataManager shared].currentFBUserId]

@implementation DataManager

static DataManager *instance = nil;

@synthesize accessToken, expirationDate;

@synthesize currentQBUser;
@synthesize currentFBUser;
@synthesize currentFBUserId;

@synthesize myFriends, myFriendsAsDictionary;

@synthesize historyConversation, historyConversationAsArray;

+ (DataManager *)shared {
	@synchronized (self) {
		if (instance == nil){ 
            instance = [[self alloc] init];
        }
	}
	
	return instance;
}

- (void)sortMessagesArray
{
	Conversation* temp;
	int n = [historyConversationAsArray count];
	for (int i = 0; i < n-1; i++)
	{
		for (int j = 0; j < n-1-i; j++)
		{
			NSString* date1 = [(NSMutableDictionary*)[((Conversation*)[historyConversationAsArray objectAtIndex:j]).messages lastObject] objectForKey:@"created_time"];
			NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
			[formatter1 setLocale:[NSLocale currentLocale]];
			[formatter1 setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"];
			NSDate *timeStamp1 = [formatter1 dateFromString:date1];
			[formatter1 release];
			
			NSString* date2 = [(NSMutableDictionary*)[((Conversation*)[historyConversationAsArray objectAtIndex:j+1]).messages lastObject] objectForKey:@"created_time"];
			NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
			[formatter2 setLocale:[NSLocale currentLocale]];
			[formatter2 setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"];
			NSDate *timeStamp2 = [formatter2 dateFromString:date2];
			[formatter2 release];

			if ([timeStamp1 compare:timeStamp2] == -1)
			{
				temp = [((Conversation*)[historyConversationAsArray objectAtIndex:j]) retain];
				[historyConversationAsArray replaceObjectAtIndex:j withObject:[historyConversationAsArray objectAtIndex:j+1]];
				[historyConversationAsArray replaceObjectAtIndex:j+1 withObject:temp];
				[temp release];
			}
		}
	}
}

- (id)init
{
    self = [super init];
    if (self) {
        historyConversation = [[NSMutableDictionary alloc] init];
        
        // logout
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutDone) name:kNotificationLogout object:nil];
    }
    return self;
}

-(void) dealloc 
{
    [accessToken release];
	[expirationDate release];
    
	[currentFBUser release];
	[currentQBUser release];
    [currentFBUserId release];
    
	[myFriends release];
	[myFriendsAsDictionary release];
    
	[historyConversation release];
    [historyConversationAsArray release];
    
    
    [managedObjectContext release];
    [managedObjectModel release];
    [persistentStoreCoordinator release];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationLogout object:nil];
	
	[super dealloc];
}

- (void)logoutDone{
    // clear defaults
    [self clearFBAccess];

    
    // reset user
    self.currentFBUser = nil;
    self.currentQBUser = nil;
    self.currentFBUserId = nil;
    
    // reset Friends
    self.myFriends = nil;
    self.myFriendsAsDictionary = nil;
    
    // reset Dialogs
    [historyConversation removeAllObjects];
    [historyConversationAsArray removeAllObjects];
}


#pragma mark -
#pragma mark FB access

- (void)saveFBToken:(NSString *)token andDate:(NSDate *)date{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:token forKey:FBAccessTokenKey];
    [defaults setObject:date forKey:FBExpirationDateKey];
	[defaults synchronize];
    
    self.accessToken = token;
}

- (void)clearFBAccess{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:FBAccessTokenKey];
    [defaults removeObjectForKey:FBExpirationDateKey];
	[defaults synchronize];

    self.accessToken = nil;
}

- (NSDictionary *)fbUserTokenAndDate
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults objectForKey:FBAccessTokenKey] && [defaults objectForKey:FBExpirationDateKey]){
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		[dict setObject:[defaults objectForKey:FBAccessTokenKey] forKey:FBAccessTokenKey];
		[dict setObject:[defaults objectForKey:FBExpirationDateKey] forKey:FBExpirationDateKey];
        
		return dict;
    }
    
    return nil;
}


#pragma mark -
#pragma mark Friends

- (void)makeFriendsDictionary{
    if(myFriendsAsDictionary == nil){
        myFriendsAsDictionary = [[NSMutableDictionary alloc] init];
    }
    for (NSDictionary* user in [DataManager shared].myFriends){
        [myFriendsAsDictionary setObject:user forKey:[user objectForKey:kId]];
    }
}


#pragma mark -
#pragma mark Favorities friends

-(NSMutableArray *) favoritiesFriends{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *favoritiesFriends = [[NSMutableArray alloc] initWithArray:[defaults objectForKey:kFavoritiesFriends]];
    return [favoritiesFriends autorelease];
}

-(void) addFavoriteFriend:(NSString *)_friendID
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	//already exist
	NSMutableArray *favFriends = [[DataManager shared] favoritiesFriends];
	if (favFriends == nil){
		favFriends = [[[NSMutableArray alloc] init] autorelease];
	}

	[favFriends addObject:_friendID];
	[defaults setObject:favFriends forKey:kFavoritiesFriends];
	[defaults synchronize];
}

-(void) removeFavoriteFriend:(NSString *)_friendID
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *favFriends = [[self favoritiesFriends] mutableCopy];
	
	if (favFriends == nil){
		return;
    }
	
	for (int i=0; i < [favFriends count]; i++)
	{
		if ([_friendID isEqual:[favFriends objectAtIndex:i]])
		{
			[favFriends removeObject:_friendID];
		}
	}
	[defaults setObject:favFriends forKey:kFavoritiesFriends];
	[favFriends release];
	[defaults synchronize];
}

-(BOOL) friendIDInFavorities:(NSString *)_friendID{
    NSMutableArray *favFriends = [self favoritiesFriends];
    if([favFriends containsObject:_friendID]){
        return YES;
    }
    
    return NO;
}


#pragma mark -
#pragma mark First switch All/Friends

- (BOOL)isFirstStartApp{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *firstStartApp = [defaults objectForKey:kFirstSwitchAllFriends];
    if(firstStartApp == nil){
        return YES;
    }
    return  [firstStartApp boolValue];
}

- (void)setFirstStartApp:(BOOL)firstStartApp{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:firstStartApp] forKey:kFirstSwitchAllFriends];
    [defaults synchronize];
}


#pragma mark -
#pragma mark QuickBlox Quote

- (NSString *)originMessageFromQuote:(NSString *)quote{
    if([quote length] > 6){
        if ([[quote substringToIndex:6] isEqualToString:fbidIdentifier])
		{
            return [quote substringFromIndex:[quote rangeOfString:quoteDelimiter].location+1];
        }
    }
    
    return quote;
}

- (NSString *)messageFromQuote:(NSString *)quote{
    if([quote length] > 6){
        if ([[quote substringToIndex:6] isEqualToString:fbidIdentifier]){
            return [quote substringFromIndex:[quote rangeOfString:quoteDelimiter].location+1];
        }
    }
    
    return quote;
}


#pragma mark -
#pragma mark Core Data core

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
	
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [NSManagedObjectContext new];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
        [managedObjectContext setMergePolicy:NSOverwriteMergePolicy];
        [managedObjectContext setUndoManager:nil];
    }
    return managedObjectContext;
}


/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {
	
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
    return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
    
	/*
	 Set up the store.
	 */
	NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"chattardata.bin"]];
    
	NSError *error;
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error]) {
		/*
		 Replace this implementation with code to handle the error appropriately.
		 
		 abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
		 
		 Typical reasons for an error here include:
		 * The persistent store is not accessible
		 * The schema for the persistent store is incompatible with current managed object model
		 Check the error message to determine what the actual problem was.
		 */
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
    }
    
    return persistentStoreCoordinator;
}


#pragma mark -
#pragma mark Core Data api

/**
 Friend:save,get
 */
-(NSArray *)friendsFromStorage{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Friend"
                                                         inManagedObjectContext:[self managedObjectContext]];
    
    [fetchRequest setEntity:entityDescription];
    
    NSError *error;
    NSArray* results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    return results;
}
//
-(void)saveFriendsToStorage:(NSArray*)friends{
    
    for(NSDictionary *friend in friends){
    
        NSManagedObject *friendObject = [NSEntityDescription insertNewObjectForEntityForName:@"Friend"
                                                                    inManagedObjectContext:[self managedObjectContext]];
        [friendObject setValue:friend forKey:@"body"];
        
        NSError *error = nil;
        [[self managedObjectContext] save:&error];
    }
}


/**
 Chat messages: save, get
 */
-(void)addChatMessagesToStorage:(NSArray *)chatMessages{
    
    for(UserAnnotation *message in chatMessages){
        
        NSManagedObject *messageObject = [NSEntityDescription insertNewObjectForEntityForName:@"ChatMessage"
                                                                      inManagedObjectContext:[self managedObjectContext]];
        [messageObject setValue:message forKey:@"body"];
        
        NSError *error = nil;
        [[self managedObjectContext] save:&error];
    }
}
//
-(NSArray *)chatMessagesFromStorage{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"ChatMessage"
                                                         inManagedObjectContext:[self managedObjectContext]];
    
    [fetchRequest setEntity:entityDescription];
    
    NSError *error;
    NSArray* results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    return results;
}


/**
 Map messages: save, get
 */
-(void)addMapARPointsToStorage:(NSArray *)chatMessages{
    for(UserAnnotation *message in chatMessages){
        
        NSManagedObject *messageObject = [NSEntityDescription insertNewObjectForEntityForName:@"MapARPoint"
                                                                       inManagedObjectContext:[self managedObjectContext]];
        [messageObject setValue:message forKey:@"body"];
        
        NSError *error = nil;
        [[self managedObjectContext] save:&error];
    }
}
//
-(NSArray *)mapARPointsFromStorage{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"MapARPoint"
                                                         inManagedObjectContext:[self managedObjectContext]];
    
    [fetchRequest setEntity:entityDescription];
    
    NSError *error;
    NSArray* results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    return results;
}

/**
 Checkins: save, get
 */
-(void)addCheckinsToStorage:(NSArray *)chatMessages{
    for(UserAnnotation *message in chatMessages){
        
        NSManagedObject *messageObject = [NSEntityDescription insertNewObjectForEntityForName:@"Checkin"
                                                                       inManagedObjectContext:[self managedObjectContext]];
        [messageObject setValue:message forKey:@"body"];
        [messageObject setValue:currentFBUserId forKey:@"accountFBUserID"];
        
        NSError *error = nil;
        [[self managedObjectContext] save:&error];
    }
}
//
-(NSArray *)checkinsFromStorage{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Checkin"
                                                         inManagedObjectContext:[self managedObjectContext]];
    
    [fetchRequest setEntity:entityDescription];
    
    NSError *error;
    NSArray* results = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    [fetchRequest release];
    return results;
}


#pragma mark -
#pragma mark Application's documents directory

/**
 Returns the path to the application's documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


@end
