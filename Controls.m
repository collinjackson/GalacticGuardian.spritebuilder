#import <GameController/GameController.h>

#import "ObjectiveChipmunk/ObjectiveChipmunk.h"

#import "Controls.h"


@interface VirtualJoystick : CCNode @end
@implementation VirtualJoystick {
	CGPoint _center;
	float _radius;
	
	CGPoint _value;
	
	__unsafe_unretained CCTouch *_trackingTouch;
}

-(instancetype)initWithSize:(CGFloat)size
{
	if((self = [super init])){
		self.contentSize = CGSizeMake(size, size);
		self.anchorPoint = ccp(0.5, 0.5);
	}
	
	return self;
}

-(void)onEnter
{
	[super onEnter];
	
	_center = self.position;
	_radius = self.contentSize.width/2.0;
	
	// Quick and dirty way to draw the joystick nub.
	CCDrawNode *drawNode = [CCDrawNode node];
	[self addChild:drawNode];
	
	[drawNode drawDot:self.anchorPointInPoints radius:_radius color:[CCColor colorWithWhite:1.0 alpha:0.5]];
	
	self.userInteractionEnabled = YES;
}

-(CGPoint)value {return _value;}

-(void)setTouchPosition:(CGPoint)touch
{
	CGPoint delta = cpvclamp(cpvsub(touch, _center), _radius);
	self.position = cpvadd(_center, delta);
	
	_value = cpvmult(delta, 1.0/_radius);
}

-(void)touchBegan:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
	if(_trackingTouch) return;
	
	CGPoint pos = [touch locationInNode:self.parent];
	if(cpvnear(_center, pos, _radius)){
		_trackingTouch = touch;
		self.touchPosition = pos;
	}
}

-(void)touchMoved:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
	if(touch == _trackingTouch){
		self.touchPosition = [touch locationInNode:self.parent];
	}
}

-(void)touchEnded:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
	if(touch == _trackingTouch){
		_trackingTouch = nil;
		self.touchPosition = _center;
	}
}

-(void)touchCancelled:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
	[self touchEnded:touch withEvent:event];
}

@end


@implementation Controls {
	VirtualJoystick *_virtualJoystick;
	
	GCController *_controller;
	GCControllerDirectionPad *_controllerStick;
	GCControllerDirectionPad *_controllerDpad;
	
	NSArray *_observers;
}

-(id)init
{
	if((self = [super init])){
		CGSize viewSize = [CCDirector sharedDirector].viewSize;
		
		CGFloat joystickOffset = viewSize.width/8.0;
		_virtualJoystick = [[VirtualJoystick alloc] initWithSize:joystickOffset];
		_virtualJoystick.position = ccp(joystickOffset, joystickOffset);
		[self addChild:_virtualJoystick];
		
		[self setupGamepadSupport];
	}
	
	return self;
}

-(void)logController:(GCController *)controller
{
	NSLog(@"Controller: %@", controller);
	NSLog(@"	Extended: %@", controller.extendedGamepad);
	NSLog(@"	VendorName: %@", controller.vendorName);
}

-(BOOL)activateController:(GCController *)controller
{
	if(_controller) return NO;
	
	_controllerStick = controller.extendedGamepad.leftThumbstick;
	_controllerDpad = controller.gamepad.dpad;
	
	if(_controllerStick || _controllerDpad){
		NSLog(@"Using controller %@", controller);
		
		controller.playerIndex = 0;
		_controller = controller;
		return YES;
	} else {
		controller.playerIndex = GCControllerPlayerIndexUnset;
		return NO;
	}
}

-(void)deactivateController:(GCController *)controller
{
	if(controller == _controller){
		_controller = nil;
		_controllerStick = nil;
	}
}

-(void)setupGamepadSupport
{
	NSArray *controllers = [GCController controllers];
	NSLog(@"%d controllers found.", (int)controllers.count);
	
	for(GCController *controller in controllers){
		[self logController:controller];
		if(_controller == nil) [self activateController:controller];
	}
	
	id connect = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:nil
		usingBlock:^(NSNotification *notification){
			NSLog(@"Controller connected.");
			GCController *controller = notification.object;
			[self logController:controller];
			[self activateController:controller];
		}
	];
	
	id disconnect = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification object:nil queue:nil
		usingBlock:^(NSNotification *notification){
			NSLog(@"Controller disconnected.");
			GCController *controller = notification.object;
			[self logController:controller];
			[self deactivateController:controller];
		}
	];
	
	_observers = @[connect, disconnect];
}

-(void)onExit
{
	for(id observer in _observers){
		[[NSNotificationCenter defaultCenter] removeObserver:observer];
	}
	
	[super onExit];
}

-(CGPoint)directionValue
{
	if(_controller){
		return cpvclamp(cpv(
			_controllerStick.xAxis.value + _controllerDpad.xAxis.value,
			_controllerStick.yAxis.value + _controllerDpad.yAxis.value
		), 1.0);
	} else {
		return _virtualJoystick.value;
	}
}

@end
