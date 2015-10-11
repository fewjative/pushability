#import <UIKit/UIKit.h>
#import <substrate.h>

@interface SBFAnimationFactory
@end

@interface SBWindow : UIWindow
@end

static BOOL enabled = NO;
static BOOL activatingReachability = NO;
static BOOL deactivatingReachability = NO;
static SBFAnimationFactory * factory = nil;
static BOOL once = NO;
static BOOL twice = NO;
static BOOL aligning = NO;
static BOOL useDefault = YES;
static CGFloat yOffset = 0.3;
static CGRect defaultFirstRect;
static CGRect defaultSecondRect;

/*
	Wow. This code....it works but is ugly. 
*/

// for iOS9
%hook SBMainWorkspace

-(void)handleReachabilityModeActivated {
	NSLog(@"[Pushability]Activating reachability.");
	activatingReachability = YES;
	useDefault = NO;
	once = NO;
	%orig;
}

-(void)handleReachabilityModeDeactivated {
	NSLog(@"[Pushability]Deactivating reachability.");
	deactivatingReachability = YES;
	activatingReachability = NO;
	useDefault = NO;
	once = NO;
	%orig;
	factory = nil;
}

%end

%hook SBWorkspace

-(void)handleReachabilityModeActivated {
	NSLog(@"[Pushability]Activating reachability.");
	activatingReachability = YES;
	useDefault = NO;
	once = NO;
	%orig;
}

-(void)handleReachabilityModeDeactivated {
	NSLog(@"[Pushability]Deactivating reachability.");
	deactivatingReachability = YES;
	activatingReachability = NO;
	useDefault = NO;
	once = NO;
	%orig;
	factory = nil;
}

%end

%hook SBReachabilitySettings

-(id)animationFactory{
	id orig = %orig;
	factory = [orig copyWithZone:NULL];

	//I guess when a user taps on the reachability zone, handleReachabilityModeDeactivated is not called.
	//Thus, this fix is required so when setFrame is called, it has the proper booleans set so that it
	//will go into the deactivatingReachability branch.
	if(![[%c(SBReachabilityManager) sharedInstance] reachabilityModeActive] && activatingReachability)
	{
		NSLog(@"[Pushability]Tapped the reachability area.");
		activatingReachability = NO;
		deactivatingReachability = YES;
		useDefault = NO;
		once = NO;
	}
	return orig;
}

-(CGFloat)yOffsetFactor{
	CGFloat orig = %orig;
	yOffset = orig;
	return orig;
}

%end

%hook SBWindow

//When Reachability is activated, there are many calls to setFrame. If you log 'self', you will actually see that at some points
//the frame has both a negative origin x and y(don't know the reasoning for this). Ultimately, when reachability is activating, we only care
//about two calls to setFrame, the first sets the main app window and the second sets the reachability window. These calls happen AFTER the animation factory 
//is created. Thus, our goal is to us the original setFrame for everything BUT these two calls, which we will hijack and reposition reachability to
//show from the bottom of the screen. Similar logic used for when Reachability is deactivating.
-(void)setFrame:(CGRect)rect{

	if(!enabled || useDefault)
	{
		NSLog(@"[Pushability]Using the original setFrame.");
		%orig;
		return;
	}

	//Original logged self/incoming rect from an iPhone 5s
	//Self: (0 0 320 568)
	//Rect we change to: (0 170.4, 320  397.6)

	//Self: (0 0 320 0)
	//Rect we change to: (0 0 320 170.4)
	if(activatingReachability)
	{
		if(factory==nil)
		{
			useDefault = YES;
			%orig;
			useDefault = NO;
			return;
		}
		
		CGRect bottomsUp;

		if(self.frame.origin.x==0 && self.frame.origin.y==0 && !once)
		{
			NSLog(@"[Pushability]Modifying the first window(main app) - ReachActive");
			CGFloat height = [[UIScreen mainScreen] bounds].size.height;
			bottomsUp = CGRectMake(0,-height*yOffset,rect.size.width,height);

			useDefault = YES;
			[%c(SBFAnimationFactory) animateWithFactory:factory actions:^{
				self.frame = bottomsUp;
			} completion:^(BOOL finished){
			}];

			// for iOS9
			[%c(BSUIAnimationFactory) animateWithFactory:factory actions:^{
				self.frame = bottomsUp;
			} completion:^(BOOL finished){
			}];

			useDefault = NO;
			once = YES;
			NSLog(@"[Pushability]Finished modifying the first window: %@", self);
		}
		else if(self.frame.origin.y==0 && self.frame.size.height==0)
		{
			NSLog(@"[Pushability]Modifying the second window(reachability window) - ReachActive");
			//Realign the reachability frame so it is located at the bottom of the screen
			CGRect realign = CGRectMake(0,[[UIScreen mainScreen] bounds].size.height,rect.size.width,0);
			useDefault = YES;
			self.frame = realign;
			useDefault = NO;

			bottomsUp = CGRectMake(0,self.frame.origin.y-rect.size.height,rect.size.width,rect.size.height);

			useDefault = YES;
			[%c(SBFAnimationFactory) animateWithFactory:factory actions:^{
				self.frame = bottomsUp;
			} completion:^(BOOL finished){
			}];

			// for iOS9
			[%c(BSUIAnimationFactory) animateWithFactory:factory actions:^{
				self.frame = bottomsUp;
			} completion:^(BOOL finished){
			}];
			useDefault = NO;
			NSLog(@"[Pushability]Finished modifying the second window: %@", self);
		}
		else
		{
			useDefault = YES;
			%orig;
			useDefault = NO;
		}
	}
	else if(deactivatingReachability)
	{
		if(!once)
		{
			once = YES;
			useDefault = YES;
			%orig;
			useDefault = NO;
		}
		else
		{
			NSLog(@"[Pushability]Modifying the second window(reachability window) - ReachDeactive");

			CGRect topsUp = CGRectMake(0,[[UIScreen mainScreen] bounds].size.height,rect.size.width,self.frame.size.height);

			useDefault = YES;
			[%c(SBFAnimationFactory) animateWithFactory:factory actions:^{
				self.frame = topsUp;
			} completion:^(BOOL finished){
				//If we don't set the frame to the original incoming frame, the lockscreen gets messed up. Weird.
				useDefault = YES;
				self.frame = rect;
				useDefault =  NO;
			}];

			// for iOS9
			[%c(BSUIAnimationFactory) animateWithFactory:factory actions:^{
				self.frame = topsUp;
			} completion:^(BOOL finished){
				//If we don't set the frame to the original incoming frame, the lockscreen gets messed up. Weird.
				useDefault = YES;
				self.frame = rect;
				useDefault =  NO;
			}];
			useDefault = NO;
			factory = nil;
			NSLog(@"[Pushability]Finished modifying the second window: %@", self);
		}
	}
	else
		%orig;
}

%end


static void loadPrefs() 
{
	NSLog(@"Loading [Pushability] prefs");
    CFPreferencesAppSynchronize(CFSTR("com.joshdoctors.pushability"));

    enabled = !CFPreferencesCopyAppValue(CFSTR("enabled"), CFSTR("com.joshdoctors.pushability")) ? NO : [(id)CFPreferencesCopyAppValue(CFSTR("enabled"), CFSTR("com.joshdoctors.pushability")) boolValue];
    if (enabled) {
        NSLog(@"[Pushability] We are enabled");
    } else {
        NSLog(@"[Pushability] We are NOT enabled");
    }
}

%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                NULL,
                                (CFNotificationCallback)loadPrefs,
                                CFSTR("com.joshdoctors.pushability/settingschanged"),
                                NULL,
                                CFNotificationSuspensionBehaviorDeliverImmediately);
	loadPrefs();
}